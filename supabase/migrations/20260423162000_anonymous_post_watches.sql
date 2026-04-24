-- Anonymous watched threads.
-- Keeps no-login watch state separate from posts, comments, and auth notifications.

CREATE TABLE IF NOT EXISTS anonymous_post_watches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  anonymous_user_id TEXT NOT NULL,
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  last_seen_comment_count INTEGER NOT NULL DEFAULT 0,
  notifications_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT anonymous_post_watches_unique UNIQUE (anonymous_user_id, post_id)
);

CREATE INDEX IF NOT EXISTS idx_anonymous_post_watches_anon_updated
  ON anonymous_post_watches(anonymous_user_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_anonymous_post_watches_post_enabled
  ON anonymous_post_watches(post_id)
  WHERE notifications_enabled = TRUE;

ALTER TABLE anonymous_post_watches ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON anonymous_post_watches FROM anon, authenticated;

CREATE OR REPLACE FUNCTION touch_anonymous_post_watch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_anonymous_post_watches_updated_at
  ON anonymous_post_watches;

CREATE TRIGGER trg_anonymous_post_watches_updated_at
BEFORE UPDATE ON anonymous_post_watches
FOR EACH ROW EXECUTE FUNCTION touch_anonymous_post_watch_updated_at();

CREATE OR REPLACE FUNCTION get_anonymous_post_watches(
  anonymous_user_id_in TEXT
)
RETURNS TABLE (
  post_id UUID,
  title TEXT,
  category TEXT,
  last_seen_comment_count INTEGER,
  notifications_enabled BOOLEAN,
  watched_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  normalized_anonymous_user_id TEXT;
BEGIN
  normalized_anonymous_user_id := NULLIF(BTRIM(anonymous_user_id_in), '');

  IF normalized_anonymous_user_id IS NULL THEN
    RAISE EXCEPTION 'Anonymous id required';
  END IF;

  RETURN QUERY
  SELECT
    w.post_id,
    p.title,
    p.category,
    w.last_seen_comment_count,
    w.notifications_enabled,
    w.created_at AS watched_at,
    w.updated_at
  FROM anonymous_post_watches w
  JOIN posts p ON p.id = w.post_id
  WHERE w.anonymous_user_id = normalized_anonymous_user_id
    AND COALESCE(p.is_deleted, FALSE) = FALSE
  ORDER BY w.updated_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION upsert_anonymous_post_watch(
  anonymous_user_id_in TEXT,
  post_id_in UUID,
  last_seen_comment_count_in INTEGER DEFAULT 0,
  notifications_enabled_in BOOLEAN DEFAULT FALSE
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  normalized_anonymous_user_id TEXT;
BEGIN
  normalized_anonymous_user_id := NULLIF(BTRIM(anonymous_user_id_in), '');

  IF normalized_anonymous_user_id IS NULL THEN
    RAISE EXCEPTION 'Anonymous id required';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM posts
    WHERE id = post_id_in
      AND COALESCE(is_deleted, FALSE) = FALSE
  ) THEN
    RAISE EXCEPTION 'Post not found';
  END IF;

  INSERT INTO anonymous_post_watches (
    anonymous_user_id,
    post_id,
    last_seen_comment_count,
    notifications_enabled
  )
  VALUES (
    normalized_anonymous_user_id,
    post_id_in,
    GREATEST(COALESCE(last_seen_comment_count_in, 0), 0),
    COALESCE(notifications_enabled_in, FALSE)
  )
  ON CONFLICT (anonymous_user_id, post_id)
  DO UPDATE SET
    last_seen_comment_count = GREATEST(
      anonymous_post_watches.last_seen_comment_count,
      EXCLUDED.last_seen_comment_count
    ),
    notifications_enabled =
      anonymous_post_watches.notifications_enabled
      OR EXCLUDED.notifications_enabled;
END;
$$;

CREATE OR REPLACE FUNCTION delete_anonymous_post_watch(
  anonymous_user_id_in TEXT,
  post_id_in UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  normalized_anonymous_user_id TEXT;
BEGIN
  normalized_anonymous_user_id := NULLIF(BTRIM(anonymous_user_id_in), '');

  IF normalized_anonymous_user_id IS NULL THEN
    RAISE EXCEPTION 'Anonymous id required';
  END IF;

  DELETE FROM anonymous_post_watches
  WHERE anonymous_user_id = normalized_anonymous_user_id
    AND post_id = post_id_in;
END;
$$;

GRANT EXECUTE ON FUNCTION get_anonymous_post_watches(TEXT)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION upsert_anonymous_post_watch(TEXT, UUID, INTEGER, BOOLEAN)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION delete_anonymous_post_watch(TEXT, UUID)
  TO anon, authenticated;
