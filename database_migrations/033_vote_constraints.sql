-- ============================================
-- ADD UNIQUE VOTING CONSTRAINTS
-- Version: 033
-- Description: Prevent duplicate votes per user/device
-- ============================================

-- 1. Ensure anonymous_user_id cannot be duplicate per post for ANONYMOUS entries
-- This allows one vote per device per post
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_vote_per_anon_device 
ON truth_votes(post_id, anonymous_user_id) 
WHERE anonymous_user_id IS NOT NULL;

-- 2. Ensure user_id cannot be duplicate per post for AUTHENTICATED entries
-- This allows one vote per user per post
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_vote_per_user 
ON truth_votes(post_id, user_id) 
WHERE user_id IS NOT NULL;

RAISE NOTICE '✅ Voting constraints applied to prevent duplicates.';
