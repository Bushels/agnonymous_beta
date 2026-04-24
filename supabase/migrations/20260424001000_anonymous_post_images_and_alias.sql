-- Anonymous post display aliases and image attachments.
--
-- This keeps the v1 identity model intact:
-- - posts/comments remain anonymous (`user_id` stays null)
-- - `author_username` is public display text only
-- - images are stored as public post media, not account media

ALTER TABLE posts ADD COLUMN IF NOT EXISTS author_username TEXT;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS author_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS image_urls JSONB NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE comments ADD COLUMN IF NOT EXISTS author_username TEXT;
ALTER TABLE comments ADD COLUMN IF NOT EXISTS author_verified BOOLEAN DEFAULT FALSE;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'posts_image_urls_is_array'
  ) THEN
    ALTER TABLE posts
      ADD CONSTRAINT posts_image_urls_is_array
      CHECK (jsonb_typeof(image_urls) = 'array');
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_posts_has_image_urls
  ON posts ((jsonb_array_length(image_urls)))
  WHERE jsonb_array_length(image_urls) > 0;

COMMENT ON COLUMN posts.author_username IS
  'Public anonymous display label only; not an account identifier.';
COMMENT ON COLUMN comments.author_username IS
  'Public anonymous display label only; not an account identifier.';
COMMENT ON COLUMN posts.image_urls IS
  'Public post image URLs, sanitized/re-encoded by the client before upload.';

INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'post-images',
  'post-images',
  TRUE,
  5242880,
  ARRAY['image/jpeg']::TEXT[]
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Anyone can read post images" ON storage.objects;
CREATE POLICY "Anyone can read post images"
  ON storage.objects
  FOR SELECT
  TO anon, authenticated
  USING (bucket_id = 'post-images');

DROP POLICY IF EXISTS "Anonymous users can upload post images" ON storage.objects;
CREATE POLICY "Anonymous users can upload post images"
  ON storage.objects
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    bucket_id = 'post-images'
    AND (storage.foldername(name))[1] = 'anonymous'
  );
