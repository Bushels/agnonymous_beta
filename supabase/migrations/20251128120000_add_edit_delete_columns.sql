-- Migration: Add edit and soft delete columns to posts and comments
-- Date: 2025-11-28

-- =============================================================================
-- POSTS TABLE: Add edit and soft delete columns
-- =============================================================================

-- Add soft delete columns to posts
ALTER TABLE posts
ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES user_profiles(id);

-- Add edit tracking columns to posts
ALTER TABLE posts
ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS edit_count INTEGER DEFAULT 0;

-- Create index for soft delete filtering (most queries will filter by is_deleted = false)
CREATE INDEX IF NOT EXISTS idx_posts_is_deleted ON posts(is_deleted) WHERE is_deleted = FALSE;

-- =============================================================================
-- COMMENTS TABLE: Add edit and soft delete columns
-- =============================================================================

-- Add soft delete columns to comments
ALTER TABLE comments
ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Add edit tracking columns to comments
ALTER TABLE comments
ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ;

-- Create index for soft delete filtering
CREATE INDEX IF NOT EXISTS idx_comments_is_deleted ON comments(is_deleted) WHERE is_deleted = FALSE;

-- =============================================================================
-- POST EDIT HISTORY TABLE: Track post edit history
-- =============================================================================

CREATE TABLE IF NOT EXISTS post_edit_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  edited_by UUID REFERENCES user_profiles(id),
  previous_title TEXT NOT NULL,
  previous_content TEXT NOT NULL,
  edit_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for quick lookup by post_id
CREATE INDEX IF NOT EXISTS idx_post_edit_history_post_id ON post_edit_history(post_id);

-- =============================================================================
-- RLS POLICIES
-- =============================================================================

-- Enable RLS on post_edit_history
ALTER TABLE post_edit_history ENABLE ROW LEVEL SECURITY;

-- Allow users to view edit history for any post
CREATE POLICY "Anyone can view post edit history"
ON post_edit_history
FOR SELECT
USING (true);

-- Only post owner can create edit history (happens automatically on edit)
CREATE POLICY "Only authenticated users can insert edit history"
ON post_edit_history
FOR INSERT
WITH CHECK (auth.uid() IS NOT NULL);

-- =============================================================================
-- FUNCTIONS FOR EDIT/DELETE OPERATIONS
-- =============================================================================

-- Function to soft delete a post (marks as deleted but keeps data)
CREATE OR REPLACE FUNCTION soft_delete_post(post_id_in UUID, user_id_in UUID)
RETURNS BOOLEAN AS $$
DECLARE
  post_owner UUID;
BEGIN
  -- Get the post owner
  SELECT user_id INTO post_owner FROM posts WHERE id = post_id_in;

  -- Check if user owns the post
  IF post_owner IS NULL OR post_owner != user_id_in THEN
    RAISE EXCEPTION 'You can only delete your own posts';
  END IF;

  -- Soft delete the post
  UPDATE posts
  SET is_deleted = TRUE,
      deleted_at = NOW(),
      deleted_by = user_id_in
  WHERE id = post_id_in;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to restore a soft-deleted post (undo delete)
CREATE OR REPLACE FUNCTION restore_post(post_id_in UUID, user_id_in UUID)
RETURNS BOOLEAN AS $$
DECLARE
  post_owner UUID;
BEGIN
  -- Get the post owner
  SELECT user_id INTO post_owner FROM posts WHERE id = post_id_in;

  -- Check if user owns the post
  IF post_owner IS NULL OR post_owner != user_id_in THEN
    RAISE EXCEPTION 'You can only restore your own posts';
  END IF;

  -- Restore the post
  UPDATE posts
  SET is_deleted = FALSE,
      deleted_at = NULL,
      deleted_by = NULL
  WHERE id = post_id_in;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to edit a post and track history
CREATE OR REPLACE FUNCTION edit_post(
  post_id_in UUID,
  user_id_in UUID,
  new_title TEXT,
  new_content TEXT,
  edit_reason_in TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  post_owner UUID;
  old_title TEXT;
  old_content TEXT;
BEGIN
  -- Get the post owner and current content
  SELECT user_id, title, content
  INTO post_owner, old_title, old_content
  FROM posts
  WHERE id = post_id_in AND is_deleted = FALSE;

  -- Check if post exists
  IF post_owner IS NULL THEN
    RAISE EXCEPTION 'Post not found or has been deleted';
  END IF;

  -- Check if user owns the post
  IF post_owner != user_id_in THEN
    RAISE EXCEPTION 'You can only edit your own posts';
  END IF;

  -- Save the old version to history
  INSERT INTO post_edit_history (post_id, edited_by, previous_title, previous_content, edit_reason)
  VALUES (post_id_in, user_id_in, old_title, old_content, edit_reason_in);

  -- Update the post
  UPDATE posts
  SET title = new_title,
      content = new_content,
      edited_at = NOW(),
      edit_count = edit_count + 1,
      updated_at = NOW()
  WHERE id = post_id_in;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to soft delete a comment
CREATE OR REPLACE FUNCTION soft_delete_comment(comment_id_in UUID, user_id_in UUID)
RETURNS BOOLEAN AS $$
DECLARE
  comment_owner UUID;
BEGIN
  -- Get the comment owner (using anonymous_user_id since that's what's stored)
  SELECT anonymous_user_id INTO comment_owner FROM comments WHERE id = comment_id_in;

  -- Check if user owns the comment
  IF comment_owner IS NULL OR comment_owner != user_id_in THEN
    RAISE EXCEPTION 'You can only delete your own comments';
  END IF;

  -- Soft delete the comment
  UPDATE comments
  SET is_deleted = TRUE,
      deleted_at = NOW()
  WHERE id = comment_id_in;

  -- Update comment count on post
  UPDATE posts
  SET comment_count = comment_count - 1
  WHERE id = (SELECT post_id FROM comments WHERE id = comment_id_in);

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to edit a comment
CREATE OR REPLACE FUNCTION edit_comment(
  comment_id_in UUID,
  user_id_in UUID,
  new_content TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
  comment_owner UUID;
BEGIN
  -- Get the comment owner
  SELECT anonymous_user_id INTO comment_owner
  FROM comments
  WHERE id = comment_id_in AND is_deleted = FALSE;

  -- Check if comment exists
  IF comment_owner IS NULL THEN
    RAISE EXCEPTION 'Comment not found or has been deleted';
  END IF;

  -- Check if user owns the comment
  IF comment_owner != user_id_in THEN
    RAISE EXCEPTION 'You can only edit your own comments';
  END IF;

  -- Update the comment
  UPDATE comments
  SET content = new_content,
      edited_at = NOW()
  WHERE id = comment_id_in;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- UPDATE EXISTING QUERIES TO FILTER DELETED POSTS
-- =============================================================================

-- Note: You'll need to update your frontend queries to include:
-- .eq('is_deleted', false)
-- Or create a view that automatically filters deleted posts

-- Create a view for non-deleted posts (optional, for convenience)
CREATE OR REPLACE VIEW active_posts AS
SELECT * FROM posts WHERE is_deleted = FALSE OR is_deleted IS NULL;

-- Create a view for non-deleted comments (optional, for convenience)
CREATE OR REPLACE VIEW active_comments AS
SELECT * FROM comments WHERE is_deleted = FALSE OR is_deleted IS NULL;
