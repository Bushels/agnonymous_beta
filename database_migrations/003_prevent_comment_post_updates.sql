-- ============================================================================
-- PREVENT COMMENT POST_ID UPDATES (Optional Security Enhancement)
-- ============================================================================
-- This prevents comments from being moved between posts, which could:
-- 1. Corrupt comment counts if UPDATE trigger not implemented
-- 2. Be used to de-anonymize users by correlating comment patterns
-- 3. Break comment threading logic
-- ============================================================================

-- Create trigger function to prevent post_id changes
CREATE OR REPLACE FUNCTION prevent_comment_post_update()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.post_id != NEW.post_id THEN
    RAISE EXCEPTION 'Changing comment post_id is not allowed. Delete and recreate instead.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Install trigger
DROP TRIGGER IF EXISTS trg_prevent_comment_post_update ON comments;
CREATE TRIGGER trg_prevent_comment_post_update
  BEFORE UPDATE ON comments
  FOR EACH ROW
  WHEN (OLD.post_id IS DISTINCT FROM NEW.post_id)
  EXECUTE FUNCTION prevent_comment_post_update();

-- Verify trigger was created
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trg_prevent_comment_post_update'
  ) THEN
    RAISE NOTICE '✅ Comment post_id protection trigger installed successfully';
  ELSE
    RAISE WARNING '⚠️ Trigger may not have been created';
  END IF;
END $$;

RAISE NOTICE '✅ Migration 003_prevent_comment_post_updates.sql completed successfully';
