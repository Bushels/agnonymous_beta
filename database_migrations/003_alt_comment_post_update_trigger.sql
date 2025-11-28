-- ============================================================================
-- HANDLE COMMENT POST_ID UPDATES (Alternative Approach)
-- ============================================================================
-- This allows comments to be moved between posts while maintaining accurate counts
-- Use this INSTEAD of 003_prevent_comment_post_updates.sql if you need flexibility
-- ============================================================================

-- Modify the trigger function to handle UPDATE operations
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

  ELSIF TG_OP = 'UPDATE' THEN
    -- Handle post_id changes (moving comment to different post)
    IF OLD.post_id != NEW.post_id THEN
      -- Decrement old post
      UPDATE posts
      SET comment_count = GREATEST(comment_count - 1, 0),
          updated_at = NOW()
      WHERE id = OLD.post_id;

      -- Increment new post
      UPDATE posts
      SET comment_count = comment_count + 1,
          updated_at = NOW()
      WHERE id = NEW.post_id;
    END IF;
    RETURN NEW;

  ELSIF TG_OP = 'DELETE' THEN
    -- Decrement comment count when comment is deleted
    UPDATE posts
    SET comment_count = GREATEST(comment_count - 1, 0),
        updated_at = NOW()
    WHERE id = OLD.post_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Add UPDATE trigger
DROP TRIGGER IF EXISTS trg_comment_count_update ON comments;
CREATE TRIGGER trg_comment_count_update
  AFTER UPDATE ON comments
  FOR EACH ROW
  WHEN (OLD.post_id IS DISTINCT FROM NEW.post_id)
  EXECUTE FUNCTION update_post_comment_count();

-- Verify all triggers exist
DO $$
DECLARE
  insert_trigger_exists BOOLEAN;
  update_trigger_exists BOOLEAN;
  delete_trigger_exists BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trg_comment_count_insert'
  ) INTO insert_trigger_exists;

  SELECT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trg_comment_count_update'
  ) INTO update_trigger_exists;

  SELECT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trg_comment_count_delete'
  ) INTO delete_trigger_exists;

  IF insert_trigger_exists AND update_trigger_exists AND delete_trigger_exists THEN
    RAISE NOTICE '✅ All comment count triggers (INSERT, UPDATE, DELETE) installed successfully';
  ELSE
    RAISE WARNING '⚠️ Some triggers may not have been created';
    RAISE NOTICE 'INSERT trigger: %', insert_trigger_exists;
    RAISE NOTICE 'UPDATE trigger: %', update_trigger_exists;
    RAISE NOTICE 'DELETE trigger: %', delete_trigger_exists;
  END IF;
END $$;

RAISE NOTICE '✅ Migration 003_alt_comment_post_update_trigger.sql completed successfully';
