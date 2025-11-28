-- ============================================================================
-- VERIFY SIGNUP FIX - DIAGNOSTIC SCRIPT
-- ============================================================================
-- Run this script to verify that all signup components are properly configured
-- ============================================================================

-- ============================================================================
-- 1. CHECK USER_PROFILES TABLE SCHEMA
-- ============================================================================
SELECT
  'user_profiles schema' as check_type,
  column_name,
  data_type,
  column_default,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'user_profiles'
ORDER BY ordinal_position;

-- ============================================================================
-- 2. VERIFY REQUIRED COLUMNS EXIST
-- ============================================================================
SELECT
  'Required columns check' as check_type,
  CASE
    WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'reputation_level')
    THEN '✅ reputation_level exists'
    ELSE '❌ reputation_level MISSING'
  END as reputation_level,
  CASE
    WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'vote_weight')
    THEN '✅ vote_weight exists'
    ELSE '❌ vote_weight MISSING'
  END as vote_weight,
  CASE
    WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'post_count')
    THEN '✅ post_count exists'
    ELSE '❌ post_count MISSING'
  END as post_count,
  CASE
    WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'comment_count')
    THEN '✅ comment_count exists'
    ELSE '❌ comment_count MISSING'
  END as comment_count,
  CASE
    WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'vote_count')
    THEN '✅ vote_count exists'
    ELSE '❌ vote_count MISSING'
  END as vote_count,
  CASE
    WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'province_state')
    THEN '✅ province_state exists'
    ELSE '❌ province_state MISSING'
  END as province_state;

-- ============================================================================
-- 3. CHECK TRIGGER EXISTS
-- ============================================================================
SELECT
  'Trigger check' as check_type,
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created';

-- ============================================================================
-- 4. CHECK FUNCTION EXISTS AND VIEW SOURCE
-- ============================================================================
SELECT
  'Function check' as check_type,
  routine_name,
  routine_type,
  data_type as return_type
FROM information_schema.routines
WHERE routine_name = 'create_user_profile';

-- View the actual function source
SELECT
  'Function source' as check_type,
  pg_get_functiondef(oid) as function_definition
FROM pg_proc
WHERE proname = 'create_user_profile';

-- ============================================================================
-- 5. CHECK RLS POLICIES
-- ============================================================================
SELECT
  'RLS Policies' as check_type,
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'user_profiles';

-- ============================================================================
-- 6. TEST USER PROFILE CREATION (SIMULATION)
-- ============================================================================
-- This shows what data would be inserted for a new user
SELECT
  'Simulated signup data' as check_type,
  'test-user-id-123' as id,
  'test@example.com' as email,
  false as email_verified,
  'testuser' as username,
  'Ontario' as province_state,
  0 as reputation_points,
  0 as public_reputation,
  0 as anonymous_reputation,
  0 as reputation_level,
  1.0 as vote_weight,
  0 as post_count,
  0 as comment_count,
  0 as vote_count;

-- ============================================================================
-- 7. COUNT EXISTING USERS
-- ============================================================================
SELECT
  'User count' as check_type,
  COUNT(*) as total_users,
  COUNT(CASE WHEN email IS NOT NULL THEN 1 END) as authenticated_users,
  COUNT(CASE WHEN email IS NULL THEN 1 END) as anonymous_users,
  COUNT(CASE WHEN province_state IS NOT NULL THEN 1 END) as users_with_location,
  COUNT(CASE WHEN reputation_level > 0 THEN 1 END) as users_with_reputation
FROM user_profiles;

-- ============================================================================
-- 8. CHECK FOR NULL VALUES IN CRITICAL FIELDS
-- ============================================================================
SELECT
  'Data integrity check' as check_type,
  COUNT(CASE WHEN reputation_level IS NULL THEN 1 END) as null_reputation_level,
  COUNT(CASE WHEN vote_weight IS NULL THEN 1 END) as null_vote_weight,
  COUNT(CASE WHEN username IS NULL THEN 1 END) as null_username,
  COUNT(CASE WHEN post_count IS NULL THEN 1 END) as null_post_count,
  COUNT(CASE WHEN comment_count IS NULL THEN 1 END) as null_comment_count,
  COUNT(CASE WHEN vote_count IS NULL THEN 1 END) as null_vote_count
FROM user_profiles;

-- ============================================================================
-- INTERPRETATION GUIDE
-- ============================================================================
/*
EXPECTED RESULTS:
-----------------

1. USER_PROFILES SCHEMA:
   - Should show all columns including reputation_level, vote_weight, post_count, comment_count, vote_count
   - reputation_level: integer with default 0
   - vote_weight: numeric(3,1) with default 1.0

2. REQUIRED COLUMNS CHECK:
   - All checks should show ✅
   - If any show ❌, run migration 012_ensure_user_profile_columns.sql

3. TRIGGER CHECK:
   - Should show 'on_auth_user_created' trigger on auth.users table
   - Event: INSERT
   - If missing, run migration 011_fix_signup_trigger.sql

4. FUNCTION CHECK:
   - Should show create_user_profile function
   - Return type: trigger
   - Source should include extraction of province_state from metadata

5. RLS POLICIES:
   - Should show policies for SELECT (public) and UPDATE (own profile only)

6. DATA INTEGRITY CHECK:
   - All null counts should be 0
   - If any nulls exist, run the backfill in migration 012

TROUBLESHOOTING:
----------------
If signup still fails after running migrations:
1. Check Supabase dashboard for auth errors
2. Verify .env file has correct SUPABASE_URL and SUPABASE_ANON_KEY
3. Check browser console / Flutter logs for specific error messages
4. Test with a fresh email address (Supabase may cache failed signups)
*/
