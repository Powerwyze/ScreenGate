create or replace function public.approve_family_quest(p_mission_id uuid)
returns public.missions
language plpgsql
security definer
set search_path = public
as $$
declare
  quest public.missions;
  target_family_id uuid;
  reward_user_id uuid;
begin
  select * into quest from public.missions where id = p_mission_id for update;
  reward_user_id := coalesce(quest.assigned_to_user_id, quest.user_id);

  select family_id into target_family_id
  from public.family_members
  where user_id = reward_user_id and status = 'active'
  limit 1;

  if quest.id is null or not (
    public.is_active_family_parent(target_family_id)
    or (quest.user_id = auth.uid() and quest.assigned_to_user_id is null)
  ) then
    raise exception 'Only this quest''s parent or owner can approve it';
  end if;
  if quest.status not in ('completed', 'verified') then
    raise exception 'The quest must be submitted before approval';
  end if;

  update public.missions
  set status = 'verified',
      stars_earned = greatest(stars_earned, 5),
      completed_at = coalesce(completed_at, now()),
      updated_at = now()
  where id = p_mission_id
  returning * into quest;

  insert into public.reward_requests (
    family_id, child_user_id, mission_id, requested_minutes, status,
    reviewed_by, requested_at, reviewed_at
  ) values (
    target_family_id, reward_user_id, quest.id,
    greatest(1, quest.reward_minutes), 'approved', auth.uid(), now(), now()
  )
  on conflict (mission_id) where mission_id is not null do update set
    status = 'approved',
    reviewed_by = excluded.reviewed_by,
    reviewed_at = excluded.reviewed_at;

  return quest;
end;
$$;

revoke all on function public.approve_family_quest(uuid) from public;
grant execute on function public.approve_family_quest(uuid) to authenticated;
