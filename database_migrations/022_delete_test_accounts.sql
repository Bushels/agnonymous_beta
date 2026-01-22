-- ============================================================================
-- DELETE TEST ACCOUNTS
-- ============================================================================
-- This migration deletes test accounts for fresh testing.
-- Accounts to delete:
--   - bushels (gronningk@gmail.com)
--   - buperac (buperac@gmail.com)
--
-- NOTE: Handles tables that may not exist gracefully
-- ============================================================================

-- First, find the user IDs
DO $$
DECLARE
  bushels_id UUID;
  buperac_id UUID;
BEGIN
  -- Get user IDs from auth.users
  SELECT id INTO bushels_id FROM auth.users WHERE email = 'gronningk@gmail.com';
  SELECT id INTO buperac_id FROM auth.users WHERE email = 'buperac@gmail.com';

  RAISE NOTICE 'Found bushels ID: %', bushels_id;
  RAISE NOTICE 'Found buperac ID: %', buperac_id;

  -- Delete in order respecting foreign keys
  -- Each section wrapped in BEGIN/EXCEPTION to handle missing tables

  -- 1. Delete from user_post_interactions
  BEGIN
    IF bushels_id IS NOT NULL THEN
      DELETE FROM user_post_interactions WHERE user_id = bushels_id;
      RAISE NOTICE 'Deleted bushels user_post_interactions';
    END IF;
    IF buperac_id IS NOT NULL THEN
      DELETE FROM user_post_interactions WHERE user_id = buperac_id;
      RAISE NOTICE 'Deleted buperac user_post_interactions';
    END IF;
  EXCEPTION WHEN undefined_table THEN
    RAISE NOTICE 'user_post_interactions table does not exist, skipping';
  END;

  -- 2. Delete from truth_votes
  BEGIN
    IF bushels_id IS NOT NULL THEN
      DELETE FROM truth_votes WHERE user_id = bushels_id;
      RAISE NOTICE 'Deleted bushels truth_votes';
    END IF;
    IF buperac_id IS NOT NULL THEN
      DELETE FROM truth_votes WHERE user_id = buperac_id;
      RAISE NOTICE 'Deleted buperac truth_votes';
    END IF;
  EXCEPTION WHEN undefined_table THEN
    RAISE NOTICE 'truth_votes table does not exist, skipping';
  END;

  -- 3. Delete from comments
  BEGIN
    IF bushels_id IS NOT NULL THEN
      DELETE FROM comments WHERE user_id = bushels_id;
      RAISE NOTICE 'Deleted bushels comments';
    END IF;
    IF buperac_id IS NOT NULL THEN
      DELETE FROM comments WHERE user_id = buperac_id;
      RAISE NOTICE 'Deleted buperac comments';
    END IF;
  EXCEPTION WHEN undefined_table THEN
    RAISE NOTICE 'comments table does not exist, skipping';
  END;

  -- 4. Delete from notifications (may not exist yet)
  BEGIN
    IF bushels_id IS NOT NULL THEN
      DELETE FROM notifications WHERE user_id = bushels_id;
      RAISE NOTICE 'Deleted bushels notifications';
    END IF;
    IF buperac_id IS NOT NULL THEN
      DELETE FROM notifications WHERE user_id = buperac_id;
      RAISE NOTICE 'Deleted buperac notifications';
    END IF;
  EXCEPTION WHEN undefined_table THEN
    RAISE NOTICE 'notifications table does not exist, skipping';
  END;

  -- 5. Delete from price_entries
  BEGIN
    IF bushels_id IS NOT NULL THEN
      DELETE FROM price_entries WHERE user_id = bushels_id;
      RAISE NOTICE 'Deleted bushels price_entries';
    END IF;
    IF buperac_id IS NOT NULL THEN
      DELETE FROM price_entries WHERE user_id = buperac_id;
      RAISE NOTICE 'Deleted buperac price_entries';
    END IF;
  EXCEPTION WHEN undefined_table THEN
    RAISE NOTICE 'price_entries table does not exist, skipping';
  END;

  -- 6. Delete from price_alerts
  BEGIN
    IF bushels_id IS NOT NULL THEN
      DELETE FROM price_alerts WHERE user_id = bushels_id;
      RAISE NOTICE 'Deleted bushels price_alerts';
    END IF;
    IF buperac_id IS NOT NULL THEN
      DELETE FROM price_alerts WHERE user_id = buperac_id;
      RAISE NOTICE 'Deleted buperac price_alerts';
    END IF;
  EXCEPTION WHEN undefined_table THEN
    RAISE NOTICE 'price_alerts table does not exist, skipping';
  END;

  -- 7. Delete from admin_roles (if any)
  BEGIN
    IF bushels_id IS NOT NULL THEN
      DELETE FROM admin_roles WHERE user_id = bushels_id;
    END IF;
    IF buperac_id IS NOT NULL THEN
      DELETE FROM admin_roles WHERE user_id = buperac_id;
    END IF;
  EXCEPTION WHEN undefined_table THEN
    RAISE NOTICE 'admin_roles table does not exist, skipping';
  END;

  -- 8. Delete from reputation_logs
  BEGIN
    IF bushels_id IS NOT NULL THEN
      DELETE FROM reputation_logs WHERE user_id = bushels_id;
    END IF;
    IF buperac_id IS NOT NULL THEN
      DELETE FROM reputation_logs WHERE user_id = buperac_id;
    END IF;
  EXCEPTION WHEN undefined_table THEN
    RAISE NOTICE 'reputation_logs table does not exist, skipping';
  END;

  -- 9. Delete posts and related data
  BEGIN
    IF bushels_id IS NOT NULL THEN
      -- First delete comments on their posts
      DELETE FROM comments WHERE post_id IN (SELECT id FROM posts WHERE user_id = bushels_id);
      -- Then delete votes on their posts
      DELETE FROM truth_votes WHERE post_id IN (SELECT id FROM posts WHERE user_id = bushels_id);
      -- Then delete the posts
      DELETE FROM posts WHERE user_id = bushels_id;
      RAISE NOTICE 'Deleted bushels posts and related data';
    END IF;
    IF buperac_id IS NOT NULL THEN
      DELETE FROM comments WHERE post_id IN (SELECT id FROM posts WHERE user_id = buperac_id);
      DELETE FROM truth_votes WHERE post_id IN (SELECT id FROM posts WHERE user_id = buperac_id);
      DELETE FROM posts WHERE user_id = buperac_id;
      RAISE NOTICE 'Deleted buperac posts and related data';
    END IF;
  EXCEPTION WHEN undefined_table THEN
    RAISE NOTICE 'posts/comments/truth_votes table does not exist, skipping';
  END;

  -- 10. Delete from user_profiles
  BEGIN
    IF bushels_id IS NOT NULL THEN
      DELETE FROM user_profiles WHERE id = bushels_id;
      RAISE NOTICE 'Deleted bushels user_profile';
    END IF;
    IF buperac_id IS NOT NULL THEN
      DELETE FROM user_profiles WHERE id = buperac_id;
      RAISE NOTICE 'Deleted buperac user_profile';
    END IF;
  EXCEPTION WHEN undefined_table THEN
    RAISE NOTICE 'user_profiles table does not exist, skipping';
  END;

  -- 11. Finally, delete from auth.users
  IF bushels_id IS NOT NULL THEN
    DELETE FROM auth.users WHERE id = bushels_id;
    RAISE NOTICE 'Deleted bushels (gronningk@gmail.com) from auth.users';
  ELSE
    RAISE NOTICE 'bushels (gronningk@gmail.com) not found';
  END IF;

  IF buperac_id IS NOT NULL THEN
    DELETE FROM auth.users WHERE id = buperac_id;
    RAISE NOTICE 'Deleted buperac (buperac@gmail.com) from auth.users';
  ELSE
    RAISE NOTICE 'buperac (buperac@gmail.com) not found';
  END IF;

END $$;

-- Verify deletion
SELECT 'Remaining users:' as info;
SELECT email, created_at FROM auth.users ORDER BY created_at DESC LIMIT 10;
