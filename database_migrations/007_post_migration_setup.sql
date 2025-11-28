-- ============================================================================
-- POST-MIGRATION SETUP & OPTIMIZATION
-- ============================================================================
-- This migration completes the gamification setup:
-- 1. Recalculates truth meters for all existing posts
-- 2. Adds RLS policies for new tables
-- 3. Adds performance indexes
-- 4. Backfills user statistics for existing data
-- ============================================================================

-- ============================================================================
-- PART 1: RECALCULATE TRUTH METERS FOR EXISTING POSTS
-- ============================================================================

-- Function to recalculate truth meter for a single post
CREATE OR REPLACE FUNCTION recalculate_post_truth_meter(p_post_id UUID)
RETURNS VOID AS $$
DECLARE
  up_count INTEGER;
  down_count INTEGER;
  part_count INTEGER;
  fun_count INTEGER;
  total_votes INTEGER;
  weighted_score NUMERIC;
  accuracy NUMERIC;
BEGIN
  -- Count votes for this post
  SELECT
    COUNT(*) FILTER (WHERE vote_type = 'thumbs_up'),
    COUNT(*) FILTER (WHERE vote_type = 'thumbs_down'),
    COUNT(*) FILTER (WHERE vote_type = 'partial'),
    COUNT(*) FILTER (WHERE vote_type = 'funny')
  INTO up_count, down_count, part_count, fun_count
  FROM truth_votes
  WHERE post_id = p_post_id;

  total_votes := up_count + down_count + part_count;

  -- Calculate weighted score (partial = 0.5)
  weighted_score := up_count + (part_count * 0.5) - down_count;

  -- Calculate accuracy percentage
  IF total_votes > 0 THEN
    accuracy := ((up_count + part_count * 0.5) / total_votes) * 100;
  ELSE
    accuracy := 0;
  END IF;

  -- Update post with calculated values
  UPDATE posts
  SET
    vote_count = total_votes,
    thumbs_up_count = up_count,
    thumbs_down_count = down_count,
    partial_count = part_count,
    funny_count = fun_count,
    truth_meter_score = accuracy,
    truth_meter_status = CASE
      WHEN total_votes = 0 THEN 'unrated'
      WHEN admin_verified THEN 'verified_truth'
      WHEN accuracy >= 90 AND total_votes >= 5 THEN 'verified_community'
      WHEN accuracy >= 70 THEN 'likely_true'
      WHEN accuracy >= 50 THEN 'partially_true'
      WHEN accuracy >= 30 THEN 'questionable'
      ELSE 'rumour'
    END
  WHERE id = p_post_id;

  RAISE NOTICE 'Recalculated post %: % votes, %.1f%% accuracy', p_post_id, total_votes, accuracy;
END;
$$ LANGUAGE plpgsql;

-- Recalculate ALL existing posts
DO $$
DECLARE
  post_record RECORD;
  posts_processed INTEGER := 0;
BEGIN
  RAISE NOTICE 'Starting truth meter recalculation for all posts...';

  FOR post_record IN SELECT id FROM posts ORDER BY created_at
  LOOP
    PERFORM recalculate_post_truth_meter(post_record.id);
    posts_processed := posts_processed + 1;
  END LOOP;

  RAISE NOTICE '✅ Recalculated truth meters for % posts', posts_processed;
END $$;

-- ============================================================================
-- PART 2: ADD RLS POLICIES FOR NEW TABLES
-- ============================================================================

-- RLS for user_post_interactions (private tracking table)
ALTER TABLE user_post_interactions ENABLE ROW LEVEL SECURITY;

-- Users can only see their own interactions
DROP POLICY IF EXISTS "Users can view own interactions" ON user_post_interactions;
CREATE POLICY "Users can view own interactions"
ON user_post_interactions FOR SELECT
USING (user_id = auth.uid());

-- System can insert/update (triggers handle this)
DROP POLICY IF EXISTS "System can manage interactions" ON user_post_interactions;
CREATE POLICY "System can manage interactions"
ON user_post_interactions FOR ALL
USING (true)
WITH CHECK (true);

RAISE NOTICE '✅ Created RLS policies for user_post_interactions';

-- RLS for admin_roles
ALTER TABLE admin_roles ENABLE ROW LEVEL SECURITY;

-- Anyone can see who is an admin (transparency)
DROP POLICY IF EXISTS "Admin roles are viewable by everyone" ON admin_roles;
CREATE POLICY "Admin roles are viewable by everyone"
ON admin_roles FOR SELECT
USING (true);

-- Only super_admins can grant roles
DROP POLICY IF EXISTS "Super admins can grant roles" ON admin_roles;
CREATE POLICY "Super admins can grant roles"
ON admin_roles FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM admin_roles
    WHERE user_id = auth.uid()
    AND role = 'super_admin'
  )
);

-- Only super_admins can revoke roles
DROP POLICY IF EXISTS "Super admins can revoke roles" ON admin_roles;
CREATE POLICY "Super admins can revoke roles"
ON admin_roles FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM admin_roles
    WHERE user_id = auth.uid()
    AND role = 'super_admin'
  )
);

RAISE NOTICE '✅ Created RLS policies for admin_roles';

-- RLS for post_verifications
ALTER TABLE post_verifications ENABLE ROW LEVEL SECURITY;

-- Everyone can see verifications (transparency)
DROP POLICY IF EXISTS "Verifications are viewable by everyone" ON post_verifications;
CREATE POLICY "Verifications are viewable by everyone"
ON post_verifications FOR SELECT
USING (true);

-- Only admins/moderators can verify posts
DROP POLICY IF EXISTS "Admins can verify posts" ON post_verifications;
CREATE POLICY "Admins can verify posts"
ON post_verifications FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM admin_roles
    WHERE user_id = auth.uid()
    AND role IN ('admin', 'moderator', 'super_admin')
  )
);

-- Only super_admins can modify verifications
DROP POLICY IF EXISTS "Super admins can modify verifications" ON post_verifications;
CREATE POLICY "Super admins can modify verifications"
ON post_verifications FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM admin_roles
    WHERE user_id = auth.uid()
    AND role = 'super_admin'
  )
);

RAISE NOTICE '✅ Created RLS policies for post_verifications';

-- RLS for suspicious_activity (admin-only access)
ALTER TABLE suspicious_activity ENABLE ROW LEVEL SECURITY;

-- Only admins can view suspicious activity
DROP POLICY IF EXISTS "Admins can view suspicious activity" ON suspicious_activity;
CREATE POLICY "Admins can view suspicious activity"
ON suspicious_activity FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM admin_roles
    WHERE user_id = auth.uid()
    AND role IN ('admin', 'moderator', 'super_admin')
  )
);

-- System can log suspicious activity (triggers handle this)
DROP POLICY IF EXISTS "System can log suspicious activity" ON suspicious_activity;
CREATE POLICY "System can log suspicious activity"
ON suspicious_activity FOR INSERT
WITH CHECK (true);

RAISE NOTICE '✅ Created RLS policies for suspicious_activity';

-- ============================================================================
-- PART 3: ADD PERFORMANCE INDEXES
-- ============================================================================

-- Indexes for frequent queries
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_posts_admin_verified ON posts(admin_verified) WHERE admin_verified = TRUE;
CREATE INDEX IF NOT EXISTS idx_posts_truth_meter_status ON posts(truth_meter_status);
CREATE INDEX IF NOT EXISTS idx_posts_truth_meter_score ON posts(truth_meter_score DESC);

CREATE INDEX IF NOT EXISTS idx_comments_user_id ON comments(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_comments_post_id ON comments(post_id);

CREATE INDEX IF NOT EXISTS idx_truth_votes_post_id ON truth_votes(post_id);
CREATE INDEX IF NOT EXISTS idx_truth_votes_user_id ON truth_votes(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_truth_votes_vote_type ON truth_votes(vote_type);

RAISE NOTICE '✅ Created performance indexes';

-- ============================================================================
-- PART 4: BACKFILL USER STATISTICS (If user_profiles exists)
-- ============================================================================

DO $$
DECLARE
  user_count INTEGER;
BEGIN
  -- Check if user_profiles table exists
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'user_profiles'
  ) THEN
    -- Backfill post counts
    UPDATE user_profiles up
    SET post_count = (
      SELECT COUNT(*)
      FROM posts p
      WHERE p.user_id = up.id
    )
    WHERE EXISTS (
      SELECT 1 FROM posts p WHERE p.user_id = up.id
    );

    -- Backfill comment counts
    UPDATE user_profiles up
    SET comment_count = (
      SELECT COUNT(*)
      FROM comments c
      WHERE c.user_id = up.id
    )
    WHERE EXISTS (
      SELECT 1 FROM comments c WHERE c.user_id = up.id
    );

    -- Backfill vote counts
    UPDATE user_profiles up
    SET vote_count = (
      SELECT COUNT(*)
      FROM truth_votes v
      WHERE v.user_id = up.id
    )
    WHERE EXISTS (
      SELECT 1 FROM truth_votes v WHERE v.user_id = up.id
    );

    SELECT COUNT(*) INTO user_count FROM user_profiles WHERE post_count > 0 OR comment_count > 0 OR vote_count > 0;

    RAISE NOTICE '✅ Backfilled statistics for % users', user_count;
  ELSE
    RAISE NOTICE 'ℹ️  user_profiles table not found, skipping backfill';
  END IF;
END $$;

-- ============================================================================
-- PART 5: CREATE HELPER VIEWS FOR ANALYTICS
-- ============================================================================

-- View: Top posts by truth meter score
CREATE OR REPLACE VIEW top_verified_posts AS
SELECT
  p.id,
  p.title,
  p.truth_meter_score,
  p.truth_meter_status,
  p.vote_count,
  p.thumbs_up_count,
  p.thumbs_down_count,
  p.admin_verified,
  p.created_at,
  CASE
    WHEN p.is_anonymous THEN '🎭 Anonymous'
    ELSE p.author_username
  END as author_display
FROM posts p
WHERE p.vote_count >= 3
ORDER BY p.truth_meter_score DESC, p.vote_count DESC
LIMIT 100;

-- View: Most controversial posts (mixed voting)
CREATE OR REPLACE VIEW controversial_posts AS
SELECT
  p.id,
  p.title,
  p.truth_meter_score,
  p.truth_meter_status,
  p.vote_count,
  p.thumbs_up_count,
  p.thumbs_down_count,
  p.partial_count,
  CASE
    WHEN p.is_anonymous THEN '🎭 Anonymous'
    ELSE p.author_username
  END as author_display,
  -- Controversy score: high when votes are split
  ABS(p.thumbs_up_count - p.thumbs_down_count)::FLOAT / NULLIF(p.vote_count, 0) as controversy_ratio
FROM posts p
WHERE p.vote_count >= 5
AND p.thumbs_up_count > 0
AND p.thumbs_down_count > 0
ORDER BY controversy_ratio ASC, p.vote_count DESC
LIMIT 100;

-- View: Recent suspicious activity
CREATE OR REPLACE VIEW recent_suspicious_activity AS
SELECT
  sa.id,
  sa.activity_type,
  sa.details,
  sa.created_at,
  up.username,
  up.reputation_points,
  up.reputation_level
FROM suspicious_activity sa
LEFT JOIN user_profiles up ON sa.user_id = up.id
ORDER BY sa.created_at DESC
LIMIT 100;

RAISE NOTICE '✅ Created analytics views';

-- ============================================================================
-- PART 6: VERIFICATION QUERIES
-- ============================================================================

-- Show summary of what was set up
DO $$
DECLARE
  total_posts INTEGER;
  posts_with_votes INTEGER;
  avg_truth_score NUMERIC;
  total_users INTEGER;
  total_admins INTEGER;
BEGIN
  SELECT COUNT(*) INTO total_posts FROM posts;
  SELECT COUNT(*) INTO posts_with_votes FROM posts WHERE vote_count > 0;
  SELECT AVG(truth_meter_score) INTO avg_truth_score FROM posts WHERE vote_count > 0;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_profiles') THEN
    SELECT COUNT(*) INTO total_users FROM user_profiles;
    SELECT COUNT(DISTINCT user_id) INTO total_admins FROM admin_roles;
  ELSE
    total_users := 0;
    total_admins := 0;
  END IF;

  RAISE NOTICE '===========================================';
  RAISE NOTICE 'POST-MIGRATION SETUP COMPLETE';
  RAISE NOTICE '===========================================';
  RAISE NOTICE 'Total posts: %', total_posts;
  RAISE NOTICE 'Posts with votes: %', posts_with_votes;
  RAISE NOTICE 'Average truth score: %.1f%%', COALESCE(avg_truth_score, 0);
  RAISE NOTICE 'Total users: %', total_users;
  RAISE NOTICE 'Total admins: %', total_admins;
  RAISE NOTICE '';
  RAISE NOTICE 'Next steps:';
  RAISE NOTICE '1. Grant admin roles to moderators';
  RAISE NOTICE '2. Test point awarding system';
  RAISE NOTICE '3. Update Flutter UI to show reputation & truth meter';
  RAISE NOTICE '';
END $$;

RAISE NOTICE '✅ Migration 007_post_migration_setup.sql completed successfully';
