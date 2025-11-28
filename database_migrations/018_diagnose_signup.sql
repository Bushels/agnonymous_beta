-- ============================================================================
-- DIAGNOSE SIGNUP ISSUES
-- Run this to see what's happening with users and profiles
-- ============================================================================

-- 1. Show all auth users
SELECT 'AUTH USERS' as section;
SELECT
  id,
  email,
  raw_user_meta_data->>'username' as meta_username,
  created_at
FROM auth.users
ORDER BY created_at DESC
LIMIT 10;

-- 2. Show all profiles
SELECT 'USER PROFILES' as section;
SELECT
  id,
  username,
  email,
  province_state,
  created_at
FROM user_profiles
ORDER BY created_at DESC
LIMIT 10;

-- 3. Find users WITHOUT profiles (orphaned)
SELECT 'ORPHANED USERS (no profile)' as section;
SELECT
  au.id,
  au.email,
  au.raw_user_meta_data->>'username' as meta_username,
  au.created_at
FROM auth.users au
LEFT JOIN user_profiles up ON au.id = up.id
WHERE up.id IS NULL;

-- 4. Check for duplicate usernames
SELECT 'DUPLICATE USERNAMES' as section;
SELECT username, COUNT(*) as count
FROM user_profiles
GROUP BY username
HAVING COUNT(*) > 1;

-- 5. Show current RLS policies
SELECT 'RLS POLICIES' as section;
SELECT
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'user_profiles';

-- 6. Check trigger exists
SELECT 'TRIGGER CHECK' as section;
SELECT
  trigger_name,
  event_manipulation,
  action_statement
FROM information_schema.triggers
WHERE event_object_table = 'users'
AND trigger_schema = 'auth';

-- 7. Summary
DO $$
DECLARE
  auth_count INTEGER;
  profile_count INTEGER;
  orphan_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO auth_count FROM auth.users;
  SELECT COUNT(*) INTO profile_count FROM user_profiles;
  SELECT COUNT(*) INTO orphan_count
  FROM auth.users au
  LEFT JOIN user_profiles up ON au.id = up.id
  WHERE up.id IS NULL;

  RAISE NOTICE '';
  RAISE NOTICE '========== DIAGNOSIS SUMMARY ==========';
  RAISE NOTICE 'Total auth users: %', auth_count;
  RAISE NOTICE 'Total profiles: %', profile_count;
  RAISE NOTICE 'Orphaned users (no profile): %', orphan_count;
  RAISE NOTICE '=======================================';
END $$;
