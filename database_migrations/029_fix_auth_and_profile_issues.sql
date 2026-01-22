-- ============================================================================
-- FIX AUTH AND PROFILE ISSUES
-- Migration: 029_fix_auth_and_profile_issues.sql
-- Purpose: Fix orphaned auth users, ensure profiles exist, fix RLS
-- ============================================================================

-- 1. Ensure RLS INSERT policy exists for user_profiles
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
CREATE POLICY "Users can insert own profile"
ON user_profiles FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- 2. Also allow the service role / trigger to insert (for signup trigger)
DROP POLICY IF EXISTS "Service can insert profiles" ON user_profiles;
CREATE POLICY "Service can insert profiles"
ON user_profiles FOR INSERT
TO service_role
WITH CHECK (true);

-- 3. Backfill ALL missing profiles from auth.users
DO $$
DECLARE
    r RECORD;
    profiles_created INTEGER := 0;
BEGIN
    RAISE NOTICE 'Starting profile backfill...';

    FOR r IN
        SELECT
            u.id,
            u.email,
            u.email_confirmed_at,
            u.raw_user_meta_data,
            u.created_at
        FROM auth.users u
        LEFT JOIN public.user_profiles p ON u.id = p.id
        WHERE p.id IS NULL
    LOOP
        INSERT INTO public.user_profiles (
            id,
            email,
            email_verified,
            username,
            province_state,
            created_at
        )
        VALUES (
            r.id,
            r.email,
            COALESCE((r.email_confirmed_at IS NOT NULL), false),
            COALESCE(
                r.raw_user_meta_data->>'username',
                'user_' || substring(r.id::text, 1, 8)
            ),
            r.raw_user_meta_data->>'province_state',
            COALESCE(r.created_at, NOW())
        )
        ON CONFLICT (id) DO NOTHING;

        profiles_created := profiles_created + 1;
        RAISE NOTICE 'Created profile for user % (email: %)', r.id, r.email;
    END LOOP;

    RAISE NOTICE 'Backfill complete. Created % profiles.', profiles_created;
END $$;

-- 4. Verify the specific user mentioned in the error
DO $$
DECLARE
    user_exists BOOLEAN;
    profile_exists BOOLEAN;
    user_email TEXT;
BEGIN
    -- Check if the specific user from the error exists
    SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = '2f00bf8f-42eb-43f0-98c4-fd1b8a083aa0') INTO user_exists;
    SELECT EXISTS(SELECT 1 FROM user_profiles WHERE id = '2f00bf8f-42eb-43f0-98c4-fd1b8a083aa0') INTO profile_exists;
    SELECT email INTO user_email FROM auth.users WHERE id = '2f00bf8f-42eb-43f0-98c4-fd1b8a083aa0';

    IF user_exists THEN
        RAISE NOTICE 'User 2f00bf8f... exists in auth.users (email: %)', user_email;
        IF profile_exists THEN
            RAISE NOTICE 'User 2f00bf8f... has a profile in user_profiles';
        ELSE
            RAISE NOTICE 'User 2f00bf8f... is MISSING profile - should have been created above';
        END IF;
    ELSE
        RAISE NOTICE 'User 2f00bf8f... does NOT exist in auth.users';
    END IF;
END $$;

-- 5. Show current state
SELECT 'Auth users without profiles:' as check;
SELECT u.id, u.email, u.email_confirmed_at, u.created_at
FROM auth.users u
LEFT JOIN user_profiles p ON u.id = p.id
WHERE p.id IS NULL;

SELECT 'RLS policies on user_profiles:' as check;
SELECT policyname, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'user_profiles';
