-- Supabase installs pgcrypto in the extensions schema.

create or replace function public.create_family_pairing_code()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  parent_profile public.users%rowtype;
  target_family_id uuid;
  pairing_code text;
  attempts integer := 0;
begin
  select * into parent_profile
  from public.users
  where id = auth.uid() and account_role = 'parent';

  if parent_profile.id is null then
    raise exception 'Only a parent account can create a pairing code';
  end if;

  select family_id into target_family_id
  from public.family_members
  where user_id = auth.uid() and role = 'parent' and status = 'active'
  order by joined_at
  limit 1;

  if target_family_id is null then
    insert into public.families (name, created_by)
    values (parent_profile.codename || '''s family', auth.uid())
    returning id into target_family_id;

    insert into public.family_members (family_id, user_id, role, status)
    values (target_family_id, auth.uid(), 'parent', 'active');
  end if;

  delete from public.family_pairing_codes
  where created_by = auth.uid() and (used_at is null or expires_at < now());

  loop
    pairing_code := upper(
      substr(encode(extensions.gen_random_bytes(4), 'hex'), 1, 6)
    );
    begin
      insert into public.family_pairing_codes (
        code, family_id, created_by, expires_at
      ) values (
        pairing_code, target_family_id, auth.uid(), now() + interval '15 minutes'
      );
      exit;
    exception when unique_violation then
      attempts := attempts + 1;
      if attempts >= 5 then
        raise exception 'Unable to generate a pairing code';
      end if;
    end;
  end loop;

  return jsonb_build_object(
    'code', pairing_code,
    'family_id', target_family_id,
    'expires_at', now() + interval '15 minutes'
  );
end;
$$;

revoke all on function public.create_family_pairing_code() from public;
grant execute on function public.create_family_pairing_code() to authenticated;
