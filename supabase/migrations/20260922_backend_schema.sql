-- UABJ OPTICA Student Chapter Election
-- Sanitized backend schema export. No voter credentials, hashes, ballots or receipts are included.
create extension if not exists pgcrypto;

create table if not exists public.election_config (
  id smallint primary key default 1 check (id=1),
  title text not null default 'ELEIÇÃO DA PRIMEIRA DIRETORIA',
  chapter_name text not null default 'UABJ OPTICA STUDENT CHAPTER',
  term text not null default '2026–2027',
  faculty_advisor text not null default 'Prof. Dr. Sabi Yari Moïse Bandiri',
  status text not null default 'closed' check (status in ('closed','open')),
  opened_at timestamptz,
  closed_at timestamptz,
  updated_at timestamptz not null default now()
);
create table if not exists public.positions (
  id bigint generated always as identity primary key,
  code text not null unique,
  name text not null,
  ballot_type text not null check (ballot_type in ('competitive','confirmation','indication')),
  sort_order integer not null
);
create table if not exists public.candidates (
  id bigint generated always as identity primary key,
  position_id bigint not null references public.positions(id),
  name text not null,
  consent_status text not null default 'confirmed' check (consent_status in ('confirmed','pending','declined')),
  active boolean not null default true
);
create table if not exists public.members (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.eligible_voters (
  id uuid primary key default gen_random_uuid(),
  voter_code_hash text not null unique,
  display_name text,
  has_voted boolean not null default false,
  voted_at timestamptz,
  created_at timestamptz not null default now()
);
create table if not exists public.ballots (
  id uuid primary key default gen_random_uuid(),
  receipt_code text not null unique,
  submitted_at timestamptz not null default now()
);
create table if not exists public.ballot_choices (
  id bigint generated always as identity primary key,
  ballot_id uuid not null references public.ballots(id),
  position_id bigint not null references public.positions(id),
  candidate_id bigint references public.candidates(id),
  choice_type text not null check (choice_type in ('candidate','blank','confirm','not_confirm','self_candidate','nominate','no_nomination')),
  nominated_member_id uuid references public.members(id),
  unique(ballot_id,position_id)
);
create table if not exists public.participation_log (
  id bigint generated always as identity primary key,
  voter_id uuid not null unique references public.eligible_voters(id),
  receipt_hash text not null unique,
  recorded_at timestamptz not null default now()
);
create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id),
  email text not null unique,
  created_at timestamptz not null default now()
);
create index if not exists idx_candidates_position on public.candidates(position_id);
create index if not exists idx_choices_position on public.ballot_choices(position_id);
create index if not exists idx_choices_candidate on public.ballot_choices(candidate_id);
create index if not exists idx_choices_nominee on public.ballot_choices(nominated_member_id);

alter table public.election_config enable row level security;
alter table public.positions enable row level security;
alter table public.candidates enable row level security;
alter table public.members enable row level security;
alter table public.eligible_voters enable row level security;
alter table public.ballots enable row level security;
alter table public.ballot_choices enable row level security;
alter table public.participation_log enable row level security;
alter table public.admin_users enable row level security;

create policy public_read_election_config on public.election_config for select to anon,authenticated using (true);
create policy public_read_positions on public.positions for select to anon,authenticated using (true);
create policy public_read_active_candidates on public.candidates for select to anon,authenticated using (active=true);
create policy public_read_active_members on public.members for select to anon,authenticated using (active=true);

revoke all on public.eligible_voters,public.ballots,public.ballot_choices,public.participation_log,public.admin_users from anon,authenticated;
