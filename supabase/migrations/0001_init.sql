-- DayHop schema from the MVP spec, section 7.
-- Apply on an empty Supabase project. Auth tables come from Supabase.
create table households (
    id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 40),
  timezone text not null,
  owner_id uuid not null references auth.users(id),
  plan text not null default 'free' check (plan in ('free','plus')),
  plus_expires_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz default now(), updated_at timestamptz default now());

create table household_members (
    household_id uuid references households(id) on delete cascade,
  user_id uuid not null unique references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','guardian')),
  primary key (household_id, user_id));

create table kids (
    id uuid primary key default gen_random_uuid(),
  household_id uuid not null references households(id) on delete cascade,
  nickname text not null check (char_length(nickname) between 1 and 20),
  age_band text not null check (age_band in ('3-4','5-6','7-8','9-10','11+')),
  character_id text not null, accent text not null,
  stars_balance int not null default 0 check (stars_balance >= 0 and stars_balance <= 99999),
  lifetime_stars int not null default 0,
  streak_current int not null default 0, streak_best int not null default 0,
  archived_at timestamptz, deleted_at timestamptz);

create table routines (
    id uuid primary key default gen_random_uuid(),
  household_id uuid not null references households(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 30),
  time_of_day text not null check (time_of_day in ('morning','afternoon','evening','custom')),
  days smallint not null check (days between 1 and 127),
  start_time time, requires_approval boolean not null default false,
  bonus_stars smallint not null default 3 check (bonus_stars between 0 and 10),
  version int not null default 1, archived_at timestamptz);

create table routine_assignments (
    routine_id uuid references routines(id) on delete cascade,
  kid_id uuid references kids(id) on delete cascade,
  active boolean not null default true,
  primary key (routine_id, kid_id));

create table steps (
    id uuid primary key default gen_random_uuid(),
  routine_id uuid not null references routines(id) on delete cascade,
  position int not null, title text not null check (char_length(title) between 1 and 40),
  icon_key text not null, timer_minutes smallint, stars smallint not null default 1 check (stars between 0 and 5),
  archived_at timestamptz );

create table routine_runs (
    id uuid primary key,
  household_id uuid not null, kid_id uuid not null references kids(id) on delete cascade,
  routine_id uuid not null references routines(id), routine_date date not null,
  status text not null check (status in ('in_progress','pending_approval','approved','completed','reopened','expired')),
  steps_snapshot jsonb not null, routine_version int not null,
  submitted_at timestamptz, approved_at timestamptz, approved_by uuid, auto_approved boolean default false,
  unique (kid_id, routine_id, routine_date));

create table step_completions (
    id uuid primary key,
  run_id uuid not null references routine_runs(id) on delete cascade,
  step_id uuid not null, completed_at timestamptz not null default now(),
  client_time timestamptz, undone_at timestamptz,
  unique (run_id, step_id));

create table star_ledger (
    id uuid primary key,
  household_id uuid not null, kid_id uuid not null references kids(id) on delete cascade,
  amount int not null check (amount <> 0),
  type text not null check (type in ('step','routine_bonus','streak_bonus','redemption_hold','redemption_refund','adjustment','reversal')),
  ref_id uuid, note text check (char_length(note) <= 120), created_by uuid);

create table rewards (
    id uuid primary key default gen_random_uuid(),
  household_id uuid not null references households(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 40), icon_key text not null,
  cost smallint not null check (cost between 1 and 999), weekly_limit smallint, archived_at timestamptz);

create table redemptions (
    id uuid primary key, household_id uuid not null, kid_id uuid not null references kids(id) on delete cascade,
  reward_id uuid references rewards(id), reward_title text not null, cost int not null,
  status text not null check (status in ('requested','fulfilled','denied','cancelled')),
  requested_at timestamptz default now(), resolved_at timestamptz, resolved_by uuid);

create table invites (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references households(id) on delete cascade,
  code text not null unique check (char_length(code) = 8),
  expires_at timestamptz not null,
  used_by uuid,
  revoked_at timestamptz,
  created_at timestamptz default now()
);

create table consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  household_id uuid not null references households(id) on delete cascade,
  policy_version text not null,
  consented_at timestamptz not null default now()
);

create table streak_pauses (
  id uuid primary key default gen_random_uuid(),
  kid_id uuid not null references kids(id) on delete cascade,
  start_date date not null,
  end_date date not null
);

create table devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  expo_push_token text unique,
  timezone text,
  last_seen_at timestamptz
);

create table notification_prefs (
  user_id uuid primary key references auth.users(id) on delete cascade,
  quiet_start time not null default '21:00',
  quiet_end time not null default '07:00',
  toggles jsonb not null default '{}'::jsonb
);

create table notification_events (
  id uuid primary key default gen_random_uuid(),
  dedupe_key text not null unique,
  payload jsonb not null,
  sent_at timestamptz
);

create table rc_events (
  id text primary key,
  payload jsonb not null,
  created_at timestamptz default now()
);

create table app_config (
  key text primary key,
  value jsonb not null
);
