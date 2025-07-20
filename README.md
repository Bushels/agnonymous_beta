# Agnonymous Beta - Project Status & Handoff

This document provides a high-level overview of the Agnonymous Beta application, its current state, and the immediate next steps for development.

## 1. Project Overview

Agnonymous is a Flutter-based mobile and web application designed as a secure and anonymous platform for the agricultural sector. Users can anonymously post reports, which are then validated by the community through a real-time voting and commenting system.

- **Frontend:** Flutter
- **Backend:** Supabase (Database, Auth, Real-time)
- **State Management:** Flutter Riverpod

## 2. Current Functionality (What's Working)

The application has the core user-facing features implemented. The UI is connected to the Supabase backend, and all actions are performed in real-time.

- **Real-Time Post Feed:** The home screen displays a live feed of posts from the `posts` table. New posts created by any user appear instantly at the top of the feed for everyone.
- **Post Creation:** Users can click the "+" button to open a dedicated screen where they can write and submit a new post. The form includes validation and category selection.
- **Real-Time Comments:** Each post has a collapsible comment section. Users can view and submit comments, which appear instantly for all users viewing that post.
- **Real-Time Voting:** Users can cast a "True," "Partial," or "False" vote on any post. The vote is recorded in the `truth_votes` table, and the "Truth Meter" UI updates in real-time for all users.

## 3. Pending Tasks (What's Not Working)

The primary remaining task is to implement the real-time aggregation and display of counters. The underlying data is being created correctly, but the UI is not yet displaying the live totals.

- **Post-Specific Comment Count:** The comment count displayed on each `PostCard` is currently a placeholder and does not update when new comments are added.
- **Global Counters:** The main counters in the header for total Posts, Votes, and Comments are placeholders and do not reflect the actual totals from the database.

## 4. Next Steps & Implementation Plan

The immediate goal is to make all counters live and real-time. This requires a new Supabase SQL function and a new Riverpod provider in the Flutter app.

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

Third Supabase Function
ALTER PUBLICATION supabase_realtime ADD TABLE truth_votes;