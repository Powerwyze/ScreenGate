create table if not exists public.solo_reward_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  mission_id uuid not null unique references public.missions(id) on delete cascade,
  requested_minutes integer not null check (requested_minutes between 1 and 60),
  status text not null default 'approved' check (status in ('approved', 'used')),
  created_at timestamptz not null default now(),
  used_at timestamptz
);

create index if not exists solo_reward_requests_user_day_idx
  on public.solo_reward_requests(user_id, created_at, status);

alter table public.solo_reward_requests enable row level security;

create policy solo_reward_requests_select_own
  on public.solo_reward_requests for select
  using (user_id = auth.uid());
