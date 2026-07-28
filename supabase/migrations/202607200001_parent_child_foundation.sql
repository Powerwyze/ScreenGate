-- Questime parent/child foundation. Apply through Supabase migrations after review.

alter table public.users
  add column if not exists account_role text not null default 'parent'
  check (account_role in ('parent', 'child'));

create table if not exists public.families (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  created_by uuid not null references public.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.family_members (
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null check (role in ('parent', 'child')),
  status text not null default 'active' check (status in ('invited', 'active', 'removed')),
  joined_at timestamptz not null default now(),
  primary key (family_id, user_id)
);

create table if not exists public.questime_devices (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  installation_id text not null unique,
  platform text not null default 'ios' check (platform in ('ios', 'android')),
  device_role text not null check (device_role in ('parent', 'child')),
  screen_time_authorized boolean not null default false,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.screen_time_rules (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  child_user_id uuid not null references public.users(id) on delete cascade,
  created_by uuid not null references public.users(id) on delete restrict,
  daily_limit_minutes integer not null default 90 check (daily_limit_minutes between 0 and 1440),
  reward_minutes integer not null default 15 check (reward_minutes between 1 and 240),
  blocked_selection jsonb not null default '{}'::jsonb,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.reward_requests (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  child_user_id uuid not null references public.users(id) on delete cascade,
  mission_id uuid references public.missions(id) on delete set null,
  requested_minutes integer not null check (requested_minutes between 1 and 240),
  status text not null default 'pending' check (status in ('pending', 'approved', 'denied', 'expired', 'used')),
  reviewed_by uuid references public.users(id) on delete set null,
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  expires_at timestamptz
);

create index if not exists family_members_user_idx on public.family_members(user_id);
create index if not exists questime_devices_family_idx on public.questime_devices(family_id);
create index if not exists screen_time_rules_child_idx on public.screen_time_rules(child_user_id);
create index if not exists reward_requests_child_status_idx on public.reward_requests(child_user_id, status);

create or replace function public.is_active_family_member(target_family_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.family_members
    where family_id = target_family_id
      and user_id = auth.uid()
      and status = 'active'
  );
$$;

create or replace function public.is_active_family_parent(target_family_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.family_members
    where family_id = target_family_id
      and user_id = auth.uid()
      and role = 'parent'
      and status = 'active'
  );
$$;

revoke all on function public.is_active_family_member(uuid) from public;
revoke all on function public.is_active_family_parent(uuid) from public;
grant execute on function public.is_active_family_member(uuid) to authenticated;
grant execute on function public.is_active_family_parent(uuid) to authenticated;

alter table public.families enable row level security;
alter table public.family_members enable row level security;
alter table public.questime_devices enable row level security;
alter table public.screen_time_rules enable row level security;
alter table public.reward_requests enable row level security;

create policy families_select_members on public.families
  for select using (public.is_active_family_member(id) or created_by = auth.uid());
create policy families_insert_parent on public.families
  for insert with check (created_by = auth.uid() and exists (
    select 1 from public.users where id = auth.uid() and account_role = 'parent'
  ));
create policy families_update_parents on public.families
  for update using (public.is_active_family_parent(id));

create policy family_members_select_family on public.family_members
  for select using (public.is_active_family_member(family_id) or user_id = auth.uid());
create policy family_members_insert_creator on public.family_members
  for insert with check (
    user_id = auth.uid()
    and role = 'parent'
    and status = 'active'
    and exists (
      select 1 from public.families
      where id = family_id and created_by = auth.uid()
    )
  );
create policy family_members_manage_parents on public.family_members
  for all using (public.is_active_family_parent(family_id))
  with check (public.is_active_family_parent(family_id));

create policy devices_select_family on public.questime_devices
  for select using (public.is_active_family_member(family_id));
create policy devices_insert_own on public.questime_devices
  for insert with check (user_id = auth.uid() and public.is_active_family_member(family_id));
create policy devices_update_owner_or_parent on public.questime_devices
  for update using (user_id = auth.uid() or public.is_active_family_parent(family_id));

create policy rules_select_family on public.screen_time_rules
  for select using (public.is_active_family_member(family_id));
create policy rules_manage_parents on public.screen_time_rules
  for all using (public.is_active_family_parent(family_id))
  with check (public.is_active_family_parent(family_id) and created_by = auth.uid());

create policy rewards_select_family on public.reward_requests
  for select using (public.is_active_family_member(family_id));
create policy rewards_request_child on public.reward_requests
  for insert with check (
    child_user_id = auth.uid()
    and public.is_active_family_member(family_id)
  );
create policy rewards_review_parent on public.reward_requests
  for update using (public.is_active_family_parent(family_id))
  with check (public.is_active_family_parent(family_id) and reviewed_by = auth.uid());
