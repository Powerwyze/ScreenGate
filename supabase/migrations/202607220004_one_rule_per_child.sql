create unique index if not exists screen_time_rules_family_child_unique
  on public.screen_time_rules(family_id, child_user_id);
