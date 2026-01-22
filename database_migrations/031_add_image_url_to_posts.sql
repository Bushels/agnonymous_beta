-- ============================================
-- ADD IMAGE URL TO POSTS
-- Version: 031
-- Description: Add image_url column to posts table for verification photos
-- ============================================

-- Add image_url column to posts table
ALTER TABLE posts ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Add index for posts with images (for filtering)
CREATE INDEX IF NOT EXISTS idx_posts_has_image ON posts ((image_url IS NOT NULL));

COMMENT ON COLUMN posts.image_url IS 'URL to verification image, required for Input Prices posts';
