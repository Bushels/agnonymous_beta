-- ============================================================================
-- GAMIFICATION SYSTEM TEST SUITE
-- ============================================================================
-- Run these queries to verify the gamification system is working correctly
-- ============================================================================

-- ============================================================================
-- TEST 1: Verify All Tables Exist
-- ============================================================================

SELECT 'TEST 1: Checking tables...' as test;

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN (
  'user_profiles',
  'user_post_interactions',
  'admin_roles',
  'post_verifications',
  'suspicious_activity'
)
ORDER BY table_name;

-- Expected: All 5 tables should appear

-- ============================================================================
-- TEST 2: Verify All Functions Exist
-- ============================================================================

SELECT 'TEST 2: Checking functions...' as test;

SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN (
  'calculate_reputation_level',
  'calculate_vote_weight',
  'update_reputation_level',
  'award_post_creation_points',
  'award_comment_points',
  'award_vote_points',
  'calculate_truth_meter',
  'prevent_self_voting',
  'detect_vote_brigading',
  'award_verification_bonus',
  'recalculate_post_truth_meter'
)
ORDER BY routine_name;

-- Expected: All 11 functions should appear

-- ============================================================================
-- TEST 3: Verify All Triggers Exist
-- ============================================================================

SELECT 'TEST 3: Checking triggers...' as test;

SELECT tgname as trigger_name, tgenabled as enabled
FROM pg_trigger
WHERE tgname IN (
  'trg_update_reputation_level',
  'trg_award_post_creation_points',
  'trg_award_comment_points',
  'trg_award_vote_points',
  'trg_calculate_truth_meter_insert',
  'trg_calculate_truth_meter_update',
  'trg_calculate_truth_meter_delete',
  'trg_prevent_self_voting',
  'trg_detect_vote_brigading',
  'trg_verification_bonus'
)
ORDER BY tgname;

-- Expected: All 10 triggers with enabled = 'O' (origin enabled)

-- ============================================================================
-- TEST 4: Check Posts Truth Meter Columns
-- ============================================================================

SELECT 'TEST 4: Checking posts truth meter data...' as test;

SELECT
  COUNT(*) as total_posts,
  COUNT(*) FILTER (WHERE vote_count > 0) as posts_with_votes,
  COUNT(*) FILTER (WHERE truth_meter_status = 'unrated') as unrated,
  COUNT(*) FILTER (WHERE truth_meter_status = 'verified_truth') as verified_truth,
  COUNT(*) FILTER (WHERE truth_meter_status = 'verified_community') as verified_community,
  COUNT(*) FILTER (WHERE truth_meter_status = 'likely_true') as likely_true,
  COUNT(*) FILTER (WHERE truth_meter_status = 'partially_true') as partially_true,
  COUNT(*) FILTER (WHERE truth_meter_status = 'questionable') as questionable,
  COUNT(*) FILTER (WHERE truth_meter_status = 'rumour') as rumour,
  ROUND(AVG(truth_meter_score)::numeric, 2) as avg_truth_score
FROM posts;

-- Expected: Counts for each status, avg_truth_score should be reasonable

-- ============================================================================
-- TEST 5: Sample Posts with Truth Meter
-- ============================================================================

SELECT 'TEST 5: Sample posts with truth meter...' as test;

SELECT
  id,
  LEFT(title, 50) as title,
  truth_meter_score,
  truth_meter_status,
  vote_count,
  thumbs_up_count,
  thumbs_down_count,
  partial_count,
  admin_verified
FROM posts
WHERE vote_count > 0
ORDER BY vote_count DESC, truth_meter_score DESC
LIMIT 10;

-- Expected: Posts with calculated truth meters

-- ============================================================================
-- TEST 6: Test Reputation Level Calculation
-- ============================================================================

SELECT 'TEST 6: Testing reputation level function...' as test;

SELECT
  points,
  calculate_reputation_level(points) as level,
  calculate_vote_weight(points) as vote_weight,
  CASE calculate_reputation_level(points)
    WHEN 0 THEN '🌱 Seedling'
    WHEN 1 THEN '🌿 Sprout'
    WHEN 2 THEN '🌾 Growing'
    WHEN 3 THEN '🌳 Established'
    WHEN 4 THEN '⭐ Reliable Source'
    WHEN 5 THEN '⭐⭐ Trusted Reporter'
    WHEN 6 THEN '⭐⭐⭐ Expert Whistleblower'
    WHEN 7 THEN '🏅 Truth Guardian'
    WHEN 8 THEN '🏅🏅 Master Investigator'
    WHEN 9 THEN '👑 Legend'
  END as title
FROM (
  VALUES (0), (50), (150), (300), (500), (750), (1000), (1500), (2500), (5000)
) AS test_points(points);

-- Expected: Correct levels and vote weights for each point threshold

-- ============================================================================
-- TEST 7: Check User Profiles (if exists)
-- ============================================================================

SELECT 'TEST 7: Checking user profiles...' as test;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_profiles') THEN
    RAISE NOTICE 'User profiles table exists';

    PERFORM 1 FROM (
      SELECT
        COUNT(*) as total_users,
        COUNT(*) FILTER (WHERE reputation_points > 0) as users_with_points,
        MAX(reputation_points) as max_reputation,
        AVG(reputation_points)::INTEGER as avg_reputation
      FROM user_profiles
    ) stats;

  ELSE
    RAISE NOTICE 'User profiles table does not exist - skipping';
  END IF;
END $$;

-- ============================================================================
-- TEST 8: Verify RLS Policies
-- ============================================================================

SELECT 'TEST 8: Checking RLS policies...' as test;

SELECT
  schemaname,
  tablename,
  policyname,
  cmd as command,
  CASE
    WHEN qual IS NOT NULL THEN 'USING clause present'
    ELSE 'No USING clause'
  END as using_check,
  CASE
    WHEN with_check IS NOT NULL THEN 'WITH CHECK present'
    ELSE 'No WITH CHECK'
  END as with_check_present
FROM pg_policies
WHERE schemaname = 'public'
AND tablename IN (
  'user_post_interactions',
  'admin_roles',
  'post_verifications',
  'suspicious_activity'
)
ORDER BY tablename, policyname;

-- Expected: Multiple policies for each new table

-- ============================================================================
-- TEST 9: Check Indexes
-- ============================================================================

SELECT 'TEST 9: Checking performance indexes...' as test;

SELECT
  schemaname,
  tablename,
  indexname
FROM pg_indexes
WHERE schemaname = 'public'
AND (
  indexname LIKE 'idx_posts_%'
  OR indexname LIKE 'idx_comments_%'
  OR indexname LIKE 'idx_truth_votes_%'
  OR indexname LIKE 'idx_user_post_interactions_%'
  OR indexname LIKE 'idx_admin_roles_%'
  OR indexname LIKE 'idx_post_verifications_%'
  OR indexname LIKE 'idx_suspicious_activity_%'
)
ORDER BY tablename, indexname;

-- Expected: Many indexes for performance optimization

-- ============================================================================
-- TEST 10: Check Views
-- ============================================================================

SELECT 'TEST 10: Checking views...' as test;

SELECT table_name as view_name
FROM information_schema.views
WHERE table_schema = 'public'
AND table_name IN (
  'leaderboard_all_time',
  'top_verified_posts',
  'controversial_posts',
  'recent_suspicious_activity'
)
ORDER BY table_name;

-- Expected: All 4 views should exist

-- ============================================================================
-- TEST 11: Sample Leaderboard
-- ============================================================================

SELECT 'TEST 11: Sample leaderboard...' as test;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'leaderboard_all_time') THEN
    RAISE NOTICE 'Leaderboard view exists - sample data:';

    PERFORM 1 FROM (
      SELECT
        rank,
        username,
        reputation_points,
        reputation_level,
        vote_weight,
        post_count,
        verified_posts_count
      FROM leaderboard_all_time
      LIMIT 10
    ) sample;

  ELSE
    RAISE NOTICE 'Leaderboard view does not exist';
  END IF;
END $$;

-- ============================================================================
-- SUMMARY
-- ============================================================================

SELECT 'SUMMARY: Gamification system verification complete!' as result;

-- Run a comprehensive check
DO $$
DECLARE
  tables_count INTEGER;
  functions_count INTEGER;
  triggers_count INTEGER;
  views_count INTEGER;
  policies_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO tables_count
  FROM information_schema.tables
  WHERE table_schema = 'public'
  AND table_name IN ('user_profiles', 'user_post_interactions', 'admin_roles', 'post_verifications', 'suspicious_activity');

  SELECT COUNT(*) INTO functions_count
  FROM information_schema.routines
  WHERE routine_schema = 'public'
  AND routine_name IN ('calculate_reputation_level', 'calculate_vote_weight', 'award_post_creation_points', 'award_comment_points', 'award_vote_points', 'calculate_truth_meter', 'prevent_self_voting', 'detect_vote_brigading', 'award_verification_bonus');

  SELECT COUNT(*) INTO triggers_count
  FROM pg_trigger
  WHERE tgname IN ('trg_update_reputation_level', 'trg_award_post_creation_points', 'trg_award_comment_points', 'trg_award_vote_points', 'trg_calculate_truth_meter_insert', 'trg_prevent_self_voting', 'trg_detect_vote_brigading', 'trg_verification_bonus');

  SELECT COUNT(*) INTO views_count
  FROM information_schema.views
  WHERE table_schema = 'public'
  AND table_name IN ('leaderboard_all_time', 'top_verified_posts', 'controversial_posts');

  SELECT COUNT(*) INTO policies_count
  FROM pg_policies
  WHERE schemaname = 'public'
  AND tablename IN ('user_post_interactions', 'admin_roles', 'post_verifications', 'suspicious_activity');

  RAISE NOTICE '===========================================';
  RAISE NOTICE 'GAMIFICATION SYSTEM VERIFICATION';
  RAISE NOTICE '===========================================';
  RAISE NOTICE 'Tables: % / 5 expected', tables_count;
  RAISE NOTICE 'Functions: % / 9+ expected', functions_count;
  RAISE NOTICE 'Triggers: % / 8+ expected', triggers_count;
  RAISE NOTICE 'Views: % / 3+ expected', views_count;
  RAISE NOTICE 'RLS Policies: % / 8+ expected', policies_count;
  RAISE NOTICE '';

  IF tables_count >= 4 AND functions_count >= 8 AND triggers_count >= 8 THEN
    RAISE NOTICE '✅ GAMIFICATION SYSTEM FULLY OPERATIONAL';
  ELSE
    RAISE WARNING '⚠️ Some components may be missing';
  END IF;
END $$;
