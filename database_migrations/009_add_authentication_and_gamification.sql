-- ============================================================================
-- AGNONYMOUS APP REVAMP - PHASE 1: AUTHENTICATION & GAMIFICATION SYSTEM
-- Migration: 009_add_authentication_and_gamification.sql
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. CREATE USER_PROFILES TABLE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE NOT NULL,
  email TEXT NOT NULL,
  email_verified BOOLEAN DEFAULT FALSE,
  province_state TEXT,
  bio TEXT,
  
  -- Reputation & Stats
  reputation_points INTEGER DEFAULT 0,
  public_reputation INTEGER DEFAULT 0,
  anonymous_reputation INTEGER DEFAULT 0,
  post_count INTEGER DEFAULT 0,
  comment_count INTEGER DEFAULT 0,
  vote_count INTEGER DEFAULT 0,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT username_length CHECK (LENGTH(username) >= 3 AND LENGTH(username) <= 30),
  CONSTRAINT username_format CHECK (username ~ '^[a-zA-Z0-9_-]+$'),
  CONSTRAINT bio_length CHECK (LENGTH(bio) <= 500),
  CONSTRAINT reputation_floor CHECK (reputation_points >= 0)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_username ON user_profiles(username);
CREATE INDEX IF NOT EXISTS idx_user_profiles_email_verified ON user_profiles(email_verified);
CREATE INDEX IF NOT EXISTS idx_user_profiles_reputation ON user_profiles(reputation_points DESC);

-- ----------------------------------------------------------------------------
-- 2. MODIFY POSTS TABLE - ADD USER FIELDS
-- ----------------------------------------------------------------------------
ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS author_username TEXT,
  ADD COLUMN IF NOT EXISTS author_verified BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS truth_meter_score DOUBLE PRECISION DEFAULT 0.0,
  ADD COLUMN IF NOT EXISTS truth_meter_status TEXT DEFAULT 'unrated',
  ADD COLUMN IF NOT EXISTS admin_verified BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS verified_by UUID REFERENCES user_profiles(id),
  ADD COLUMN IF NOT EXISTS thumbs_up_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS thumbs_down_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS partial_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS funny_count INTEGER DEFAULT 0;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_anonymous ON posts(is_anonymous);
CREATE INDEX IF NOT EXISTS idx_posts_admin_verified ON posts(admin_verified);

-- ----------------------------------------------------------------------------
-- 3. MODIFY COMMENTS TABLE - ADD USER FIELDS
-- ----------------------------------------------------------------------------
ALTER TABLE comments
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS author_username TEXT,
  ADD COLUMN IF NOT EXISTS author_verified BOOLEAN DEFAULT FALSE;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_comments_user_id ON comments(user_id);
CREATE INDEX IF NOT EXISTS idx_comments_anonymous ON comments(is_anonymous);

-- ----------------------------------------------------------------------------
-- 4. MODIFY TRUTH_VOTES TABLE - ADD USER FIELDS
-- ----------------------------------------------------------------------------
ALTER TABLE truth_votes
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS vote_weight DOUBLE PRECISION DEFAULT 1.0;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_truth_votes_user_id ON truth_votes(user_id);

-- Prevent duplicate votes per user per post (for authenticated users)
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_user_vote
  ON truth_votes(user_id, post_id)
  WHERE user_id IS NOT NULL;

-- ----------------------------------------------------------------------------
-- 5. CREATE USER_POST_INTERACTIONS TABLE
-- Track which posts user has interacted with to prevent point farming
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_post_interactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  has_commented BOOLEAN DEFAULT FALSE,
  has_voted BOOLEAN DEFAULT FALSE,
  comment_points_awarded BOOLEAN DEFAULT FALSE,
  vote_points_awarded BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(user_id, post_id)
);

CREATE INDEX IF NOT EXISTS idx_user_post_interactions_user ON user_post_interactions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_post_interactions_post ON user_post_interactions(post_id);

-- ----------------------------------------------------------------------------
-- 6. CREATE ADMIN_ROLES TABLE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS admin_roles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('moderator', 'admin', 'super_admin')),
  granted_by UUID REFERENCES user_profiles(id),
  granted_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(user_id, role)
);

CREATE INDEX IF NOT EXISTS idx_admin_roles_user ON admin_roles(user_id);

-- ----------------------------------------------------------------------------
-- 7. CREATE POST_VERIFICATIONS TABLE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS post_verifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  verified_by UUID REFERENCES user_profiles(id),
  verification_type TEXT CHECK (verification_type IN ('verified_true', 'verified_false', 'needs_investigation')),
  verification_notes TEXT,
  evidence_links TEXT[],
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(post_id)
);

CREATE INDEX IF NOT EXISTS idx_post_verifications_post ON post_verifications(post_id);
CREATE INDEX IF NOT EXISTS idx_post_verifications_verifier ON post_verifications(verified_by);

-- ----------------------------------------------------------------------------
-- 8. CREATE SUSPICIOUS_ACTIVITY TABLE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS suspicious_activity (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES user_profiles(id),
  activity_type TEXT NOT NULL,
  details JSONB,
  ip_address TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_suspicious_activity_user ON suspicious_activity(user_id);
CREATE INDEX IF NOT EXISTS idx_suspicious_activity_type ON suspicious_activity(activity_type);
CREATE INDEX IF NOT EXISTS idx_suspicious_activity_created ON suspicious_activity(created_at DESC);

-- ----------------------------------------------------------------------------
-- 9. CREATE REPUTATION_LOGS TABLE
-- Track reputation changes for transparency
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reputation_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  points_change INTEGER NOT NULL,
  reason TEXT NOT NULL,
  related_post_id UUID REFERENCES posts(id) ON DELETE SET NULL,
  related_comment_id UUID REFERENCES comments(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reputation_logs_user ON reputation_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_reputation_logs_created ON reputation_logs(created_at DESC);

-- ----------------------------------------------------------------------------
-- 10. CREATE TRIGGERS & FUNCTIONS
-- ----------------------------------------------------------------------------

-- Function: Auto-create user profile when user signs up
CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_profiles (id, email, email_verified, username)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.email_confirmed_at IS NOT NULL,
    COALESCE(NEW.raw_user_meta_data->>'username', 'user_' || SUBSTRING(NEW.id::text, 1, 8))
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: Create profile on user signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION create_user_profile();

-- Function: Update email verification status
CREATE OR REPLACE FUNCTION update_email_verification()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.email_confirmed_at IS NOT NULL AND OLD.email_confirmed_at IS NULL THEN
    UPDATE user_profiles
    SET email_verified = TRUE,
        updated_at = NOW()
    WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: Update verification status
DROP TRIGGER IF EXISTS on_email_verified ON auth.users;
CREATE TRIGGER on_email_verified
  AFTER UPDATE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION update_email_verification();

-- Function: Prevent self-voting
CREATE OR REPLACE FUNCTION prevent_self_voting()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM posts
    WHERE id = NEW.post_id
    AND user_id = NEW.user_id
    AND NEW.user_id IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'You cannot vote on your own posts';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger: Prevent self-voting
DROP TRIGGER IF EXISTS trg_prevent_self_voting ON truth_votes;
CREATE TRIGGER trg_prevent_self_voting
  BEFORE INSERT ON truth_votes
  FOR EACH ROW EXECUTE FUNCTION prevent_self_voting();

-- Function: Detect vote brigading
CREATE OR REPLACE FUNCTION detect_vote_brigading()
RETURNS TRIGGER AS $$
DECLARE
  recent_votes INTEGER;
BEGIN
  IF NEW.user_id IS NOT NULL THEN
    SELECT COUNT(*) INTO recent_votes
    FROM truth_votes
    WHERE user_id = NEW.user_id
    AND created_at > NOW() - INTERVAL '5 minutes';
    
    IF recent_votes > 10 THEN
      INSERT INTO suspicious_activity (user_id, activity_type, details)
      VALUES (
        NEW.user_id,
        'rapid_voting',
        jsonb_build_object('votes_in_5min', recent_votes, 'post_id', NEW.post_id)
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger: Detect vote brigading
DROP TRIGGER IF EXISTS trg_detect_brigading ON truth_votes;
CREATE TRIGGER trg_detect_brigading
  AFTER INSERT ON truth_votes
  FOR EACH ROW EXECUTE FUNCTION detect_vote_brigading();

-- Function: Calculate reputation level from points
CREATE OR REPLACE FUNCTION get_reputation_level(points INTEGER)
RETURNS INTEGER AS $$
BEGIN
  IF points < 50 THEN RETURN 0;
  ELSIF points < 150 THEN RETURN 1;
  ELSIF points < 300 THEN RETURN 2;
  ELSIF points < 500 THEN RETURN 3;
  ELSIF points < 750 THEN RETURN 4;
  ELSIF points < 1000 THEN RETURN 5;
  ELSIF points < 1500 THEN RETURN 6;
  ELSIF points < 2500 THEN RETURN 7;
  ELSIF points < 5000 THEN RETURN 8;
  ELSE RETURN 9;
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function: Calculate vote weight from reputation
CREATE OR REPLACE FUNCTION get_vote_weight(reputation INTEGER)
RETURNS DOUBLE PRECISION AS $$
BEGIN
  IF reputation < 150 THEN RETURN 1.0;
  ELSIF reputation < 300 THEN RETURN 1.1;
  ELSIF reputation < 500 THEN RETURN 1.2;
  ELSIF reputation < 750 THEN RETURN 1.3;
  ELSIF reputation < 1000 THEN RETURN 1.5;
  ELSIF reputation < 1500 THEN RETURN 1.7;
  ELSIF reputation < 2500 THEN RETURN 2.0;
  ELSIF reputation < 5000 THEN RETURN 2.5;
  ELSE RETURN 3.0;
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ----------------------------------------------------------------------------
-- 11. UPDATE RLS POLICIES
-- ----------------------------------------------------------------------------

-- User Profiles RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON user_profiles;
CREATE POLICY "Profiles are viewable by everyone"
ON user_profiles FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
CREATE POLICY "Users can update own profile"
ON user_profiles FOR UPDATE
USING (id = auth.uid());

-- User Post Interactions RLS
ALTER TABLE user_post_interactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own interactions" ON user_post_interactions;
CREATE POLICY "Users can view own interactions"
ON user_post_interactions FOR SELECT
USING (user_id = auth.uid());

-- Admin Roles RLS
ALTER TABLE admin_roles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin roles viewable by authenticated users" ON admin_roles;
CREATE POLICY "Admin roles viewable by authenticated users"
ON admin_roles FOR SELECT
TO authenticated
USING (true);

-- Post Verifications RLS
ALTER TABLE post_verifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Post verifications viewable by everyone" ON post_verifications;
CREATE POLICY "Post verifications viewable by everyone"
ON post_verifications FOR SELECT
USING (true);

-- Suspicious Activity RLS (admin only)
ALTER TABLE suspicious_activity ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Only admins can view suspicious activity" ON suspicious_activity;
CREATE POLICY "Only admins can view suspicious activity"
ON suspicious_activity FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM admin_roles
    WHERE user_id = auth.uid()
    AND role IN ('admin', 'super_admin')
  )
);

-- Reputation Logs RLS
ALTER TABLE reputation_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own reputation logs" ON reputation_logs;
CREATE POLICY "Users can view own reputation logs"
ON reputation_logs FOR SELECT
USING (user_id = auth.uid());

-- Update Posts RLS to allow authenticated users to create posts
DROP POLICY IF EXISTS "Authenticated users can create posts" ON posts;
CREATE POLICY "Authenticated users can create posts"
ON posts FOR INSERT
TO authenticated
WITH CHECK (auth.uid() IS NOT NULL);

-- Update Comments RLS
DROP POLICY IF EXISTS "Authenticated users can create comments" ON comments;
CREATE POLICY "Authenticated users can create comments"
ON comments FOR INSERT
TO authenticated
WITH CHECK (auth.uid() IS NOT NULL);

-- Update Truth Votes RLS
DROP POLICY IF EXISTS "Authenticated users can vote" ON truth_votes;
CREATE POLICY "Authenticated users can vote"
ON truth_votes FOR INSERT
TO authenticated
WITH CHECK (auth.uid() IS NOT NULL);

-- ----------------------------------------------------------------------------
-- 12. GRANT PERMISSIONS
-- ----------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON user_profiles TO authenticated;
GRANT SELECT ON user_profiles TO anon;
GRANT ALL ON user_post_interactions TO authenticated;
GRANT ALL ON admin_roles TO authenticated;
GRANT SELECT ON post_verifications TO anon, authenticated;
GRANT SELECT ON suspicious_activity TO authenticated;
GRANT SELECT ON reputation_logs TO authenticated;

GRANT EXECUTE ON FUNCTION create_user_profile() TO authenticated;
GRANT EXECUTE ON FUNCTION update_email_verification() TO authenticated;
GRANT EXECUTE ON FUNCTION get_reputation_level(INTEGER) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_vote_weight(INTEGER) TO anon, authenticated;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
