-- Optional Monette farming-area reference for anonymous board posts.
--
-- This is a post-level public label only. It does not add accounts,
-- geolocation, maps, or identity tracking.

ALTER TABLE posts ADD COLUMN IF NOT EXISTS monette_area TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'posts_monette_area_only_for_monette'
  ) THEN
    ALTER TABLE posts
      ADD CONSTRAINT posts_monette_area_only_for_monette
      CHECK (monette_area IS NULL OR category = 'Monette');
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_posts_monette_area_created_at
  ON posts(monette_area, created_at DESC)
  WHERE category = 'Monette'
    AND monette_area IS NOT NULL
    AND COALESCE(is_deleted, FALSE) = FALSE;

COMMENT ON COLUMN posts.monette_area IS
  'Optional public Monette farming-area label selected by the anonymous poster.';
