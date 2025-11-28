-- ============================================================================
-- FIX USER PROFILE CREATION TRIGGER FOR SIGNUP
-- Migration: 011_fix_signup_trigger.sql
-- ============================================================================
-- This migration fixes the create_user_profile() trigger to properly extract
-- and insert all required fields during signup, including province_state.
-- ============================================================================

CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER AS $$
DECLARE
  new_username TEXT;
  is_anonymous BOOLEAN;
BEGIN
  -- Check if this is an anonymous user
  is_anonymous := (NEW.email IS NULL) OR (NEW.raw_user_meta_data->>'is_anonymous' = 'true');

  -- Generate username
  IF NEW.raw_user_meta_data->>'username' IS NOT NULL THEN
    new_username := NEW.raw_user_meta_data->>'username';
  ELSIF is_anonymous THEN
    new_username := 'anon_' || SUBSTRING(NEW.id::text, 1, 8);
  ELSE
    new_username := 'user_' || SUBSTRING(NEW.id::text, 1, 8);
  END IF;

  INSERT INTO user_profiles (
    id,
    email,
    email_verified,
    username,
    province_state,
    reputation_points,
    public_reputation,
    anonymous_reputation,
    reputation_level,
    vote_weight,
    post_count,
    comment_count,
    vote_count
  )
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.email_confirmed_at IS NOT NULL, FALSE),
    new_username,
    NEW.raw_user_meta_data->>'province_state',  -- Extract province_state from metadata
    0,  -- reputation_points
    0,  -- public_reputation
    CASE WHEN is_anonymous THEN 50 ELSE 0 END,  -- anonymous_reputation
    0,  -- reputation_level (will be calculated by update trigger)
    1.0,  -- vote_weight (will be calculated by update trigger)
    0,  -- post_count
    0,  -- comment_count
    0   -- vote_count
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-create the trigger to ensure it uses the updated function
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION create_user_profile();
