-- ============================================================================
-- FIX SIGNUP RLS AND TRIGGER ISSUES - FINAL
-- Migration: 030_fix_signup_rls_final.sql
-- Purpose: Fix "new row violates row-level security policy" errors during signup
-- ============================================================================

-- 1. Reset RLS policies on user_profiles to a clean state
-- We drop ALL existing policies to ensure no conflicts or "hidden" blocks
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
DROP POLICY IF EXISTS "Service can insert profiles" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON user_profiles;
DROP POLICY IF EXISTS "Anyone can view profiles" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON user_profiles;
DROP POLICY IF EXISTS "Users can create own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
DROP POLICY IF EXISTS "Enable read access for all users" ON user_profiles;
DROP POLICY IF EXISTS "Enable update for users based on id" ON user_profiles;
DROP POLICY IF EXISTS "Service role has full access" ON user_profiles;

-- Enable RLS just in case it was disabled
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- 2. Create comprehensive policies

-- Allow ANYONE to view profiles (needed for public feeds, etc.)
CREATE POLICY "Anyone can view profiles"
ON user_profiles FOR SELECT
USING (true);

-- Allow authenticated users to INSERT their own profile
-- This is the fallback if the trigger fails or for client-side creation
CREATE POLICY "Users can insert own profile"
ON user_profiles FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- Allow authenticated users to UPDATE their own profile
CREATE POLICY "Users can update own profile"
ON user_profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Allow Service Role (and Triggers) full access
-- This is CRITICAL for the trigger to work if it's not SECURITY DEFINER (but we'll make it so anyway)
CREATE POLICY "Service role has full access"
ON user_profiles
TO service_role
USING (true)
WITH CHECK (true);

-- 3. Fix the Trigger Function
-- We make it SECURITY DEFINER to bypass RLS completely when running as a trigger
CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER
SECURITY DEFINER -- Bypasses RLS
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
    vote_count,
    created_at
  )
  VALUES (
    NEW.id,
    new_username,
    NEW.email,
    COALESCE(NEW.email_confirmed_at IS NOT NULL, FALSE),
    NEW.raw_user_meta_data->>'province_state',
    0, 0, 0, 0, 0, 0,
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    email_verified = EXCLUDED.email_verified,
    province_state = COALESCE(user_profiles.province_state, EXCLUDED.province_state);

  RETURN NEW;
EXCEPTION
  WHEN others THEN
    -- Log error but don't fail the auth user creation if possible
    RAISE WARNING 'Profile creation failed for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Re-attach the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION create_user_profile();

-- 5. Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON user_profiles TO authenticated;
GRANT ALL ON user_profiles TO service_role;
GRANT SELECT ON user_profiles TO anon;

-- 6. Verify and Fix Missing Profiles (Backfill)
DO $$
DECLARE
    r RECORD;
    profiles_created INTEGER := 0;
BEGIN
    FOR r IN
        SELECT u.id, u.email, u.raw_user_meta_data
        FROM auth.users u
        LEFT JOIN public.user_profiles p ON u.id = p.id
        WHERE p.id IS NULL
    LOOP
        INSERT INTO public.user_profiles (
            id,
            email,
            username,
            province_state
        )
        VALUES (
            r.id,
            r.email,
            COALESCE(r.raw_user_meta_data->>'username', 'user_' || substring(r.id::text, 1, 8)),
            r.raw_user_meta_data->>'province_state'
        )
        ON CONFLICT (id) DO NOTHING;
        profiles_created := profiles_created + 1;
    END LOOP;
    
    RAISE NOTICE 'Backfilled % missing profiles', profiles_created;
END $$;
