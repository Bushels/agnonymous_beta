-- ============================================================================
-- FIX ANONYMOUS AUTHENTICATION
-- Migration: 010_fix_anonymous_auth.sql
-- ============================================================================

-- 1. Make email nullable in user_profiles
-- Anonymous users do not have an email address, so this column must be nullable
ALTER TABLE user_profiles ALTER COLUMN email DROP NOT NULL;

-- 2. Update create_user_profile function to handle anonymous users better
CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER AS $$
DECLARE
  new_username TEXT;
  is_anonymous BOOLEAN;
BEGIN
  -- Check if this is an anonymous user (no email or is_anonymous meta)
  is_anonymous := (NEW.email IS NULL) OR (NEW.raw_user_meta_data->>'is_anonymous' = 'true');
  
  -- Generate a username
  -- If provided in metadata, use it.
  -- If anonymous, generate 'anon_xyz'.
  -- Otherwise generate 'user_xyz'.
  IF NEW.raw_user_meta_data->>'username' IS NOT NULL THEN
    new_username := NEW.raw_user_meta_data->>'username';
  ELSIF is_anonymous THEN
    new_username := 'anon_' || SUBSTRING(NEW.id::text, 1, 8);
  ELSE
    new_username := 'user_' || SUBSTRING(NEW.id::text, 1, 8);
  END IF;

  INSERT INTO user_profiles (id, email, email_verified, username, anonymous_reputation)
  VALUES (
    NEW.id,
    NEW.email, -- Can now be NULL
    COALESCE(NEW.email_confirmed_at IS NOT NULL, FALSE),
    new_username,
    CASE WHEN is_anonymous THEN 50 ELSE 0 END -- Give anonymous users a small starting rep? Or 0.
  )
  ON CONFLICT (id) DO NOTHING;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Add index for nullable email queries if needed
CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON user_profiles(email) WHERE email IS NOT NULL;
