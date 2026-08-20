-- Idempotent seed for ScreenGate. Safe to run multiple times.
-- Run from Supabase SQL Editor. Uses SECURITY DEFINER to bypass RLS for seeding.

create or replace function app_private.seed_taskassassin()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Ensure default handlers
  insert into handlers (id, name, description, avatar_url, created_at)
  values
    ('handler_1', 'Nova', 'Motivational mentor with sharp insights', null, now()),
    ('handler_2', 'Echo', 'Calm planner who loves structure', null, now()),
    ('handler_3', 'Zephyr', 'Playful challenger to keep you moving', null, now())
  on conflict (id) do nothing;

  -- Create a demo user if not present (email-anchored)
  -- Note: this does NOT create an auth user; it only seeds the profile table.
  -- Replace with a real user id if you want linkage to auth.users.
  insert into users (id, codename, email, avatar_url, selected_handler_id, life_goals,
                     total_stars, level, current_streak, longest_streak, created_at, updated_at)
  values (
    '00000000-0000-0000-0000-000000000001',
    'DemoWolf01',
    'demo@example.com',
    null,
    'handler_1',
    'Ship a side-project this month',
    120,
    2,
    3,
    5,
    now(),
    now()
  ) on conflict (id) do nothing;

  -- Seed some missions for the demo user
  insert into missions (id, user_id, title, description, completed_state, type, status,
                        deadline, recurrence_pattern, before_photo_url, after_photo_url,
                        stars_earned, ai_feedback, assigned_by_user_id, assigned_to_user_id,
                        created_at, updated_at, completed_at)
  values
    (
      gen_random_uuid()::text,
      '00000000-0000-0000-0000-000000000001',
      'Morning workout',
      '20-minute HIIT session',
      'Sweaty and energized',
      'selfAssigned',
      'pending',
      now() + interval '1 day',
      null,
      null,
      null,
      10,
      null,
      null,
      null,
      now(),
      now(),
      null
    ),
    (
      gen_random_uuid()::text,
      '00000000-0000-0000-0000-000000000001',
      'Inbox zero',
      'Clear and categorize email inbox',
      'All critical emails handled',
      'aiSuggested',
      'inProgress',
      now() + interval '2 days',
      null,
      null,
      null,
      15,
      'Try batching emails in 2x 15-min sprints',
      null,
      null,
      now(),
      now(),
      null
    )
  on conflict do nothing;

  -- Notification for demo user
  insert into notifications (id, user_id, type, title, message, data, read, created_at)
  values (
    gen_random_uuid()::text,
    '00000000-0000-0000-0000-000000000001',
    'missionAssigned',
    'Welcome to ScreenGate',
    'You have 2 missions waiting for you',
    '{}'::jsonb,
    false,
    now()
  ) on conflict do nothing;
end;
$$;

-- Execute the seed
select app_private.seed_taskassassin();
