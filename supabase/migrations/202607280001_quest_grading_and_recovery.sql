-- Persistent child recovery, role-owned proof photos, and half-star grading.

alter table public.missions
  drop constraint if exists missions_stars_earned_check;

alter table public.missions
  alter column stars_earned type numeric(2,1) using stars_earned::numeric,
  alter column stars_earned set default 0;

alter table public.missions
  add constraint missions_stars_earned_check
    check (stars_earned between 0 and 5 and mod(stars_earned * 2, 1) = 0),
  add column if not exists approval_mode text not null default 'manual'
    check (approval_mode in ('manual', 'ai')),
  add column if not exists minimum_passing_rating numeric(2,1) not null default 4
    check (
      minimum_passing_rating between 1 and 5
      and mod(minimum_passing_rating * 2, 1) = 0
    ),
  add column if not exists ai_graded_at timestamptz;

create table if not exists public.child_recovery_codes (
  child_user_id uuid primary key references public.users(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  code_hash text not null unique,
  code_hint text not null,
  created_by uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  rotated_at timestamptz
);

alter table public.child_recovery_codes enable row level security;

create policy child_recovery_parent_read on public.child_recovery_codes
  for select to authenticated
  using (public.is_active_family_parent(family_id));

create or replace function public.create_child_recovery_code(p_child_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_family_id uuid;
  recovery_code text;
begin
  select fm.family_id into target_family_id
  from public.family_members fm
  where fm.user_id = p_child_user_id
    and fm.role = 'child'
    and fm.status = 'active'
    and public.is_active_family_parent(fm.family_id)
  limit 1;

  if target_family_id is null then
    raise exception 'Only this child''s parent can create a recovery code';
  end if;

  recovery_code := upper(substr(encode(gen_random_bytes(6), 'hex'), 1, 8));

  insert into public.child_recovery_codes (
    child_user_id, family_id, code_hash, code_hint, created_by
  ) values (
    p_child_user_id, target_family_id, encode(digest(recovery_code, 'sha256'), 'hex'),
    right(recovery_code, 2), auth.uid()
  )
  on conflict (child_user_id) do update set
    code_hash = excluded.code_hash,
    code_hint = excluded.code_hint,
    created_by = excluded.created_by,
    rotated_at = now();

  return jsonb_build_object('code', recovery_code, 'child_user_id', p_child_user_id);
end;
$$;

create or replace function public.set_quest_before_photo(
  p_mission_id uuid,
  p_photo_url text
)
returns public.missions
language plpgsql
security definer
set search_path = public
as $$
declare
  quest public.missions;
  target_family_id uuid;
begin
  select * into quest from public.missions where id = p_mission_id for update;
  select family_id into target_family_id from public.family_members
    where user_id = coalesce(quest.assigned_to_user_id, quest.user_id)
      and status = 'active' limit 1;

  if quest.id is null or not (
    quest.user_id = auth.uid()
    or public.is_active_family_parent(target_family_id)
  ) then
    raise exception 'Only the parent can add the before photo';
  end if;

  update public.missions set before_photo_url = p_photo_url, updated_at = now()
  where id = p_mission_id returning * into quest;
  return quest;
end;
$$;

create or replace function public.set_quest_after_photo(
  p_mission_id uuid,
  p_photo_url text
)
returns public.missions
language plpgsql
security definer
set search_path = public
as $$
declare
  quest public.missions;
begin
  select * into quest from public.missions where id = p_mission_id for update;
  if quest.id is null
    or coalesce(quest.assigned_to_user_id, quest.user_id) <> auth.uid()
  then
    raise exception 'Only the person doing this quest can add the after photo';
  end if;
  if quest.before_photo_url is null then
    raise exception 'The parent must add a before photo first';
  end if;

  update public.missions
  set after_photo_url = p_photo_url, status = 'completed',
      completed_at = now(), updated_at = now()
  where id = p_mission_id returning * into quest;
  return quest;
end;
$$;

create or replace function public.approve_family_quest(p_mission_id uuid)
returns public.missions
language plpgsql
security definer
set search_path = public
as $$
declare
  quest public.missions;
  target_family_id uuid;
begin
  select * into quest from public.missions where id = p_mission_id for update;
  select family_id into target_family_id from public.family_members
    where user_id = coalesce(quest.assigned_to_user_id, quest.user_id)
      and status = 'active' limit 1;

  if quest.id is null or not (
    public.is_active_family_parent(target_family_id)
    or (quest.user_id = auth.uid() and quest.assigned_to_user_id is null)
  ) then
    raise exception 'Only this quest''s parent can approve it';
  end if;
  if quest.status not in ('completed', 'verified') then
    raise exception 'The quest must be submitted before approval';
  end if;

  update public.missions
  set status = 'verified', stars_earned = greatest(stars_earned, 5),
      completed_at = coalesce(completed_at, now()), updated_at = now()
  where id = p_mission_id returning * into quest;

  if quest.assigned_to_user_id is not null then
    insert into public.reward_requests (
      family_id, child_user_id, mission_id, requested_minutes, status,
      reviewed_by, requested_at, reviewed_at
    ) values (
      target_family_id, quest.assigned_to_user_id, quest.id,
      greatest(1, quest.reward_minutes), 'approved', auth.uid(), now(), now()
    )
    on conflict (mission_id) where mission_id is not null do update set
      status = 'approved', reviewed_by = excluded.reviewed_by,
      reviewed_at = excluded.reviewed_at;
  end if;
  return quest;
end;
$$;

revoke all on function public.create_child_recovery_code(uuid) from public;
revoke all on function public.set_quest_before_photo(uuid,text) from public;
revoke all on function public.set_quest_after_photo(uuid,text) from public;
grant execute on function public.create_child_recovery_code(uuid) to authenticated;
grant execute on function public.set_quest_before_photo(uuid,text) to authenticated;
grant execute on function public.set_quest_after_photo(uuid,text) to authenticated;

