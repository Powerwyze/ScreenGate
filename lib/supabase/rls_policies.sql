-- Idempotent RLS policies for ScreenGate schema
-- Run this in Supabase SQL Editor. Safe to re-run.
-- Fixed: All auth.uid() comparisons now properly cast to UUID, removed string concatenation

-- Users table policies
ALTER TABLE IF EXISTS public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS users_select_own ON public.users;
CREATE POLICY users_select_own ON public.users
  FOR SELECT
  USING ((SELECT auth.uid())::uuid = id);

DROP POLICY IF EXISTS users_insert_own ON public.users;
CREATE POLICY users_insert_own ON public.users
  FOR INSERT WITH CHECK ((SELECT auth.uid())::uuid = id);

DROP POLICY IF EXISTS users_update_own ON public.users;
CREATE POLICY users_update_own ON public.users
  FOR UPDATE USING ((SELECT auth.uid())::uuid = id) WITH CHECK ((SELECT auth.uid())::uuid = id);

DROP POLICY IF EXISTS users_delete_own ON public.users;
CREATE POLICY users_delete_own ON public.users
  FOR DELETE USING ((SELECT auth.uid())::uuid = id);

-- Handlers are readable by all, not writable by clients
ALTER TABLE IF EXISTS public.handlers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS handlers_read_all ON public.handlers;
CREATE POLICY handlers_read_all ON public.handlers
  FOR SELECT USING (true);

-- Missions policies (owner or assignee can access)
ALTER TABLE IF EXISTS public.missions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS missions_crud_by_owner_or_assignee ON public.missions;
CREATE POLICY missions_crud_by_owner_or_assignee ON public.missions
  FOR ALL
  USING (
    (SELECT auth.uid())::uuid = user_id
    OR (assigned_to_user_id IS NOT NULL AND (SELECT auth.uid())::uuid = assigned_to_user_id)
    OR (assigned_by_user_id IS NOT NULL AND (SELECT auth.uid())::uuid = assigned_by_user_id)
  )
  WITH CHECK (
    (SELECT auth.uid())::uuid = user_id
    OR (assigned_to_user_id IS NOT NULL AND (SELECT auth.uid())::uuid = assigned_to_user_id)
    OR (assigned_by_user_id IS NOT NULL AND (SELECT auth.uid())::uuid = assigned_by_user_id)
  );

-- Notifications (target user can read/write own)
ALTER TABLE IF EXISTS public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS notifications_crud_own ON public.notifications;
CREATE POLICY notifications_crud_own ON public.notifications
  FOR ALL
  USING ((SELECT auth.uid())::uuid = user_id)
  WITH CHECK ((SELECT auth.uid())::uuid = user_id);

-- Messages (DM threads) - Fixed column name: receiver_id not recipient_id
ALTER TABLE IF EXISTS public.messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS messages_crud_participants ON public.messages;
CREATE POLICY messages_crud_participants ON public.messages
  FOR ALL
  USING (
    (SELECT auth.uid())::uuid = sender_id OR (SELECT auth.uid())::uuid = receiver_id
  )
  WITH CHECK (
    (SELECT auth.uid())::uuid = sender_id OR (SELECT auth.uid())::uuid = receiver_id
  );

-- Chat messages (handler/user conversations)
ALTER TABLE IF EXISTS public.chat_messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS chat_messages_crud_owner ON public.chat_messages;
CREATE POLICY chat_messages_crud_owner ON public.chat_messages
  FOR ALL
  USING ((SELECT auth.uid())::uuid = user_id)
  WITH CHECK ((SELECT auth.uid())::uuid = user_id);

-- Friends - Fixed column name: friend_user_id not friend_id
ALTER TABLE IF EXISTS public.friends ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS friends_crud_involving_me ON public.friends;
CREATE POLICY friends_crud_involving_me ON public.friends
  FOR ALL
  USING ((SELECT auth.uid())::uuid = user_id OR (SELECT auth.uid())::uuid = friend_user_id)
  WITH CHECK ((SELECT auth.uid())::uuid = user_id OR (SELECT auth.uid())::uuid = friend_user_id);

-- Achievements (read-only, no user_id column - these are global achievements)
ALTER TABLE IF EXISTS public.achievements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS achievements_read_all ON public.achievements;
CREATE POLICY achievements_read_all ON public.achievements
  FOR SELECT USING (true);

-- User achievements (many-to-many - users can only see/manage their own unlocked achievements)
ALTER TABLE IF EXISTS public.user_achievements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS user_achievements_crud_own ON public.user_achievements;
CREATE POLICY user_achievements_crud_own ON public.user_achievements
  FOR ALL
  USING ((SELECT auth.uid())::uuid = user_id)
  WITH CHECK ((SELECT auth.uid())::uuid = user_id);

-- Bug reports (users can only see/manage their own reports)
ALTER TABLE IF EXISTS public.bug_reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS bug_reports_crud_own ON public.bug_reports;
CREATE POLICY bug_reports_crud_own ON public.bug_reports
  FOR ALL
  USING ((SELECT auth.uid())::uuid = user_id)
  WITH CHECK ((SELECT auth.uid())::uuid = user_id);
