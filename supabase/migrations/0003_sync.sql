-- Household sync: timestamps, star balance trigger, remaining policies,
-- and the section 8 RPCs that 0002 did not include.
-- Apply after 0001_init.sql and 0002_rls_and_rpcs.sql.

alter table household_members add column if not exists created_at timestamptz default now();
alter table household_members add column if not exists updated_at timestamptz default now();
alter table kids add column if not exists created_at timestamptz default now();
alter table kids add column if not exists updated_at timestamptz default now();
alter table routines add column if not exists created_at timestamptz default now();
alter table routines add column if not exists updated_at timestamptz default now();
alter table routine_assignments add column if not exists created_at timestamptz default now();
alter table routine_assignments add column if not exists updated_at timestamptz default now();
alter table steps add column if not exists created_at timestamptz default now();
alter table steps add column if not exists updated_at timestamptz default now();
alter table routine_runs add column if not exists created_at timestamptz default now();
alter table routine_runs add column if not exists updated_at timestamptz default now();
alter table step_completions add column if not exists created_at timestamptz default now();
alter table step_completions add column if not exists updated_at timestamptz default now();
alter table star_ledger add column if not exists created_at timestamptz default now();
alter table star_ledger add column if not exists updated_at timestamptz default now();
alter table rewards add column if not exists created_at timestamptz default now();
alter table rewards add column if not exists updated_at timestamptz default now();
alter table redemptions add column if not exists created_at timestamptz default now();
alter table redemptions add column if not exists updated_at timestamptz default now();
alter table invites add column if not exists updated_at timestamptz default now();
alter table consents add column if not exists created_at timestamptz default now();
alter table consents add column if not exists updated_at timestamptz default now();
alter table streak_pauses add column if not exists created_at timestamptz default now();
alter table streak_pauses add column if not exists updated_at timestamptz default now();
alter table devices add column if not exists created_at timestamptz default now();
alter table devices add column if not exists updated_at timestamptz default now();
alter table notification_prefs add column if not exists created_at timestamptz default now();
alter table notification_prefs add column if not exists updated_at timestamptz default now();
alter table notification_events add column if not exists created_at timestamptz default now();
alter table notification_events add column if not exists updated_at timestamptz default now();
alter table rc_events add column if not exists updated_at timestamptz default now();
alter table app_config add column if not exists created_at timestamptz default now();
alter table app_config add column if not exists updated_at timestamptz default now();

create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array[
    'households','household_members','kids','routines','routine_assignments','steps',
    'routine_runs','step_completions','star_ledger','rewards','redemptions','invites',
    'consents','streak_pauses','devices','notification_prefs','notification_events',
    'rc_events','app_config'
  ]
  loop
    execute format('drop trigger if exists set_updated_at on %I', t);
    execute format('create trigger set_updated_at before update on %I for each row execute function set_updated_at()', t);
  end loop;
end $$;

create or replace function apply_star_ledger()
returns trigger
language plpgsql
as $$
declare
  next_balance int;
begin
  select stars_balance into next_balance from kids where id = new.kid_id for update;
  if next_balance is null then
    raise exception 'NOT_FOUND';
  end if;
  if new.amount < 0 and next_balance + new.amount < 0 then
    raise exception 'INSUFFICIENT_STARS';
  end if;
  if next_balance + new.amount > 99999 then
    new.amount := 99999 - next_balance;
  end if;
  if new.amount = 0 then
    return null;
  end if;
  update kids
  set stars_balance = least(99999, stars_balance + new.amount),
      lifetime_stars = lifetime_stars + case when new.amount > 0 then new.amount else 0 end
  where id = new.kid_id;
  return new;
end;
$$;

drop trigger if exists apply_star_ledger on star_ledger;
create trigger apply_star_ledger
before insert on star_ledger
for each row execute function apply_star_ledger();

drop policy if exists households_update on households;
create policy households_update on households
for update using (is_member(id)) with check (is_member(id));

drop policy if exists assignments_member on routine_assignments;
create policy assignments_member on routine_assignments
for all using (
  exists (select 1 from routines r where r.id = routine_id and is_member(r.household_id))
) with check (
  exists (select 1 from routines r where r.id = routine_id and is_member(r.household_id))
);

drop policy if exists invites_read on invites;
create policy invites_read on invites
for select using (is_member(household_id));

drop policy if exists consents_read on consents;
create policy consents_read on consents
for select using (user_id = auth.uid() and is_member(household_id));

drop policy if exists consents_insert on consents;
create policy consents_insert on consents
for insert with check (user_id = auth.uid() and is_member(household_id));

drop policy if exists pauses_member on streak_pauses;
create policy pauses_member on streak_pauses
for all using (
  exists (select 1 from kids k where k.id = kid_id and is_member(k.household_id))
) with check (
  exists (select 1 from kids k where k.id = kid_id and is_member(k.household_id))
);

alter table devices enable row level security;
alter table notification_prefs enable row level security;
alter table notification_events enable row level security;
alter table rc_events enable row level security;
alter table app_config enable row level security;

drop policy if exists devices_own on devices;
create policy devices_own on devices
for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists prefs_own on notification_prefs;
create policy prefs_own on notification_prefs
for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create or replace function create_household(household_name text, tz text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  existing uuid;
  hid uuid;
begin
  if auth.uid() is null then
    raise exception 'FORBIDDEN';
  end if;
  select household_id into existing from household_members where user_id = auth.uid();
  if existing is not null then
    return existing;
  end if;
  insert into households (name, timezone, owner_id)
  values (trim(household_name), coalesce(nullif(tz, ''), 'America/New_York'), auth.uid())
  returning id into hid;
  insert into household_members (household_id, user_id, role)
  values (hid, auth.uid(), 'owner');
  return hid;
end;
$$;

create or replace function approve_run(run_id uuid, reopen_step_ids uuid[] default '{}')
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  run routine_runs%rowtype;
  step jsonb;
  stars int;
  bonus int;
  entry uuid;
begin
  select * into run from routine_runs where id = run_id;
  if not found then return jsonb_build_object('error', 'NOT_FOUND'); end if;
  if not is_member(run.household_id) then return jsonb_build_object('error', 'FORBIDDEN'); end if;
  if run.status <> 'pending_approval' then return jsonb_build_object('error', 'ALREADY_HANDLED'); end if;
  if coalesce(array_length(reopen_step_ids, 1), 0) > 0 then
    update step_completions set undone_at = now()
    where step_completions.run_id = approve_run.run_id and step_id = any (reopen_step_ids);
    update routine_runs set status = 'reopened' where id = run_id;
    return jsonb_build_object('ok', true, 'status', 'reopened');
  end if;
  update routine_runs
  set status = 'approved', approved_at = now(), approved_by = auth.uid()
  where id = run_id;
  for step in select jsonb_array_elements(run.steps_snapshot)
  loop
    stars := coalesce((step->>'stars')::int, 0);
    if stars > 0 then
      entry := md5(run.id::text || (step->>'id') || 'step')::uuid;
      insert into star_ledger (id, household_id, kid_id, amount, type, ref_id)
      values (entry, run.household_id, run.kid_id, stars, 'step', (step->>'id')::uuid)
      on conflict (id) do nothing;
    end if;
  end loop;
  select r.bonus_stars into bonus from routines r where r.id = run.routine_id;
  if coalesce(bonus, 0) > 0 then
    entry := md5(run.id::text || 'bonus')::uuid;
    insert into star_ledger (id, household_id, kid_id, amount, type, ref_id)
    values (entry, run.household_id, run.kid_id, bonus, 'routine_bonus', run.routine_id)
    on conflict (id) do nothing;
  end if;
  return jsonb_build_object('ok', true, 'status', 'approved');
end;
$$;

create or replace function resolve_redemption(id uuid, action text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  rec redemptions%rowtype;
begin
  select * into rec from redemptions where redemptions.id = resolve_redemption.id for update;
  if not found then return jsonb_build_object('error', 'NOT_FOUND'); end if;
  if not is_member(rec.household_id) then return jsonb_build_object('error', 'FORBIDDEN'); end if;
  if rec.status <> 'requested' then return jsonb_build_object('error', 'ALREADY_HANDLED'); end if;
  if action = 'fulfilled' then
    update redemptions set status = 'fulfilled', resolved_at = now(), resolved_by = auth.uid()
    where redemptions.id = rec.id;
    return jsonb_build_object('ok', true);
  end if;
  if action in ('denied', 'cancelled') then
    insert into star_ledger (id, household_id, kid_id, amount, type, ref_id)
    values (md5(rec.id::text || action)::uuid, rec.household_id, rec.kid_id, rec.cost, 'redemption_refund', rec.reward_id)
    on conflict (id) do nothing;
    update redemptions set status = action, resolved_at = now(), resolved_by = auth.uid()
    where redemptions.id = rec.id;
    return jsonb_build_object('ok', true);
  end if;
  return jsonb_build_object('error', 'INVALID_DATE');
end;
$$;

create or replace function adjust_stars(entry_id uuid, kid_id uuid, amount int, note text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  hid uuid;
begin
  if amount = 0 or char_length(coalesce(note, '')) > 120 then
    return jsonb_build_object('error', 'INVALID_DATE');
  end if;
  select k.household_id into hid from kids k where k.id = kid_id;
  if hid is null or not is_member(hid) then return jsonb_build_object('error', 'FORBIDDEN'); end if;
  insert into star_ledger (id, household_id, kid_id, amount, type, note, created_by)
  values (entry_id, hid, kid_id, amount, 'adjustment', note, auth.uid())
  on conflict (id) do nothing;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function recompute_streak(kid_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  hid uuid;
  current_streak int := 0;
  best int;
  day date;
  expected date;
begin
  select k.household_id, k.streak_best into hid, best from kids k where k.id = kid_id;
  if hid is null or not is_member(hid) then return jsonb_build_object('error', 'FORBIDDEN'); end if;
  expected := household_routine_date((select timezone from households where id = hid), now());
  for day in
    select distinct r.routine_date
    from routine_runs r
    where r.kid_id = recompute_streak.kid_id
      and r.status in ('approved', 'completed')
    order by r.routine_date desc
  loop
    if day = expected or day = expected - 1 then
      current_streak := current_streak + 1;
      expected := day - 1;
    else
      exit;
    end if;
  end loop;
  best := greatest(coalesce(best, 0), current_streak);
  update kids set streak_current = current_streak, streak_best = best where id = kid_id;
  return jsonb_build_object('ok', true, 'streak', current_streak);
end;
$$;

create or replace function save_routine(routine jsonb, steps jsonb, expected_version int)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  hid uuid;
  rid uuid;
  current_version int;
  step jsonb;
begin
  hid := (routine->>'household_id')::uuid;
  rid := (routine->>'id')::uuid;
  if hid is null or rid is null or not is_member(hid) then
    return jsonb_build_object('error', 'FORBIDDEN');
  end if;
  select version into current_version from routines where id = rid;
  if current_version is not null and expected_version is not null and current_version <> expected_version then
    return jsonb_build_object('error', 'STALE_VERSION');
  end if;
  insert into routines (id, household_id, name, time_of_day, days, start_time, requires_approval, bonus_stars, version, archived_at)
  values (
    rid, hid, routine->>'name', routine->>'time_of_day', (routine->>'days')::int,
    nullif(routine->>'start_time', '')::time, coalesce((routine->>'requires_approval')::boolean, false),
    coalesce((routine->>'bonus_stars')::int, 3), coalesce(current_version, 0) + 1,
    nullif(routine->>'archived_at', '')::timestamptz
  )
  on conflict (id) do update set
    name = excluded.name,
    time_of_day = excluded.time_of_day,
    days = excluded.days,
    start_time = excluded.start_time,
    requires_approval = excluded.requires_approval,
    bonus_stars = excluded.bonus_stars,
    version = routines.version + 1,
    archived_at = excluded.archived_at;
  for step in select jsonb_array_elements(coalesce(steps, '[]'::jsonb))
  loop
    insert into steps (id, routine_id, position, title, icon_key, timer_minutes, stars, archived_at)
    values (
      (step->>'id')::uuid, rid, (step->>'position')::int, step->>'title', step->>'icon_key',
      nullif(step->>'timer_minutes', '')::int, coalesce((step->>'stars')::int, 1),
      nullif(step->>'archived_at', '')::timestamptz
    )
    on conflict (id) do update set
      position = excluded.position,
      title = excluded.title,
      icon_key = excluded.icon_key,
      timer_minutes = excluded.timer_minutes,
      stars = excluded.stars,
      archived_at = excluded.archived_at;
  end loop;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function create_invite(code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  hid uuid;
  invite_id uuid;
begin
  if char_length(code) <> 8 then return jsonb_build_object('error', 'INVITE_INVALID'); end if;
  select household_id into hid from household_members where user_id = auth.uid();
  if hid is null then return jsonb_build_object('error', 'FORBIDDEN'); end if;
  insert into invites (household_id, code, expires_at)
  values (hid, code, now() + interval '7 days')
  returning id into invite_id;
  return jsonb_build_object('ok', true, 'id', invite_id);
end;
$$;

create or replace function revoke_invite(invite_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  hid uuid;
begin
  select household_id into hid from invites where id = invite_id;
  if hid is null then return jsonb_build_object('error', 'NOT_FOUND'); end if;
  if not is_member(hid) then return jsonb_build_object('error', 'FORBIDDEN'); end if;
  update invites set revoked_at = now() where id = invite_id and revoked_at is null;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function accept_invite(code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  invite invites%rowtype;
begin
  if auth.uid() is null then return jsonb_build_object('error', 'FORBIDDEN'); end if;
  if exists (select 1 from household_members where user_id = auth.uid()) then
    return jsonb_build_object('error', 'ALREADY_HANDLED');
  end if;
  select * into invite from invites
  where invites.code = accept_invite.code and revoked_at is null and used_by is null and expires_at > now()
  for update;
  if not found then return jsonb_build_object('error', 'INVITE_INVALID'); end if;
  insert into household_members (household_id, user_id, role)
  values (invite.household_id, auth.uid(), 'guardian');
  update invites set used_by = auth.uid() where id = invite.id;
  return jsonb_build_object('ok', true, 'household_id', invite.household_id);
end;
$$;

create or replace function remove_guardian(member_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  hid uuid;
  member_role text;
begin
  select household_id, role into hid, member_role from household_members where user_id = member_id;
  if hid is null then return jsonb_build_object('error', 'NOT_FOUND'); end if;
  if not is_member(hid) or member_role <> 'guardian' then return jsonb_build_object('error', 'FORBIDDEN'); end if;
  delete from household_members where user_id = member_id and household_id = hid;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function leave_household()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  member_role text;
  hid uuid;
begin
  select role, household_id into member_role, hid from household_members where user_id = auth.uid();
  if hid is null then return jsonb_build_object('error', 'NOT_FOUND'); end if;
  if member_role = 'owner' then return jsonb_build_object('error', 'FORBIDDEN'); end if;
  delete from household_members where user_id = auth.uid() and household_id = hid;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function transfer_ownership(member_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  hid uuid;
  owner_role text;
begin
  select household_id, role into hid, owner_role from household_members where user_id = auth.uid();
  if hid is null or owner_role <> 'owner' then return jsonb_build_object('error', 'FORBIDDEN'); end if;
  if not exists (select 1 from household_members where user_id = member_id and household_id = hid and role = 'guardian') then
    return jsonb_build_object('error', 'NOT_FOUND');
  end if;
  update household_members set role = 'guardian' where user_id = auth.uid() and household_id = hid;
  update household_members set role = 'owner' where user_id = member_id and household_id = hid;
  update households set owner_id = member_id where id = hid;
  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function create_household(text, text) to authenticated;
grant execute on function approve_run(uuid, uuid[]) to authenticated;
grant execute on function resolve_redemption(uuid, text) to authenticated;
grant execute on function adjust_stars(uuid, uuid, int, text) to authenticated;
grant execute on function recompute_streak(uuid) to authenticated;
grant execute on function save_routine(jsonb, jsonb, int) to authenticated;
grant execute on function create_invite(text) to authenticated;
grant execute on function revoke_invite(uuid) to authenticated;
grant execute on function accept_invite(text) to authenticated;
grant execute on function remove_guardian(uuid) to authenticated;
grant execute on function leave_household() to authenticated;
grant execute on function transfer_ownership(uuid) to authenticated;

do $$
declare t text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    return;
  end if;
  foreach t in array array[
    'households','household_members','kids','routines','routine_assignments','steps',
    'routine_runs','step_completions','star_ledger','rewards','redemptions','invites',
    'consents','streak_pauses'
  ]
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
