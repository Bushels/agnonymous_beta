# Authentication & User System Design

## 🎯 Feature Overview

Transform Agnonymous from fully anonymous to a **hybrid system** that supports:
- **Verified Users** - Email verified accounts with username badges
- **Unverified Users** - Accounts without email verification
- **Anonymous Posts** - Authenticated users can still post anonymously
- **Guest Browsing** - Read-only access without account

---

## 👥 User Types & Permissions

| User Type | Browse | Post | Comment | Vote | Badge |
|-----------|--------|------|---------|------|-------|
| **Guest (No Account)** | ✅ | ❌ | ❌ | ❌ | 🔒 Guest |
| **Unverified User** | ✅ | ✅ | ✅ | ✅ | ⚠️ Unverified |
| **Verified User** | ✅ | ✅ | ✅ | ✅ | ✅ Verified |
| **Anonymous Post (Auth)** | - | ✅ | ✅ | ✅ | 🎭 Anonymous |

---

## 🗄️ Database Schema Design

### **New Table: `user_profiles`**

```sql
CREATE TABLE user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE NOT NULL,
  email TEXT NOT NULL,
  email_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  province_state TEXT,
  bio TEXT,
  post_count INTEGER DEFAULT 0,
  comment_count INTEGER DEFAULT 0,
  vote_count INTEGER DEFAULT 0,

  -- Constraints
  CONSTRAINT username_length CHECK (LENGTH(username) >= 3 AND LENGTH(username) <= 30),
  CONSTRAINT username_format CHECK (username ~ '^[a-zA-Z0-9_-]+$'),
  CONSTRAINT bio_length CHECK (LENGTH(bio) <= 500)
);

-- Indexes for performance
CREATE INDEX idx_user_profiles_username ON user_profiles(username);
CREATE INDEX idx_user_profiles_email_verified ON user_profiles(email_verified);
```

### **Modified Table: `posts`**

```sql
ALTER TABLE posts
  ADD COLUMN user_id UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
  ADD COLUMN is_anonymous BOOLEAN DEFAULT TRUE,
  ADD COLUMN author_username TEXT,
  ADD COLUMN author_verified BOOLEAN DEFAULT FALSE;

-- Migration logic:
-- - Existing posts: user_id = NULL, is_anonymous = TRUE (legacy anonymous)
-- - New posts by guests: user_id = NULL, is_anonymous = TRUE
-- - New posts by users (anonymous): user_id = UUID, is_anonymous = TRUE
-- - New posts by users (with username): user_id = UUID, is_anonymous = FALSE, author_username = username

-- Index for user's posts
CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_anonymous ON posts(is_anonymous);
```

### **Modified Table: `comments`**

```sql
ALTER TABLE comments
  ADD COLUMN user_id UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
  ADD COLUMN is_anonymous BOOLEAN DEFAULT TRUE,
  ADD COLUMN author_username TEXT,
  ADD COLUMN author_verified BOOLEAN DEFAULT FALSE;

-- Same migration logic as posts
CREATE INDEX idx_comments_user_id ON comments(user_id);
```

### **Modified Table: `truth_votes`**

```sql
ALTER TABLE truth_votes
  ADD COLUMN user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  ADD COLUMN is_anonymous BOOLEAN DEFAULT TRUE;

-- Note: Votes should be linked to user_id for duplicate prevention
-- but can still be displayed anonymously if is_anonymous = TRUE

CREATE INDEX idx_truth_votes_user_id ON truth_votes(user_id);

-- Prevent duplicate votes per user per post
CREATE UNIQUE INDEX idx_unique_user_vote
  ON truth_votes(user_id, post_id)
  WHERE user_id IS NOT NULL;
```

---

## 🔐 Authentication Flow

### **1. Guest Browsing (Default)**

```dart
// User opens app → Not authenticated
// - Can view all posts/comments/votes
// - Cannot post/comment/vote
// - Shows "Sign In" / "Sign Up" buttons on actions
// - Badge: 🔒 "Guest" or no interaction allowed
```

### **2. Sign Up Flow**

```
User clicks "Sign Up"
  ↓
Enter email, password, username
  ↓
Supabase.auth.signUp()
  ↓
Create user_profile record
  ↓
Send verification email
  ↓
User lands on "Verify Your Email" screen
  ↓
Option to "Skip verification and start posting" OR "Verify email"
```

**Database Operations:**
```sql
-- Supabase Auth creates user in auth.users
-- Trigger creates user_profile automatically:
CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_profiles (id, email, email_verified, username)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.email_confirmed_at IS NOT NULL,
    NEW.raw_user_meta_data->>'username'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION create_user_profile();
```

### **3. Email Verification Flow**

```
User clicks verification link in email
  ↓
Supabase confirms email
  ↓
Update user_profiles.email_verified = TRUE
  ↓
Show "✅ Email Verified" badge
```

**Database Operations:**
```sql
CREATE OR REPLACE FUNCTION update_email_verification()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.email_confirmed_at IS NOT NULL AND OLD.email_confirmed_at IS NULL THEN
    UPDATE user_profiles
    SET email_verified = TRUE,
        updated_at = NOW()
    WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_email_verified
  AFTER UPDATE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION update_email_verification();
```

### **4. Sign In Flow**

```
User clicks "Sign In"
  ↓
Enter email + password
  ↓
Supabase.auth.signInWithPassword()
  ↓
Load user_profile
  ↓
Redirect to home feed (now can post/comment/vote)
```

---

## 🎨 UI/UX Design

### **Post Creation Screen - New Options**

```
┌─────────────────────────────────────┐
│ Create Post                         │
├─────────────────────────────────────┤
│                                     │
│ Post as: [Toggle]                  │
│   ● @username (Verified ✅)        │
│   ○ Anonymous 🎭                   │
│                                     │
│ Title: ___________________________  │
│                                     │
│ Content: ________________________   │
│          ________________________   │
│                                     │
│ Category: [Dropdown]                │
│                                     │
│ [Cancel]              [Post]        │
└─────────────────────────────────────┘
```

### **Comment Display - Badge System**

```
Posts and Comments show author info:

┌─────────────────────────────────────┐
│ @farmer_john ✅ Verified            │  ← Verified user
│ "This is concerning for our area"   │
│ 👍 12  💬 3  🕐 2h ago              │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ @newuser ⚠️ Unverified              │  ← Unverified user
│ "I can confirm this happened"       │
│ 👍 5  💬 1  🕐 1h ago               │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ 🎭 Anonymous                        │  ← Anonymous (could be guest or auth user)
│ "I witnessed this but need privacy" │
│ 👍 23  💬 8  🕐 3h ago              │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ 🔒 Guest                            │  ← Read-only indicator
│ [Sign in to comment/vote]           │
└─────────────────────────────────────┘
```

### **User Profile Screen (New)**

```
┌─────────────────────────────────────┐
│ Profile                             │
├─────────────────────────────────────┤
│ @username ✅ Verified               │
│ farmer_john@email.com               │
│                                     │
│ Province: Alberta                   │
│                                     │
│ Bio: Long-time farmer sharing       │
│      agricultural insights.         │
│                                     │
│ Stats:                              │
│   📝 Posts: 12                      │
│   💬 Comments: 45                   │
│   👍 Votes: 128                     │
│                                     │
│ [Edit Profile]  [Sign Out]          │
└─────────────────────────────────────┘
```

---

## 🔒 Row-Level Security (RLS) Policies

### **Posts Table RLS**

```sql
-- Enable RLS
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- Everyone can read posts
CREATE POLICY "Posts are viewable by everyone"
ON posts FOR SELECT
USING (true);

-- Only authenticated users can create posts
CREATE POLICY "Authenticated users can create posts"
ON posts FOR INSERT
WITH CHECK (auth.uid() IS NOT NULL);

-- Users can only update their own posts (within time limit)
CREATE POLICY "Users can update own posts"
ON posts FOR UPDATE
USING (
  user_id = auth.uid()
  AND created_at > NOW() - INTERVAL '15 minutes'
);

-- Users can only delete their own posts (within time limit)
CREATE POLICY "Users can delete own posts"
ON posts FOR DELETE
USING (
  user_id = auth.uid()
  AND created_at > NOW() - INTERVAL '15 minutes'
);
```

### **Comments Table RLS**

```sql
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

-- Everyone can read comments
CREATE POLICY "Comments are viewable by everyone"
ON comments FOR SELECT
USING (true);

-- Only authenticated users can create comments
CREATE POLICY "Authenticated users can create comments"
ON comments FOR INSERT
WITH CHECK (auth.uid() IS NOT NULL);

-- Users can update their own comments
CREATE POLICY "Users can update own comments"
ON comments FOR UPDATE
USING (
  user_id = auth.uid()
  AND created_at > NOW() - INTERVAL '5 minutes'
);

-- Users can delete their own comments
CREATE POLICY "Users can delete own comments"
ON comments FOR DELETE
USING (user_id = auth.uid());
```

### **Truth Votes Table RLS**

```sql
ALTER TABLE truth_votes ENABLE ROW LEVEL SECURITY;

-- Users can read all votes (for counting)
CREATE POLICY "Votes are viewable by everyone"
ON truth_votes FOR SELECT
USING (true);

-- Only authenticated users can vote
CREATE POLICY "Authenticated users can vote"
ON truth_votes FOR INSERT
WITH CHECK (auth.uid() IS NOT NULL);

-- Users can update their own votes (change vote type)
CREATE POLICY "Users can update own votes"
ON truth_votes FOR UPDATE
USING (user_id = auth.uid());

-- Users can delete their own votes
CREATE POLICY "Users can delete own votes"
ON truth_votes FOR DELETE
USING (user_id = auth.uid());
```

### **User Profiles Table RLS**

```sql
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Everyone can read public profiles
CREATE POLICY "Profiles are viewable by everyone"
ON user_profiles FOR SELECT
USING (true);

-- Users can only update their own profile
CREATE POLICY "Users can update own profile"
ON user_profiles FOR UPDATE
USING (id = auth.uid());
```

---

## 📱 Flutter Implementation Structure

### **New Files to Create**

```
lib/
├── models/
│   ├── user_profile.dart          # User profile model
│   └── auth_state.dart             # Authentication state model
├── providers/
│   ├── auth_provider.dart          # Riverpod auth state provider
│   └── user_profile_provider.dart  # User profile provider
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart       # Login UI
│   │   ├── signup_screen.dart      # Sign up UI
│   │   ├── verify_email_screen.dart # Email verification prompt
│   │   └── forgot_password_screen.dart
│   └── profile/
│       ├── profile_screen.dart     # User profile view
│       └── edit_profile_screen.dart # Edit profile
└── widgets/
    ├── user_badge.dart              # Verified/Unverified badges
    ├── post_as_toggle.dart          # Username vs Anonymous toggle
    └── guest_prompt.dart            # "Sign in to interact" prompt
```

### **Updated Files**

```
lib/
├── main.dart                        # Add auth state management
├── create_post_screen.dart          # Add post-as toggle, auth check
└── widgets/
    ├── post_card.dart               # Display user badges
    └── comment_section.dart         # Display commenter badges
```

---

## 🚀 Implementation Phases

### **Phase 1: Database Setup** (1-2 hours)
- [ ] Create `user_profiles` table
- [ ] Add columns to `posts`, `comments`, `truth_votes`
- [ ] Create database triggers for auto-profile creation
- [ ] Set up RLS policies
- [ ] Migration file: `005_add_authentication_system.sql`

### **Phase 2: Authentication Screens** (2-3 hours)
- [ ] Login screen
- [ ] Sign up screen with username input
- [ ] Email verification screen
- [ ] Forgot password flow

### **Phase 3: User Profile** (1-2 hours)
- [ ] Profile view screen
- [ ] Edit profile screen
- [ ] User stats display

### **Phase 4: Update Posting/Commenting** (2-3 hours)
- [ ] Add "Post as" toggle to post creation
- [ ] Update post creation to include user_id and author_username
- [ ] Add auth checks before posting
- [ ] Update comment creation similarly

### **Phase 5: Badge System** (1 hour)
- [ ] Create badge widget
- [ ] Add badges to post cards
- [ ] Add badges to comments
- [ ] Style verified vs unverified

### **Phase 6: Guest Mode Restrictions** (1 hour)
- [ ] Disable post/comment/vote buttons for guests
- [ ] Show "Sign in to interact" prompts
- [ ] Add guest indicator

### **Phase 7: Testing** (2 hours)
- [ ] Test sign up flow
- [ ] Test email verification
- [ ] Test posting as username vs anonymous
- [ ] Test guest restrictions
- [ ] Test RLS policies

---

## 🎨 Badge Design Specifications

```dart
// Verified User Badge
Container(
  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  decoration: BoxDecoration(
    color: Colors.blue.shade100,
    borderRadius: BorderRadius.circular(4),
  ),
  child: Row(
    children: [
      Icon(Icons.verified, size: 14, color: Colors.blue),
      SizedBox(width: 4),
      Text('Verified', style: TextStyle(fontSize: 11, color: Colors.blue.shade900)),
    ],
  ),
)

// Unverified User Badge
Container(
  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  decoration: BoxDecoration(
    color: Colors.orange.shade100,
    borderRadius: BorderRadius.circular(4),
  ),
  child: Row(
    children: [
      Icon(Icons.warning_amber, size: 14, color: Colors.orange),
      SizedBox(width: 4),
      Text('Unverified', style: TextStyle(fontSize: 11, color: Colors.orange.shade900)),
    ],
  ),
)

// Anonymous Badge
Container(
  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  decoration: BoxDecoration(
    color: Colors.grey.shade200,
    borderRadius: BorderRadius.circular(4),
  ),
  child: Row(
    children: [
      Icon(Icons.masks, size: 14, color: Colors.grey.shade700),
      SizedBox(width: 4),
      Text('Anonymous', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
    ],
  ),
)
```

---

## ⚠️ Important Considerations

### **Privacy & Anonymity**
- Even verified users can post anonymously
- `is_anonymous = TRUE` hides username but still links to `user_id` internally
- Never expose `user_id` for anonymous posts in API responses
- Consider: Should moderators see real user behind anonymous posts?

### **Email Verification**
- Supabase handles email verification automatically
- Custom email templates can be configured in Supabase dashboard
- Unverified users can still use the platform (just with badge)

### **Username Uniqueness**
- Usernames must be unique
- Validate on client side before submission
- Database constraint enforces uniqueness
- Consider: Username change policy? (Allow once? Never?)

### **Legacy Data**
- Existing posts/comments remain fully anonymous
- `user_id = NULL` indicates legacy or guest posts
- Migration doesn't break existing functionality

### **Guest Mode**
- Guests can browse without friction
- Clear CTAs to sign up when attempting to interact
- Consider: Allow guest voting? (Probably no, prevents spam)

---

## 📊 Database Migration Checklist

- [ ] Create `user_profiles` table
- [ ] Alter `posts` table (add user_id, is_anonymous, author_username, author_verified)
- [ ] Alter `comments` table (add user_id, is_anonymous, author_username, author_verified)
- [ ] Alter `truth_votes` table (add user_id, is_anonymous)
- [ ] Create trigger: `create_user_profile()` on auth.users INSERT
- [ ] Create trigger: `update_email_verification()` on auth.users UPDATE
- [ ] Create RLS policies for all tables
- [ ] Add indexes for performance
- [ ] Test with sample data

---

**Ready to implement?** Let me know and I'll start creating the database migration file!
