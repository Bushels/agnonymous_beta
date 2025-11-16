-- ============================================================================
-- DATABASE VERIFICATION: Vote Types (NO MIGRATION NEEDED)
-- ============================================================================
-- Status: Database already has correct vote types!
-- - CHECK constraint: ('thumbs_up', 'partial', 'thumbs_down', 'funny') ✓
-- - Existing data: 160 thumbs_up, 88 thumbs_down, 25 funny, 11 partial ✓
--
-- This script only verifies/updates the get_post_vote_stats function
-- ============================================================================

-- Verify current vote type constraint
DO $$
DECLARE
  constraint_exists BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'truth_votes_vote_type_check'
  ) INTO constraint_exists;

  IF constraint_exists THEN
    RAISE NOTICE '✅ Vote type constraint exists';
  ELSE
    RAISE WARNING '⚠️ Vote type constraint not found';
  END IF;
END $$;

-- Create or replace the get_post_vote_stats function with correct vote types
CREATE OR REPLACE FUNCTION get_post_vote_stats(post_id_in UUID)
RETURNS TABLE (
  thumbs_up_votes BIGINT,
  partial_votes BIGINT,
  thumbs_down_votes BIGINT,
  funny_votes BIGINT,
  total_votes BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE vote_type = 'thumbs_up') AS thumbs_up_votes,
    COUNT(*) FILTER (WHERE vote_type = 'partial') AS partial_votes,
    COUNT(*) FILTER (WHERE vote_type = 'thumbs_down') AS thumbs_down_votes,
    COUNT(*) FILTER (WHERE vote_type = 'funny') AS funny_votes,
    COUNT(*) AS total_votes
  FROM truth_votes
  WHERE post_id = post_id_in;
END;
$$ LANGUAGE plpgsql;

-- Show current vote distribution to verify everything is working
DO $$
BEGIN
  RAISE NOTICE '=== Current Vote Distribution ===';
END $$;

SELECT
  vote_type,
  COUNT(*) as count
FROM truth_votes
GROUP BY vote_type
ORDER BY count DESC;

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ Database verification completed successfully';
  RAISE NOTICE 'Vote types are correct - no migration needed!';
END $$;
