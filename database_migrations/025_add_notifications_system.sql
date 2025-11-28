-- 025_add_notifications_system.sql
-- Creates notification system for alerting users about votes and comments on their posts

-- ============================================================================
-- 1. Create notifications table
-- ============================================================================
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('vote', 'comment', 'mention', 'price_alert', 'system')),
  title TEXT NOT NULL,
  message TEXT NOT NULL,

  -- Related entities
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  comment_id UUID REFERENCES comments(id) ON DELETE CASCADE,
  vote_type TEXT, -- For vote notifications: thumbs_up, thumbs_down, partial, funny

  -- Actor info (who triggered the notification)
  actor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_username TEXT,
  actor_is_anonymous BOOLEAN DEFAULT true,

  -- Status
  is_read BOOLEAN DEFAULT false,
  read_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 2. Create indexes for efficient queries
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id, is_read) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_post_id ON notifications(post_id);

-- ============================================================================
-- 3. Enable RLS
-- ============================================================================
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Users can only see their own notifications
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
CREATE POLICY "Users can view own notifications"
ON notifications FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Users can update their own notifications (mark as read)
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications"
ON notifications FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Users can delete their own notifications
DROP POLICY IF EXISTS "Users can delete own notifications" ON notifications;
CREATE POLICY "Users can delete own notifications"
ON notifications FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- System can insert notifications (via triggers)
DROP POLICY IF EXISTS "System can insert notifications" ON notifications;
CREATE POLICY "System can insert notifications"
ON notifications FOR INSERT
TO authenticated
WITH CHECK (true);

-- ============================================================================
-- 4. Create trigger function to notify on new votes
-- ============================================================================
CREATE OR REPLACE FUNCTION notify_post_author_on_vote()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  post_author_id UUID;
  post_title TEXT;
  voter_username TEXT;
  voter_is_anon BOOLEAN;
  vote_emoji TEXT;
BEGIN
  -- Get post author info
  SELECT user_id, title INTO post_author_id, post_title
  FROM posts
  WHERE id = NEW.post_id;

  -- Don't notify if post has no author (anonymous) or author votes on own post
  IF post_author_id IS NULL OR post_author_id = NEW.user_id THEN
    RETURN NEW;
  END IF;

  -- Get voter info
  SELECT username, false INTO voter_username, voter_is_anon
  FROM user_profiles
  WHERE id = NEW.user_id;

  -- If no profile found, mark as anonymous
  IF voter_username IS NULL THEN
    voter_username := 'Someone';
    voter_is_anon := true;
  END IF;

  -- Get vote emoji
  SELECT CASE NEW.vote_type
    WHEN 'thumbs_up' THEN '👍'
    WHEN 'thumbs_down' THEN '👎'
    WHEN 'partial' THEN '🤔'
    WHEN 'funny' THEN '😂'
    ELSE '✓'
  END INTO vote_emoji;

  -- Create notification
  INSERT INTO notifications (
    user_id,
    type,
    title,
    message,
    post_id,
    vote_type,
    actor_id,
    actor_username,
    actor_is_anonymous
  ) VALUES (
    post_author_id,
    'vote',
    vote_emoji || ' New vote on your post',
    voter_username || ' voted on "' || LEFT(post_title, 50) || CASE WHEN LENGTH(post_title) > 50 THEN '...' ELSE '' END || '"',
    NEW.post_id,
    NEW.vote_type,
    NEW.user_id,
    voter_username,
    voter_is_anon
  );

  RETURN NEW;
END;
$$;

-- Create trigger for votes
DROP TRIGGER IF EXISTS trigger_notify_on_vote ON truth_votes;
CREATE TRIGGER trigger_notify_on_vote
AFTER INSERT ON truth_votes
FOR EACH ROW
EXECUTE FUNCTION notify_post_author_on_vote();

-- ============================================================================
-- 5. Create trigger function to notify on new comments
-- ============================================================================
CREATE OR REPLACE FUNCTION notify_post_author_on_comment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  post_author_id UUID;
  post_title TEXT;
  commenter_username TEXT;
  commenter_is_anon BOOLEAN;
BEGIN
  -- Get post author info
  SELECT user_id, title INTO post_author_id, post_title
  FROM posts
  WHERE id = NEW.post_id;

  -- Don't notify if post has no author (anonymous) or author comments on own post
  IF post_author_id IS NULL OR post_author_id = NEW.anonymous_user_id THEN
    RETURN NEW;
  END IF;

  -- Get commenter info
  commenter_is_anon := COALESCE(NEW.is_anonymous, true);

  IF NOT commenter_is_anon AND NEW.author_username IS NOT NULL THEN
    commenter_username := NEW.author_username;
  ELSE
    commenter_username := 'Someone';
    commenter_is_anon := true;
  END IF;

  -- Create notification
  INSERT INTO notifications (
    user_id,
    type,
    title,
    message,
    post_id,
    comment_id,
    actor_id,
    actor_username,
    actor_is_anonymous
  ) VALUES (
    post_author_id,
    'comment',
    '💬 New comment on your post',
    commenter_username || ' commented on "' || LEFT(post_title, 50) || CASE WHEN LENGTH(post_title) > 50 THEN '...' ELSE '' END || '"',
    NEW.post_id,
    NEW.id,
    NEW.anonymous_user_id,
    commenter_username,
    commenter_is_anon
  );

  RETURN NEW;
END;
$$;

-- Create trigger for comments
DROP TRIGGER IF EXISTS trigger_notify_on_comment ON comments;
CREATE TRIGGER trigger_notify_on_comment
AFTER INSERT ON comments
FOR EACH ROW
EXECUTE FUNCTION notify_post_author_on_comment();

-- ============================================================================
-- 6. Create RPC function to get unread notification count
-- ============================================================================
CREATE OR REPLACE FUNCTION get_unread_notification_count()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  count_val INTEGER;
BEGIN
  SELECT COUNT(*) INTO count_val
  FROM notifications
  WHERE user_id = auth.uid() AND is_read = false;

  RETURN COALESCE(count_val, 0);
END;
$$;

GRANT EXECUTE ON FUNCTION get_unread_notification_count() TO authenticated;

-- ============================================================================
-- 7. Create RPC function to mark notifications as read
-- ============================================================================
CREATE OR REPLACE FUNCTION mark_notifications_read(notification_ids UUID[])
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE notifications
  SET is_read = true, read_at = NOW()
  WHERE id = ANY(notification_ids) AND user_id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION mark_notifications_read(UUID[]) TO authenticated;

-- ============================================================================
-- 8. Create RPC function to mark all notifications as read
-- ============================================================================
CREATE OR REPLACE FUNCTION mark_all_notifications_read()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE notifications
  SET is_read = true, read_at = NOW()
  WHERE user_id = auth.uid() AND is_read = false;
END;
$$;

GRANT EXECUTE ON FUNCTION mark_all_notifications_read() TO authenticated;

-- ============================================================================
-- 9. Grant permissions
-- ============================================================================
GRANT SELECT, UPDATE, DELETE ON notifications TO authenticated;
