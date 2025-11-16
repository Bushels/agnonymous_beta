# Agnonymous Beta - Agricultural Transparency Platform

Agnonymous is a Flutter-based web and mobile application designed as a secure and anonymous platform for the agricultural sector. Users can anonymously post reports about agricultural issues, companies, and practices, which are then validated by the community through a real-time voting and commenting system.

## 🚀 Recent Updates (January 2025)

### ✅ **Major Features Added**
- **New Categories:** Added "General" 📝 and "Other" 🔗 categories to complement existing agricultural categories
- **Data Migration:** Successfully imported 97 legacy posts from original Agnonymous platform
- **Enhanced Post Creation:** Improved validation with more flexible requirements
- **Performance Optimization:** Added pagination to handle large datasets efficiently
- **Web App Fixes:** Resolved loading issues and improved compatibility

### 🐛 **Critical Issues Resolved**
- **App Loading Failures:** Fixed web app crashes when loading large datasets (97+ posts)
- **Environment Variable Issues:** Implemented JavaScript interop to properly read Supabase credentials
- **HTML Structure Problems:** Simplified web/index.html for better browser compatibility
- **Post Validation:** Reduced minimum requirements to be more user-friendly

### 📊 **Current Data Status**
- **97 imported posts** from legacy platform with proper categorization
- **11 categories** available: Farming, Livestock, Ranching, Crops, Markets, Weather, Chemicals, Equipment, Politics, General, Other
- **30-post pagination** implemented for optimal performance

## 🛠️ Technology Stack

- **Frontend:** Flutter (Web & Mobile)
- **Backend:** Supabase (Database, Auth, Real-time)
- **State Management:** Flutter Riverpod
- **Hosting:** Firebase Hosting
- **Database:** PostgreSQL (via Supabase)

## ⚡ Current Functionality

### ✅ **Fully Working Features**
- **Real-Time Post Feed:** Live feed displays posts with pagination (30 posts max)
- **Post Creation:** Complete form with category selection and validation
- **Real-Time Comments:** Instant comment system for all posts
- **Real-Time Voting:** Truth meter with "True," "Partial," or "False" voting
- **Category Filtering:** Filter posts by agricultural categories
- **Search Functionality:** Search posts by title and content
- **Responsive Design:** Works across web and mobile platforms
- **AdSense Integration:** Site verification and monetization ready

### 📝 **Post Validation Requirements**
- **Title:** Minimum 1 character, Maximum 100 characters
- **Content:** Minimum 10 characters, Maximum 2000 characters
- **Category:** Required selection from predefined list

### 🎯 **Available Categories**
1. **Farming** 🚜 - General farming practices and issues
2. **Livestock** 🐄 - Animal husbandry and cattle-related posts
3. **Ranching** 🤠 - Ranch management and operations
4. **Crops** 🌾 - Crop production, seeds, and harvest
5. **Markets** 📈 - Agricultural markets and pricing
6. **Weather** 🌦️ - Weather impacts and forecasting
7. **Chemicals** 🧪 - Pesticides, fertilizers, and agricultural chemicals
8. **Equipment** 🔧 - Machinery and agricultural technology
9. **Politics** 🏛️ - Agricultural policy and regulations
10. **General** 📝 - General agricultural discussions
11. **Other** 🔗 - Miscellaneous topics

## 🌐 **Deployment & Live URLs**
- **Live Web App:** [https://agnonymousbeta.web.app](https://agnonymousbeta.web.app)
- **Firebase Console:** [https://console.firebase.google.com/project/agnonymousbeta](https://console.firebase.google.com/project/agnonymousbeta)
- **Custom Domain:** Prepared for agnonymous.news (DNS setup pending)

## 🔧 **Recent Technical Fixes**

### **Web App Loading Issues**
**Problem:** After importing 97 posts, the web app would hang or crash when trying to load all posts simultaneously.

**Root Causes:**
1. No pagination - app tried to load all 97 posts at once
2. Supabase credentials not properly accessible via JavaScript
3. Complex HTML structure with Flutter bootstrap causing loading delays

**Solutions Implemented:**
1. **Added Pagination:** Limited initial load to 30 posts with `.limit(30)` in `main.dart:150`
2. **JavaScript Interop:** Added `dart:js` import to read `window.ENV` variables from HTML
3. **Simplified HTML:** Streamlined `web/index.html` to use direct `main.dart.js` loading
4. **Enhanced Error Handling:** Added comprehensive logging for debugging

### **Environment Variable Resolution**
**Issue:** App couldn't read Supabase credentials from environment variables

**Resolution:** Implemented fallback system in `main.dart`:
1. Try `window.ENV` (Firebase/web deployment)
2. Fallback to `dart-define` (production builds)
3. Fallback to `.env` file (development)

## 📦 **Data Migration Details**

### **Legacy Post Import**
- **Source:** Original Agnonymous platform database
- **Total Posts:** 97 historical posts imported
- **Date Range:** Posts from June 2025 - July 2025
- **Categorization:** All posts categorized using new 11-category system
- **Anonymous Users:** Migrated with `user_migrated_[0-96]` IDs

### **Category Mapping Applied**
Legacy posts were analyzed and categorized based on content:
- Agricultural supply chain issues → **Markets**
- Chemical/pesticide concerns → **Chemicals**  
- Equipment and technology → **Equipment**
- Policy and regulatory → **Politics**
- General farming practices → **Farming**
- Livestock operations → **Livestock**
- And more...

## 🚧 **Known Issues & Limitations**

### **Current Limitations**
- **Mobile App:** Not yet deployed to app stores (Flutter web only)
- **Load More:** No "load more" button for pagination (only shows latest 30)
- **User Profiles:** All users are anonymous, no persistent profiles
- **Image Upload:** Not implemented in current version
- **Push Notifications:** Not configured

### **Future Enhancements**
- Infinite scroll or "Load More" functionality
- Mobile app deployment (iOS/Android)
- Image/file attachment support
- Advanced search and filtering
- User reputation system
- Content moderation tools

## 💻 **Development Setup**

### **Prerequisites**
- Flutter SDK (latest stable)
- Firebase CLI
- Git

### **Local Development**
```bash
# Clone repository
git clone https://github.com/Bushels/agnonymous_beta.git
cd agnonymous_beta

# Install dependencies
flutter pub get

# Run web development server
flutter run -d chrome

# Build for production
flutter build web

# Deploy to Firebase
firebase deploy --only hosting
```

### **Environment Variables**
The app uses a fallback system for configuration:
1. **Production (Firebase):** Credentials in `web/index.html` as `window.ENV`
2. **Development:** Create `.env` file with:
   ```
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key
   ```

### **Key Files**
- `lib/main.dart` - Main app with providers and UI
- `lib/create_post_screen.dart` - Post creation form
- `web/index.html` - Web app HTML with credentials
- `firebase.json` - Firebase hosting configuration
- `pubspec.yaml` - Flutter dependencies

## 🎯 **Next Steps & Implementation Plan**

### **Immediate Priorities**
1. **Load More Posts:** Implement pagination beyond first 30 posts
2. **Counter Accuracy:** Fix live counters for posts, votes, and comments
3. **Mobile Optimization:** Improve mobile responsive design
4. **Performance:** Optimize real-time updates for better performance

### **Medium Term Goals**
1. **Mobile App Deployment:** Build and deploy to iOS/Android app stores
2. **Enhanced Search:** Add advanced filtering and search capabilities
3. **User Experience:** Improve post creation and interaction flows
4. **Content Management:** Add moderation and reporting features

### **Long Term Vision**
1. **Community Features:** User reputation and community governance
2. **Data Analytics:** Trending topics and agricultural insights
3. **Integration:** Connect with agricultural data sources and APIs
4. **Monetization:** Expand AdSense and explore agricultural partnerships

### Step 1: Create a New Supabase SQL Function

A new function, `get_global_stats`, needs to be created in the Supabase SQL Editor. This function will efficiently query the database to get the total counts of posts, votes, and comments.

```sql
-- This function should be added to the Supabase SQL Editor
CREATE OR REPLACE FUNCTION get_global_stats()
RETURNS TABLE (
  total_posts BIGINT,
  total_votes BIGINT,
  total_comments BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM posts) AS total_posts,
    (SELECT COUNT(*) FROM truth_votes) AS total_votes,
    (SELECT COUNT(*) FROM comments) AS total_comments;
END;
$$ LANGUAGE plpgsql;
Step 2: Create a New Riverpod Provider in FlutterA new StreamProvider named globalStatsProvider should be created in main.dart. This provider will:Call the get_global_stats function to get the initial counts.Establish a real-time listener that re-fetches the stats whenever a new post, vote, or comment is created.Step 3: Update the UI WidgetsGlobalStatsHeader Widget: This widget must be converted to a ConsumerWidget to watch the new globalStatsProvider and display the live data

Supabase SQL
-- #############################################################################
-- ## COMPLETE & HARDENED SUPABASE SETUP FOR AGNONYMOUS APP
-- #############################################################################

-- Drop existing resources to ensure a clean slate
DROP TABLE IF EXISTS comments CASCADE;
DROP TABLE IF EXISTS truth_votes CASCADE;
DROP TABLE IF EXISTS posts CASCADE;
DROP FUNCTION IF EXISTS get_post_vote_stats(UUID);
DROP FUNCTION IF EXISTS cast_user_vote(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS check_vote_rate();

-- #############################################################################
-- ## 1. CREATE TABLES
-- #############################################################################
CREATE TABLE posts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  anonymous_user_id TEXT NOT NULL,
  title TEXT,
  content TEXT NOT NULL,
  category TEXT NOT NULL,
  subcategory TEXT,
  location TEXT,
  topics TEXT[] DEFAULT '{}',
  evidence_urls TEXT[] DEFAULT '{}',
  truth_score INTEGER DEFAULT 0,
  vote_count INTEGER DEFAULT 0,
  comment_count INTEGER DEFAULT 0,
  flag_count INTEGER DEFAULT 0,
  is_hidden BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE truth_votes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  anonymous_user_id TEXT NOT NULL,
  vote_type TEXT CHECK (vote_type IN ('thumbs_up', 'partial', 'thumbs_down', 'funny')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(post_id, anonymous_user_id)
);

CREATE TABLE comments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  anonymous_user_id TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- #############################################################################
-- ## 2. ADD PERFORMANCE INDEXES
-- #############################################################################
CREATE INDEX IF NOT EXISTS idx_truth_votes_post_id ON truth_votes(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_post_id ON comments(post_id);

-- #############################################################################
-- ## 3. CREATE FUNCTIONS
-- #############################################################################
CREATE OR REPLACE FUNCTION get_post_vote_stats(post_id_in UUID)
RETURNS TABLE (
  thumbs_up_votes BIGINT,
  partial_votes BIGINT,
  thumbs_down_votes BIGINT,
  funny_votes BIGINT,
  total_votes BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE vote_type = 'thumbs_up') AS thumbs_up_votes,
    COUNT(*) FILTER (WHERE vote_type = 'partial') AS partial_votes,
    COUNT(*) FILTER (WHERE vote_type = 'thumbs_down') AS thumbs_down_votes,
    COUNT(*) FILTER (WHERE vote_type = 'funny') AS funny_votes,
    COUNT(*) AS total_votes
  FROM truth_votes
  WHERE post_id = post_id_in;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION cast_user_vote(post_id_in UUID, user_id_in TEXT, vote_type_in TEXT)
RETURNS VOID AS $$
BEGIN
  IF vote_type_in IS NULL THEN
    DELETE FROM truth_votes
    WHERE post_id = post_id_in AND anonymous_user_id = user_id_in;
  ELSE
    INSERT INTO truth_votes (post_id, anonymous_user_id, vote_type)
    VALUES (post_id_in, user_id_in, vote_type_in)
    ON CONFLICT (post_id, anonymous_user_id)
    DO UPDATE SET vote_type = vote_type_in;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_vote_rate() RETURNS TRIGGER AS $$
BEGIN
  IF (
    SELECT COUNT(*)
    FROM truth_votes
    WHERE anonymous_user_id = NEW.anonymous_user_id
    AND created_at > NOW() - INTERVAL '1 minute'
  ) >= 5 THEN
    RAISE EXCEPTION 'Vote rate limit exceeded. Please try again later.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- #############################################################################
-- ## 4. SETUP TRIGGERS AND SECURITY
-- #############################################################################

-- VOTE RATE LIMITING TRIGGER
DROP TRIGGER IF EXISTS trg_vote_rate_limit ON truth_votes;
CREATE TRIGGER trg_vote_rate_limit
  BEFORE INSERT ON truth_votes
  FOR EACH ROW EXECUTE FUNCTION check_vote_rate();

-- ENABLE ROW LEVEL SECURITY
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE truth_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read access to posts" ON posts;
DROP POLICY IF EXISTS "Allow anonymous users to create posts" ON posts;
DROP POLICY IF EXISTS "Allow public read access to votes" ON truth_votes;
DROP POLICY IF EXISTS "Allow anonymous users to cast votes" ON truth_votes;
DROP POLICY IF EXISTS "Users can only update or delete their own vote" ON truth_votes;
DROP POLICY IF EXISTS "Users can only delete their own vote" ON truth_votes;
DROP POLICY IF EXISTS "Allow public read access to comments" ON comments;
DROP POLICY IF EXISTS "Allow anonymous users to create comments" ON comments;


-- SECURE RLS POLICIES (CORRECTED)
CREATE POLICY "Allow public read access to posts" ON posts
  FOR SELECT USING (true);
CREATE POLICY "Allow authenticated users to create posts"
  ON posts FOR INSERT TO authenticated WITH CHECK
  (auth.uid()::text = anonymous_user_id);

CREATE POLICY "Allow public read access to votes" ON
  truth_votes FOR SELECT USING (true);
CREATE POLICY "Allow authenticated users to cast votes" ON
  truth_votes FOR INSERT TO authenticated WITH CHECK
  (auth.uid()::text = anonymous_user_id);
CREATE POLICY "Users can update their own vote" ON
  truth_votes FOR UPDATE TO authenticated USING
  (auth.uid()::text = anonymous_user_id);
CREATE POLICY "Users can delete their own vote" ON
  truth_votes FOR DELETE TO authenticated USING
  (auth.uid()::text = anonymous_user_id);

CREATE POLICY "Allow public read access to comments" ON
  comments FOR SELECT USING (true);
CREATE POLICY "Allow authenticated users to create
  comments" ON comments FOR INSERT TO authenticated WITH
  CHECK (auth.uid()::text = anonymous_user_id);


-- #############################################################################
-- ## 5. GRANT PERMISSIONS
-- #############################################################################
GRANT EXECUTE ON FUNCTION get_post_vote_stats(UUID) TO anon;
GRANT EXECUTE ON FUNCTION cast_user_vote(UUID, TEXT, TEXT) TO anon;
GRANT ALL ON posts TO anon;
GRANT ALL ON truth_votes TO anon;
GRANT ALL ON comments TO anon;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO anon;

-- #############################################################################
-- ## SETUP COMPLETE!
-- #############################################################################

Second Supabase Function
ALTER PUBLICATION supabase_realtime ADD TABLE posts;

Third Supabase Function
ALTER PUBLICATION supabase_realtime ADD TABLE truth_votes;