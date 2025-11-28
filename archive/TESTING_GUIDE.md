# Testing Guide - Authentication & Gamification System

## 🎯 **Two Ways to Test**

1. **Local Testing** (Fastest - Recommended First)
2. **Firebase Deploy** (Production Testing)

---

## ✅ **Prerequisites: Database Setup**

Before testing the Flutter app, ensure database migrations are complete.

### **Check if Migrations Are Done**

Run this in Supabase SQL Editor:

```sql
-- Check if user_profiles table exists
SELECT EXISTS (
  SELECT 1 FROM information_schema.tables
  WHERE table_name = 'user_profiles'
) as user_profiles_exists;

-- Check if gamification columns exist
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'user_profiles'
AND column_name IN ('reputation_points', 'vote_weight');

-- Check if truth meter columns exist
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'posts'
AND column_name IN ('truth_meter_score', 'truth_meter_status');
```

### **If Migrations NOT Done:**

Run these in order in Supabase SQL Editor:

```bash
# 1. Authentication system (creates user_profiles)
migration 005_add_authentication_system.sql

# 2. Gamification system (adds reputation & truth meter)
migration 006_add_gamification_system.sql

# 3. Post-migration setup (RLS policies, indexes, recalculation)
migration 007_post_migration_setup.sql

# 4. Test everything works
TEST_GAMIFICATION.sql
```

**Expected output from test:**
```
✅ GAMIFICATION SYSTEM FULLY OPERATIONAL
```

---

## 🏃 **Option 1: Local Testing (FASTEST)**

Test on your local machine without deploying.

### **Step 1: Install Dependencies**

```bash
cd C:\Users\kyle\Agriculture\agnonymous_beta
flutter pub get
```

### **Step 2: Run Locally**

```bash
# Run in Chrome (web)
flutter run -d chrome

# OR run in Edge
flutter run -d edge

# OR run on Android emulator (if you have one)
flutter run
```

### **Step 3: What You'll See**

The app will open in your browser at `http://localhost:PORT`

**What to test:**
1. ✅ App loads without errors
2. ✅ Posts display with truth meter badges
3. ✅ Try to create a post → Should prompt "Sign in required"
4. ✅ Try to comment → Should prompt "Sign in required"
5. ✅ Try to vote → Should prompt "Sign in required"

### **Step 4: Test Sign Up**

Since we haven't built the auth UI yet, you can test via Supabase:

```bash
# Option A: Use Supabase Auth UI
# Go to: https://supabase.com/dashboard/project/[your-project]/auth

# Option B: Create test user via SQL
```

Run this in Supabase SQL Editor to create a test user:

```sql
-- Create a test user (this simulates sign up)
-- Note: This is a workaround until we build the auth UI

-- First, manually create auth user in Supabase Dashboard:
-- 1. Go to Authentication → Users
-- 2. Click "Add User"
-- 3. Email: test@example.com
-- 4. Password: testpassword123
-- 5. Confirm email immediately

-- Then verify the user_profile was created automatically
SELECT * FROM user_profiles WHERE email = 'test@example.com';
```

### **Step 5: Test Authentication State**

Add this temporary debug code to `lib/main.dart` to verify auth works:

```dart
// Add this inside HomeScreen's build method, at the top
@override
Widget build(BuildContext context) {
  // DEBUG: Show auth state
  final authState = ref.watch(authProvider);
  print('Auth state: ${authState.isAuthenticated}');
  print('User: ${authState.user?.email}');
  print('Profile: ${authState.profile?.username}');

  // ... rest of your build method
}
```

Then check the console for debug output.

---

## 🚀 **Option 2: Deploy to Firebase (PRODUCTION)**

Deploy to test in production environment.

### **Step 1: Build for Production**

```bash
# Build optimized web version
flutter build web --release
```

**Expected output:**
```
✓ Built build\web
```

### **Step 2: Deploy to Firebase**

```bash
# Deploy to Firebase Hosting
firebase deploy --only hosting
```

**Expected output:**
```
✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/agnonymousbeta/overview
Hosting URL: https://agnonymousbeta.web.app
```

### **Step 3: Test on Production**

1. Open `https://agnonymousbeta.web.app`
2. Same tests as local testing
3. Check browser console for errors (F12)

---

## 🧪 **Comprehensive Testing Checklist**

### **Phase 1: Basic Functionality**

- [ ] App loads without errors
- [ ] Posts display correctly
- [ ] Comments display correctly
- [ ] Votes display correctly
- [ ] Categories filter correctly

### **Phase 2: Truth Meter Display**

- [ ] Truth meter badges show on posts
- [ ] Unrated posts show "❓ Unrated"
- [ ] Posts with votes show correct status
- [ ] Admin verified posts show "🛡️ VERIFIED TRUTH"
- [ ] Vote counts display (👍 👎 🟡)

### **Phase 3: User Badges**

- [ ] Anonymous posts show "🎭 Anonymous"
- [ ] User posts show username
- [ ] Verified users show "✅ Verified"
- [ ] Unverified users show "⚠️ Unverified"

### **Phase 4: Guest Mode Restrictions**

- [ ] Guest can browse posts ✅
- [ ] Guest cannot create posts ❌
- [ ] Guest cannot comment ❌
- [ ] Guest cannot vote ❌
- [ ] Guest sees "Sign in" prompts

### **Phase 5: Authentication (When UI Built)**

- [ ] Sign up works
- [ ] Email verification sent
- [ ] Sign in works
- [ ] Profile loads automatically
- [ ] Sign out works

### **Phase 6: Point System (When UI Built)**

- [ ] Creating post awards +5 points
- [ ] Commenting awards +2 points (once per post)
- [ ] Voting awards +1 point (once per post)
- [ ] Vote-based points update correctly
- [ ] Reputation level updates automatically

---

## 🐛 **Troubleshooting**

### **Error: "Cannot find module 'models/user_profile.dart'"**

**Fix:** The import path might be wrong. Check `lib/main.dart` line 75:

```dart
// Should be:
import 'models/user_profile.dart';

// NOT:
import 'package:agnonymous_beta/models/user_profile.dart';
```

### **Error: "TruthMeterStatus is not defined"**

**Fix:** Make sure the import is at the top of `lib/main.dart`:

```dart
import 'models/user_profile.dart';
```

### **Error: "The getter 'truthMeterScore' isn't defined for the class 'Post'"**

**Fix:** This means the Post model wasn't updated. Make sure you saved the changes to `lib/main.dart`.

### **App loads but no truth meters show**

**Cause:** Database doesn't have the new columns yet.

**Fix:** Run migration 006 and 007 in Supabase.

### **Posts don't have vote counts**

**Cause:** Migration 007 recalculation didn't run.

**Fix:** Run this in Supabase SQL Editor:

```sql
-- Recalculate all truth meters
DO $$
DECLARE
  post_record RECORD;
BEGIN
  FOR post_record IN SELECT id FROM posts
  LOOP
    PERFORM recalculate_post_truth_meter(post_record.id);
  END LOOP;
END $$;
```

### **"Sign in required" doesn't show**

**Cause:** Auth provider not initialized.

**Fix:** Make sure you're wrapping your app with `ProviderScope`:

```dart
void main() {
  runApp(
    ProviderScope(  // This is required!
      child: MyApp(),
    ),
  );
}
```

---

## 📊 **Quick Verification Queries**

Run these in Supabase SQL Editor to check data:

```sql
-- Check if truth meters are calculated
SELECT
  title,
  truth_meter_score,
  truth_meter_status,
  vote_count,
  thumbs_up_count,
  thumbs_down_count
FROM posts
WHERE vote_count > 0
LIMIT 10;

-- Check if user_profiles exist
SELECT username, reputation_points, reputation_level, vote_weight
FROM user_profiles
LIMIT 10;

-- Check if triggers are working
SELECT tgname, tgenabled
FROM pg_trigger
WHERE tgname LIKE '%award%' OR tgname LIKE '%truth_meter%';
```

---

## 🎯 **Recommended Testing Flow**

1. **✅ Verify database migrations** (run SQL checks above)
2. **✅ Test locally first** (`flutter run -d chrome`)
3. **✅ Fix any compilation errors**
4. **✅ Verify data displays correctly** (truth meters, badges)
5. **✅ Test guest restrictions** (can't post/comment/vote)
6. **✅ Deploy to Firebase** (when local tests pass)
7. **✅ Test on production** (https://agnonymousbeta.web.app)

---

## 💡 **Tips**

- **Use hot reload:** When testing locally, press `r` in the terminal to hot reload changes
- **Clear browser cache:** If things look broken, try Ctrl+Shift+R (hard refresh)
- **Check console:** Always check browser console (F12) for errors
- **Start simple:** Test one feature at a time
- **Database first:** Always verify database migrations before testing Flutter

---

## ⚠️ **Known Limitations (Until Auth UI Built)**

- Can't sign up via app yet (use Supabase Dashboard)
- Can't sign in via app yet (use Supabase Dashboard)
- Guest mode works perfectly
- All data displays correctly
- Point awarding works in background

**Next step:** Build auth UI screens so users can sign up/in from the app!

---

**Ready to test?** Start with local testing first, then deploy to Firebase once everything works!
