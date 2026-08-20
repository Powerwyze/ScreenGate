-- Row Level Security (RLS) Policies for ScreenGate

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

-- Users table policies
CREATE POLICY users_select_policy ON users FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY users_insert_policy ON users FOR INSERT WITH CHECK (true);
CREATE POLICY users_update_policy ON users FOR UPDATE USING (auth.uid() = id) WITH CHECK (true);
CREATE POLICY users_delete_policy ON users FOR DELETE USING (auth.uid() = id);

-- Handlers table policies (read-only for all authenticated users)
CREATE POLICY handlers_select_policy ON handlers FOR SELECT USING (auth.uid() IS NOT NULL);

-- Missions table policies
CREATE POLICY missions_select_policy ON missions FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY missions_insert_policy ON missions FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY missions_update_policy ON missions FOR UPDATE USING (auth.uid() IS NOT NULL);
CREATE POLICY missions_delete_policy ON missions FOR DELETE USING (auth.uid() IS NOT NULL);

-- Achievements table policies (read-only for all authenticated users)
CREATE POLICY achievements_select_policy ON achievements FOR SELECT USING (auth.uid() IS NOT NULL);

-- User achievements table policies
CREATE POLICY user_achievements_select_policy ON user_achievements FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY user_achievements_insert_policy ON user_achievements FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY user_achievements_update_policy ON user_achievements FOR UPDATE USING (auth.uid() IS NOT NULL);
CREATE POLICY user_achievements_delete_policy ON user_achievements FOR DELETE USING (auth.uid() IS NOT NULL);

-- Friends table policies
CREATE POLICY friends_select_policy ON friends FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY friends_insert_policy ON friends FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY friends_update_policy ON friends FOR UPDATE USING (auth.uid() IS NOT NULL);
CREATE POLICY friends_delete_policy ON friends FOR DELETE USING (auth.uid() IS NOT NULL);

-- Messages table policies
CREATE POLICY messages_select_policy ON messages FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY messages_insert_policy ON messages FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY messages_update_policy ON messages FOR UPDATE USING (auth.uid() IS NOT NULL);
CREATE POLICY messages_delete_policy ON messages FOR DELETE USING (auth.uid() IS NOT NULL);

-- Chat messages table policies
CREATE POLICY chat_messages_select_policy ON chat_messages FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY chat_messages_insert_policy ON chat_messages FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY chat_messages_update_policy ON chat_messages FOR UPDATE USING (auth.uid() IS NOT NULL);
CREATE POLICY chat_messages_delete_policy ON chat_messages FOR DELETE USING (auth.uid() IS NOT NULL);

-- Notifications table policies
CREATE POLICY notifications_select_policy ON notifications FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY notifications_insert_policy ON notifications FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY notifications_update_policy ON notifications FOR UPDATE USING (auth.uid() IS NOT NULL);
CREATE POLICY notifications_delete_policy ON notifications FOR DELETE USING (auth.uid() IS NOT NULL);

-- Bug reports table policies
CREATE POLICY bug_reports_select_policy ON bug_reports FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY bug_reports_insert_policy ON bug_reports FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY bug_reports_update_policy ON bug_reports FOR UPDATE USING (auth.uid() IS NOT NULL);
CREATE POLICY bug_reports_delete_policy ON bug_reports FOR DELETE USING (auth.uid() IS NOT NULL);
