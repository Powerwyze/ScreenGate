alter table public.child_recovery_codes
  add column if not exists code_value text;

drop function if exists public.create_child_recovery_code(uuid);

create function public.create_child_recovery_code(
  p_child_user_id uuid,
  p_rotate boolean default false
)
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
    raise exception 'Only this child''s parent can manage the child code';
  end if;

  if not p_rotate then
    select code_value into recovery_code
    from public.child_recovery_codes
    where child_user_id = p_child_user_id;
  end if;

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

revoke all on function public.create_child_recovery_code(uuid,boolean) from public;
grant execute on function public.create_child_recovery_code(uuid,boolean) to authenticated;
