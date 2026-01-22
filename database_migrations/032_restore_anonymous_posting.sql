-- ============================================
-- RESTORE ANONYMOUS POSTING MIGRATION (OPTION B - SAFER)
-- Version: 032
-- Description: Allow guests to post/vote with least-privilege security.
-- ============================================

-- 1. POSTS TABLE
-- Ensure user_id allows NULL (Anonymous)
ALTER TABLE posts ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE posts ALTER COLUMN anonymous_user_id DROP NOT NULL;

-- Enable RLS
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- Drop insecure/old policies
DROP POLICY IF EXISTS "Authenticated users can create posts" ON posts;
DROP POLICY IF EXISTS "Anyone can create posts" ON posts;

-- Create "Insert Only" policy for public/anon
CREATE POLICY "Anyone can create posts"
  ON posts FOR INSERT
  WITH CHECK (true);

-- Grant ONLY INSERT to anon (prevent public delete/update)
GRANT INSERT ON TABLE posts TO anon;


-- 2. COMMENTS TABLE
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

-- Drop old policies
DROP POLICY IF EXISTS "Authenticated users can create comments" ON comments;
DROP POLICY IF EXISTS "Anyone can create comments" ON comments;

-- Create "Insert Only" policy
CREATE POLICY "Anyone can create comments"
  ON comments FOR INSERT
  WITH CHECK (true);

-- Grant ONLY INSERT to comments
GRANT INSERT ON TABLE comments TO anon;


-- 3. TRUTH VOTES TABLE (Voting)
ALTER TABLE truth_votes ENABLE ROW LEVEL SECURITY;

-- Drop old policies
DROP POLICY IF EXISTS "Authenticated users can cast votes" ON truth_votes;
DROP POLICY IF EXISTS "Anyone can cast votes" ON truth_votes;
DROP POLICY IF EXISTS "Anyone can update own votes" ON truth_votes;

-- Allow Insert (Voting)
CREATE POLICY "Anyone can cast votes"
  ON truth_votes FOR INSERT
  WITH CHECK (true);

-- Allow Update only if anonymous_user_id matches (Security for guest updates)
-- NOTE: Client must send consistent anonymous_user_id for this to work.
CREATE POLICY "Anyone can update own votes"
  ON truth_votes FOR UPDATE
  USING (
    (auth.uid() IS NULL AND anonymous_user_id IS NOT NULL AND anonymous_user_id = current_setting('request.headers', true)::json->>'x-anonymous-id')
    OR
    (auth.uid() = user_id)
  )
  WITH CHECK (true);

-- Grant Insert and Update (restricted by RLS) to anon
GRANT INSERT, UPDATE ON TABLE truth_votes TO anon;

-- 4. PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_posts_anon_user_id ON posts(anonymous_user_id);
CREATE INDEX IF NOT EXISTS idx_truth_votes_anon_user_id ON truth_votes(anonymous_user_id);

-- 5. GENERAL PERMISSIONS
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon;

RAISE NOTICE '✅ Restoration of anonymous posting complete (Option B - Secure).';
