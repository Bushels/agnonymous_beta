-- ============================================================================
-- MIGRATION 004 (REVISED): Update Posts for OPTIONAL User System
-- ============================================================================
-- This migration updates tables to support OPTIONAL authenticated users
-- while maintaining low-friction anonymous posting
--
-- KEY PRINCIPLE: Anonymous posting remains the default and easy path
-- Accounts are OPTIONAL for those who want gamification
-- ============================================================================

-- 1. Add user columns to posts table (same as before)
ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS posted_as_username BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS username_at_post_time TEXT,
  ADD COLUMN IF NOT EXISTS user_verified_at_post_time BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_posts_posted_as_username ON posts(posted_as_username) WHERE posted_as_username = TRUE;

-- 2. Add user columns to comments table (same as before)
ALTER TABLE comments
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS posted_as_username BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS username_at_comment_time TEXT,
  ADD COLUMN IF NOT EXISTS user_verified_at_comment_time BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_comments_user_id ON comments(user_id) WHERE user_id IS NOT NULL;

-- 3. Add user_id to truth_votes table (same as before)
ALTER TABLE truth_votes
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_votes_user_id ON truth_votes(user_id) WHERE user_id IS NOT NULL;

-- 4. Update unique constraint on truth_votes (same as before)
ALTER TABLE truth_votes
  DROP CONSTRAINT IF EXISTS truth_votes_post_id_anonymous_user_id_key;

ALTER TABLE truth_votes
  ADD CONSTRAINT truth_votes_post_user_unique
    UNIQUE (post_id, COALESCE(user_id::text, anonymous_user_id));

-- 5. RLS Policies for posts - ALLOW ANONYMOUS POSTING
DROP POLICY IF EXISTS "Allow authenticated users to create posts" ON posts;
DROP POLICY IF EXISTS "Allow anonymous users to create posts" ON posts;

-- Anyone can create posts (anonymous or authenticated)
CREATE POLICY "Anyone can create posts"
  ON posts FOR INSERT
  TO authenticated, anon
  WITH CHECK (true);

-- 6. RLS Policies for comments - ALLOW ANONYMOUS COMMENTS
DROP POLICY IF EXISTS "Allow authenticated users to create comments" ON comments;
DROP POLICY IF EXISTS "Allow anonymous users to create comments" ON comments;
DROP POLICY IF EXISTS "Guests cannot read comments" ON comments;

-- Anyone can read comments
CREATE POLICY "Anyone can read comments"
  ON comments FOR SELECT
  TO authenticated, anon
  USING (true);

-- Anyone can create comments (anonymous or authenticated)
CREATE POLICY "Anyone can create comments"
  ON comments FOR INSERT
  TO authenticated, anon
  WITH CHECK (true);

-- 7. RLS Policies for votes - ALLOW ANONYMOUS VOTING
DROP POLICY IF EXISTS "Allow authenticated users to cast votes" ON truth_votes;
DROP POLICY IF EXISTS "Users can update their own vote" ON truth_votes;
DROP POLICY IF EXISTS "Users can delete their own vote" ON truth_votes;

-- Anyone can cast votes
CREATE POLICY "Anyone can cast votes"
  ON truth_votes FOR INSERT
  TO authenticated, anon
  WITH CHECK (true);

-- Users can update their own vote (by anonymous_user_id or user_id)
CREATE POLICY "Users can update their own vote"
  ON truth_votes FOR UPDATE
  TO authenticated, anon
  USING (
    anonymous_user_id = COALESCE(auth.uid()::text, anonymous_user_id) OR
    (user_id IS NOT NULL AND user_id IN (
      SELECT id FROM users WHERE auth_user_id = auth.uid()
    ))
  );

-- Users can delete their own vote
CREATE POLICY "Users can delete their own vote"
  ON truth_votes FOR DELETE
  TO authenticated, anon
  USING (
    anonymous_user_id = COALESCE(auth.uid()::text, anonymous_user_id) OR
    (user_id IS NOT NULL AND user_id IN (
      SELECT id FROM users WHERE auth_user_id = auth.uid()
    ))
  );

-- 8. Helper function to get user info for display (same as before)
CREATE OR REPLACE FUNCTION get_user_display_info(user_id_param UUID)
RETURNS TABLE (
  username TEXT,
  display_name TEXT,
  verified BOOLEAN,
  points INTEGER,
  badges JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.username,
    COALESCE(u.display_name, u.username) as display_name,
    u.email_verified as verified,
    u.points,
    u.badges
  FROM users u
  WHERE u.id = user_id_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_user_display_info(UUID) TO authenticated, anon;

-- 9. Remove restrictive permission check functions
DROP FUNCTION IF EXISTS can_user_post();
DROP FUNCTION IF EXISTS can_user_comment();
DROP FUNCTION IF EXISTS can_user_vote();

-- 10. Verify migration
DO $$
DECLARE
  posts_columns_count INTEGER;
  comments_columns_count INTEGER;
  votes_columns_count INTEGER;
BEGIN
  -- Count new columns
  SELECT COUNT(*) INTO posts_columns_count
  FROM information_schema.columns
  WHERE table_name = 'posts'
    AND column_name IN ('user_id', 'posted_as_username', 'username_at_post_time', 'user_verified_at_post_time');

  SELECT COUNT(*) INTO comments_columns_count
  FROM information_schema.columns
  WHERE table_name = 'comments'
    AND column_name IN ('user_id', 'posted_as_username', 'username_at_comment_time', 'user_verified_at_comment_time');

  SELECT COUNT(*) INTO votes_columns_count
  FROM information_schema.columns
  WHERE table_name = 'truth_votes'
    AND column_name = 'user_id';

  IF posts_columns_count = 4 AND comments_columns_count = 4 AND votes_columns_count = 1 THEN
    RAISE NOTICE '✅ Posts table updated: % new columns', posts_columns_count;
    RAISE NOTICE '✅ Comments table updated: % new columns', comments_columns_count;
    RAISE NOTICE '✅ Votes table updated: % new columns', votes_columns_count;
    RAISE NOTICE '✅ LOW FRICTION MODE: Anonymous posting fully enabled';
    RAISE NOTICE '✅ Users can post/comment/vote WITHOUT creating account';
    RAISE NOTICE '✅ Optional: Users WITH accounts can post as username for points';
  ELSE
    RAISE WARNING '⚠️ Migration may be incomplete';
  END IF;
END $$;

RAISE NOTICE '✅ Migration 004_update_posts_for_users_REVISED.sql completed';
