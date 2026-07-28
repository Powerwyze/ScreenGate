-- Family quest assignment, device registration, and time rewards.

alter table public.missions
  add column if not exists reward_minutes integer not null default 15
  check (reward_minutes between 0 and 240);

alter table public.questime_devices
  add column if not exists device_name text,
  add column if not exists os_version text,
  add column if not exists app_version text;

create or replace function public.register_questime_device(
  p_installation_id text,
  p_platform text,
  p_device_role text,
  p_device_name text,
  p_os_version text,
  p_app_version text,
  p_screen_time_authorized boolean default false
)
returns public.questime_devices
language plpgsql
security definer
set search_path = public
as $$
declare
  target_family_id uuid;
  saved public.questime_devices;
begin
  if p_platform not in ('ios', 'android') then
    raise exception 'Unsupported device platform';
  end if;

  select family_id into target_family_id
  from public.family_members
  where user_id = auth.uid() and status = 'active'
  order by joined_at limit 1;

  if target_family_id is null then raise exception 'Pair this device first'; end if;

  insert into public.questime_devices (
    family_id, user_id, installation_id, platform, device_role,
    device_name, os_version, app_version, screen_time_authorized, last_seen_at
  ) values (
    target_family_id, auth.uid(), p_installation_id, p_platform, p_device_role,
    p_device_name, p_os_version, p_app_version, p_screen_time_authorized, now()
  )
  on conflict (installation_id) do update set
    family_id = excluded.family_id,
    user_id = excluded.user_id,
    platform = excluded.platform,
    device_role = excluded.device_role,
    device_name = excluded.device_name,
    os_version = excluded.os_version,
    app_version = excluded.app_version,
    screen_time_authorized = excluded.screen_time_authorized,
    last_seen_at = now()
  returning * into saved;

  return saved;
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
  select * into quest from public.missions where id = p_mission_id;

  select fm.family_id into target_family_id
  from public.family_members fm
  where fm.user_id = quest.assigned_to_user_id and fm.status = 'active'
  limit 1;

  if quest.id is null or not public.is_active_family_parent(target_family_id) then
    raise exception 'Only this child''s parent can approve the quest';
  end if;

  update public.missions
  set status = 'verified', completed_at = coalesce(completed_at, now()), updated_at = now()
  where id = p_mission_id
  returning * into quest;

  insert into public.reward_requests (
    family_id, child_user_id, mission_id, requested_minutes, status,
    reviewed_by, requested_at, reviewed_at
  ) values (
    target_family_id, quest.assigned_to_user_id, quest.id,
    greatest(1, quest.reward_minutes), 'approved', auth.uid(), now(), now()
  ) on conflict do nothing;

  return quest;
end;
$$;

revoke all on function public.register_questime_device(text,text,text,text,text,text,boolean) from public;
revoke all on function public.approve_family_quest(uuid) from public;
grant execute on function public.register_questime_device(text,text,text,text,text,text,boolean) to authenticated;
grant execute on function public.approve_family_quest(uuid) to authenticated;
