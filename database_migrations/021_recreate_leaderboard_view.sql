-- Recreate the leaderboard_all_time view to ensure it exists
-- This fixes the "relation public.leaderboard_all_time does not exist" error

DROP VIEW IF EXISTS leaderboard_all_time;

CREATE OR REPLACE VIEW leaderboard_all_time AS
SELECT
  up.id,
  up.username,
  up.email_verified,
  up.public_reputation,
  up.reputation_points,
  up.reputation_level,
  up.vote_weight,
  up.post_count,
  (
    SELECT COUNT(*)
    FROM posts p
    WHERE p.user_id = up.id AND p.admin_verified = TRUE
  ) as verified_posts_count,
  (
    SELECT AVG(p.truth_meter_score)
    FROM posts p
    WHERE p.user_id = up.id AND p.vote_count >= 3
  ) as avg_accuracy,
  ROW_NUMBER() OVER (ORDER BY up.reputation_points DESC) as rank
FROM user_profiles up
WHERE up.public_reputation > 0
ORDER BY up.reputation_points DESC;

RAISE NOTICE '✅ Recreated leaderboard_all_time view';
