-- ============================================================================
-- FIX RLS AND PERMISSIONS
-- Migration: 028_fix_rls_and_permissions.sql
-- Purpose: Fix Error 42501 (RLS) when creating profiles and ensure voting works.
-- ============================================================================

-- 1. Allow authenticated users to INSERT their own profile
-- This fixes the "new row violates row-level security policy" error when the app tries to self-heal.
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
CREATE POLICY "Users can insert own profile"
ON user_profiles FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- 2. Ensure UPDATE policy is correct (idempotent)
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
CREATE POLICY "Users can update own profile"
ON user_profiles FOR UPDATE
USING (auth.uid() = id);

-- 3. Backfill missing profiles
-- If the trigger failed previously, this will fix "random user" accounts by creating a profile for them.
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT u.id, u.email, u.email_confirmed_at, u.raw_user_meta_data
        FROM auth.users u
        LEFT JOIN public.user_profiles p ON u.id = p.id
        WHERE p.id IS NULL
    LOOP
        INSERT INTO public.user_profiles (id, email, email_verified, username, province_state)
        VALUES (
            r.id,
            r.email,
            (r.email_confirmed_at IS NOT NULL),
            COALESCE(r.raw_user_meta_data->>'username', 'user_' || substring(r.id::text, 1, 8)),
            r.raw_user_meta_data->>'province_state'
        )
        ON CONFLICT (id) DO NOTHING;
        
        RAISE NOTICE 'Created missing profile for user %', r.id;
    END LOOP;
END $$;

-- 4. Ensure truth_votes RLS allows INSERT (Redundant but safe check)
-- The previous migration 026 should have handled this, but let's be sure.
DROP POLICY IF EXISTS "Users can insert own votes" ON truth_votes;
CREATE POLICY "Users can insert own votes"
ON truth_votes FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());
