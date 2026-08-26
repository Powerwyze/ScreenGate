-- Separate Family and Solo profiles while adding the communication tables used
-- by the mobile app. Existing IDs stay attached to Family data; existing Solo
-- rows are split into a clean Solo profile so family tasks never leak into it.

alter table public.users drop constraint if exists users_id_fkey;
alter table public.users
  add column if not exists auth_user_id uuid references auth.users(id) on delete cascade;

update public.users
set auth_user_id = id
where auth_user_id is null
  and exists (select 1 from auth.users a where a.id = public.users.id);

with existing_solo as (
  select * from public.users where usage_mode = 'solo' and auth_user_id = id
)
insert into public.users (
  id, auth_user_id, email, codename, avatar_url, selected_handler_id,
  life_goals, account_role, usage_mode, total_stars, level,
  current_streak, longest_streak, created_at, updated_at
)
select
  gen_random_uuid(), id, email, codename, avatar_url, selected_handler_id,
  'Block distractions and build focused habits.', 'parent', 'solo', 0, 1,
  0, 0, now(), now()
from existing_solo
where not exists (
  select 1 from public.users other
  where other.auth_user_id = existing_solo.id
    and other.usage_mode = 'solo'
    and other.id <> existing_solo.id
);

update public.users
set usage_mode = 'family', auth_user_id = id, updated_at = now()
where usage_mode = 'solo' and auth_user_id = id;

create unique index if not exists users_auth_mode_unique
  on public.users(auth_user_id, usage_mode)
  where auth_user_id is not null and account_role <> 'child';
create index if not exists users_auth_user_id_idx on public.users(auth_user_id);

create table if not exists public.friends (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  friend_user_id uuid not null references public.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (user_id <> friend_user_id),
  unique (user_id, friend_user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.users(id) on delete cascade,
  receiver_id uuid not null references public.users(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 4000),
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  type text not null,
  title text not null,
  message text not null,
  data jsonb,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null check (role in ('user', 'handler')),
  content text not null check (char_length(content) between 1 and 8000),
  created_at timestamptz not null default now()
);

create table if not exists public.bug_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  user_email text not null,
  title text not null,
  description text not null,
  severity text not null check (severity in ('low', 'medium', 'high', 'critical')),
  status text not null default 'open' check (status in ('open', 'inProgress', 'resolved', 'closed')),
  device_info text,
  app_version text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists friends_user_idx on public.friends(user_id, status);
create index if not exists friends_friend_idx on public.friends(friend_user_id, status);
create index if not exists messages_pair_idx on public.messages(sender_id, receiver_id, created_at);
create index if not exists notifications_user_idx on public.notifications(user_id, created_at desc);
create index if not exists chat_messages_user_idx on public.chat_messages(user_id, created_at);
create index if not exists bug_reports_user_idx on public.bug_reports(user_id, created_at desc);

alter table public.friends enable row level security;
alter table public.messages enable row level security;
alter table public.notifications enable row level security;
alter table public.chat_messages enable row level security;
alter table public.bug_reports enable row level security;

drop policy if exists users_insert_own on public.users;
drop policy if exists users_update_own on public.users;
drop policy if exists users_delete_own on public.users;
create policy users_insert_own on public.users for insert to authenticated
  with check (auth_user_id = auth.uid() or id = auth.uid());
create policy users_update_own on public.users for update to authenticated
  using (auth_user_id = auth.uid() or id = auth.uid())
  with check (auth_user_id = auth.uid() or id = auth.uid());
create policy users_delete_own on public.users for delete to authenticated
  using (auth_user_id = auth.uid() or id = auth.uid());

drop policy if exists missions_select_involved on public.missions;
drop policy if exists missions_insert_involved on public.missions;
drop policy if exists missions_update_involved on public.missions;
drop policy if exists missions_delete_owner on public.missions;
create policy missions_select_involved on public.missions for select to authenticated using (
  exists (select 1 from public.users u where u.id in (user_id, assigned_by_user_id, assigned_to_user_id)
    and (u.auth_user_id = auth.uid() or u.id = auth.uid()))
);
create policy missions_insert_involved on public.missions for insert to authenticated with check (
  exists (select 1 from public.users u where u.id in (user_id, assigned_by_user_id)
    and (u.auth_user_id = auth.uid() or u.id = auth.uid()))
);
create policy missions_update_involved on public.missions for update to authenticated using (
  exists (select 1 from public.users u where u.id in (user_id, assigned_by_user_id, assigned_to_user_id)
    and (u.auth_user_id = auth.uid() or u.id = auth.uid()))
);
create policy missions_delete_owner on public.missions for delete to authenticated using (
  exists (select 1 from public.users u where u.id = user_id
    and (u.auth_user_id = auth.uid() or u.id = auth.uid()))
);

create policy friends_involved on public.friends for all to authenticated
  using (exists (select 1 from public.users u where u.id in (user_id, friend_user_id)
    and (u.auth_user_id = auth.uid() or u.id = auth.uid())))
  with check (exists (select 1 from public.users u where u.id = user_id
    and u.usage_mode = 'solo' and u.auth_user_id = auth.uid()));
create policy messages_involved on public.messages for all to authenticated
  using (exists (select 1 from public.users u where u.id in (sender_id, receiver_id)
    and (u.auth_user_id = auth.uid() or u.id = auth.uid())))
  with check (exists (select 1 from public.users u where u.id = sender_id and u.auth_user_id = auth.uid()));
create policy notifications_read_own on public.notifications for select to authenticated
  using (exists (select 1 from public.users u where u.id = user_id and (u.auth_user_id = auth.uid() or u.id = auth.uid())));
create policy notifications_insert_involved on public.notifications for insert to authenticated
  with check (exists (select 1 from public.users u where u.id = user_id));
create policy notifications_update_own on public.notifications for update to authenticated
  using (exists (select 1 from public.users u where u.id = user_id and (u.auth_user_id = auth.uid() or u.id = auth.uid())));
create policy notifications_delete_own on public.notifications for delete to authenticated
  using (exists (select 1 from public.users u where u.id = user_id and (u.auth_user_id = auth.uid() or u.id = auth.uid())));
create policy chat_messages_own on public.chat_messages for all to authenticated
  using (exists (select 1 from public.users u where u.id = user_id and u.auth_user_id = auth.uid()))
  with check (exists (select 1 from public.users u where u.id = user_id and u.auth_user_id = auth.uid()));
create policy bug_reports_own on public.bug_reports for all to authenticated
  using (exists (select 1 from public.users u where u.id = user_id and (u.auth_user_id = auth.uid() or u.id = auth.uid())))
  with check (exists (select 1 from public.users u where u.id = user_id and (u.auth_user_id = auth.uid() or u.id = auth.uid())));

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages') then
    alter publication supabase_realtime add table public.messages;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications') then
    alter publication supabase_realtime add table public.notifications;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'chat_messages') then
    alter publication supabase_realtime add table public.chat_messages;
  end if;
end $$;
