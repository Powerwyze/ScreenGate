-- Pending Migrations for ScreenGate
-- This file contains migrations that need to be re-applied

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS users_select_policy ON users;
DROP POLICY IF EXISTS users_insert_policy ON users;
DROP POLICY IF EXISTS users_update_policy ON users;
DROP POLICY IF EXISTS users_delete_policy ON users;

DROP POLICY IF EXISTS handlers_select_policy ON handlers;

DROP POLICY IF EXISTS missions_select_policy ON missions;
DROP POLICY IF EXISTS missions_insert_policy ON missions;
DROP POLICY IF EXISTS missions_update_policy ON missions;
DROP POLICY IF EXISTS missions_delete_policy ON missions;

DROP POLICY IF EXISTS achievements_select_policy ON achievements;

DROP POLICY IF EXISTS user_achievements_select_policy ON user_achievements;
DROP POLICY IF EXISTS user_achievements_insert_policy ON user_achievements;
DROP POLICY IF EXISTS user_achievements_update_policy ON user_achievements;
DROP POLICY IF EXISTS user_achievements_delete_policy ON user_achievements;

DROP POLICY IF EXISTS friends_select_policy ON friends;
DROP POLICY IF EXISTS friends_insert_policy ON friends;
DROP POLICY IF EXISTS friends_update_policy ON friends;
DROP POLICY IF EXISTS friends_delete_policy ON friends;

DROP POLICY IF EXISTS messages_select_policy ON messages;
DROP POLICY IF EXISTS messages_insert_policy ON messages;
DROP POLICY IF EXISTS messages_update_policy ON messages;
DROP POLICY IF EXISTS messages_delete_policy ON messages;

DROP POLICY IF EXISTS chat_messages_select_policy ON chat_messages;
DROP POLICY IF EXISTS chat_messages_insert_policy ON chat_messages;
DROP POLICY IF EXISTS chat_messages_update_policy ON chat_messages;
DROP POLICY IF EXISTS chat_messages_delete_policy ON chat_messages;

DROP POLICY IF EXISTS notifications_select_policy ON notifications;
DROP POLICY IF EXISTS notifications_insert_policy ON notifications;
DROP POLICY IF EXISTS notifications_update_policy ON notifications;
DROP POLICY IF EXISTS notifications_delete_policy ON notifications;

DROP POLICY IF EXISTS bug_reports_select_policy ON bug_reports;
DROP POLICY IF EXISTS bug_reports_insert_policy ON bug_reports;
DROP POLICY IF EXISTS bug_reports_update_policy ON bug_reports;
DROP POLICY IF EXISTS bug_reports_delete_policy ON bug_reports;

-- Drop indexes (avoid conflicts)
DROP INDEX IF EXISTS idx_missions_user_id;
DROP INDEX IF EXISTS idx_missions_status;
DROP INDEX IF EXISTS idx_missions_deadline;
DROP INDEX IF EXISTS idx_user_achievements_user_id;
DROP INDEX IF EXISTS idx_friends_user_id;
DROP INDEX IF EXISTS idx_friends_friend_user_id;
DROP INDEX IF EXISTS idx_messages_sender_id;
DROP INDEX IF EXISTS idx_messages_receiver_id;
DROP INDEX IF EXISTS idx_chat_messages_user_id;
DROP INDEX IF EXISTS idx_notifications_user_id;
DROP INDEX IF EXISTS idx_bug_reports_user_id;

DROP INDEX IF EXISTS idx_missions_user_id_new;
DROP INDEX IF EXISTS idx_missions_status_new;
DROP INDEX IF EXISTS idx_missions_deadline_new;
DROP INDEX IF EXISTS idx_user_achievements_user_id_new;
DROP INDEX IF EXISTS idx_friends_user_id_new;
DROP INDEX IF EXISTS idx_friends_friend_user_id_new;
DROP INDEX IF EXISTS idx_messages_sender_id_new;
DROP INDEX IF EXISTS idx_messages_receiver_id_new;
DROP INDEX IF EXISTS idx_chat_messages_user_id_new;
DROP INDEX IF EXISTS idx_notifications_user_id_new;
DROP INDEX IF EXISTS idx_bug_reports_user_id_new;

-- Drop tables if they exist (in reverse order due to foreign keys)
DROP TABLE IF EXISTS bug_reports CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS chat_messages CASCADE;
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS friends CASCADE;
DROP TABLE IF EXISTS user_achievements CASCADE;
DROP TABLE IF EXISTS achievements CASCADE;
DROP TABLE IF EXISTS missions CASCADE;
DROP TABLE IF EXISTS handlers CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Create all tables
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  codename TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  avatar_url TEXT,
  selected_handler_id TEXT NOT NULL,
  life_goals TEXT NOT NULL DEFAULT '',
  total_stars INTEGER NOT NULL DEFAULT 0,
  level INTEGER NOT NULL DEFAULT 0,
  current_streak INTEGER NOT NULL DEFAULT 0,
  longest_streak INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE handlers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  description TEXT NOT NULL,
  personality_style TEXT NOT NULL,
  avatar TEXT NOT NULL,
  greeting_message TEXT NOT NULL
);

CREATE TABLE missions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  completed_state TEXT NOT NULL,
  type TEXT NOT NULL,
  status TEXT NOT NULL,
  deadline TIMESTAMPTZ,
  recurrence_pattern TEXT,
  before_photo_url TEXT,
  after_photo_url TEXT,
  stars_earned INTEGER NOT NULL DEFAULT 0,
  ai_feedback TEXT,
  assigned_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  assigned_to_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

CREATE TABLE achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  icon TEXT NOT NULL,
  criteria TEXT NOT NULL,
  stars_required INTEGER NOT NULL DEFAULT 0,
  category TEXT NOT NULL
);

CREATE TABLE user_achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  achievement_id UUID NOT NULL REFERENCES achievements(id) ON DELETE CASCADE,
  unlocked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  earned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, achievement_id)
);

CREATE TABLE friends (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  friend_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, friend_user_id)
);

CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  data JSONB,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE bug_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_email TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  severity TEXT NOT NULL,
  status TEXT NOT NULL,
  device_info TEXT,
  app_version TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes with unique names
CREATE INDEX idx_missions_user_id_v2 ON missions(user_id);
CREATE INDEX idx_missions_status_v2 ON missions(status);
CREATE INDEX idx_missions_deadline_v2 ON missions(deadline);
CREATE INDEX idx_user_achievements_user_id_v2 ON user_achievements(user_id);
CREATE INDEX idx_friends_user_id_v2 ON friends(user_id);
CREATE INDEX idx_friends_friend_user_id_v2 ON friends(friend_user_id);
CREATE INDEX idx_messages_sender_id_v2 ON messages(sender_id);
CREATE INDEX idx_messages_receiver_id_v2 ON messages(receiver_id);
CREATE INDEX idx_chat_messages_user_id_v2 ON chat_messages(user_id);
CREATE INDEX idx_notifications_user_id_v2 ON notifications(user_id);
CREATE INDEX idx_bug_reports_user_id_v2 ON bug_reports(user_id);

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE handlers ENABLE ROW LEVEL SECURITY;
ALTER TABLE missions ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE friends ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE bug_reports ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY users_select_policy ON users FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY users_insert_policy ON users FOR INSERT WITH CHECK (true);
CREATE POLICY users_update_policy ON users FOR UPDATE USING (auth.uid() = id) WITH CHECK (true);
CREATE POLICY users_delete_policy ON users FOR DELETE USING (auth.uid() = id);

CREATE POLICY handlers_select_policy ON handlers FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY missions_select_policy ON missions FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY missions_insert_policy ON missions FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY missions_update_policy ON missions FOR UPDATE USING (auth.uid() IS NOT NULL);
CREATE POLICY missions_delete_policy ON missions FOR DELETE USING (auth.uid() IS NOT NULL);

CREATE POLICY achievements_select_policy ON achievements FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY user_achievements_select_policy ON user_achievements FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY user_achievements_insert_policy ON user_achievements FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY user_achievements_update_policy ON user_achievements FOR UPDATE USING (auth.uid() IS NOT NULL);
CREATE POLICY user_achievements_delete_policy ON user_achievements FOR DELETE USING (auth.uid() IS NOT NULL);

CREATE POLICY friends_select_policy ON friends FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY friends_insert_policy ON friends FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY friends_update_policy ON friends FOR UPDATE USING (auth.uid() IS NOT NULL);
CREATE POLICY friends_delete_policy ON friends FOR DELETE USING (auth.uid() IS NOT NULL);

CREATE POLICY messages_select_policy ON messages FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY messages_insert_policy ON messages FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY messages_update_policy ON messages FOR UPDATE USING (auth.uid() IS NOT NULL);
CREATE POLICY messages_delete_policy ON messages FOR DELETE USING (auth.uid() IS NOT NULL);

CREATE POLICY chat_messages_select_policy ON chat_messages FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY chat_messages_insert_policy ON chat_messages FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY chat_messages_update_policy ON chat_messages FOR UPDATE USING (auth.uid() IS NOT NULL);
CREATE POLICY chat_messages_delete_policy ON chat_messages FOR DELETE USING (auth.uid() IS NOT NULL);

CREATE POLICY notifications_select_policy ON notifications FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY notifications_insert_policy ON notifications FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY notifications_update_policy ON notifications FOR UPDATE USING (auth.uid() IS NOT NULL);
CREATE POLICY notifications_delete_policy ON notifications FOR DELETE USING (auth.uid() IS NOT NULL);

CREATE POLICY bug_reports_select_policy ON bug_reports FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY bug_reports_insert_policy ON bug_reports FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY bug_reports_update_policy ON bug_reports FOR UPDATE USING (auth.uid() IS NOT NULL);
CREATE POLICY bug_reports_delete_policy ON bug_reports FOR DELETE USING (auth.uid() IS NOT NULL);
