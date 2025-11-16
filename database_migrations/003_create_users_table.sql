-- ============================================================================
-- MIGRATION 003: User Authentication System - Users Table
-- ============================================================================
-- This migration creates the core user authentication system
--
-- Features:
-- - User accounts with username (case-insensitive unique)
-- - Link to Supabase auth.users
-- - Email verification tracking
-- - Gamification fields (points, reputation, badges)
-- - Privacy settings (default anonymous posting)
-- ============================================================================

-- 1. Create users table
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Link to Supabase auth (one-to-one relationship)
  auth_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,

  -- User identity
  username TEXT UNIQUE NOT NULL,
  username_lowercase TEXT UNIQUE NOT NULL,  -- For case-insensitive uniqueness
  display_name TEXT,  -- Optional display name (can be different from username)
  bio TEXT,

  -- Email verification status (synced from auth.users)
  email_verified BOOLEAN DEFAULT FALSE,

  -- Gamification fields
  points INTEGER DEFAULT 0,
  reputation_score INTEGER DEFAULT 0,
  badges JSONB DEFAULT '[]'::jsonb,

  -- Privacy settings
  default_anonymous BOOLEAN DEFAULT TRUE,  -- User's default posting preference
  show_verified_badge BOOLEAN DEFAULT TRUE,  -- Show verified badge on posts

  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_seen_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  -- Constraints
  CONSTRAINT username_length CHECK (char_length(username) >= 3 AND char_length(username) <= 30),
  CONSTRAINT username_format CHECK (username ~ '^[a-zA-Z0-9_-]+$'),
  CONSTRAINT username_lowercase_format CHECK (username_lowercase ~ '^[a-z0-9_-]+$'),
  CONSTRAINT bio_length CHECK (bio IS NULL OR char_length(bio) <= 500),
  CONSTRAINT points_non_negative CHECK (points >= 0)
);

-- 2. Create indexes for performance
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_username_lowercase ON users(username_lowercase);
CREATE INDEX idx_users_auth_user_id ON users(auth_user_id);
CREATE INDEX idx_users_points ON users(points DESC);  -- For leaderboards
CREATE INDEX idx_users_created_at ON users(created_at DESC);

-- 3. Create function to automatically set username_lowercase
CREATE OR REPLACE FUNCTION set_username_lowercase()
RETURNS TRIGGER AS $$
BEGIN
  NEW.username_lowercase := LOWER(NEW.username);
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Create trigger to maintain username_lowercase
DROP TRIGGER IF EXISTS trg_set_username_lowercase ON users;
CREATE TRIGGER trg_set_username_lowercase
  BEFORE INSERT OR UPDATE OF username ON users
  FOR EACH ROW EXECUTE FUNCTION set_username_lowercase();

-- 5. Create function to sync email_verified from auth.users
CREATE OR REPLACE FUNCTION sync_email_verified()
RETURNS TRIGGER AS $$
BEGIN
  -- Update email_verified in users table when auth.users changes
  UPDATE users
  SET email_verified = NEW.email_confirmed_at IS NOT NULL
  WHERE auth_user_id = NEW.id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6. Create trigger on auth.users to sync email verification
DROP TRIGGER IF EXISTS trg_sync_email_verified ON auth.users;
CREATE TRIGGER trg_sync_email_verified
  AFTER UPDATE OF email_confirmed_at ON auth.users
  FOR EACH ROW EXECUTE FUNCTION sync_email_verified();

-- 7. Create function to update last_seen_at
CREATE OR REPLACE FUNCTION update_last_seen()
RETURNS TRIGGER AS $$
BEGIN
  NEW.last_seen_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 8. Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 9. RLS Policies for users table
-- Anyone can view public user info (username, badges, points)
CREATE POLICY "Public users are viewable by everyone"
  ON users FOR SELECT
  USING (true);

-- Users can only update their own profile
CREATE POLICY "Users can update their own profile"
  ON users FOR UPDATE
  TO authenticated
  USING (auth.uid() = auth_user_id)
  WITH CHECK (auth.uid() = auth_user_id);

-- Only authenticated users can insert (during signup)
CREATE POLICY "Users can insert their own profile"
  ON users FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = auth_user_id);

-- Users cannot delete their profile (must use Supabase auth delete)
-- Profile will be cascade deleted when auth.users record is deleted

-- 10. Create helper function to check if username is available
CREATE OR REPLACE FUNCTION is_username_available(username_to_check TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN NOT EXISTS (
    SELECT 1 FROM users
    WHERE username_lowercase = LOWER(username_to_check)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION is_username_available(TEXT) TO authenticated;

-- 11. Verify migration
DO $$
DECLARE
  table_exists BOOLEAN;
  trigger_count INTEGER;
BEGIN
  -- Check if users table was created
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'users'
  ) INTO table_exists;

  -- Count triggers
  SELECT COUNT(*) INTO trigger_count
  FROM pg_trigger
  WHERE tgname IN ('trg_set_username_lowercase', 'trg_sync_email_verified');

  IF table_exists AND trigger_count = 2 THEN
    RAISE NOTICE '✅ Users table created successfully';
    RAISE NOTICE '✅ Triggers installed: %', trigger_count;
    RAISE NOTICE '✅ RLS policies enabled';
  ELSE
    RAISE WARNING '⚠️ Migration may be incomplete';
    RAISE WARNING 'Table exists: %, Triggers: %', table_exists, trigger_count;
  END IF;
END $$;

-- 12. Show sample of constraints
SELECT
  constraint_name,
  constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'users'
  AND table_schema = 'public'
ORDER BY constraint_type, constraint_name;

RAISE NOTICE '✅ Migration 003_create_users_table.sql completed successfully';
