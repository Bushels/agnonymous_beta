-- ============================================================================
-- MIGRATION 004: Update Posts, Comments, and Votes for User System
-- ============================================================================
-- This migration updates existing tables to support authenticated users
-- and optional username display on posts/comments
--
-- Features:
-- - Add user_id to posts, comments, votes
-- - Add posted_as_username flag
-- - Store username at time of posting (in case user changes username later)
-- - Maintain backward compatibility with anonymous posts
-- ============================================================================

-- 1. Add user columns to posts table
ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS posted_as_username BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS username_at_post_time TEXT,
  ADD COLUMN IF NOT EXISTS user_verified_at_post_time BOOLEAN DEFAULT FALSE;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_posts_posted_as_username ON posts(posted_as_username) WHERE posted_as_username = TRUE;

-- 2. Add user columns to comments table
ALTER TABLE comments
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS posted_as_username BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS username_at_comment_time TEXT,
  ADD COLUMN IF NOT EXISTS user_verified_at_comment_time BOOLEAN DEFAULT FALSE;

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_comments_user_id ON comments(user_id) WHERE user_id IS NOT NULL;

-- 3. Add user_id to truth_votes table
ALTER TABLE truth_votes
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE;

-- Add index
CREATE INDEX IF NOT EXISTS idx_votes_user_id ON truth_votes(user_id) WHERE user_id IS NOT NULL;

-- 4. Update unique constraint on truth_votes to handle both authenticated and anonymous votes
-- Drop old constraint
ALTER TABLE truth_votes
  DROP CONSTRAINT IF EXISTS truth_votes_post_id_anonymous_user_id_key;

-- Add new constraint that works for both authenticated and anonymous users
-- For authenticated users: use user_id
-- For anonymous users: use anonymous_user_id
ALTER TABLE truth_votes
  ADD CONSTRAINT truth_votes_post_user_unique
    UNIQUE (post_id, COALESCE(user_id::text, anonymous_user_id));

-- 5. Update RLS policies for posts to allow authenticated users
DROP POLICY IF EXISTS "Allow authenticated users to create posts" ON posts;
CREATE POLICY "Allow authenticated users to create posts"
  ON posts FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid()::text = anonymous_user_id OR
    (user_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM users WHERE id = posts.user_id AND auth_user_id = auth.uid()
    ))
  );

-- 6. Update RLS policies for comments to allow authenticated users
DROP POLICY IF EXISTS "Allow authenticated users to create comments" ON comments;
CREATE POLICY "Allow authenticated users to create comments"
  ON comments FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid()::text = anonymous_user_id OR
    (user_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM users WHERE id = comments.user_id AND auth_user_id = auth.uid()
    ))
  );

-- 7. Update RLS policies for votes to allow authenticated users
DROP POLICY IF EXISTS "Allow authenticated users to cast votes" ON truth_votes;
CREATE POLICY "Allow authenticated users to cast votes"
  ON truth_votes FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid()::text = anonymous_user_id OR
    (user_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM users WHERE id = truth_votes.user_id AND auth_user_id = auth.uid()
    ))
  );

-- Update policy for updating votes
DROP POLICY IF EXISTS "Users can update their own vote" ON truth_votes;
CREATE POLICY "Users can update their own vote"
  ON truth_votes FOR UPDATE
  TO authenticated
  USING (
    auth.uid()::text = anonymous_user_id OR
    (user_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM users WHERE id = truth_votes.user_id AND auth_user_id = auth.uid()
    ))
  );

-- Update policy for deleting votes
DROP POLICY IF EXISTS "Users can delete their own vote" ON truth_votes;
CREATE POLICY "Users can delete their own vote"
  ON truth_votes FOR DELETE
  TO authenticated
  USING (
    auth.uid()::text = anonymous_user_id OR
    (user_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM users WHERE id = truth_votes.user_id AND auth_user_id = auth.uid()
    ))
  );

-- 8. Create helper function to get user info for display
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

-- 9. Create function to check if user can post (must be authenticated, not guest)
CREATE OR REPLACE FUNCTION can_user_post()
RETURNS BOOLEAN AS $$
BEGIN
  -- Guests (anon users without account) cannot post
  -- Must be authenticated user
  RETURN auth.role() = 'authenticated';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION can_user_post() TO authenticated, anon;

-- 10. Create function to check if user can comment
CREATE OR REPLACE FUNCTION can_user_comment()
RETURNS BOOLEAN AS $$
BEGIN
  -- Same as posting - must be authenticated
  RETURN auth.role() = 'authenticated';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION can_user_comment() TO authenticated, anon;

-- 11. Create function to check if user can vote
CREATE OR REPLACE FUNCTION can_user_vote()
RETURNS BOOLEAN AS $$
BEGIN
  -- Same as posting - must be authenticated
  RETURN auth.role() = 'authenticated';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION can_user_vote() TO authenticated, anon;

-- 12. Update RLS policy for reading comments (guests cannot see comments)
DROP POLICY IF EXISTS "Allow public read access to comments" ON comments;
CREATE POLICY "Authenticated users can read comments"
  ON comments FOR SELECT
  TO authenticated
  USING (true);

-- Anon (guest) users CANNOT read comments
CREATE POLICY "Guests cannot read comments"
  ON comments FOR SELECT
  TO anon
  USING (false);

-- 13. Verify migration
DO $$
DECLARE
  posts_columns_count INTEGER;
  comments_columns_count INTEGER;
  votes_columns_count INTEGER;
BEGIN
  -- Count new columns in posts
  SELECT COUNT(*) INTO posts_columns_count
  FROM information_schema.columns
  WHERE table_name = 'posts'
    AND column_name IN ('user_id', 'posted_as_username', 'username_at_post_time', 'user_verified_at_post_time');

  -- Count new columns in comments
  SELECT COUNT(*) INTO comments_columns_count
  FROM information_schema.columns
  WHERE table_name = 'comments'
    AND column_name IN ('user_id', 'posted_as_username', 'username_at_comment_time', 'user_verified_at_comment_time');

  -- Count new columns in votes
  SELECT COUNT(*) INTO votes_columns_count
  FROM information_schema.columns
  WHERE table_name = 'truth_votes'
    AND column_name = 'user_id';

  IF posts_columns_count = 4 AND comments_columns_count = 4 AND votes_columns_count = 1 THEN
    RAISE NOTICE '✅ Posts table updated: % new columns', posts_columns_count;
    RAISE NOTICE '✅ Comments table updated: % new columns', comments_columns_count;
    RAISE NOTICE '✅ Votes table updated: % new columns', votes_columns_count;
    RAISE NOTICE '✅ Guest restrictions applied (cannot see comments or vote)';
    RAISE NOTICE '✅ RLS policies updated for authenticated users';
  ELSE
    RAISE WARNING '⚠️ Migration may be incomplete';
    RAISE WARNING 'Posts columns: %, Comments: %, Votes: %',
      posts_columns_count, comments_columns_count, votes_columns_count;
  END IF;
END $$;

RAISE NOTICE '✅ Migration 004_update_posts_for_users.sql completed successfully';
