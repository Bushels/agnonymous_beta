-- ============================================================================
-- CRITICAL DATABASE MIGRATION: Fix Vote Type Mismatch
-- ============================================================================
-- Issue: Database schema expects ('true', 'partial', 'false') but app sends
--        ('thumbs_up', 'partial', 'thumbs_down', 'funny')
-- Impact: Voting functionality is completely broken
-- Solution: Update database schema to match app implementation
-- ============================================================================

-- Step 1: Drop the existing CHECK constraint
ALTER TABLE truth_votes DROP CONSTRAINT IF EXISTS truth_votes_vote_type_check;

-- Step 2: Update existing data to new vote types (if any exists)
UPDATE truth_votes SET vote_type = 'thumbs_up' WHERE vote_type = 'true';
UPDATE truth_votes SET vote_type = 'thumbs_down' WHERE vote_type = 'false';
-- 'partial' remains the same

-- Step 3: Add new CHECK constraint with correct vote types
ALTER TABLE truth_votes
ADD CONSTRAINT truth_votes_vote_type_check
CHECK (vote_type IN ('thumbs_up', 'partial', 'thumbs_down', 'funny'));

-- Step 4: Update the get_post_vote_stats function to use new vote types
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

-- Step 5: Verify the migration worked
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
    RAISE NOTICE '✅ Vote type constraint successfully updated';
  ELSE
    RAISE WARNING '⚠️ Vote type constraint not found - migration may have failed';
  END IF;
END $$;

-- Step 6: Show sample of vote types to verify
SELECT
  vote_type,
  COUNT(*) as count
FROM truth_votes
GROUP BY vote_type
ORDER BY count DESC;

RAISE NOTICE '✅ Migration 001_fix_vote_types.sql completed successfully';
