-- ============================================================================
-- ENSURE USER_PROFILES TABLE HAS ALL REQUIRED COLUMNS
-- Migration: 012_ensure_user_profile_columns.sql
-- ============================================================================
-- This migration ensures the user_profiles table has all columns expected by
-- the Flutter app's UserProfile model, including reputation_level, vote_weight,
-- and stat counters.
-- ============================================================================

DO $$
BEGIN
  -- Add reputation_level if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_profiles' AND column_name = 'reputation_level'
  ) THEN
    ALTER TABLE user_profiles ADD COLUMN reputation_level INTEGER DEFAULT 0;
    RAISE NOTICE '✅ Added reputation_level column';
  ELSE
    RAISE NOTICE '✅ reputation_level column already exists';
  END IF;

  -- Add vote_weight if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_profiles' AND column_name = 'vote_weight'
  ) THEN
    ALTER TABLE user_profiles ADD COLUMN vote_weight NUMERIC(3,1) DEFAULT 1.0;
    RAISE NOTICE '✅ Added vote_weight column';
  ELSE
    RAISE NOTICE '✅ vote_weight column already exists';
  END IF;

  -- Add post_count if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_profiles' AND column_name = 'post_count'
  ) THEN
    ALTER TABLE user_profiles ADD COLUMN post_count INTEGER DEFAULT 0;
    RAISE NOTICE '✅ Added post_count column';
  ELSE
    RAISE NOTICE '✅ post_count column already exists';
  END IF;

  -- Add comment_count if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_profiles' AND column_name = 'comment_count'
  ) THEN
    ALTER TABLE user_profiles ADD COLUMN comment_count INTEGER DEFAULT 0;
    RAISE NOTICE '✅ Added comment_count column';
  ELSE
    RAISE NOTICE '✅ comment_count column already exists';
  END IF;

  -- Add vote_count if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_profiles' AND column_name = 'vote_count'
  ) THEN
    ALTER TABLE user_profiles ADD COLUMN vote_count INTEGER DEFAULT 0;
    RAISE NOTICE '✅ Added vote_count column';
  ELSE
    RAISE NOTICE '✅ vote_count column already exists';
  END IF;
END $$;

-- ============================================================================
-- CREATE TRIGGER TO AUTO-CALCULATE REPUTATION LEVEL AND VOTE WEIGHT
-- ============================================================================

CREATE OR REPLACE FUNCTION update_reputation_level()
RETURNS TRIGGER AS $$
BEGIN
  -- Calculate reputation level based on points
  NEW.reputation_level := (
    SELECT CASE
      WHEN NEW.reputation_points < 50 THEN 0
      WHEN NEW.reputation_points < 150 THEN 1
      WHEN NEW.reputation_points < 300 THEN 2
      WHEN NEW.reputation_points < 500 THEN 3
      WHEN NEW.reputation_points < 750 THEN 4
      WHEN NEW.reputation_points < 1000 THEN 5
      WHEN NEW.reputation_points < 1500 THEN 6
      WHEN NEW.reputation_points < 2500 THEN 7
      WHEN NEW.reputation_points < 5000 THEN 8
      ELSE 9
    END
  );

  -- Calculate vote weight based on reputation level
  NEW.vote_weight := (
    SELECT CASE
      WHEN NEW.reputation_points < 150 THEN 1.0
      WHEN NEW.reputation_points < 300 THEN 1.1
      WHEN NEW.reputation_points < 500 THEN 1.2
      WHEN NEW.reputation_points < 750 THEN 1.3
      WHEN NEW.reputation_points < 1000 THEN 1.5
      WHEN NEW.reputation_points < 1500 THEN 1.7
      WHEN NEW.reputation_points < 2500 THEN 2.0
      WHEN NEW.reputation_points < 5000 THEN 2.5
      ELSE 3.0
    END
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create or replace the trigger
DROP TRIGGER IF EXISTS trg_update_reputation_level ON user_profiles;
CREATE TRIGGER trg_update_reputation_level
  BEFORE INSERT OR UPDATE OF reputation_points ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION update_reputation_level();

-- ============================================================================
-- BACKFILL EXISTING USERS (if any exist without these values)
-- ============================================================================

UPDATE user_profiles
SET
  reputation_level = (
    SELECT CASE
      WHEN reputation_points < 50 THEN 0
      WHEN reputation_points < 150 THEN 1
      WHEN reputation_points < 300 THEN 2
      WHEN reputation_points < 500 THEN 3
      WHEN reputation_points < 750 THEN 4
      WHEN reputation_points < 1000 THEN 5
      WHEN reputation_points < 1500 THEN 6
      WHEN reputation_points < 2500 THEN 7
      WHEN reputation_points < 5000 THEN 8
      ELSE 9
    END
  ),
  vote_weight = (
    SELECT CASE
      WHEN reputation_points < 150 THEN 1.0
      WHEN reputation_points < 300 THEN 1.1
      WHEN reputation_points < 500 THEN 1.2
      WHEN reputation_points < 750 THEN 1.3
      WHEN reputation_points < 1000 THEN 1.5
      WHEN reputation_points < 1500 THEN 1.7
      WHEN reputation_points < 2500 THEN 2.0
      WHEN reputation_points < 5000 THEN 2.5
      ELSE 3.0
    END
  )
WHERE reputation_level IS NULL OR vote_weight IS NULL;
