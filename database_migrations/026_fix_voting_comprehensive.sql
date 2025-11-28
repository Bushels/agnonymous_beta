-- 026_fix_voting_comprehensive.sql
-- Comprehensive fix for voting system - 400 Bad Request errors
-- This migration ensures the voting system works end-to-end

-- ============================================================================
-- 1. Ensure truth_votes table exists with correct schema
-- ============================================================================
CREATE TABLE IF NOT EXISTS truth_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  vote_type TEXT NOT NULL CHECK (vote_type IN ('thumbs_up', 'thumbs_down', 'partial', 'funny')),
  is_anonymous BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT unique_user_post_vote UNIQUE(user_id, post_id)
);

-- Add indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_truth_votes_post_id ON truth_votes(post_id);
CREATE INDEX IF NOT EXISTS idx_truth_votes_user_id ON truth_votes(user_id);

-- ============================================================================
-- 2. Enable RLS on truth_votes
-- ============================================================================
ALTER TABLE truth_votes ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 3. Drop ALL existing versions of cast_user_vote function
-- ============================================================================
DROP FUNCTION IF EXISTS cast_user_vote(UUID, UUID, TEXT);
DROP FUNCTION IF EXISTS public.cast_user_vote(UUID, UUID, TEXT);

-- ============================================================================
-- 4. Create the cast_user_vote function with EXACT parameter names
--    The client sends: post_id_in, user_id_in, vote_type_in
-- ============================================================================
CREATE OR REPLACE FUNCTION cast_user_vote(
  post_id_in UUID,
  user_id_in UUID,
  vote_type_in TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  existing_vote_id UUID;
  post_author_id UUID;
BEGIN
  -- 1. Security Check: Ensure the caller is logged in
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Access Denied: You must be logged in to vote.';
  END IF;

  -- 2. Security Check: Ensure caller is voting for themselves
  IF auth.uid() != user_id_in THEN
    RAISE EXCEPTION 'Access Denied: You can only cast votes for yourself.';
  END IF;

  -- 3. Validation: Check vote type
  IF vote_type_in NOT IN ('thumbs_up', 'thumbs_down', 'partial', 'funny') THEN
    RAISE EXCEPTION 'Invalid vote type: %. Allowed: thumbs_up, thumbs_down, partial, funny', vote_type_in;
  END IF;

  -- 4. Prevent self-voting: Get post author
  SELECT user_id INTO post_author_id
  FROM posts
  WHERE id = post_id_in;

  IF post_author_id IS NOT NULL AND post_author_id = user_id_in THEN
    RAISE EXCEPTION 'You cannot vote on your own posts.';
  END IF;

  -- 5. Check if user has already voted on this post
  SELECT id INTO existing_vote_id
  FROM truth_votes
  WHERE post_id = post_id_in AND user_id = user_id_in;

  IF existing_vote_id IS NOT NULL THEN
    -- Update existing vote
    UPDATE truth_votes
    SET vote_type = vote_type_in,
        created_at = NOW()
    WHERE id = existing_vote_id;
  ELSE
    -- Insert new vote
    INSERT INTO truth_votes (post_id, user_id, vote_type, is_anonymous)
    VALUES (post_id_in, user_id_in, vote_type_in, TRUE);
  END IF;
END;
$$;

-- ============================================================================
-- 5. Grant execute permissions
-- ============================================================================
GRANT EXECUTE ON FUNCTION cast_user_vote(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION cast_user_vote(UUID, UUID, TEXT) TO anon;

-- ============================================================================
-- 6. Create/update RLS policies for truth_votes
-- ============================================================================

-- Policy: Anyone can read votes (for displaying vote counts)
DROP POLICY IF EXISTS "Anyone can read votes" ON truth_votes;
CREATE POLICY "Anyone can read votes"
ON truth_votes FOR SELECT
TO anon, authenticated
USING (true);

-- Policy: Authenticated users can insert their own votes
DROP POLICY IF EXISTS "Users can insert own votes" ON truth_votes;
CREATE POLICY "Users can insert own votes"
ON truth_votes FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- Policy: Authenticated users can update their own votes
DROP POLICY IF EXISTS "Users can update own votes" ON truth_votes;
CREATE POLICY "Users can update own votes"
ON truth_votes FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Policy: Authenticated users can delete their own votes
DROP POLICY IF EXISTS "Users can delete own votes" ON truth_votes;
CREATE POLICY "Users can delete own votes"
ON truth_votes FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- ============================================================================
-- 7. Create trigger to update vote counts on posts table
-- ============================================================================

-- First ensure posts table has vote count columns
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name = 'posts' AND column_name = 'thumbs_up_count') THEN
    ALTER TABLE posts ADD COLUMN thumbs_up_count INTEGER DEFAULT 0;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name = 'posts' AND column_name = 'thumbs_down_count') THEN
    ALTER TABLE posts ADD COLUMN thumbs_down_count INTEGER DEFAULT 0;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name = 'posts' AND column_name = 'partial_count') THEN
    ALTER TABLE posts ADD COLUMN partial_count INTEGER DEFAULT 0;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name = 'posts' AND column_name = 'funny_count') THEN
    ALTER TABLE posts ADD COLUMN funny_count INTEGER DEFAULT 0;
  END IF;
END $$;

-- Create function to update vote counts
CREATE OR REPLACE FUNCTION update_post_vote_counts()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  target_post_id UUID;
BEGIN
  -- Determine which post to update
  IF TG_OP = 'DELETE' THEN
    target_post_id := OLD.post_id;
  ELSE
    target_post_id := NEW.post_id;
  END IF;

  -- Update the post with fresh vote counts
  UPDATE posts
  SET
    thumbs_up_count = (SELECT COUNT(*) FROM truth_votes WHERE post_id = target_post_id AND vote_type = 'thumbs_up'),
    thumbs_down_count = (SELECT COUNT(*) FROM truth_votes WHERE post_id = target_post_id AND vote_type = 'thumbs_down'),
    partial_count = (SELECT COUNT(*) FROM truth_votes WHERE post_id = target_post_id AND vote_type = 'partial'),
    funny_count = (SELECT COUNT(*) FROM truth_votes WHERE post_id = target_post_id AND vote_type = 'funny')
  WHERE id = target_post_id;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_update_vote_counts ON truth_votes;
CREATE TRIGGER trigger_update_vote_counts
AFTER INSERT OR UPDATE OR DELETE ON truth_votes
FOR EACH ROW
EXECUTE FUNCTION update_post_vote_counts();

-- ============================================================================
-- 8. Grant table permissions
-- ============================================================================
GRANT SELECT ON truth_votes TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON truth_votes TO authenticated;

-- ============================================================================
-- 9. Verification query (run this to test)
-- ============================================================================
-- SELECT proname, proargtypes::regtype[]
-- FROM pg_proc
-- WHERE proname = 'cast_user_vote';
