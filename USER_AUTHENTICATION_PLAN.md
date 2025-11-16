# User Authentication & Username System Implementation Plan

## 📋 Overview

Transform Agnonymous from purely anonymous to **optional identity** system:
- Users create accounts with username + email/password
- **Default: Posts remain anonymous** (privacy-first)
- **Optional: Users can choose to post with their username**
- Foundation for gamification (points, badges, reputation)
- Email verification for account security

---

## 🎯 Core Principles

1. **Anonymity by Default** - Posts are anonymous unless user explicitly chooses username
2. **Privacy-First** - Clear messaging that anonymity is always an option
3. **Progressive Disclosure** - Simple signup, advanced features discovered over time
4. **Backward Compatible** - Existing anonymous posts remain unchanged
5. **Gamification Ready** - Database schema supports future points/badges system

---

## 🗄️ Database Schema Changes

### New Table: `users`

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Supabase auth user ID (links to auth.users)
  auth_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,

  -- User identity
  username TEXT UNIQUE NOT NULL,
  display_name TEXT,  -- Optional display name (can be different from username)
  bio TEXT,           -- User bio (max 500 chars)

  -- Gamification fields (for future use)
  points INTEGER DEFAULT 0,
  reputation_score INTEGER DEFAULT 0,
  badges JSONB DEFAULT '[]',

  -- Privacy settings
  default_anonymous BOOLEAN DEFAULT TRUE,  -- User's default posting preference
  show_badge_on_posts BOOLEAN DEFAULT TRUE,

  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_seen_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  -- Constraints
  CONSTRAINT username_length CHECK (char_length(username) >= 3 AND char_length(username) <= 30),
  CONSTRAINT username_format CHECK (username ~ '^[a-zA-Z0-9_-]+$'),
  CONSTRAINT bio_length CHECK (char_length(bio) <= 500)
);

-- Indexes for performance
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_auth_user_id ON users(auth_user_id);
CREATE INDEX idx_users_points ON users(points DESC);  -- For leaderboards
```

### Modified Table: `posts`

```sql
-- Add new columns to existing posts table
ALTER TABLE posts
  ADD COLUMN user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN posted_as_username BOOLEAN DEFAULT FALSE,
  ADD COLUMN username_at_post_time TEXT;  -- Store username at time of posting (in case user changes it later)

-- Add index for user's posts
CREATE INDEX idx_posts_user_id ON posts(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_posts_posted_as_username ON posts(posted_as_username) WHERE posted_as_username = TRUE;
```

### Modified Table: `truth_votes`

```sql
-- Add user_id for authenticated votes
ALTER TABLE truth_votes
  ADD COLUMN user_id UUID REFERENCES users(id) ON DELETE CASCADE;

-- Update unique constraint to use user_id instead of just anonymous_user_id
ALTER TABLE truth_votes
  DROP CONSTRAINT truth_votes_post_id_anonymous_user_id_key,
  ADD CONSTRAINT truth_votes_post_user_unique
    UNIQUE (post_id, COALESCE(user_id::text, anonymous_user_id));
```

### Modified Table: `comments`

```sql
-- Add user_id and username display option
ALTER TABLE comments
  ADD COLUMN user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  ADD COLUMN posted_as_username BOOLEAN DEFAULT FALSE,
  ADD COLUMN username_at_comment_time TEXT;

-- Add index
CREATE INDEX idx_comments_user_id ON comments(user_id) WHERE user_id IS NOT NULL;
```

### New Table: `user_activity_log` (for gamification)

```sql
CREATE TABLE user_activity_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  activity_type TEXT NOT NULL,  -- 'post_created', 'comment_posted', 'vote_cast', 'badge_earned', etc.
  points_earned INTEGER DEFAULT 0,
  metadata JSONB,  -- Store activity-specific data
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_user_activity_user_id ON user_activity_log(user_id);
CREATE INDEX idx_user_activity_type ON user_activity_log(activity_type);
CREATE INDEX idx_user_activity_created ON user_activity_log(created_at DESC);
```

---

## 🎨 UI/UX Flow

### 1. First-Time User Experience

**Landing Page** (new users see this first):
```
┌────────────────────────────────────┐
│         AGNONYMOUS BETA            │
│  Agricultural Transparency Platform│
│                                    │
│  [Sign Up]    [Sign In]            │
│                                    │
│  Or browse posts anonymously       │
│  [Continue as Guest] →             │
└────────────────────────────────────┘
```

### 2. Sign Up Screen

```
┌────────────────────────────────────┐
│  Create Your Account               │
│                                    │
│  Username: [________________]      │
│  • 3-30 characters                 │
│  • Letters, numbers, _ and -       │
│                                    │
│  Email: [________________]         │
│  • For account recovery only       │
│  • Will never be shown publicly    │
│                                    │
│  Password: [________________]      │
│  • Minimum 8 characters            │
│                                    │
│  ┌──────────────────────────────┐ │
│  │ ℹ️ Your Privacy Matters       │ │
│  │                              │ │
│  │ • Posts are anonymous by     │ │
│  │   default                    │ │
│  │ • You choose when to show    │ │
│  │   your username              │ │
│  │ • Earn rewards for using     │ │
│  │   your username              │ │
│  └──────────────────────────────┘ │
│                                    │
│  [Create Account]                  │
│                                    │
│  Already have an account?          │
│  [Sign In]                         │
└────────────────────────────────────┘
```

### 3. Email Verification

```
┌────────────────────────────────────┐
│  Verify Your Email                 │
│                                    │
│  We sent a verification link to:   │
│  user@example.com                  │
│                                    │
│  Please check your email and       │
│  click the link to verify.         │
│                                    │
│  [Resend Email]                    │
│                                    │
│  [Continue to App] →               │
│  (Limited features until verified) │
└────────────────────────────────────┘
```

### 4. Create Post Screen (Updated)

```
┌────────────────────────────────────┐
│  Create Post                  [✕]  │
│                                    │
│  Category: [Farming ▼]             │
│  Province/State: [Optional ▼]      │
│                                    │
│  Title: [________________]         │
│                                    │
│  Content:                          │
│  [_____________________________]  │
│  [_____________________________]  │
│  [_____________________________]  │
│                                    │
│  ┌──────────────────────────────┐ │
│  │ 🎭 Posting Options           │ │
│  │                              │ │
│  │ ☐ Post as @YourUsername      │ │
│  │                              │ │
│  │ ℹ️ Default: Anonymous        │ │
│  │ ✨ Earn +5 points for using  │ │
│  │    your username!            │ │
│  └──────────────────────────────┘ │
│                                    │
│  [Submit Post]                     │
│                                    │
│  🔒 Your post will be anonymous   │
│     unless you check the box above │
└────────────────────────────────────┘
```

### 5. Post Display (With Username)

**Anonymous Post:**
```
┌────────────────────────────────────┐
│ 🚜 Farming                         │
│ Alberta • 2 hours ago              │
│                                    │
│ Posted by: Anonymous Farmer        │
│                                    │
│ Having issues with my combine...   │
└────────────────────────────────────┘
```

**Username Post:**
```
┌────────────────────────────────────┐
│ 🚜 Farming                         │
│ Alberta • 2 hours ago              │
│                                    │
│ Posted by: @JohnDoe ⭐             │
│ (Reputation: 150 points)           │
│                                    │
│ Having issues with my combine...   │
└────────────────────────────────────┘
```

### 6. User Profile Screen (New)

```
┌────────────────────────────────────┐
│  Profile               [⚙️ Settings]│
│                                    │
│  @JohnDoe                          │
│  Member since: Jan 2025            │
│                                    │
│  📊 Stats                          │
│  • 42 posts (15 with username)     │
│  • 128 comments                    │
│  • 234 votes cast                  │
│  • 150 reputation points           │
│                                    │
│  🏆 Badges                         │
│  [🌟 Early Adopter]                │
│  [💬 Active Commenter]             │
│  [📝 Trusted Contributor]          │
│                                    │
│  📄 Recent Posts                   │
│  [View All Posts →]                │
│                                    │
│  ⚙️ Privacy Settings               │
│  • Default to anonymous: [✓]       │
│  • Show badges on posts: [✓]       │
│                                    │
│  [Sign Out]                        │
└────────────────────────────────────┘
```

---

## 🔄 Authentication Flow

### Sign Up Flow

```
User fills form
    ↓
Validate username (unique, format)
    ↓
Validate email (format)
    ↓
Validate password (min 8 chars)
    ↓
Supabase.auth.signUp(email, password)
    ↓
Send verification email
    ↓
Create user record in users table
    ↓
Show "Check your email" screen
    ↓
User clicks email link
    ↓
Email verified = TRUE
    ↓
Redirect to app
```

### Sign In Flow

```
User enters email + password
    ↓
Supabase.auth.signIn(email, password)
    ↓
Success?
    ├─ Yes → Load user profile from users table
    │         ↓
    │        Navigate to home screen
    │
    └─ No → Show error message
            ↓
           [Forgot Password?] link
```

### Guest Mode (Backward Compatible)

```
User clicks "Continue as Guest"
    ↓
Supabase.auth.signInAnonymously()
    ↓
Create temporary session
    ↓
Can view posts, vote, comment
    ↓
BUT: Posts are always anonymous
     No points/badges/profile
    ↓
Show banner: "Sign up to unlock features!"
```

---

## 🎮 Gamification System (Phase 2)

### Points System

**Earning Points:**
- Post with username: +5 points
- Comment with username: +2 points
- Receive thumbs_up vote: +1 point
- Receive thumbs_down vote: -1 point
- Post gets 10+ comments: +10 bonus points
- Post gets 50+ votes: +25 bonus points

**Points Leaderboard:**
- Daily top 10
- Weekly top 10
- All-time top 10
- Category-specific leaders

### Badge System

**Badges to Implement:**

🌟 **Early Adopter** - Sign up in first month
💬 **Active Commenter** - 50 comments posted
📝 **Trusted Contributor** - 100 posts with username
🏆 **Community Leader** - 500+ reputation points
🎯 **Truth Seeker** - Cast 100 votes
🔥 **On Fire** - 5 posts in one day
🌾 **Category Expert** - 20 posts in one category
👥 **Helpful Farmer** - 50 comments with thumbs_up

### Reputation System

```
Reputation Score =
  (thumbs_up_votes_received * 2) +
  (posts_with_username * 5) +
  (helpful_comments * 3) -
  (thumbs_down_votes_received * 1)
```

---

## 🔒 Privacy & Security Considerations

### Privacy Assurances

1. **Email Privacy:**
   - Never shown publicly
   - Used only for login and account recovery
   - No email notifications without explicit opt-in

2. **Username Privacy:**
   - Username is OPTIONAL to display on posts
   - Users can change username anytime
   - Old posts retain the username used at time of posting

3. **Anonymous Option Always Available:**
   - Clear messaging in UI
   - Default checkbox state = unchecked (anonymous)
   - No pressure to use username

4. **Data Export:**
   - Users can export their data anytime
   - Includes all posts (anonymous and username)
   - GDPR compliant

### Security Measures

1. **Password Requirements:**
   - Minimum 8 characters
   - Handled by Supabase Auth (secure hashing)

2. **Email Verification:**
   - Required for full access
   - Can post/comment before verification (limited)
   - Prevents spam accounts

3. **Rate Limiting:**
   - Signup: 5 attempts per hour per IP
   - Login: 10 attempts per hour per IP
   - Post creation: 10 posts per hour per user

4. **Username Validation:**
   - Alphanumeric + underscore + hyphen only
   - 3-30 characters
   - No offensive words (banned list)
   - Case-insensitive uniqueness

---

## 📁 File Structure Changes

### New Files to Create:

```
lib/
├── screens/
│   ├── auth/
│   │   ├── signup_screen.dart
│   │   ├── signin_screen.dart
│   │   ├── forgot_password_screen.dart
│   │   └── email_verification_screen.dart
│   ├── profile/
│   │   ├── user_profile_screen.dart
│   │   ├── edit_profile_screen.dart
│   │   └── settings_screen.dart
│   └── onboarding/
│       └── welcome_screen.dart
│
├── models/
│   ├── user_model.dart
│   ├── badge_model.dart
│   └── user_activity_model.dart
│
├── providers/
│   ├── auth_provider.dart
│   ├── user_provider.dart
│   └── gamification_provider.dart
│
├── services/
│   ├── auth_service.dart
│   └── user_service.dart
│
├── widgets/
│   ├── auth/
│   │   ├── username_input.dart
│   │   └── privacy_notice.dart
│   ├── profile/
│   │   ├── user_badge.dart
│   │   ├── stats_card.dart
│   │   └── reputation_bar.dart
│   └── posts/
│       └── username_toggle.dart
│
└── utils/
    ├── username_validator.dart
    └── points_calculator.dart
```

### Modified Files:

```
lib/
├── main.dart
│   └── Add authentication check on startup
│       Add navigation to auth screens
│
└── create_post_screen.dart
    └── Add "Post as Username" checkbox
        Add user_id and posted_as_username to post creation
```

---

## 🗺️ Implementation Roadmap

### Phase 1: Core Authentication (Week 1)
- [ ] Database migrations (users table, schema updates)
- [ ] Sign up screen with username/email/password
- [ ] Sign in screen
- [ ] Email verification flow
- [ ] Update Supabase RLS policies for users table
- [ ] Auth state management with Riverpod

### Phase 2: Username on Posts (Week 1-2)
- [ ] Add "Post as Username" checkbox to create post screen
- [ ] Update post creation to include user_id and username
- [ ] Display username on posts (when not anonymous)
- [ ] Update comment posting to support username display
- [ ] Backward compatibility for existing anonymous posts

### Phase 3: User Profile (Week 2)
- [ ] User profile screen (stats, posts, settings)
- [ ] Edit profile (username, bio, display name)
- [ ] Settings screen (privacy options, default anonymous)
- [ ] Sign out functionality

### Phase 4: Gamification Foundation (Week 3)
- [ ] Points calculation system
- [ ] User activity logging
- [ ] Basic badge system (3-5 badges)
- [ ] Points display in profile
- [ ] Leaderboard (top 10 users)

### Phase 5: Advanced Gamification (Week 4+)
- [ ] Advanced badges (10+ badges)
- [ ] Reputation score calculation
- [ ] Badge display on posts
- [ ] Achievement notifications
- [ ] Daily/weekly challenges

---

## 🧪 Testing Checklist

### Authentication Testing:
- [ ] Sign up with valid username/email/password
- [ ] Sign up with duplicate username (should fail)
- [ ] Sign up with invalid email (should fail)
- [ ] Email verification link works
- [ ] Sign in with correct credentials
- [ ] Sign in with wrong password (should fail)
- [ ] Forgot password flow works
- [ ] Sign out works properly

### Posting Testing:
- [ ] Create post as anonymous (default)
- [ ] Create post with username (checkbox checked)
- [ ] Username displays correctly on post
- [ ] Anonymous posts don't show username
- [ ] Existing anonymous posts still work
- [ ] Points awarded for username posts

### Privacy Testing:
- [ ] Email never displayed publicly
- [ ] Username can be changed
- [ ] Default anonymous setting works
- [ ] Guest users can't see email addresses
- [ ] User can export their data

---

## 📊 Success Metrics

### Adoption Metrics:
- % of users who create accounts
- % of posts made with username vs anonymous
- Average time to first account creation
- Email verification rate

### Engagement Metrics:
- Posts per user (authenticated vs guest)
- Comments per user (authenticated vs guest)
- Retention rate (7-day, 30-day)
- Daily active users (DAU)

### Gamification Metrics:
- Points distribution (median, average)
- Badges earned per user
- Leaderboard engagement
- Time to first badge earned

---

## 🚀 Launch Strategy

### Soft Launch (Week 1-2):
1. Deploy authentication system
2. Monitor for bugs
3. Gather user feedback
4. Adjust UX based on feedback

### Full Launch (Week 3):
1. Announce new features
2. Email existing users (if we have emails)
3. Promote gamification features
4. Host launch contest (most points wins prize)

### Post-Launch (Week 4+):
1. Analyze metrics
2. Iterate on gamification
3. Add requested features
4. Scale infrastructure if needed

---

## ❓ Open Questions to Clarify

Before implementing, please confirm:

1. **Username Requirements:**
   - Min/max length: 3-30 characters OK?
   - Allowed characters: a-z, A-Z, 0-9, _, - OK?
   - Case sensitivity: "JohnDoe" ≠ "johndoe"?

2. **Email Verification:**
   - Required before posting? Or can post with limited features?
   - Resend verification email limit?

3. **Guest Mode:**
   - Keep anonymous guest mode? Or require accounts?
   - Guest limitations vs authenticated users?

4. **Gamification Launch:**
   - Launch with Phase 1 only, or include gamification?
   - Point values: +5 for username post, +2 for comment OK?
   - Which badges to launch with?

5. **Existing Data:**
   - Keep all existing anonymous posts as-is?
   - Migrate anonymous_user_id to new system?

6. **Profile Visibility:**
   - Public profiles? (anyone can see user's stats)
   - Private profiles? (only user sees own stats)
   - Followers/following system?

---

**Next Steps:** Please review this plan and let me know your preferences for the open questions. Then I'll begin implementation! 🚀
