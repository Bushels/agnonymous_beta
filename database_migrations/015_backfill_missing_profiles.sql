-- ============================================================================
-- BACKFILL MISSING USER PROFILES
-- Migration: 015_backfill_missing_profiles.sql
-- ============================================================================
-- This creates profiles for any auth.users that don't have a user_profiles row
-- Run this to fix users who signed up when the trigger was broken
-- ============================================================================

-- Insert missing profiles for all users who don't have one
INSERT INTO user_profiles (
  id,
  username,
  email,
  email_verified,
  province_state,
  reputation_points,
  public_reputation,
  anonymous_reputation,
  post_count,
  comment_count,
  vote_count
)
SELECT
  au.id,
  COALESCE(
    au.raw_user_meta_data->>'username',
    'user_' || SUBSTRING(au.id::text, 1, 8)
  ) as username,
  au.email,
  COALESCE(au.email_confirmed_at IS NOT NULL, FALSE) as email_verified,
  au.raw_user_meta_data->>'province_state' as province_state,
  0 as reputation_points,
  0 as public_reputation,
  0 as anonymous_reputation,
  0 as post_count,
  0 as comment_count,
  0 as vote_count
FROM auth.users au
WHERE NOT EXISTS (
  SELECT 1 FROM user_profiles up WHERE up.id = au.id
);

-- Report how many were created
DO $$
DECLARE
  missing_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO missing_count
  FROM auth.users au
  WHERE NOT EXISTS (
    SELECT 1 FROM user_profiles up WHERE up.id = au.id
  );

  IF missing_count > 0 THEN
    RAISE NOTICE 'Created % missing user profiles', missing_count;
  ELSE
    RAISE NOTICE 'All users already have profiles - no action needed';
  END IF;
END $$;
