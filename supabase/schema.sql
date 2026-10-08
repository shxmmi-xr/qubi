-- ============================================================
-- FEST ATM — Complete Supabase Schema
-- Run this in Supabase SQL Editor
-- ============================================================

-- Enable UUID extension
create extension if not exists "pgcrypto";

-- ─────────────────────────────────────────────
-- TEAMS
-- ─────────────────────────────────────────────
create table if not exists teams (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  color text not null default '#6C0E0E',
  created_at timestamptz not null default now()
);

insert into teams (name, color) values
  ('DAHFATAHAN', '#6C0E0E'),
  ('BADFATHAN',  '#1E3A5F')
on conflict (name) do nothing;

-- ─────────────────────────────────────────────
-- PARTICIPANTS
-- ─────────────────────────────────────────────
create table if not exists atm_participants (
  id              uuid primary key default gen_random_uuid(),
  participant_id  text not null unique,   -- e.g. "KUIA-101"
  name            text not null,
  photo_url       text,
  team            text references teams(name),
  category        text,                   -- Sub Junior | Junior | Senior
  chest_no        int unique,
  class           text,
  phone           text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ─────────────────────────────────────────────
-- KIOSKS
-- ─────────────────────────────────────────────
create table if not exists atm_kiosks (
  id          uuid primary key default gen_random_uuid(),
  kiosk_id    text not null unique,       -- e.g. "KIOSK-01"
  name        text not null,
  location    text,
  status      text not null default 'OFFLINE', -- ONLINE | OFFLINE
  last_active timestamptz,
  created_at  timestamptz not null default now()
);

insert into atm_kiosks (kiosk_id, name, location, status) values
  ('KIOSK-01', 'Main Entrance Kiosk', 'Gate 1', 'ONLINE'),
  ('KIOSK-02', 'Canteen Kiosk',       'Canteen Area', 'OFFLINE'),
  ('KIOSK-03', 'Game Arena Kiosk',    'Game Zone', 'OFFLINE')
on conflict (kiosk_id) do nothing;

-- ─────────────────────────────────────────────
-- TOKENS
-- ─────────────────────────────────────────────
create table if not exists atm_tokens (
  id             uuid primary key default gen_random_uuid(),
  token          text not null unique,
  token_type     text not null,  -- ATTENDANCE | CANTEEN | GAME | SPECIAL
  participant_id uuid references atm_participants(id),
  status         text not null default 'ACTIVE', -- ACTIVE | USED | EXPIRED | BLOCKED | CANCELLED
  created_at     timestamptz not null default now(),
  used_at        timestamptz,
  expires_at     timestamptz,
  metadata       jsonb default '{}',
  created_by     text
);

create index if not exists idx_atm_tokens_token on atm_tokens(token);
create index if not exists idx_atm_tokens_participant on atm_tokens(participant_id);
create index if not exists idx_atm_tokens_type on atm_tokens(token_type);
create index if not exists idx_atm_tokens_status on atm_tokens(status);

-- ─────────────────────────────────────────────
-- ATTENDANCE LOGS
-- ─────────────────────────────────────────────
create table if not exists atm_attendance_logs (
  id             uuid primary key default gen_random_uuid(),
  participant_id uuid not null references atm_participants(id),
  token_id       uuid references atm_tokens(id),
  kiosk_id       text references atm_kiosks(kiosk_id),
  scan_time      timestamptz not null default now(),
  status         text not null default 'PRESENT'
);

create index if not exists idx_attendance_participant on atm_attendance_logs(participant_id);
create index if not exists idx_attendance_scan_time  on atm_attendance_logs(scan_time);

-- ─────────────────────────────────────────────
-- CANTEEN TOKENS
-- ─────────────────────────────────────────────
create table if not exists atm_canteen_tokens (
  id             uuid primary key default gen_random_uuid(),
  token_id       uuid not null unique references atm_tokens(id),
  participant_id uuid references atm_participants(id),
  item           text not null default 'Meal',   -- Lunch | Dinner | Snacks | Special
  value          numeric(10,2) default 0,
  status         text not null default 'ACTIVE', -- ACTIVE | REDEEMED | CANCELLED
  redeemed_at    timestamptz,
  redeemed_by    text,
  kiosk_id       text references atm_kiosks(kiosk_id),
  created_at     timestamptz not null default now()
);

create index if not exists idx_canteen_status on atm_canteen_tokens(status);

-- ─────────────────────────────────────────────
-- GAME SESSIONS
-- ─────────────────────────────────────────────
create table if not exists atm_game_sessions (
  id             uuid primary key default gen_random_uuid(),
  token_id       uuid references atm_tokens(id),
  participant_id uuid references atm_participants(id),
  player_name    text not null,
  team           text,
  kiosk_id       text references atm_kiosks(kiosk_id),
  score          int not null default 0,
  accuracy       numeric(5,2) default 0,
  combo_max      int default 0,
  duration_secs  int default 30,
  status         text not null default 'IN_PROGRESS', -- IN_PROGRESS | COMPLETED | ABANDONED
  started_at     timestamptz not null default now(),
  ended_at       timestamptz,
  created_at     timestamptz not null default now()
);

create index if not exists idx_game_score      on atm_game_sessions(score desc);
create index if not exists idx_game_participant on atm_game_sessions(participant_id);
create index if not exists idx_game_status     on atm_game_sessions(status);

-- ─────────────────────────────────────────────
-- EXPERIENCE PAGES (Special Token Routing)
-- ─────────────────────────────────────────────
create table if not exists atm_experience_pages (
  id          uuid primary key default gen_random_uuid(),
  slug        text not null unique,
  title       text not null,
  description text,
  content     jsonb default '{}',
  status      text not null default 'ACTIVE', -- ACTIVE | INACTIVE
  created_at  timestamptz not null default now()
);

-- ─────────────────────────────────────────────
-- SPECIAL TOKENS
-- ─────────────────────────────────────────────
create table if not exists atm_special_tokens (
  id            uuid primary key default gen_random_uuid(),
  token_id      uuid not null unique references atm_tokens(id),
  experience_id uuid references atm_experience_pages(id),
  status        text not null default 'ACTIVE',
  created_at    timestamptz not null default now()
);

-- ─────────────────────────────────────────────
-- SCAN LOGS (all scans, for audit trail)
-- ─────────────────────────────────────────────
create table if not exists atm_scan_logs (
  id          uuid primary key default gen_random_uuid(),
  raw_token   text not null,
  token_id    uuid references atm_tokens(id),
  token_type  text,
  kiosk_id    text references atm_kiosks(kiosk_id),
  result      text not null, -- SUCCESS | INVALID | ALREADY_USED | EXPIRED | BLOCKED | ERROR
  participant_id uuid references atm_participants(id),
  scan_time   timestamptz not null default now(),
  metadata    jsonb default '{}'
);

create index if not exists idx_scan_logs_time   on atm_scan_logs(scan_time desc);
create index if not exists idx_scan_logs_kiosk  on atm_scan_logs(kiosk_id);
create index if not exists idx_scan_logs_result on atm_scan_logs(result);

-- ─────────────────────────────────────────────
-- SETTINGS
-- ─────────────────────────────────────────────
create table if not exists atm_settings (
  id    uuid primary key default gen_random_uuid(),
  key   text not null unique,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

insert into atm_settings (key, value) values
  ('sound_enabled',           'true'),
  ('scan_beep_enabled',       'true'),
  ('success_sound_enabled',   'true'),
  ('error_sound_enabled',     'true'),
  ('game_sounds_enabled',     'true'),
  ('master_volume',           '75'),
  ('success_display_duration','3'),
  ('game_duration_secs',      '30'),
  ('game_token_required',     'true'),
  ('allow_duplicate_attendance', 'false')
on conflict (key) do nothing;

-- ─────────────────────────────────────────────
-- DEMO PARTICIPANTS (20 participants, 2 teams)
-- ─────────────────────────────────────────────
insert into atm_participants (participant_id, name, team, category, chest_no) values
  ('KUIA-101', 'Ahamad Muzammil',  'DAHFATAHAN', 'Senior',    101),
  ('KUIA-102', 'Mohammed Ameen',   'DAHFATAHAN', 'Senior',    102),
  ('KUIA-103', 'Abdul Shamil',     'DAHFATAHAN', 'Junior',    103),
  ('KUIA-104', 'Riyas Ahammed',    'DAHFATAHAN', 'Junior',    104),
  ('KUIA-105', 'Faris Muhammed',   'DAHFATAHAN', 'Sub Junior',105),
  ('KUIA-106', 'Shafeel Ahammed',  'DAHFATAHAN', 'Sub Junior',106),
  ('KUIA-107', 'Ashraf Nizar',     'DAHFATAHAN', 'Senior',    107),
  ('KUIA-108', 'Bilal Rashid',     'DAHFATAHAN', 'Junior',    108),
  ('KUIA-109', 'Haroon Siddiq',    'DAHFATAHAN', 'Sub Junior',109),
  ('KUIA-110', 'Zaid Farhan',      'DAHFATAHAN', 'Junior',    110),
  ('KUIA-201', 'Irfan Basheer',    'BADFATHAN',  'Senior',    201),
  ('KUIA-202', 'Nabeel Shihab',    'BADFATHAN',  'Senior',    202),
  ('KUIA-203', 'Salman Farsi',     'BADFATHAN',  'Junior',    203),
  ('KUIA-204', 'Yusuf Zakir',      'BADFATHAN',  'Junior',    204),
  ('KUIA-205', 'Rayhan Aziz',      'BADFATHAN',  'Sub Junior',205),
  ('KUIA-206', 'Taha Ibrahim',     'BADFATHAN',  'Sub Junior',206),
  ('KUIA-207', 'Khalid Usman',     'BADFATHAN',  'Senior',    207),
  ('KUIA-208', 'Zakariya Noor',    'BADFATHAN',  'Junior',    208),
  ('KUIA-209', 'Hamdan Shaikh',    'BADFATHAN',  'Sub Junior',209),
  ('KUIA-210', 'Ismail Shuaib',    'BADFATHAN',  'Junior',    210)
on conflict (participant_id) do nothing;

-- ─────────────────────────────────────────────
-- DEMO TOKENS
-- ─────────────────────────────────────────────
-- We insert tokens by referencing participants via subquery
-- Attendance tokens (ATT-XXXXXXXX)
insert into atm_tokens (token, token_type, participant_id, status)
select
  'ATT-' || lpad(cast(chest_no as text), 3, '0') || '-DEMO',
  'ATTENDANCE',
  id,
  'ACTIVE'
from atm_participants
on conflict (token) do nothing;

-- Canteen tokens
insert into atm_tokens (token, token_type, participant_id, status, metadata)
select
  'CAN-' || lpad(cast(chest_no as text), 3, '0') || '-LUNCH',
  'CANTEEN',
  id,
  'ACTIVE',
  '{"item":"Lunch"}'
from atm_participants
on conflict (token) do nothing;

-- Game tokens
insert into atm_tokens (token, token_type, participant_id, status, metadata)
select
  'GAME-' || lpad(cast(chest_no as text), 3, '0') || '-P1',
  'GAME',
  id,
  'ACTIVE',
  '{"price":20}'
from atm_participants
on conflict (token) do nothing;

-- Canteen records
insert into atm_canteen_tokens (token_id, participant_id, item, status)
select
  t.id,
  t.participant_id,
  'Lunch',
  'ACTIVE'
from atm_tokens t
where t.token_type = 'CANTEEN'
on conflict (token_id) do nothing;

-- ─────────────────────────────────────────────
-- ROW LEVEL SECURITY
-- ─────────────────────────────────────────────

alter table atm_participants enable row level security;
alter table atm_tokens enable row level security;
alter table atm_attendance_logs enable row level security;
alter table atm_canteen_tokens enable row level security;
alter table atm_game_sessions enable row level security;
alter table atm_scan_logs enable row level security;
alter table atm_kiosks enable row level security;
alter table atm_settings enable row level security;
alter table atm_experience_pages enable row level security;
alter table atm_special_tokens enable row level security;
alter table teams enable row level security;

-- Allow public (anon) read on teams and kiosk status
create policy "public_read_teams" on teams for select using (true);
create policy "public_read_kiosks" on atm_kiosks for select using (true);

-- Service role bypass (API routes use service key)
create policy "service_all_participants"  on atm_participants  using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "service_all_tokens"        on atm_tokens        using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "service_all_attendance"    on atm_attendance_logs using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "service_all_canteen"       on atm_canteen_tokens using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "service_all_game"          on atm_game_sessions using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "service_all_scan_logs"     on atm_scan_logs     using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "service_all_kiosks"        on atm_kiosks        using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "service_all_settings"      on atm_settings      using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "service_all_experience"    on atm_experience_pages using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy "service_all_special"       on atm_special_tokens using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

-- Allow authenticated admin users to read all
create policy "auth_read_participants"    on atm_participants      for select using (auth.role() = 'authenticated');
create policy "auth_read_tokens"          on atm_tokens            for select using (auth.role() = 'authenticated');
create policy "auth_read_attendance"      on atm_attendance_logs   for select using (auth.role() = 'authenticated');
create policy "auth_read_canteen"         on atm_canteen_tokens    for select using (auth.role() = 'authenticated');
create policy "auth_read_game"            on atm_game_sessions     for select using (auth.role() = 'authenticated');
create policy "auth_read_scan_logs"       on atm_scan_logs         for select using (auth.role() = 'authenticated');
create policy "auth_read_settings"        on atm_settings          for select using (auth.role() = 'authenticated');
create policy "auth_read_experience"      on atm_experience_pages  for select using (auth.role() = 'authenticated');

-- Leaderboard: public can read completed game sessions (for live scoreboard)
create policy "public_leaderboard" on atm_game_sessions
  for select using (status = 'COMPLETED');
