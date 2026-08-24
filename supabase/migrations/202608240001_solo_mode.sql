alter table public.users
  add column if not exists usage_mode text not null default 'family'
  check (usage_mode in ('family', 'solo'));
