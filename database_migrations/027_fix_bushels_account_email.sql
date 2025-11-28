-- ============================================================================
-- FIX BUSHELS ACCOUNT EMAIL
-- Migration: 027_fix_bushels_account_email.sql
-- Purpose: Swap the email 'gronningk@gmail.com' to the user profile 'bushels'.
-- ============================================================================

DO $$
DECLARE
    v_target_username TEXT := 'bushels';
    v_target_email TEXT := 'gronningk@gmail.com';
    v_bushels_user_id UUID;
    v_current_email_holder_id UUID;
    v_archived_email TEXT;
BEGIN
    -- 1. Find the User ID for the profile with username 'bushels'
    SELECT id INTO v_bushels_user_id
    FROM public.user_profiles
    WHERE username = v_target_username;

    -- 2. Find the User ID currently holding the email 'gronningk@gmail.com'
    SELECT id INTO v_current_email_holder_id
    FROM auth.users
    WHERE email = v_target_email;

    -- RAISE NOTICE 'Bushels ID: %, Current Email Holder ID: %', v_bushels_user_id, v_current_email_holder_id;

    -- 3. Logic to swap if they are different
    IF v_bushels_user_id IS NOT NULL AND v_current_email_holder_id IS NOT NULL AND v_bushels_user_id != v_current_email_holder_id THEN
        
        -- Generate an archived email address for the user currently holding the email
        v_archived_email := 'gronningk+archived_' || extract(epoch from now())::bigint || '@gmail.com';

        -- A. Move the current email holder to the archived email
        UPDATE auth.users
        SET email = v_archived_email,
            updated_at = now()
        WHERE id = v_current_email_holder_id;
        
        -- Also update the profile email for consistency (though it might be nullable/different)
        UPDATE public.user_profiles
        SET email = v_archived_email
        WHERE id = v_current_email_holder_id;

        RAISE NOTICE 'Moved current holder % to %', v_current_email_holder_id, v_archived_email;

        -- B. Assign the target email to the 'bushels' user
        UPDATE auth.users
        SET email = v_target_email,
            email_confirmed_at = now(), -- Ensure it's confirmed
            updated_at = now()
        WHERE id = v_bushels_user_id;

        -- Update the profile email
        UPDATE public.user_profiles
        SET email = v_target_email,
            email_verified = true
        WHERE id = v_bushels_user_id;

        RAISE NOTICE 'Assigned % to user % (bushels)', v_target_email, v_bushels_user_id;

    ELSIF v_bushels_user_id IS NULL THEN
        RAISE NOTICE 'User profile "bushels" not found.';
    ELSIF v_current_email_holder_id IS NULL THEN
        RAISE NOTICE 'No user currently has the email %. You can manually update bushels user.', v_target_email;
        -- Optional: If no one has it, just give it to bushels
        IF v_bushels_user_id IS NOT NULL THEN
             UPDATE auth.users
            SET email = v_target_email,
                email_confirmed_at = now(),
                updated_at = now()
            WHERE id = v_bushels_user_id;
            
            UPDATE public.user_profiles
            SET email = v_target_email,
                email_verified = true
            WHERE id = v_bushels_user_id;
            RAISE NOTICE 'Assigned % to user % (bushels) as it was free', v_target_email, v_bushels_user_id;
        END IF;
    ELSE
        RAISE NOTICE 'The user "bushels" already has the email %', v_target_email;
    END IF;

END $$;
