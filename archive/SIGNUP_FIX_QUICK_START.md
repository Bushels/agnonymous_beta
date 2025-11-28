# SIGNUP FIX - QUICK START

## What Was Wrong?

Signup was failing because:
1. Database missing required columns (`reputation_level`, `vote_weight`)
2. Province/State data not being saved
3. Database trigger incomplete

## How to Fix (5 minutes)

### Step 1: Run Migrations in Supabase

Open Supabase SQL Editor and run these files **in order**:

1. **First**: `database_migrations/012_ensure_user_profile_columns.sql`
   - Adds missing columns to user_profiles table

2. **Second**: `database_migrations/011_fix_signup_trigger.sql`
   - Fixes the signup trigger to insert all fields

3. **Third**: `database_migrations/013_verify_signup_fix.sql`
   - Verifies everything is working

### Step 2: Test Signup

1. Launch app
2. Go to Signup screen
3. Create test account:
   - Username: testuser1
   - Email: test1@example.com
   - Password: TestPass123
   - Province: Ontario
4. Click "Create Account"
5. Should succeed and redirect

## Quick Verification

Run this in Supabase SQL Editor:
```sql
SELECT
  username,
  province_state,
  reputation_level,
  vote_weight,
  post_count
FROM user_profiles
ORDER BY created_at DESC
LIMIT 5;
```

**Expected**: All columns should have values (no NULLs)

## If It Still Fails

1. Check Supabase Dashboard → Logs → Auth Logs
2. Run `013_verify_signup_fix.sql` to diagnose
3. See full guide: `SIGNUP_FIX_IMPLEMENTATION_GUIDE.md`

## Files Changed

- ✅ `lib/providers/auth_provider.dart` (already updated)
- ✅ `database_migrations/011_fix_signup_trigger.sql` (NEW - run this)
- ✅ `database_migrations/012_ensure_user_profile_columns.sql` (NEW - run this)
- ✅ `database_migrations/013_verify_signup_fix.sql` (NEW - run this to verify)

That's it! Signup should now work perfectly.
