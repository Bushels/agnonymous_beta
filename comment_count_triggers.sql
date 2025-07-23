-- SQL to fix comment count issue
-- Run this in your Supabase SQL Editor

-- 1. Function to update comment count
CREATE OR REPLACE FUNCTION update_post_comment_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Increment comment count when comment is added
    UPDATE posts 
    SET comment_count = comment_count + 1,
        updated_at = NOW()
    WHERE id = NEW.post_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    -- Decrement comment count when comment is deleted
    UPDATE posts 
    SET comment_count = comment_count - 1,
        updated_at = NOW()
    WHERE id = OLD.post_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 2. Triggers for comment insert and delete
DROP TRIGGER IF EXISTS trg_comment_count_insert ON comments;
CREATE TRIGGER trg_comment_count_insert
  AFTER INSERT ON comments
  FOR EACH ROW EXECUTE FUNCTION update_post_comment_count();

DROP TRIGGER IF EXISTS trg_comment_count_delete ON comments;
CREATE TRIGGER trg_comment_count_delete
  AFTER DELETE ON comments
  FOR EACH ROW EXECUTE FUNCTION update_post_comment_count();

-- 3. Fix existing posts with correct comment counts
UPDATE posts 
SET comment_count = (
  SELECT COUNT(*) 
  FROM comments 
  WHERE comments.post_id = posts.id
);