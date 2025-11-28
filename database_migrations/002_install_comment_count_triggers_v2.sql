-- ============================================================================
-- INSTALL COMMENT COUNT TRIGGERS (v2 - With GREATEST Protection)
-- ============================================================================
-- This ensures comment counts are automatically updated when comments are added/deleted
-- and that real-time updates trigger properly
-- V2 adds GREATEST() protection to prevent negative counts
-- ============================================================================

-- 1. Function to update comment count (with negative count protection)
CREATE OR REPLACE FUNCTION update_post_comment_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Increment comment count when comment is added
    UPDATE posts
    SET comment_count = comment_count + 1,
        updated_at = NOW()
    WHERE id = NEW.post_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    -- Decrement comment count when comment is deleted (with protection against negative)
    UPDATE posts
    SET comment_count = GREATEST(comment_count - 1, 0),
        updated_at = NOW()
    WHERE id = OLD.post_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 2. Triggers for comment insert and delete
DROP TRIGGER IF EXISTS trg_comment_count_insert ON comments;
CREATE TRIGGER trg_comment_count_insert
  AFTER INSERT ON comments
  FOR EACH ROW EXECUTE FUNCTION update_post_comment_count();

DROP TRIGGER IF EXISTS trg_comment_count_delete ON comments;
CREATE TRIGGER trg_comment_count_delete
  AFTER DELETE ON comments
  FOR EACH ROW EXECUTE FUNCTION update_post_comment_count();

-- 3. Fix existing posts with correct comment counts
UPDATE posts
SET comment_count = (
  SELECT COUNT(*)
  FROM comments
  WHERE comments.post_id = posts.id
);

-- 4. Verify triggers were created
DO $$
DECLARE
  insert_trigger_exists BOOLEAN;
  delete_trigger_exists BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trg_comment_count_insert'
  ) INTO insert_trigger_exists;

  SELECT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trg_comment_count_delete'
  ) INTO delete_trigger_exists;

  IF insert_trigger_exists AND delete_trigger_exists THEN
    RAISE NOTICE '✅ Comment count triggers installed successfully (v2 - with GREATEST protection)';
  ELSE
    RAISE WARNING '⚠️ Some triggers may not have been created';
  END IF;
END $$;

-- 5. Show sample of comment counts to verify
SELECT
  p.id,
  p.title,
  p.comment_count as stored_count,
  COUNT(c.id) as actual_count,
  CASE
    WHEN p.comment_count = COUNT(c.id) THEN '✅ Match'
    ELSE '❌ Mismatch'
  END as status
FROM posts p
LEFT JOIN comments c ON c.post_id = p.id
GROUP BY p.id, p.title, p.comment_count
ORDER BY p.comment_count DESC
LIMIT 10;

RAISE NOTICE '✅ Migration 002_install_comment_count_triggers_v2.sql completed successfully';
