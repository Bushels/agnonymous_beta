-- Anonymous board v1 reset.
-- Keeps the applied Supabase migration folder aligned with the no-login board.

ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE truth_votes ENABLE ROW LEVEL SECURITY;

ALTER TABLE posts ADD COLUMN IF NOT EXISTS anonymous_user_id TEXT;
ALTER TABLE posts ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT TRUE;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS comment_count INTEGER DEFAULT 0;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS vote_count INTEGER DEFAULT 0;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS thumbs_up_count INTEGER DEFAULT 0;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS thumbs_down_count INTEGER DEFAULT 0;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS partial_count INTEGER DEFAULT 0;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS funny_count INTEGER DEFAULT 0;

ALTER TABLE comments ADD COLUMN IF NOT EXISTS anonymous_user_id TEXT;
ALTER TABLE comments ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE comments ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT TRUE;
ALTER TABLE comments ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE;

ALTER TABLE truth_votes ADD COLUMN IF NOT EXISTS anonymous_user_id TEXT;
ALTER TABLE truth_votes ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE truth_votes ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT TRUE;

CREATE INDEX IF NOT EXISTS idx_posts_category_created_at
  ON posts(category, created_at DESC)
  WHERE COALESCE(is_deleted, FALSE) = FALSE;
CREATE INDEX IF NOT EXISTS idx_posts_created_at_active
  ON posts(created_at DESC)
  WHERE COALESCE(is_deleted, FALSE) = FALSE;
CREATE INDEX IF NOT EXISTS idx_comments_post_id_created_at
  ON comments(post_id, created_at ASC)
  WHERE COALESCE(is_deleted, FALSE) = FALSE;
CREATE INDEX IF NOT EXISTS idx_truth_votes_post_id
  ON truth_votes(post_id);
CREATE INDEX IF NOT EXISTS idx_truth_votes_post_anon
  ON truth_votes(post_id, anonymous_user_id)
  WHERE anonymous_user_id IS NOT NULL;

DROP POLICY IF EXISTS "Anyone can read posts" ON posts;
DROP POLICY IF EXISTS "Anyone can create anonymous posts" ON posts;
DROP POLICY IF EXISTS "Anyone can create posts" ON posts;

CREATE POLICY "Anyone can read posts"
  ON posts FOR SELECT
  TO anon, authenticated
  USING (COALESCE(is_deleted, FALSE) = FALSE);

CREATE POLICY "Anyone can create anonymous posts"
  ON posts FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    anonymous_user_id IS NOT NULL
    AND COALESCE(is_anonymous, TRUE) = TRUE
    AND user_id IS NULL
  );

DROP POLICY IF EXISTS "Anyone can read comments" ON comments;
DROP POLICY IF EXISTS "Anyone can create anonymous comments" ON comments;
DROP POLICY IF EXISTS "Anyone can create comments" ON comments;

CREATE POLICY "Anyone can read comments"
  ON comments FOR SELECT
  TO anon, authenticated
  USING (COALESCE(is_deleted, FALSE) = FALSE);

CREATE POLICY "Anyone can create anonymous comments"
  ON comments FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    anonymous_user_id IS NOT NULL
    AND COALESCE(is_anonymous, TRUE) = TRUE
    AND user_id IS NULL
  );

DROP POLICY IF EXISTS "Anyone can read votes" ON truth_votes;
DROP POLICY IF EXISTS "Anyone can cast votes" ON truth_votes;
DROP POLICY IF EXISTS "Anyone can update own votes" ON truth_votes;
DROP POLICY IF EXISTS "Users can insert own votes" ON truth_votes;
DROP POLICY IF EXISTS "Users can update own votes" ON truth_votes;
DROP POLICY IF EXISTS "Users can delete own votes" ON truth_votes;

CREATE POLICY "Anyone can read votes"
  ON truth_votes FOR SELECT
  TO anon, authenticated
  USING (TRUE);

GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT, INSERT ON posts TO anon, authenticated;
GRANT SELECT, INSERT ON comments TO anon, authenticated;
GRANT SELECT ON truth_votes TO anon, authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;

DROP FUNCTION IF EXISTS cast_user_vote(UUID, UUID, TEXT);
DROP FUNCTION IF EXISTS cast_user_vote(UUID, UUID, TEXT, TEXT);

CREATE OR REPLACE FUNCTION cast_user_vote(
  post_id_in UUID,
  user_id_in UUID,
  anonymous_user_id_in TEXT,
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
  post_anonymous_user_id TEXT;
  voter_anonymous_user_id TEXT;
BEGIN
  voter_anonymous_user_id := NULLIF(BTRIM(anonymous_user_id_in), '');

  IF vote_type_in NOT IN ('thumbs_up', 'thumbs_down', 'partial', 'funny') THEN
    RAISE EXCEPTION 'Invalid vote type';
  END IF;

  IF user_id_in IS NULL AND voter_anonymous_user_id IS NULL THEN
    RAISE EXCEPTION 'Anonymous vote id required';
  END IF;

  IF user_id_in IS NOT NULL AND auth.uid() IS DISTINCT FROM user_id_in THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  SELECT user_id, anonymous_user_id
  INTO post_user_id, post_anonymous_user_id
  FROM posts
  WHERE id = post_id_in
    AND COALESCE(is_deleted, FALSE) = FALSE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Post not found';
  END IF;

  IF user_id_in IS NOT NULL AND post_user_id = user_id_in THEN
    RAISE EXCEPTION 'You cannot vote on your own post';
  END IF;

  IF voter_anonymous_user_id IS NOT NULL
     AND post_anonymous_user_id = voter_anonymous_user_id THEN
    RAISE EXCEPTION 'You cannot vote on your own post';
  END IF;

  SELECT id INTO existing_vote_id
  FROM truth_votes
  WHERE post_id = post_id_in
    AND (
      (user_id_in IS NOT NULL AND user_id = user_id_in)
      OR
      (voter_anonymous_user_id IS NOT NULL AND anonymous_user_id = voter_anonymous_user_id)
    )
  ORDER BY created_at DESC
  LIMIT 1;

  IF existing_vote_id IS NOT NULL THEN
    UPDATE truth_votes
    SET vote_type = vote_type_in,
        is_anonymous = TRUE,
        created_at = NOW()
    WHERE id = existing_vote_id;
  ELSE
    INSERT INTO truth_votes (
      post_id,
      user_id,
      anonymous_user_id,
      vote_type,
      is_anonymous
    )
    VALUES (
      post_id_in,
      user_id_in,
      voter_anonymous_user_id,
      vote_type_in,
      TRUE
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION cast_user_vote(UUID, UUID, TEXT, TEXT)
  TO anon, authenticated;

CREATE OR REPLACE FUNCTION get_post_vote_stats(post_id_in UUID)
RETURNS TABLE (
  thumbs_up_votes BIGINT,
  partial_votes BIGINT,
  thumbs_down_votes BIGINT,
  funny_votes BIGINT,
  total_votes BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE vote_type = 'thumbs_up') AS thumbs_up_votes,
    COUNT(*) FILTER (WHERE vote_type = 'partial') AS partial_votes,
    COUNT(*) FILTER (WHERE vote_type = 'thumbs_down') AS thumbs_down_votes,
    COUNT(*) FILTER (WHERE vote_type = 'funny') AS funny_votes,
    COUNT(*) AS total_votes
  FROM truth_votes
  WHERE post_id = post_id_in;
END;
$$;

GRANT EXECUTE ON FUNCTION get_post_vote_stats(UUID) TO anon, authenticated;

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
    (SELECT COUNT(*) FROM posts WHERE COALESCE(is_deleted, FALSE) = FALSE),
    (SELECT COUNT(*) FROM truth_votes),
    (SELECT COUNT(*) FROM comments WHERE COALESCE(is_deleted, FALSE) = FALSE);
END;
$$;

GRANT EXECUTE ON FUNCTION get_global_stats() TO anon, authenticated;

CREATE OR REPLACE FUNCTION update_post_comment_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  target_post_id UUID;
BEGIN
  target_post_id := COALESCE(NEW.post_id, OLD.post_id);

  UPDATE posts
  SET comment_count = (
    SELECT COUNT(*)
    FROM comments
    WHERE post_id = target_post_id
      AND COALESCE(is_deleted, FALSE) = FALSE
  )
  WHERE id = target_post_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_comment_count_insert ON comments;
DROP TRIGGER IF EXISTS trg_comment_count_update ON comments;
DROP TRIGGER IF EXISTS trg_comment_count_delete ON comments;

CREATE TRIGGER trg_comment_count_insert
AFTER INSERT ON comments
FOR EACH ROW EXECUTE FUNCTION update_post_comment_count();

CREATE TRIGGER trg_comment_count_update
AFTER UPDATE OF is_deleted ON comments
FOR EACH ROW EXECUTE FUNCTION update_post_comment_count();

CREATE TRIGGER trg_comment_count_delete
AFTER DELETE ON comments
FOR EACH ROW EXECUTE FUNCTION update_post_comment_count();

CREATE OR REPLACE FUNCTION update_post_vote_counts()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  target_post_id UUID;
BEGIN
  target_post_id := COALESCE(NEW.post_id, OLD.post_id);

  UPDATE posts
  SET
    thumbs_up_count = (
      SELECT COUNT(*) FROM truth_votes
      WHERE post_id = target_post_id AND vote_type = 'thumbs_up'
    ),
    thumbs_down_count = (
      SELECT COUNT(*) FROM truth_votes
      WHERE post_id = target_post_id AND vote_type = 'thumbs_down'
    ),
    partial_count = (
      SELECT COUNT(*) FROM truth_votes
      WHERE post_id = target_post_id AND vote_type = 'partial'
    ),
    funny_count = (
      SELECT COUNT(*) FROM truth_votes
      WHERE post_id = target_post_id AND vote_type = 'funny'
    ),
    vote_count = (
      SELECT COUNT(*) FROM truth_votes
      WHERE post_id = target_post_id
    )
  WHERE id = target_post_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trigger_update_vote_counts ON truth_votes;
DROP TRIGGER IF EXISTS trg_update_vote_counts ON truth_votes;

CREATE TRIGGER trg_update_vote_counts
AFTER INSERT OR UPDATE OR DELETE ON truth_votes
FOR EACH ROW EXECUTE FUNCTION update_post_vote_counts();
