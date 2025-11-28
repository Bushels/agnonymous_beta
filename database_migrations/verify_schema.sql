-- ============================================================================
-- DATABASE SCHEMA VERIFICATION SCRIPT
-- Run this to verify that authentication and gamification tables exist
-- ============================================================================

-- 1. Check if user_profiles table exists
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name = 'user_profiles'
    ) THEN '✅ user_profiles table exists'
    ELSE '❌ user_profiles table MISSING'
  END as status;

-- 2. Check user_profiles columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_profiles' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 3. Check if posts table has user_id column
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT FROM information_schema.columns 
      WHERE table_name = 'posts' 
      AND column_name = 'user_id'
      AND table_schema = 'public'
    ) THEN '✅ posts.user_id column exists'
    ELSE '❌ posts.user_id column MISSING'
  END as status;

-- 4. Check if comments table has user_id column
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT FROM information_schema.columns 
      WHERE table_name = 'comments' 
      AND column_name = 'user_id'
      AND table_schema = 'public'
    ) THEN '✅ comments.user_id column exists'
    ELSE '❌ comments.user_id column MISSING'
  END as status;

-- 5. List all public tables
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public'
ORDER BY table_name;

-- 6. Check if gamification functions exist
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN ('get_reputation_level', 'get_vote_weight', 'create_user_profile', 'prevent_self_voting')
ORDER BY routine_name;
