-- Membership helper, RLS, and the kid-action RPCs from spec section 8.
-- Ledger writes and run writes are revoked from the authenticated role.

create or replace function is_member(hid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from household_members m
    where m.household_id = hid and m.user_id = auth.uid()
  );
$$;

alter table households enable row level security;
alter table household_members enable row level security;
alter table kids enable row level security;
alter table routines enable row level security;
alter table routine_assignments enable row level security;
alter table steps enable row level security;
alter table routine_runs enable row level security;
alter table step_completions enable row level security;
alter table star_ledger enable row level security;
alter table rewards enable row level security;
alter table redemptions enable row level security;
alter table invites enable row level security;
alter table consents enable row level security;
alter table streak_pauses enable row level security;

create policy households_read on households for select using (is_member(id));
create policy members_read on household_members for select using (is_member(household_id));
create policy kids_member on kids for all using (is_member(household_id)) with check (is_member(household_id));
create policy routines_member on routines for all using (is_member(household_id)) with check (is_member(household_id));
create policy steps_member on steps for all using (
  exists (select 1 from routines r where r.id = routine_id and is_member(r.household_id))
) with check (
  exists (select 1 from routines r where r.id = routine_id and is_member(r.household_id))
);
create policy rewards_member on rewards for all using (is_member(household_id)) with check (is_member(household_id));
create policy runs_read on routine_runs for select using (is_member(household_id));
create policy completions_read on step_completions for select using (
  exists (select 1 from routine_runs r where r.id = run_id and is_member(r.household_id))
);
create policy ledger_read on star_ledger for select using (is_member(household_id));
create policy redemptions_read on redemptions for select using (is_member(household_id));

revoke insert, update, delete on routine_runs from authenticated;
revoke insert, update, delete on step_completions from authenticated;
revoke insert, update, delete on star_ledger from authenticated;
revoke insert, update, delete on redemptions from authenticated;

create or replace function household_routine_date(tz text, at timestamptz)
returns date
language sql
stable
as $$
  select ((at at time zone tz) - interval '3 hours')::date;
$$;

create or replace function complete_step(
  completion_id uuid,
  kid_id uuid,
  routine_id uuid,
  routine_date date,
  step_id uuid,
  routine_version int,
  snapshot jsonb,
  client_time timestamptz
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  hid uuid;
  tz text;
  server_date date;
  run routine_runs%rowtype;
  step_stars int;
  requires boolean;
begin
  select k.household_id, h.timezone into hid, tz
  from kids k join households h on h.id = k.household_id
  where k.id = kid_id;
  if hid is null or not is_member(hid) then
    return jsonb_build_object('error', 'FORBIDDEN');
  end if;
  server_date := household_routine_date(tz, now());
  if abs(routine_date - server_date) > 1 then
    return jsonb_build_object('error', 'INVALID_DATE');
  end if;
  select * into run from routine_runs r
  where r.kid_id = complete_step.kid_id and r.routine_id = complete_step.routine_id and r.routine_date = complete_step.routine_date;
  if not found then
    insert into routine_runs (id, household_id, kid_id, routine_id, routine_date, status, steps_snapshot, routine_version)
    values (gen_random_uuid(), hid, kid_id, routine_id, routine_date, 'in_progress', snapshot, routine_version)
    returning * into run;
  end if;
  if run.status in ('approved', 'completed', 'pending_approval', 'expired') then
    return jsonb_build_object('error', 'ALREADY_HANDLED');
  end if;
  select (item->>'stars')::int into step_stars
  from jsonb_array_elements(snapshot) item
  where item->>'id' = step_id::text;
  if step_stars is null or step_stars < 0 or step_stars > 5 then
    return jsonb_build_object('error', 'INVALID_DATE');
  end if;
  insert into step_completions (id, run_id, step_id, client_time)
  values (completion_id, run.id, step_id, client_time)
  on conflict (run_id, step_id) do update set undone_at = null
  where step_completions.undone_at is not null;
  select r.requires_approval into requires from routines r where r.id = routine_id;
  if not requires and step_stars > 0 then
    insert into star_ledger (id, household_id, kid_id, amount, type, ref_id)
    values (completion_id, hid, kid_id, step_stars, 'step', step_id)
    on conflict (id) do nothing;
  end if;
  return jsonb_build_object('ok', true, 'run_id', run.id);
end;
$$;

create or replace function undo_step(completion_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  rec step_completions%rowtype;
  run routine_runs%rowtype;
begin
  select * into rec from step_completions where id = completion_id;
  if not found then return jsonb_build_object('error', 'NOT_FOUND'); end if;
  select * into run from routine_runs where id = rec.run_id;
  if not is_member(run.household_id) then return jsonb_build_object('error', 'FORBIDDEN'); end if;
  if run.status in ('approved', 'completed', 'pending_approval') then
    return jsonb_build_object('error', 'ALREADY_HANDLED');
  end if;
  update step_completions set undone_at = now() where id = completion_id;
  insert into star_ledger (id, household_id, kid_id, amount, type, ref_id)
  select gen_random_uuid(), run.household_id, run.kid_id, -l.amount, 'reversal', rec.step_id
  from star_ledger l where l.id = completion_id;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function request_reward(redemption_id uuid, kid_id uuid, reward_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  hid uuid;
  bal int;
  price int;
  title text;
  plan text;
begin
  select k.household_id, k.stars_balance into hid, bal from kids k where k.id = kid_id for update;
  if hid is null or not is_member(hid) then return jsonb_build_object('error', 'FORBIDDEN'); end if;
  select h.plan into plan from households h where h.id = hid;
  if plan <> 'plus' then return jsonb_build_object('error', 'PLAN_REQUIRED'); end if;
  select r.cost, r.title into price, title from rewards r where r.id = reward_id and r.household_id = hid and r.archived_at is null;
  if price is null then return jsonb_build_object('error', 'NOT_FOUND'); end if;
  if bal < price then return jsonb_build_object('error', 'INSUFFICIENT_STARS', 'short', price - bal); end if;
  insert into star_ledger (id, household_id, kid_id, amount, type, ref_id)
  values (redemption_id, hid, kid_id, -price, 'redemption_hold', reward_id);
  insert into redemptions (id, household_id, kid_id, reward_id, reward_title, cost, status)
  values (redemption_id, hid, kid_id, reward_id, title, price, 'requested');
  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function complete_step(uuid, uuid, uuid, date, uuid, int, jsonb, timestamptz) to authenticated;
grant execute on function undo_step(uuid) to authenticated;
grant execute on function request_reward(uuid, uuid, uuid) to authenticated;
