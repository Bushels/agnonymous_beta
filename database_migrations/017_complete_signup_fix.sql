-- ============================================================================
-- COMPLETE SIGNUP FIX - RUN THIS SINGLE FILE TO FIX ALL ISSUES
-- Migration: 017_complete_signup_fix.sql
-- ============================================================================
-- This is a comprehensive fix that:
-- 1. Ensures email can be NULL
-- 2. Creates the proper trigger with SECURITY DEFINER
-- 3. Sets up correct RLS policies
-- 4. Backfills any missing profiles
-- ============================================================================

-- ============================================================================
-- STEP 1: FIX TABLE STRUCTURE
-- ============================================================================
ALTER TABLE user_profiles ALTER COLUMN email DROP NOT NULL;

-- ============================================================================
-- STEP 2: CREATE ROBUST TRIGGER FUNCTION (SECURITY DEFINER bypasses RLS)
-- ============================================================================
CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER
SECURITY DEFINER  -- This bypasses RLS!
SET search_path = public
AS $$
DECLARE
  new_username TEXT;
BEGIN
  -- Get username from metadata or generate one
  new_username := COALESCE(
    NEW.raw_user_meta_data->>'username',
    'user_' || SUBSTRING(NEW.id::text, 1, 8)
  );

  -- Insert the profile
  INSERT INTO user_profiles (
    id,
    username,
    email,
    email_verified,
    province_state,
    reputation_points,
    public_reputation,
    anonymous_reputation,
    post_count,
    comment_count,
    vote_count
  )
  VALUES (
    NEW.id,
    new_username,
    NEW.email,
    COALESCE(NEW.email_confirmed_at IS NOT NULL, FALSE),
    NEW.raw_user_meta_data->>'province_state',
    0, 0, 0, 0, 0, 0
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
EXCEPTION
  WHEN others THEN
    RAISE WARNING 'Profile creation: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 3: RECREATE THE TRIGGER
-- ============================================================================
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION create_user_profile();

-- ============================================================================
-- STEP 4: FIX RLS POLICIES
-- ============================================================================

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON user_profiles;
DROP POLICY IF EXISTS "Users can create own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
DROP POLICY IF EXISTS "Enable read access for all users" ON user_profiles;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON user_profiles;
DROP POLICY IF EXISTS "Enable update for users based on id" ON user_profiles;

-- Create clean policies
CREATE POLICY "Anyone can view profiles"
ON user_profiles FOR SELECT
USING (true);

CREATE POLICY "Users can insert their own profile"
ON user_profiles FOR INSERT
TO authenticated
WITH CHECK (id = auth.uid());

CREATE POLICY "Users can update their own profile"
ON user_profiles FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- ============================================================================
-- STEP 5: BACKFILL MISSING PROFILES
-- ============================================================================
INSERT INTO user_profiles (
  id, username, email, email_verified, province_state,
  reputation_points, public_reputation, anonymous_reputation,
  post_count, comment_count, vote_count
)
SELECT
  au.id,
  COALESCE(au.raw_user_meta_data->>'username', 'user_' || SUBSTRING(au.id::text, 1, 8)),
  au.email,
  COALESCE(au.email_confirmed_at IS NOT NULL, FALSE),
  au.raw_user_meta_data->>'province_state',
  0, 0, 0, 0, 0, 0
FROM auth.users au
WHERE NOT EXISTS (SELECT 1 FROM user_profiles up WHERE up.id = au.id)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- STEP 6: GRANT PERMISSIONS
-- ============================================================================
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON user_profiles TO authenticated;
GRANT SELECT ON user_profiles TO anon;
GRANT ALL ON user_profiles TO service_role;
GRANT EXECUTE ON FUNCTION create_user_profile() TO service_role;

-- ============================================================================
-- VERIFICATION: Show current state
-- ============================================================================
DO $$
DECLARE
  profile_count INTEGER;
  user_count INTEGER;
  policy_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO user_count FROM auth.users;
  SELECT COUNT(*) INTO profile_count FROM user_profiles;
  SELECT COUNT(*) INTO policy_count FROM pg_policies WHERE tablename = 'user_profiles';

  RAISE NOTICE '';
  RAISE NOTICE '========== SIGNUP FIX COMPLETE ==========';
  RAISE NOTICE 'Users in auth.users: %', user_count;
  RAISE NOTICE 'Profiles in user_profiles: %', profile_count;
  RAISE NOTICE 'RLS policies on user_profiles: %', policy_count;
  RAISE NOTICE '';

  IF user_count = profile_count THEN
    RAISE NOTICE '✓ All users have profiles';
  ELSE
    RAISE NOTICE '⚠ Missing profiles: %', user_count - profile_count;
  END IF;

  RAISE NOTICE '==========================================';
END $$;
