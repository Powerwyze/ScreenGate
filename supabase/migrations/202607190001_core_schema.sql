-- Questime core schema for clean Supabase projects.

create extension if not exists pgcrypto;

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  codename text not null,
  avatar_url text,
  selected_handler_id text not null default 'handler_1',
  life_goals text not null default '',
  total_stars integer not null default 0 check (total_stars >= 0),
  level integer not null default 0 check (level >= 0),
  current_streak integer not null default 0 check (current_streak >= 0),
  longest_streak integer not null default 0 check (longest_streak >= 0),
  fcm_token text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.missions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 160),
  description text not null default '',
  completed_state text not null default '',
  type text not null check (type in ('selfAssigned', 'aiSuggested', 'friendAssigned', 'recurring')),
  status text not null default 'pending' check (status in ('pending', 'inProgress', 'completed', 'verified', 'failed')),
  deadline timestamptz,
  recurrence_pattern text,
  before_photo_url text,
  after_photo_url text,
  stars_earned integer not null default 0 check (stars_earned >= 0),
  ai_feedback text,
  assigned_by_user_id uuid references public.users(id) on delete set null,
  assigned_to_user_id uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz
);

create index if not exists missions_user_status_idx
  on public.missions(user_id, status, created_at desc);
create index if not exists missions_assigned_to_idx
  on public.missions(assigned_to_user_id, created_at desc);

alter table public.users enable row level security;
alter table public.missions enable row level security;

create policy users_select_authenticated on public.users
  for select to authenticated using (true);
create policy users_insert_own on public.users
  for insert to authenticated with check (id = auth.uid());
create policy users_update_own on public.users
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy users_delete_own on public.users
  for delete to authenticated using (id = auth.uid());

create policy missions_select_involved on public.missions
  for select to authenticated using (
    user_id = auth.uid()
    or assigned_by_user_id = auth.uid()
    or assigned_to_user_id = auth.uid()
  );
create policy missions_insert_involved on public.missions
  for insert to authenticated with check (
    user_id = auth.uid()
    or assigned_by_user_id = auth.uid()
  );
create policy missions_update_involved on public.missions
  for update to authenticated using (
    user_id = auth.uid()
    or assigned_by_user_id = auth.uid()
    or assigned_to_user_id = auth.uid()
  );
create policy missions_delete_owner on public.missions
  for delete to authenticated using (user_id = auth.uid());

insert into storage.buckets (id, name, public)
values ('user-uploads', 'user-uploads', true)
on conflict (id) do nothing;

create policy uploads_read_authenticated on storage.objects
  for select to authenticated using (bucket_id = 'user-uploads');
create policy uploads_insert_own on storage.objects
  for insert to authenticated with check (
    bucket_id = 'user-uploads'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy uploads_update_own on storage.objects
  for update to authenticated using (
    bucket_id = 'user-uploads'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy uploads_delete_own on storage.objects
  for delete to authenticated using (
    bucket_id = 'user-uploads'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
