delete from public.questime_devices
where installation_id = 'ios-' || user_id::text;

create or replace function public.join_family_with_code(
  pairing_code text,
  child_name text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  pairing public.family_pairing_codes%rowtype;
  parent_email text;
  normalized_name text := trim(child_name);
begin
  if auth.uid() is null then
    raise exception 'Child device is not authenticated';
  end if;

  if char_length(normalized_name) < 1 or char_length(normalized_name) > 60 then
    raise exception 'Enter the child''s name';
  end if;

  select * into pairing
  from public.family_pairing_codes
  where code = upper(trim(pairing_code))
    and used_at is null
    and expires_at > now()
  for update;

  if pairing.code is null then
    raise exception 'That family code is invalid or expired';
  end if;

  select email into parent_email
  from public.users
  where id = pairing.created_by;

  insert into public.users (
    id,
    email,
    codename,
    selected_handler_id,
    life_goals,
    account_role
  ) values (
    auth.uid(),
    parent_email,
    normalized_name,
    'commander',
    'Complete quests and build healthy habits.',
    'child'
  )
  on conflict (id) do update set
    email = excluded.email,
    codename = excluded.codename,
    account_role = 'child',
    updated_at = now();

  insert into public.family_members (family_id, user_id, role, status)
  values (pairing.family_id, auth.uid(), 'child', 'active')
  on conflict (family_id, user_id) do update set
    role = 'child',
    status = 'active';

  update public.family_pairing_codes
  set used_at = now(), used_by = auth.uid()
  where code = pairing.code;

  return jsonb_build_object(
    'family_id', pairing.family_id,
    'child_user_id', auth.uid(),
    'parent_email', parent_email
  );
end;
$$;

revoke all on function public.join_family_with_code(text, text) from public;
grant execute on function public.join_family_with_code(text, text)
  to authenticated;
