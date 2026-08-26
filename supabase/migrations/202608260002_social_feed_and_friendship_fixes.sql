-- Complete the Solo social layer and repair request/message permissions.

create or replace function public.owns_profile(profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.users
    where id = profile_id
      and (auth_user_id = auth.uid() or id = auth.uid())
  );
$$;

create or replace function public.are_accepted_friends(first_id uuid, second_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.friends
    where status = 'accepted'
      and ((user_id = first_id and friend_user_id = second_id)
        or (user_id = second_id and friend_user_id = first_id))
  );
$$;

-- Keep one relationship row per pair, preferring an accepted relationship.
with ranked as (
  select id,
    row_number() over (
      partition by least(user_id, friend_user_id), greatest(user_id, friend_user_id)
      order by case when status = 'accepted' then 0 else 1 end, created_at
    ) as position
  from public.friends
)
delete from public.friends
where id in (select id from ranked where position > 1);

create unique index if not exists friends_unique_pair_idx
  on public.friends (
    least(user_id, friend_user_id),
    greatest(user_id, friend_user_id)
  );

drop policy if exists friends_involved on public.friends;
drop policy if exists friends_select_involved on public.friends;
drop policy if exists friends_insert_sender on public.friends;
drop policy if exists friends_update_recipient on public.friends;
drop policy if exists friends_delete_involved on public.friends;

create policy friends_select_involved on public.friends for select to authenticated
  using (public.owns_profile(user_id) or public.owns_profile(friend_user_id));
create policy friends_insert_sender on public.friends for insert to authenticated
  with check (
    public.owns_profile(user_id)
    and user_id <> friend_user_id
    and status = 'pending'
    and exists (select 1 from public.users where id = friend_user_id and usage_mode = 'solo')
  );
create policy friends_update_recipient on public.friends for update to authenticated
  using (public.owns_profile(friend_user_id))
  with check (public.owns_profile(friend_user_id) and status in ('accepted', 'declined'));
create policy friends_delete_involved on public.friends for delete to authenticated
  using (public.owns_profile(user_id) or public.owns_profile(friend_user_id));

drop policy if exists messages_involved on public.messages;
drop policy if exists messages_select_involved on public.messages;
drop policy if exists messages_insert_sender on public.messages;
drop policy if exists messages_update_receiver on public.messages;
drop policy if exists messages_delete_sender on public.messages;

create policy messages_select_involved on public.messages for select to authenticated
  using (public.owns_profile(sender_id) or public.owns_profile(receiver_id));
create policy messages_insert_sender on public.messages for insert to authenticated
  with check (
    public.owns_profile(sender_id)
    and public.are_accepted_friends(sender_id, receiver_id)
  );
create policy messages_update_receiver on public.messages for update to authenticated
  using (public.owns_profile(receiver_id))
  with check (public.owns_profile(receiver_id));
create policy messages_delete_sender on public.messages for delete to authenticated
  using (public.owns_profile(sender_id));

create table if not exists public.social_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 2000),
  visibility text not null default 'public' check (visibility in ('public', 'friends')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.post_likes (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.social_posts(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);

create table if not exists public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.social_posts(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists social_posts_feed_idx
  on public.social_posts(visibility, created_at desc);
create index if not exists social_posts_user_idx
  on public.social_posts(user_id, created_at desc);
create index if not exists post_likes_post_idx on public.post_likes(post_id);
create index if not exists post_comments_post_idx
  on public.post_comments(post_id, created_at);

alter table public.social_posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.post_comments enable row level security;

create or replace function public.can_view_social_post(target_post_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.social_posts post
    where post.id = target_post_id
      and (
        post.visibility = 'public'
        or public.owns_profile(post.user_id)
        or (post.visibility = 'friends' and exists (
          select 1 from public.users viewer
          where public.owns_profile(viewer.id)
            and public.are_accepted_friends(viewer.id, post.user_id)
        ))
      )
  );
$$;

drop policy if exists social_posts_read_visible on public.social_posts;
drop policy if exists social_posts_insert_own on public.social_posts;
drop policy if exists social_posts_update_own on public.social_posts;
drop policy if exists social_posts_delete_own on public.social_posts;
create policy social_posts_read_visible on public.social_posts for select to authenticated
  using (
    visibility = 'public'
    or public.owns_profile(user_id)
    or (visibility = 'friends' and exists (
      select 1 from public.users viewer
      where public.owns_profile(viewer.id)
        and public.are_accepted_friends(viewer.id, user_id)
    ))
  );
create policy social_posts_insert_own on public.social_posts for insert to authenticated
  with check (public.owns_profile(user_id));
create policy social_posts_update_own on public.social_posts for update to authenticated
  using (public.owns_profile(user_id)) with check (public.owns_profile(user_id));
create policy social_posts_delete_own on public.social_posts for delete to authenticated
  using (public.owns_profile(user_id));

drop policy if exists post_likes_read_visible on public.post_likes;
drop policy if exists post_likes_insert_own on public.post_likes;
drop policy if exists post_likes_delete_own on public.post_likes;
create policy post_likes_read_visible on public.post_likes for select to authenticated
  using (public.can_view_social_post(post_id));
create policy post_likes_insert_own on public.post_likes for insert to authenticated
  with check (public.owns_profile(user_id) and public.can_view_social_post(post_id));
create policy post_likes_delete_own on public.post_likes for delete to authenticated
  using (public.owns_profile(user_id));

drop policy if exists post_comments_read_visible on public.post_comments;
drop policy if exists post_comments_insert_own on public.post_comments;
drop policy if exists post_comments_update_own on public.post_comments;
drop policy if exists post_comments_delete_own on public.post_comments;
create policy post_comments_read_visible on public.post_comments for select to authenticated
  using (public.can_view_social_post(post_id));
create policy post_comments_insert_own on public.post_comments for insert to authenticated
  with check (public.owns_profile(user_id) and public.can_view_social_post(post_id));
create policy post_comments_update_own on public.post_comments for update to authenticated
  using (public.owns_profile(user_id)) with check (public.owns_profile(user_id));
create policy post_comments_delete_own on public.post_comments for delete to authenticated
  using (public.owns_profile(user_id));

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'social_posts'
  ) then
    alter publication supabase_realtime add table public.social_posts;
  end if;
end $$;
