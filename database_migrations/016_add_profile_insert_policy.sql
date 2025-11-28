-- ============================================================================
-- ADD POLICY FOR USERS TO CREATE THEIR OWN PROFILE
-- Migration: 016_add_profile_insert_policy.sql
-- ============================================================================
-- This allows authenticated users to create their own profile if missing
-- This enables the self-healing profile creation in the Flutter app
-- ============================================================================

-- Allow authenticated users to insert their own profile
DROP POLICY IF EXISTS "Users can create own profile" ON user_profiles;
CREATE POLICY "Users can create own profile"
ON user_profiles FOR INSERT
TO authenticated
WITH CHECK (id = auth.uid());

-- Also ensure they can read all profiles (already should exist)
DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON user_profiles;
CREATE POLICY "Profiles are viewable by everyone"
ON user_profiles FOR SELECT
USING (true);

-- And update their own
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
CREATE POLICY "Users can update own profile"
ON user_profiles FOR UPDATE
TO authenticated
USING (id = auth.uid());
