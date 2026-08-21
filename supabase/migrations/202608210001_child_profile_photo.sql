create or replace function public.set_child_profile_photo(
  p_child_user_id uuid,
  p_avatar_url text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if nullif(trim(p_avatar_url), '') is null then
    raise exception 'A photo is required';
  end if;

  if not exists (
    select 1
    from public.family_members parent_member
    join public.family_members child_member
      on child_member.family_id = parent_member.family_id
    where parent_member.user_id = auth.uid()
      and parent_member.role = 'parent'
      and parent_member.status = 'active'
      and child_member.user_id = p_child_user_id
      and child_member.role = 'child'
      and child_member.status = 'active'
  ) then
    raise exception 'You cannot change this child';
  end if;

  update public.users
  set avatar_url = p_avatar_url,
      updated_at = now()
  where id = p_child_user_id;
end;
$$;

revoke all on function public.set_child_profile_photo(uuid, text) from public;
grant execute on function public.set_child_profile_photo(uuid, text) to authenticated;
