-- Secure one-time pairing between a parent account and a child device.

create table if not exists public.family_pairing_codes (
  code text primary key check (code ~ '^[A-F0-9]{6}$'),
  family_id uuid not null references public.families(id) on delete cascade,
  created_by uuid not null references public.users(id) on delete cascade,
  expires_at timestamptz not null,
  used_at timestamptz,
  used_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists family_pairing_codes_family_idx
  on public.family_pairing_codes(family_id, expires_at desc);

alter table public.family_pairing_codes enable row level security;

create policy pairing_codes_parent_read on public.family_pairing_codes
  for select to authenticated
  using (created_by = auth.uid());

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
    pairing_code := upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 6));
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

  insert into public.questime_devices (
    family_id,
    user_id,
    installation_id,
    platform,
    device_role
  ) values (
    pairing.family_id,
    auth.uid(),
    'ios-' || auth.uid()::text,
    'ios',
    'child'
  )
  on conflict (installation_id) do update set
    family_id = excluded.family_id,
    user_id = excluded.user_id,
    device_role = 'child',
    last_seen_at = now();

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

revoke all on function public.create_family_pairing_code() from public;
revoke all on function public.join_family_with_code(text, text) from public;
grant execute on function public.create_family_pairing_code() to authenticated;
grant execute on function public.join_family_with_code(text, text) to authenticated;
