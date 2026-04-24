-- Replace legacy permissive board policies with the v1 anonymous-board policy set.
-- This makes soft-deleted posts/comments invisible through the anon REST API.

BEGIN;

ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE truth_votes ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
  policy_record RECORD;
BEGIN
  FOR policy_record IN
    SELECT tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('posts', 'comments', 'truth_votes')
  LOOP
    EXECUTE FORMAT(
      'DROP POLICY IF EXISTS %I ON public.%I',
      policy_record.policyname,
      policy_record.tablename
    );
  END LOOP;
END $$;

CREATE POLICY "Anonymous board read active posts"
  ON posts FOR SELECT
  TO anon, authenticated
  USING (COALESCE(is_deleted, FALSE) = FALSE);

CREATE POLICY "Anonymous board create anonymous posts"
  ON posts FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    anonymous_user_id IS NOT NULL
    AND COALESCE(is_anonymous, TRUE) = TRUE
    AND user_id IS NULL
  );

CREATE POLICY "Anonymous board read active comments"
  ON comments FOR SELECT
  TO anon, authenticated
  USING (COALESCE(is_deleted, FALSE) = FALSE);

CREATE POLICY "Anonymous board create anonymous comments"
  ON comments FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    anonymous_user_id IS NOT NULL
    AND COALESCE(is_anonymous, TRUE) = TRUE
    AND user_id IS NULL
  );

CREATE POLICY "Anonymous board read votes"
  ON truth_votes FOR SELECT
  TO anon, authenticated
  USING (TRUE);

COMMIT;
