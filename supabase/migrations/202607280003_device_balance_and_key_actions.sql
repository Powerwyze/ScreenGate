alter table public.questime_devices
  add column if not exists remaining_seconds integer not null default 0
  check (remaining_seconds >= 0);

drop function if exists public.register_questime_device(
  text, text, text, text, text, text, boolean
);

create function public.register_questime_device(
  p_installation_id text,
  p_platform text,
  p_device_role text,
  p_device_name text,
  p_os_version text,
  p_app_version text,
  p_screen_time_authorized boolean default false,
  p_remaining_seconds integer default 0
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
    device_name, os_version, app_version, screen_time_authorized,
    remaining_seconds, last_seen_at
  ) values (
    target_family_id, auth.uid(), p_installation_id, p_platform, p_device_role,
    p_device_name, p_os_version, p_app_version, p_screen_time_authorized,
    greatest(0, p_remaining_seconds), now()
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
    remaining_seconds = excluded.remaining_seconds,
    last_seen_at = now()
  returning * into saved;
  return saved;
end;
$$;

drop function if exists public.create_child_recovery_code(uuid, boolean);

create function public.preview_child_recovery_code(p_child_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  recovery_code text;
  target_family_id uuid;
begin
  select fm.family_id into target_family_id
  from public.family_members fm
  where fm.user_id = p_child_user_id
    and fm.role = 'child'
    and fm.status = 'active'
    and public.is_active_family_parent(fm.family_id)
  limit 1;
  if target_family_id is null then
    raise exception 'Only this child''s parent can view the child code';
  end if;

  select code_value into recovery_code
  from public.child_recovery_codes
  where child_user_id = p_child_user_id;

  if recovery_code is null then
    recovery_code := upper(substr(encode(gen_random_bytes(6), 'hex'), 1, 8));
    insert into public.child_recovery_codes (
      child_user_id, family_id, code_hash, code_hint, code_value, created_by
    ) values (
      p_child_user_id, target_family_id,
      encode(digest(recovery_code, 'sha256'), 'hex'),
      right(recovery_code, 2), recovery_code, auth.uid()
    )
    on conflict (child_user_id) do update set
      code_hash = excluded.code_hash,
      code_hint = excluded.code_hint,
      code_value = excluded.code_value,
      created_by = excluded.created_by,
      rotated_at = now();
  end if;

  return jsonb_build_object('code', recovery_code, 'child_user_id', p_child_user_id);
end;
$$;

create function public.rotate_child_recovery_code(p_child_user_id uuid)
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
    raise exception 'Only this child''s parent can replace the child code';
  end if;

  recovery_code := upper(substr(encode(gen_random_bytes(6), 'hex'), 1, 8));
  insert into public.child_recovery_codes (
    child_user_id, family_id, code_hash, code_hint, code_value, created_by
  ) values (
    p_child_user_id, target_family_id,
    encode(digest(recovery_code, 'sha256'), 'hex'),
    right(recovery_code, 2), recovery_code, auth.uid()
  )
  on conflict (child_user_id) do update set
    code_hash = excluded.code_hash,
    code_hint = excluded.code_hint,
    code_value = excluded.code_value,
    created_by = excluded.created_by,
    rotated_at = now();

  return jsonb_build_object('code', recovery_code, 'child_user_id', p_child_user_id);
end;
$$;

revoke all on function public.register_questime_device(
  text, text, text, text, text, text, boolean, integer
) from public;
revoke all on function public.preview_child_recovery_code(uuid) from public;
revoke all on function public.rotate_child_recovery_code(uuid) from public;
grant execute on function public.register_questime_device(
  text, text, text, text, text, text, boolean, integer
) to authenticated;
grant execute on function public.preview_child_recovery_code(uuid) to authenticated;
grant execute on function public.rotate_child_recovery_code(uuid) to authenticated;
