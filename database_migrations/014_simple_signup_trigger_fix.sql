-- ============================================================================
-- SIMPLE SIGNUP TRIGGER FIX
-- Migration: 014_simple_signup_trigger_fix.sql
-- ============================================================================
-- This creates a minimal, robust trigger that works with the existing schema
-- Run this FIRST before anything else to fix signup
-- ============================================================================

-- Step 1: Ensure email can be null (for anonymous users)
ALTER TABLE user_profiles ALTER COLUMN email DROP NOT NULL;

-- Step 2: Create a simple, minimal trigger function
CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER AS $$
DECLARE
  new_username TEXT;
BEGIN
  -- Get username from metadata or generate one
  new_username := COALESCE(
    NEW.raw_user_meta_data->>'username',
    'user_' || SUBSTRING(NEW.id::text, 1, 8)
  );

  -- Insert only the columns that definitely exist in the original schema
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
    0,
    0,
    0,
    0,
    0,
    0
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
EXCEPTION
  WHEN others THEN
    -- Log error but don't fail the signup
    RAISE WARNING 'Profile creation warning: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 3: Recreate the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION create_user_profile();

-- Step 4: Grant execute permission
GRANT EXECUTE ON FUNCTION create_user_profile() TO service_role;
