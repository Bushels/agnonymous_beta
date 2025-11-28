-- ============================================================================
-- ADD MISSING RPCs (Hardened)
-- ============================================================================

-- 1. cast_user_vote
-- Hardened with:
-- - Input validation for vote_type
-- - SECURITY DEFINER to run with owner privileges
-- - Explicit auth.uid() check to prevent impersonation
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
BEGIN
  -- 1. Security Check: Ensure the caller is the user they claim to be
  -- This prevents users from calling this RPC with someone else's user_id
  IF auth.uid() != user_id_in THEN
    RAISE EXCEPTION 'Access Denied: You can only cast votes for yourself.';
  END IF;

  -- 2. Validation: Check vote type
  IF vote_type_in NOT IN ('thumbs_up', 'thumbs_down', 'partial', 'funny') THEN
    RAISE EXCEPTION 'Invalid vote type: %. Allowed values are: thumbs_up, thumbs_down, partial, funny', vote_type_in;
  END IF;

  -- 3. Check if user has already voted on this post
  SELECT id INTO existing_vote_id
  FROM truth_votes
  WHERE post_id = post_id_in AND user_id = user_id_in;

  IF existing_vote_id IS NOT NULL THEN
    -- Update existing vote
    UPDATE truth_votes
    SET vote_type = vote_type_in,
        created_at = NOW() -- Update timestamp to reflect latest action
    WHERE id = existing_vote_id;
  ELSE
    -- Insert new vote
    INSERT INTO truth_votes (post_id, user_id, vote_type, is_anonymous)
    VALUES (post_id_in, user_id_in, vote_type_in, TRUE);
  END IF;
END;
$$;

RAISE NOTICE '✅ Created hardened cast_user_vote RPC';

-- 2. get_global_stats
CREATE OR REPLACE FUNCTION get_global_stats()
RETURNS TABLE (
  total_posts BIGINT,
  total_votes BIGINT,
  total_comments BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM posts) as total_posts,
    (SELECT COUNT(*) FROM truth_votes) as total_votes,
    (SELECT COUNT(*) FROM comments) as total_comments;
END;
$$;

RAISE NOTICE '✅ Created get_global_stats RPC';
