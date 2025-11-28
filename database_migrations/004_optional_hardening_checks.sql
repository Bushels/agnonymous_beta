-- ============================================================================
-- OPTIONAL HARDENING: Add Table-Level Constraints
-- ============================================================================
-- These constraints provide additional data integrity protection at the database level
-- Run this AFTER migration 003 for defense-in-depth security
-- ============================================================================

-- 1. Ensure post_id is never NULL in comments table
-- (This should already exist from table creation, but we'll verify/add it)
DO $$
BEGIN
  -- Check if NOT NULL constraint exists
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'comments'
    AND column_name = 'post_id'
    AND is_nullable = 'NO'
  ) THEN
    -- Add NOT NULL constraint if missing
    ALTER TABLE comments
    ALTER COLUMN post_id SET NOT NULL;
    RAISE NOTICE '✅ Added NOT NULL constraint to comments.post_id';
  ELSE
    RAISE NOTICE '✅ NOT NULL constraint already exists on comments.post_id';
  END IF;
END $$;

-- 2. Verify foreign key constraint exists
-- (This ensures every comment.post_id references a valid post)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
    WHERE tc.table_name = 'comments'
    AND tc.constraint_type = 'FOREIGN KEY'
    AND kcu.column_name = 'post_id'
  ) THEN
    RAISE NOTICE '✅ Foreign key constraint exists on comments.post_id';
  ELSE
    RAISE WARNING '⚠️ No foreign key constraint found on comments.post_id';
    RAISE NOTICE 'Consider adding: ALTER TABLE comments ADD CONSTRAINT fk_comments_post_id FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;';
  END IF;
END $$;

-- 3. Ensure post_id is never NULL in truth_votes table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'truth_votes'
    AND column_name = 'post_id'
    AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE truth_votes
    ALTER COLUMN post_id SET NOT NULL;
    RAISE NOTICE '✅ Added NOT NULL constraint to truth_votes.post_id';
  ELSE
    RAISE NOTICE '✅ NOT NULL constraint already exists on truth_votes.post_id';
  END IF;
END $$;

-- 4. Verify foreign key constraint on truth_votes
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
    WHERE tc.table_name = 'truth_votes'
    AND tc.constraint_type = 'FOREIGN KEY'
    AND kcu.column_name = 'post_id'
  ) THEN
    RAISE NOTICE '✅ Foreign key constraint exists on truth_votes.post_id';
  ELSE
    RAISE WARNING '⚠️ No foreign key constraint found on truth_votes.post_id';
    RAISE NOTICE 'Consider adding: ALTER TABLE truth_votes ADD CONSTRAINT fk_truth_votes_post_id FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;';
  END IF;
END $$;

-- 5. Add CHECK constraint to ensure comment_count is never negative
-- (Additional protection beyond GREATEST() in triggers)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.check_constraints
    WHERE constraint_name = 'chk_comment_count_non_negative'
  ) THEN
    ALTER TABLE posts
    ADD CONSTRAINT chk_comment_count_non_negative
    CHECK (comment_count >= 0);
    RAISE NOTICE '✅ Added CHECK constraint to ensure comment_count >= 0';
  ELSE
    RAISE NOTICE '✅ CHECK constraint already exists on posts.comment_count';
  END IF;
END $$;

-- 6. Verify comment content is not empty
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.check_constraints
    WHERE constraint_name = 'chk_comment_content_not_empty'
  ) THEN
    ALTER TABLE comments
    ADD CONSTRAINT chk_comment_content_not_empty
    CHECK (LENGTH(TRIM(content)) > 0);
    RAISE NOTICE '✅ Added CHECK constraint to prevent empty comments';
  ELSE
    RAISE NOTICE '✅ CHECK constraint already exists on comment content';
  END IF;
END $$;

-- 7. Summary of all constraints
RAISE NOTICE '===========================================';
RAISE NOTICE 'SECURITY HARDENING SUMMARY';
RAISE NOTICE '===========================================';

-- Show all constraints on comments table
DO $$
DECLARE
  constraint_count INTEGER;
BEGIN
  SELECT COUNT(*)
  INTO constraint_count
  FROM information_schema.table_constraints
  WHERE table_name = 'comments';

  RAISE NOTICE 'Total constraints on comments table: %', constraint_count;
END $$;

-- Show all triggers on comments table
DO $$
DECLARE
  trigger_count INTEGER;
BEGIN
  SELECT COUNT(*)
  INTO trigger_count
  FROM pg_trigger
  WHERE tgname LIKE '%comment%'
  AND tgname NOT LIKE 'RI_%'; -- Exclude system triggers

  RAISE NOTICE 'Total custom triggers on comments: %', trigger_count;
END $$;

RAISE NOTICE '✅ Migration 004_optional_hardening_checks.sql completed successfully';
