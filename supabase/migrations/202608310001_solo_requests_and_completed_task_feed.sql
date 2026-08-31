-- Deliver Solo friend requests live and restrict the social feed to completed
-- tasks that their owner explicitly chooses to share.

alter table public.social_posts
  add column if not exists mission_id uuid references public.missions(id) on delete cascade,
  add column if not exists task_title text,
  add column if not exists task_description text,
  add column if not exists task_photo_url text,
  add column if not exists stars_earned numeric(3, 1) not null default 0,
  add column if not exists completed_at timestamptz;

create unique index if not exists social_posts_user_mission_idx
  on public.social_posts(user_id, mission_id)
  where mission_id is not null;

create index if not exists social_posts_mission_idx
  on public.social_posts(mission_id)
  where mission_id is not null;

create or replace function public.share_completed_task(
  p_mission_id uuid,
  p_visibility text default 'public'
)
returns public.social_posts
language plpgsql
security definer
set search_path = public
as $$
declare
  task public.missions%rowtype;
  shared public.social_posts%rowtype;
begin
  if p_visibility not in ('public', 'friends') then
    raise exception 'Choose everyone or friends.' using errcode = '22023';
  end if;

  select * into task
  from public.missions
  where id = p_mission_id;

  if not found then
    raise exception 'Task not found.' using errcode = 'P0002';
  end if;

  if not public.owns_profile(task.user_id)
      or not exists (
        select 1 from public.users profile
        where profile.id = task.user_id
          and profile.usage_mode = 'solo'
      ) then
    raise exception 'You can share only your Solo tasks.' using errcode = '42501';
  end if;

  if task.status not in ('completed', 'verified') then
    raise exception 'Finish the task before sharing it.' using errcode = '23514';
  end if;

  insert into public.social_posts (
    user_id,
    mission_id,
    content,
    visibility,
    task_title,
    task_description,
    task_photo_url,
    stars_earned,
    completed_at,
    updated_at
  ) values (
    task.user_id,
    task.id,
    left(coalesce(nullif(trim(task.ai_feedback), ''), 'Task completed.'), 2000),
    p_visibility,
    task.title,
    coalesce(task.description, ''),
    task.after_photo_url,
    coalesce(task.stars_earned, 0),
    coalesce(task.completed_at, task.updated_at, now()),
    now()
  )
  on conflict (user_id, mission_id) where mission_id is not null
  do update set
    content = excluded.content,
    visibility = excluded.visibility,
    task_title = excluded.task_title,
    task_description = excluded.task_description,
    task_photo_url = excluded.task_photo_url,
    stars_earned = excluded.stars_earned,
    completed_at = excluded.completed_at,
    updated_at = now()
  returning * into shared;

  return shared;
end;
$$;

revoke insert, update on public.social_posts from authenticated;
grant execute on function public.share_completed_task(uuid, text) to authenticated;

drop policy if exists social_posts_insert_own on public.social_posts;
drop policy if exists social_posts_update_own on public.social_posts;

-- The old client requested the inserted notification row back. Because that
-- row is visible only to its recipient, PostgREST rolled the whole insert back.
-- Backfill alerts for requests that already exist so recipients see them now.
insert into public.notifications (
  id,
  user_id,
  type,
  title,
  message,
  data,
  is_read,
  created_at
)
select
  gen_random_uuid(),
  request.friend_user_id,
  'friendRequest',
  'New Friend Request',
  sender.codename || ' wants to be your friend!',
  jsonb_build_object(
    'friend_id', request.id,
    'sender_id', request.user_id
  ),
  false,
  request.created_at
from public.friends request
join public.users sender on sender.id = request.user_id
where request.status = 'pending'
  and not exists (
    select 1
    from public.notifications notification
    where notification.type = 'friendRequest'
      and notification.data ->> 'friend_id' = request.id::text
  );

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'friends'
  ) then
    alter publication supabase_realtime add table public.friends;
  end if;
end $$;
