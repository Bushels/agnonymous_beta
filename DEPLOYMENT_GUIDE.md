# 🚀 Deployment Guide - Agnonymous Beta

## Complete deployment checklist for all security fixes and improvements

---

## 📋 PRE-DEPLOYMENT CHECKLIST

Before deploying, make sure you have:
- [x] Merged all changes from `claude/audit-app-improvements-015J7EtcwCxWztVhx66cPTdA` branch
- [ ] Flutter SDK installed (`flutter --version`)
- [ ] Firebase CLI installed (`firebase --version`)
- [ ] Logged into Firebase CLI (`firebase login`)
- [ ] Access to Supabase dashboard

---

## 🗄️ STEP 1: DATABASE MIGRATIONS (CRITICAL!)

### Migration 1: Verify Vote Types (Optional but Recommended)

**File:** `database_migrations/001_fix_vote_types.sql`

1. Go to Supabase Dashboard: https://supabase.com/dashboard
2. Select your project: `ibgsloyjxdopkvwqcqwh`
3. Click **SQL Editor** in the left sidebar
4. Click **New Query**
5. Copy/paste the entire contents of `database_migrations/001_fix_vote_types.sql`
6. Click **Run** (or press Ctrl+Enter)

**Expected Output:**
```
NOTICE: ✅ Vote type constraint exists
NOTICE: ✅ Database verification completed successfully
NOTICE: Vote types are correct - no migration needed!
```

Plus a table showing vote distribution.

---

### Migration 2: Install Comment Count Triggers (REQUIRED!)

**File:** `database_migrations/002_install_comment_count_triggers.sql`

1. In Supabase SQL Editor, click **New Query**
2. Copy/paste the entire contents of `database_migrations/002_install_comment_count_triggers.sql`
3. Click **Run** (or press Ctrl+Enter)

**Expected Output:**
```
NOTICE: ✅ Comment count triggers installed successfully
NOTICE: ✅ Migration 002_install_comment_count_triggers.sql completed successfully
```

Plus a table showing posts with their comment counts.

**Verify Triggers Installed:**
```sql
SELECT tgname, tgenabled
FROM pg_trigger
WHERE tgname IN ('trg_comment_count_insert', 'trg_comment_count_delete');
```

Should return 2 rows showing both triggers are enabled.

---

## 🛠️ STEP 2: BUILD & DEPLOY THE APP

### Option A: Using the Deployment Script (Easiest)

```bash
cd /path/to/agnonymous_beta
./deploy.sh
```

The script will:
1. Install Flutter dependencies
2. Clean previous builds
3. Build the web app in release mode
4. Deploy to Firebase Hosting
5. Show you the live URL

---

### Option B: Manual Deployment (Step-by-Step)

If you prefer to run commands manually:

#### 1. Install Dependencies
```bash
flutter pub get
```

#### 2. Clean Previous Build
```bash
flutter clean
```

#### 3. Build for Web (Production)
```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://ibgsloyjxdopkvwqcqwh.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImliZ3Nsb3lqeGRvcGt2d3FjcXdoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI2ODYzMzksImV4cCI6MjA2ODI2MjMzOX0.Ik1980vz4s_UxVuEfBm61-kcIzEH-Nt-hQtydZUeNTw
```

**Note:** The build may take 2-5 minutes.

#### 4. Deploy to Firebase
```bash
firebase deploy --only hosting
```

**Expected Output:**
```
✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/agnonymousbeta/overview
Hosting URL: https://agnonymousbeta.web.app
```

---

## ✅ STEP 3: VERIFY DEPLOYMENT

### 3.1 Check Security Headers

```bash
curl -I https://agnonymousbeta.web.app
```

**You should see:**
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: SAMEORIGIN`
- `X-XSS-Protection: 1; mode=block`
- `Content-Security-Policy: default-src 'self'...`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy: geolocation=()...`

### 3.2 Test XSS Protection

1. Go to https://agnonymousbeta.web.app
2. Click **Create Post**
3. Try entering: `<script>alert('XSS Test')</script>` in the title
4. Submit the post
5. **Expected:** Tags should be stripped, only plain text "alert('XSS Test')" shown

### 3.3 Test Comment Count Feature

1. Find a post with 0 comments
2. Button should say: **"Leave a comment"**
3. Add a comment
4. Button should change to: **"View 1 comment"** (in real-time!)
5. Add another comment
6. Button should change to: **"View 2 comments"**
7. Click the button to expand
8. Button should change to: **"Hide 2 comments"**

### 3.4 Test Real-Time Updates

1. Open the same post in two different browsers
2. Add a comment in browser 1
3. **Expected:** Browser 2 should show the updated count immediately (within 1-2 seconds)

### 3.5 Test Voting System

1. Click on any post
2. Cast a vote (Thumbs Up, Partial, Thumbs Down, or Funny)
3. **Expected:** Vote should register immediately
4. Truth Meter should update in real-time
5. Vote counts should show on the colored bar

---

## 🐛 TROUBLESHOOTING

### Issue: Build fails with "flutter: command not found"

**Solution:**
```bash
# Install Flutter SDK
# Visit: https://docs.flutter.dev/get-started/install

# Or if using snap (Linux):
sudo snap install flutter --classic

# Verify installation:
flutter doctor
```

### Issue: Firebase deploy fails with authentication error

**Solution:**
```bash
# Log in to Firebase
firebase login

# Verify you're logged in
firebase projects:list

# Should show 'agnonymousbeta' in the list
```

### Issue: Comment counts not updating

**Possible Causes:**

1. **Database triggers not installed**
   - Run migration 002 again
   - Verify triggers exist (SQL query in Step 1)

2. **Browser cache**
   - Hard refresh: Ctrl+Shift+R (Windows/Linux) or Cmd+Shift+R (Mac)
   - Clear browser cache
   - Try incognito/private mode

3. **Real-time not enabled for posts table**
   ```sql
   -- Run in Supabase SQL Editor:
   ALTER PUBLICATION supabase_realtime ADD TABLE posts;
   ```

4. **Check browser console for errors**
   - Press F12 to open DevTools
   - Click **Console** tab
   - Look for red error messages

### Issue: Security headers not showing

**Solution:**
- Headers are cached by CDN (Firebase Hosting)
- Wait 5-10 minutes for cache to clear
- Use `curl -I` instead of browser (browsers cache headers)
- Try from different network/device

### Issue: XSS protection not working

**Verify:**
```bash
# Check that sanitizeInput() is being called
# Search in lib/main.dart and lib/create_post_screen.dart
grep -n "sanitizeInput" lib/*.dart
```

Should show it's being called in:
- `create_post_screen.dart` (post creation)
- `main.dart` (comment posting)

---

## 📊 DEPLOYMENT SUMMARY

### What Was Deployed:

✅ **Security Fixes:**
- XSS input sanitization
- Comprehensive security headers (CSP, X-Frame-Options, etc.)
- Proper logging system (debug logs disabled in production)
- Platform-safe imports (mobile builds now work)

✅ **Bug Fixes:**
- Comment count display shows actual numbers
- Real-time comment count updates
- Documentation corrections (vote types)

✅ **UI Improvements:**
- Comment button shows count: "View 5 comments"
- Proper singular/plural grammar
- Better user feedback

### Database Changes Required:

⚠️ **CRITICAL:** Run both migrations in Supabase:
1. `001_fix_vote_types.sql` (optional verification)
2. `002_install_comment_count_triggers.sql` (REQUIRED)

### Files Changed:

**Code:**
- `lib/main.dart` - Security, logging, comment count display
- `lib/create_post_screen.dart` - Input sanitization
- `lib/web_helper.dart` (new) - Web platform helpers
- `lib/stub_web.dart` (new) - Mobile platform stubs
- `web/index.html` - Removed debug logging
- `pubspec.yaml` - Added logger and html_unescape packages

**Configuration:**
- `firebase.json` - Security headers added
- `README.md` - Fixed documentation

**Documentation:**
- `SECURITY_FIXES.md` (new) - Complete security audit
- `COMMENT_COUNT_FIX.md` (new) - Comment count troubleshooting
- `DEPLOYMENT_GUIDE.md` (new) - This file
- `deploy.sh` (new) - Automated deployment script

**Database:**
- `database_migrations/001_fix_vote_types.sql` (new)
- `database_migrations/002_install_comment_count_triggers.sql` (new)

---

## 📈 POST-DEPLOYMENT MONITORING

### Check Firebase Console

1. Go to: https://console.firebase.google.com/project/agnonymousbeta
2. Click **Hosting** in left sidebar
3. Verify latest deployment shows your recent build time
4. Check **Usage** tab for traffic

### Monitor Error Logs

```bash
# View Firebase logs
firebase functions:log
```

### Analytics

- Monitor user engagement in Firebase Analytics
- Check for JavaScript errors in browser console
- Watch for any Supabase connection issues

---

## 🎯 SUCCESS CRITERIA

✅ **All Checklist Items:**
- [ ] Database migrations run successfully
- [ ] App built without errors
- [ ] Deployed to Firebase successfully
- [ ] Security headers verified (curl -I)
- [ ] XSS protection tested and working
- [ ] Comment counts display correctly
- [ ] Comment counts update in real-time
- [ ] Voting system works
- [ ] No console errors in browser
- [ ] Mobile build compiles (optional: `flutter build apk --debug`)

---

## 🆘 GETTING HELP

If you encounter issues:

1. **Check Documentation:**
   - `SECURITY_FIXES.md` - Security implementation details
   - `COMMENT_COUNT_FIX.md` - Comment count troubleshooting
   - This file - Deployment steps

2. **Check Logs:**
   - Browser console (F12)
   - Firebase Hosting logs
   - Supabase dashboard logs

3. **Verify Database:**
   - Run verification queries from migration files
   - Check that triggers are installed
   - Verify real-time is enabled

4. **Common Commands:**
   ```bash
   # Re-run deployment
   ./deploy.sh

   # Check Flutter version
   flutter --version

   # Check Firebase project
   firebase projects:list

   # View hosting info
   firebase hosting:channel:list
   ```

---

## 📝 NOTES

- **Build time:** Expect 2-5 minutes for web build
- **Deploy time:** Usually 1-2 minutes to Firebase
- **CDN propagation:** Security headers may take 5-10 minutes to propagate
- **Database migrations:** Only need to run once ever
- **Environment variables:** Embedded in build and web/index.html

---

**Deployment Date:** 2025-01-15
**Version:** Security & Comment Count Fixes
**Branch:** claude/audit-app-improvements-015J7EtcwCxWztVhx66cPTdA
**Status:** Ready for production 🚀

Good luck with your deployment! 🎉
