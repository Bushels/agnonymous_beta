-- =============================================================================
-- SECURITY FIX: Enforce x-anonymous-id header on anonymous watch RPCs
-- Date: 2026-04-24
-- Purpose: Previously, get_anonymous_post_watches / upsert_anonymous_post_watch /
--          delete_anonymous_post_watch trusted whatever `anonymous_user_id_in`
--          the client passed. A malicious caller with the Supabase anon key could
--          read, overwrite, or delete ANY device's watch list by guessing/
--          brute-forcing IDs.
--
-- Fix: Pull the anonymous ID from the x-anonymous-id HTTP header
--      (exposed by PostgREST via current_setting('request.headers', true)).
--      The argument is still accepted for source compatibility, but the RPC
--      uses the header as the source of truth. Requests without the header
--      are rejected.
--
-- Client change: lib/main.dart must load the anonymous ID before
--                Supabase.initialize() and pass it as `headers`.
-- =============================================================================

BEGIN;

-- Helper: extract the anonymous id from the request header, or NULL.
-- Wrapped to swallow the JSON parse error if the GUC is empty/missing.
CREATE OR REPLACE FUNCTION _request_anonymous_id()
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  headers_raw TEXT;
  header_value TEXT;
BEGIN
  headers_raw := current_setting('request.headers', true);
  IF headers_raw IS NULL OR headers_raw = '' THEN
    RETURN NULL;
  END IF;
  BEGIN
    header_value := headers_raw::json->>'x-anonymous-id';
  EXCEPTION WHEN others THEN
    RETURN NULL;
  END;
  RETURN NULLIF(BTRIM(COALESCE(header_value, '')), '');
END;
$$;

GRANT EXECUTE ON FUNCTION _request_anonymous_id() TO anon, authenticated;

-- -----------------------------------------------------------------------------
-- get_anonymous_post_watches: header-enforced
-- -----------------------------------------------------------------------------
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
  header_anonymous_user_id TEXT;
BEGIN
  header_anonymous_user_id := _request_anonymous_id();

  IF header_anonymous_user_id IS NULL THEN
    RAISE EXCEPTION 'x-anonymous-id header required'
      USING ERRCODE = '28000';  -- invalid_authorization_specification
  END IF;

  -- argument is accepted but must match header to prevent confused-deputy bugs
  IF anonymous_user_id_in IS NOT NULL
     AND NULLIF(BTRIM(anonymous_user_id_in), '') IS DISTINCT FROM header_anonymous_user_id
  THEN
    RAISE EXCEPTION 'Access denied: anonymous id mismatch'
      USING ERRCODE = '42501';  -- insufficient_privilege
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
  WHERE w.anonymous_user_id = header_anonymous_user_id
    AND COALESCE(p.is_deleted, FALSE) = FALSE
  ORDER BY w.updated_at DESC;
END;
$$;

-- -----------------------------------------------------------------------------
-- upsert_anonymous_post_watch: header-enforced
-- -----------------------------------------------------------------------------
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
  header_anonymous_user_id TEXT;
BEGIN
  header_anonymous_user_id := _request_anonymous_id();

  IF header_anonymous_user_id IS NULL THEN
    RAISE EXCEPTION 'x-anonymous-id header required'
      USING ERRCODE = '28000';
  END IF;

  IF anonymous_user_id_in IS NOT NULL
     AND NULLIF(BTRIM(anonymous_user_id_in), '') IS DISTINCT FROM header_anonymous_user_id
  THEN
    RAISE EXCEPTION 'Access denied: anonymous id mismatch'
      USING ERRCODE = '42501';
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
    header_anonymous_user_id,
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

-- -----------------------------------------------------------------------------
-- delete_anonymous_post_watch: header-enforced
-- -----------------------------------------------------------------------------
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
  header_anonymous_user_id TEXT;
BEGIN
  header_anonymous_user_id := _request_anonymous_id();

  IF header_anonymous_user_id IS NULL THEN
    RAISE EXCEPTION 'x-anonymous-id header required'
      USING ERRCODE = '28000';
  END IF;

  IF anonymous_user_id_in IS NOT NULL
     AND NULLIF(BTRIM(anonymous_user_id_in), '') IS DISTINCT FROM header_anonymous_user_id
  THEN
    RAISE EXCEPTION 'Access denied: anonymous id mismatch'
      USING ERRCODE = '42501';
  END IF;

  DELETE FROM anonymous_post_watches
  WHERE anonymous_user_id = header_anonymous_user_id
    AND post_id = post_id_in;
END;
$$;

-- Grants are unchanged; re-asserted here for clarity.
GRANT EXECUTE ON FUNCTION get_anonymous_post_watches(TEXT)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION upsert_anonymous_post_watch(TEXT, UUID, INTEGER, BOOLEAN)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION delete_anonymous_post_watch(TEXT, UUID)
  TO anon, authenticated;

COMMIT;
