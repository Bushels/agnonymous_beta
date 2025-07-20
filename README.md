# Agnonymous Beta

Welcome to the Agnonymous Beta project! This is a Flutter-based mobile and web application designed to be a secure and anonymous platform for the agricultural sector.

## 🚀 Current Status: Critical Issue

**Problem:** The application currently launches to a blank screen, showing only the background and the floating action button. The main content (app bar, post feed, etc.) is not rendering.

**Likely Cause:** This issue almost always points to a problem during the app's startup sequence, before any UI is drawn. The most common culprit is a failure to correctly load the Supabase credentials from the `.env` file, causing the app to crash silently during initialization.

---

## 🛠️ Troubleshooting Checklist: Fixing the Blank Screen

Please follow these steps **in order**. This checklist is designed to find and fix the configuration error.

### 1. Verify the `.env` File

This is the most likely source of the error. Check every detail carefully.

- **Location:** The file must be named exactly `.env` and must be in the absolute root of your project folder (the same level as `pubspec.yaml`).
- **Content:** Open the `.env` file and ensure it looks exactly like this, with no extra spaces or characters:
SUPABASE_URL=https://ibgsloyjxdopkvwqcqwh.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImliZ3Nsb3lqeGRvcGt2d3FjcXdoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI2ODYzMzksImV4cCI6MjA2ODI2MjMzOX0.Ik1980vz4s_UxVuEfBm61-kcIzEH-Nt-hQtydZUeNTw- **Keys:** Double-check that you have copied the correct URL and `anon` key from your Supabase project's API settings.

### 2. Verify `pubspec.yaml` Assets

Your `pubspec.yaml` file must explicitly tell Flutter to include the `.env` file and the background image in the app bundle.

- Open `pubspec.yaml`.
- Find the `flutter:` section.
- Ensure the `assets:` section is present and correctly formatted. It must look exactly like this (indentation is critical):

```yaml
flutter:
  uses-material-design: true

  assets:
    - .env
    - assets/images/
3. Perform a Full Clean and RebuildSometimes, old build artifacts can cause issues. A clean rebuild ensures everything is fresh.Stop the app if it is currently running.Open your terminal in VS Code.Run the following commands, one after the other:flutter clean
```bash
flutter pub get
```bash
flutter run
4. Check the main.dart FileEnsure your lib/main.dart file is using the most recent version we created, which includes the robust error-checking logic. If the app still fails after the steps above, the ErrorApp widget in main.dart should now display a specific error message on the screen, telling us exactly what is wrong.⚙️ Project Setup from ScratchFor new setups or to start over, follow these steps:Create Project: In your parent folder, run flutter create agnonymous_beta.Open Project: Open the agnonymous_beta folder in VS Code.Replace pubspec.yaml: Replace the contents of pubspec.yaml with the latest correct version.Create .env file: Create the .env file in the project root and add your Supabase credentials.Create SVG Asset: Create the assets/images/background_pattern.svg file and paste the SVG code.Replace main.dart: Replace the contents of lib/main.dart with the latest correct version.Get Dependencies: Run flutter pub get in the terminal.Run App: Run flutter run on your desired device (Chrome is recommended for web).🗺️ Next Steps (Once UI is Visible)Once the application is rendering correctly, we will:Connect the UI to Supabase to fetch real data for the post feed.Implement the real-time functionality for posts and stats.Build the "Create Post" screen

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
  vote_type TEXT CHECK (vote_type IN ('true', 'partial', 'false')),
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
  true_votes BIGINT,
  partial_votes BIGINT,
  false_votes BIGINT,
  total_votes BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE vote_type = 'true') AS true_votes,
    COUNT(*) FILTER (WHERE vote_type = 'partial') AS partial_votes,
    COUNT(*) FILTER (WHERE vote_type = 'false') AS false_votes,
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