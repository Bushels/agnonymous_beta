-- Sync email_verified status from auth.users to user_profiles
-- This ensures that when a user verifies their email, their profile is updated

-- 1. Create function to sync email verification
CREATE OR REPLACE FUNCTION public.handle_auth_user_update()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if email_confirmed_at has changed or if it's set
  IF (NEW.email_confirmed_at IS NOT NULL AND OLD.email_confirmed_at IS NULL) OR
     (NEW.email_confirmed_at IS DISTINCT FROM OLD.email_confirmed_at) THEN
     
    UPDATE public.user_profiles
    SET 
      email_verified = (NEW.email_confirmed_at IS NOT NULL),
      updated_at = NOW()
    WHERE id = NEW.id;
    
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Create trigger on auth.users
-- Note: We need to be careful with triggers on auth.users as it's a system table
-- But this is a standard pattern in Supabase

DROP TRIGGER IF EXISTS on_auth_user_updated ON auth.users;
CREATE TRIGGER on_auth_user_updated
  AFTER UPDATE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_auth_user_update();

-- 3. Backfill existing users
-- Update any profiles where the auth user is confirmed but profile says otherwise
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT u.id, u.email_confirmed_at
    FROM auth.users u
    JOIN public.user_profiles p ON u.id = p.id
    WHERE u.email_confirmed_at IS NOT NULL AND p.email_verified = FALSE
  LOOP
    UPDATE public.user_profiles
    SET email_verified = TRUE
    WHERE id = r.id;
  END LOOP;
  
  RAISE NOTICE '✅ Backfilled email verification status';
END $$;
