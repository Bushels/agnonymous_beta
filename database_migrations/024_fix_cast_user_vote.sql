-- 024_fix_cast_user_vote.sql
-- Fix the cast_user_vote RPC function and add proper permissions
-- Fixes: 400 Bad Request when voting

-- ============================================================================
-- 1. Drop and recreate the function with proper syntax
-- ============================================================================
DROP FUNCTION IF EXISTS cast_user_vote(UUID, UUID, TEXT);

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
  post_user_id UUID;
BEGIN
  -- 1. Security Check: Ensure the caller is the user they claim to be
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Access Denied: You must be logged in to vote.';
  END IF;

  IF auth.uid() != user_id_in THEN
    RAISE EXCEPTION 'Access Denied: You can only cast votes for yourself.';
  END IF;

  -- 2. Validation: Check vote type
  IF vote_type_in NOT IN ('thumbs_up', 'thumbs_down', 'partial', 'funny') THEN
    RAISE EXCEPTION 'Invalid vote type: %. Allowed values are: thumbs_up, thumbs_down, partial, funny', vote_type_in;
  END IF;

  -- 3. Prevent self-voting: Check if user is the post author
  SELECT user_id INTO post_user_id
  FROM posts
  WHERE id = post_id_in;

  IF post_user_id IS NOT NULL AND post_user_id = user_id_in THEN
    RAISE EXCEPTION 'You cannot vote on your own posts.';
  END IF;

  -- 4. Check if user has already voted on this post
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
-- 2. Grant execute permissions to authenticated users
-- ============================================================================
GRANT EXECUTE ON FUNCTION cast_user_vote(UUID, UUID, TEXT) TO authenticated;

-- ============================================================================
-- 3. Add UPDATE policy for truth_votes (for changing votes)
-- ============================================================================
DROP POLICY IF EXISTS "Users can update their own votes" ON truth_votes;
CREATE POLICY "Users can update their own votes"
ON truth_votes FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- ============================================================================
-- 4. Ensure SELECT policy exists for truth_votes
-- ============================================================================
DROP POLICY IF EXISTS "Anyone can read votes" ON truth_votes;
CREATE POLICY "Anyone can read votes"
ON truth_votes FOR SELECT
TO anon, authenticated
USING (true);

-- ============================================================================
-- 5. Ensure RLS is enabled
-- ============================================================================
ALTER TABLE truth_votes ENABLE ROW LEVEL SECURITY;
