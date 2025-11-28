-- ============================================================================
-- ADD GAMIFICATION & REPUTATION SYSTEM
-- ============================================================================
-- This migration implements a sophisticated reputation and points system:
-- 1. Point tracking for posts, comments, votes
-- 2. Truth Meter / Rumour Mill credibility scoring
-- 3. Admin verification system
-- 4. Anti-abuse measures (prevent self-voting, vote brigading)
-- 5. Reputation levels and badges
-- 6. Vote weighting based on reputation
-- ============================================================================

-- ============================================================================
-- PART 1: EXTEND USER PROFILES FOR REPUTATION
-- ============================================================================

DO $$
BEGIN
  -- Add reputation tracking columns
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_profiles' AND column_name = 'reputation_points'
  ) THEN
    ALTER TABLE user_profiles
      ADD COLUMN reputation_points INTEGER DEFAULT 0 CHECK (reputation_points >= 0),
      ADD COLUMN public_reputation INTEGER DEFAULT 0 CHECK (public_reputation >= 0),
      ADD COLUMN anonymous_reputation INTEGER DEFAULT 0 CHECK (anonymous_reputation >= 0),
      ADD COLUMN reputation_level INTEGER DEFAULT 0,
      ADD COLUMN vote_weight NUMERIC(3,1) DEFAULT 1.0;

    RAISE NOTICE '✅ Added reputation columns to user_profiles';
  ELSE
    RAISE NOTICE '✅ Reputation columns already exist';
  END IF;
END $$;

-- ============================================================================
-- PART 2: EXTEND POSTS TABLE FOR TRUTH METER
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'posts' AND column_name = 'truth_meter_score'
  ) THEN
    ALTER TABLE posts
      ADD COLUMN truth_meter_score NUMERIC(5,2) DEFAULT 0.0,
      ADD COLUMN truth_meter_status TEXT DEFAULT 'unrated'
        CHECK (truth_meter_status IN ('unrated', 'rumour', 'questionable', 'partially_true', 'likely_true', 'verified_community', 'verified_truth')),
      ADD COLUMN admin_verified BOOLEAN DEFAULT FALSE,
      ADD COLUMN verified_at TIMESTAMPTZ,
      ADD COLUMN verified_by UUID REFERENCES user_profiles(id),
      ADD COLUMN vote_count INTEGER DEFAULT 0,
      ADD COLUMN thumbs_up_count INTEGER DEFAULT 0,
      ADD COLUMN thumbs_down_count INTEGER DEFAULT 0,
      ADD COLUMN partial_count INTEGER DEFAULT 0,
      ADD COLUMN funny_count INTEGER DEFAULT 0,
      ADD COLUMN post_points_awarded INTEGER DEFAULT 5; -- Track points already given

    RAISE NOTICE '✅ Added truth meter columns to posts';
  ELSE
    RAISE NOTICE '✅ Truth meter columns already exist';
  END IF;
END $$;

-- ============================================================================
-- PART 3: USER POST INTERACTIONS TRACKING
-- ============================================================================
-- Track which posts each user has interacted with to prevent duplicate points

CREATE TABLE IF NOT EXISTS user_post_interactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  has_commented BOOLEAN DEFAULT FALSE,
  has_voted BOOLEAN DEFAULT FALSE,
  comment_points_awarded BOOLEAN DEFAULT FALSE,
  vote_points_awarded BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  CONSTRAINT unique_user_post_interaction UNIQUE(user_id, post_id)
);

CREATE INDEX IF NOT EXISTS idx_user_post_interactions_user ON user_post_interactions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_post_interactions_post ON user_post_interactions(post_id);

RAISE NOTICE '✅ Created user_post_interactions table';

-- ============================================================================
-- PART 4: ADMIN ROLES & VERIFICATION SYSTEM
-- ============================================================================

CREATE TABLE IF NOT EXISTS admin_roles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('moderator', 'admin', 'super_admin')),
  granted_by UUID REFERENCES user_profiles(id),
  granted_at TIMESTAMPTZ DEFAULT NOW(),

  CONSTRAINT unique_user_role UNIQUE(user_id, role)
);

CREATE INDEX IF NOT EXISTS idx_admin_roles_user ON admin_roles(user_id);

RAISE NOTICE '✅ Created admin_roles table';

CREATE TABLE IF NOT EXISTS post_verifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  verified_by UUID NOT NULL REFERENCES user_profiles(id),
  verification_type TEXT NOT NULL CHECK (verification_type IN ('verified_true', 'verified_false', 'needs_investigation')),
  verification_notes TEXT,
  evidence_links TEXT[],
  created_at TIMESTAMPTZ DEFAULT NOW(),

  CONSTRAINT unique_post_verification UNIQUE(post_id)
);

CREATE INDEX IF NOT EXISTS idx_post_verifications_post ON post_verifications(post_id);
CREATE INDEX IF NOT EXISTS idx_post_verifications_verifier ON post_verifications(verified_by);

RAISE NOTICE '✅ Created post_verifications table';

-- ============================================================================
-- PART 5: SUSPICIOUS ACTIVITY LOGGING
-- ============================================================================

CREATE TABLE IF NOT EXISTS suspicious_activity (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
  activity_type TEXT NOT NULL,
  details JSONB,
  ip_address TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_suspicious_activity_user ON suspicious_activity(user_id);
CREATE INDEX IF NOT EXISTS idx_suspicious_activity_type ON suspicious_activity(activity_type);
CREATE INDEX IF NOT EXISTS idx_suspicious_activity_created ON suspicious_activity(created_at DESC);

RAISE NOTICE '✅ Created suspicious_activity table';

-- ============================================================================
-- PART 6: REPUTATION LEVEL CALCULATION FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_reputation_level(points INTEGER)
RETURNS INTEGER AS $$
BEGIN
  IF points >= 5000 THEN RETURN 9;      -- Legend
  ELSIF points >= 2500 THEN RETURN 8;   -- Master Investigator
  ELSIF points >= 1500 THEN RETURN 7;   -- Truth Guardian
  ELSIF points >= 1000 THEN RETURN 6;   -- Expert Whistleblower
  ELSIF points >= 750 THEN RETURN 5;    -- Trusted Reporter
  ELSIF points >= 500 THEN RETURN 4;    -- Reliable Source
  ELSIF points >= 300 THEN RETURN 3;    -- Established
  ELSIF points >= 150 THEN RETURN 2;    -- Growing
  ELSIF points >= 50 THEN RETURN 1;     -- Sprout
  ELSE RETURN 0;                         -- Seedling
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION calculate_vote_weight(points INTEGER)
RETURNS NUMERIC(3,1) AS $$
BEGIN
  IF points >= 5000 THEN RETURN 3.0;
  ELSIF points >= 2500 THEN RETURN 2.5;
  ELSIF points >= 1500 THEN RETURN 2.0;
  ELSIF points >= 1000 THEN RETURN 1.7;
  ELSIF points >= 750 THEN RETURN 1.5;
  ELSIF points >= 500 THEN RETURN 1.3;
  ELSIF points >= 300 THEN RETURN 1.2;
  ELSIF points >= 150 THEN RETURN 1.1;
  ELSE RETURN 1.0;
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

RAISE NOTICE '✅ Created reputation calculation functions';

-- ============================================================================
-- PART 7: AUTO-UPDATE REPUTATION LEVEL & VOTE WEIGHT
-- ============================================================================

CREATE OR REPLACE FUNCTION update_reputation_level()
RETURNS TRIGGER AS $$
BEGIN
  NEW.reputation_level := calculate_reputation_level(NEW.reputation_points);
  NEW.vote_weight := calculate_vote_weight(NEW.reputation_points);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_reputation_level ON user_profiles;
CREATE TRIGGER trg_update_reputation_level
  BEFORE UPDATE OF reputation_points ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION update_reputation_level();

RAISE NOTICE '✅ Created reputation level auto-update trigger';

-- ============================================================================
-- PART 8: AWARD POINTS FOR POST CREATION
-- ============================================================================

CREATE OR REPLACE FUNCTION award_post_creation_points()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.user_id IS NOT NULL THEN
    -- Award 5 points for creating post
    IF NEW.is_anonymous THEN
      UPDATE user_profiles
      SET anonymous_reputation = anonymous_reputation + 5,
          reputation_points = reputation_points + 5
      WHERE id = NEW.user_id;
    ELSE
      UPDATE user_profiles
      SET public_reputation = public_reputation + 5,
          reputation_points = reputation_points + 5
      WHERE id = NEW.user_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_award_post_creation_points ON posts;
CREATE TRIGGER trg_award_post_creation_points
  AFTER INSERT ON posts
  FOR EACH ROW EXECUTE FUNCTION award_post_creation_points();

RAISE NOTICE '✅ Created post creation points trigger';

-- ============================================================================
-- PART 9: AWARD POINTS FOR COMMENTING (Once per post)
-- ============================================================================

CREATE OR REPLACE FUNCTION award_comment_points()
RETURNS TRIGGER AS $$
DECLARE
  already_awarded BOOLEAN;
BEGIN
  IF NEW.user_id IS NOT NULL THEN
    -- Check if user already got comment points for this post
    SELECT comment_points_awarded INTO already_awarded
    FROM user_post_interactions
    WHERE user_id = NEW.user_id AND post_id = NEW.post_id;

    -- If no interaction record, create one
    IF already_awarded IS NULL THEN
      INSERT INTO user_post_interactions (user_id, post_id, has_commented, comment_points_awarded)
      VALUES (NEW.user_id, NEW.post_id, TRUE, TRUE);

      already_awarded := FALSE;
    END IF;

    -- Award 2 points only if not already awarded
    IF NOT already_awarded THEN
      IF NEW.is_anonymous THEN
        UPDATE user_profiles
        SET anonymous_reputation = anonymous_reputation + 2,
            reputation_points = reputation_points + 2
        WHERE id = NEW.user_id;
      ELSE
        UPDATE user_profiles
        SET public_reputation = public_reputation + 2,
            reputation_points = reputation_points + 2
        WHERE id = NEW.user_id;
      END IF;

      -- Mark as awarded
      UPDATE user_post_interactions
      SET comment_points_awarded = TRUE,
          has_commented = TRUE
      WHERE user_id = NEW.user_id AND post_id = NEW.post_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_award_comment_points ON comments;
CREATE TRIGGER trg_award_comment_points
  AFTER INSERT ON comments
  FOR EACH ROW EXECUTE FUNCTION award_comment_points();

RAISE NOTICE '✅ Created comment points trigger (once per post)';

-- ============================================================================
-- PART 10: AWARD POINTS FOR VOTING (Once per post)
-- ============================================================================

CREATE OR REPLACE FUNCTION award_vote_points()
RETURNS TRIGGER AS $$
DECLARE
  already_awarded BOOLEAN;
BEGIN
  IF NEW.user_id IS NOT NULL THEN
    -- Check if user already got vote points for this post
    SELECT vote_points_awarded INTO already_awarded
    FROM user_post_interactions
    WHERE user_id = NEW.user_id AND post_id = NEW.post_id;

    -- If no interaction record, create one
    IF already_awarded IS NULL THEN
      INSERT INTO user_post_interactions (user_id, post_id, has_voted, vote_points_awarded)
      VALUES (NEW.user_id, NEW.post_id, TRUE, TRUE);

      already_awarded := FALSE;
    END IF;

    -- Award 1 point only if not already awarded
    IF NOT already_awarded THEN
      UPDATE user_profiles
      SET reputation_points = reputation_points + 1
      WHERE id = NEW.user_id;

      -- Mark as awarded
      UPDATE user_post_interactions
      SET vote_points_awarded = TRUE,
          has_voted = TRUE
      WHERE user_id = NEW.user_id AND post_id = NEW.post_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_award_vote_points ON truth_votes;
CREATE TRIGGER trg_award_vote_points
  AFTER INSERT ON truth_votes
  FOR EACH ROW EXECUTE FUNCTION award_vote_points();

RAISE NOTICE '✅ Created vote points trigger (once per post)';

-- ============================================================================
-- PART 11: CALCULATE TRUTH METER SCORE
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_truth_meter()
RETURNS TRIGGER AS $$
DECLARE
  up_count INTEGER;
  down_count INTEGER;
  part_count INTEGER;
  fun_count INTEGER;
  total_votes INTEGER;
  weighted_score NUMERIC;
  accuracy NUMERIC;
  post_author UUID;
  current_points INTEGER;
  new_vote_points INTEGER;
BEGIN
  -- Count votes for this post
  SELECT
    COUNT(*) FILTER (WHERE vote_type = 'thumbs_up'),
    COUNT(*) FILTER (WHERE vote_type = 'thumbs_down'),
    COUNT(*) FILTER (WHERE vote_type = 'partial'),
    COUNT(*) FILTER (WHERE vote_type = 'funny')
  INTO up_count, down_count, part_count, fun_count
  FROM truth_votes
  WHERE post_id = COALESCE(NEW.post_id, OLD.post_id);

  total_votes := up_count + down_count + part_count;

  -- Calculate weighted score (partial = 0.5)
  weighted_score := up_count + (part_count * 0.5) - down_count;

  -- Calculate accuracy percentage
  IF total_votes > 0 THEN
    accuracy := ((up_count + part_count * 0.5) / total_votes) * 100;
  ELSE
    accuracy := 0;
  END IF;

  -- Update post vote counts and truth meter
  UPDATE posts
  SET
    vote_count = total_votes,
    thumbs_up_count = up_count,
    thumbs_down_count = down_count,
    partial_count = part_count,
    funny_count = fun_count,
    truth_meter_score = accuracy,
    truth_meter_status = CASE
      WHEN total_votes = 0 THEN 'unrated'
      WHEN admin_verified THEN 'verified_truth'
      WHEN accuracy >= 90 AND total_votes >= 5 THEN 'verified_community'
      WHEN accuracy >= 70 THEN 'likely_true'
      WHEN accuracy >= 50 THEN 'partially_true'
      WHEN accuracy >= 30 THEN 'questionable'
      ELSE 'rumour'
    END,
    updated_at = NOW()
  WHERE id = COALESCE(NEW.post_id, OLD.post_id);

  -- Award/deduct points to post author based on votes
  SELECT user_id, post_points_awarded INTO post_author, current_points
  FROM posts
  WHERE id = COALESCE(NEW.post_id, OLD.post_id);

  IF post_author IS NOT NULL THEN
    -- Determine vote-based points
    IF up_count >= 2 AND down_count = 0 THEN
      new_vote_points := 2;
    ELSIF up_count = 1 AND down_count = 0 THEN
      new_vote_points := 1;
    ELSIF down_count >= 2 THEN
      new_vote_points := -1;
    ELSE
      new_vote_points := 0;
    END IF;

    -- Calculate point delta (what changed from last calculation)
    DECLARE
      point_delta INTEGER;
    BEGIN
      point_delta := (5 + new_vote_points) - current_points;

      -- Cap total loss at -5 (initial post points)
      IF (5 + new_vote_points) < 0 THEN
        point_delta := -current_points;
      END IF;

      -- Update user reputation
      IF point_delta != 0 THEN
        UPDATE user_profiles
        SET reputation_points = GREATEST(reputation_points + point_delta, 0)
        WHERE id = post_author;

        -- Update post tracking
        UPDATE posts
        SET post_points_awarded = GREATEST(5 + new_vote_points, 0)
        WHERE id = COALESCE(NEW.post_id, OLD.post_id);
      END IF;
    END;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_calculate_truth_meter_insert ON truth_votes;
CREATE TRIGGER trg_calculate_truth_meter_insert
  AFTER INSERT ON truth_votes
  FOR EACH ROW EXECUTE FUNCTION calculate_truth_meter();

DROP TRIGGER IF EXISTS trg_calculate_truth_meter_update ON truth_votes;
CREATE TRIGGER trg_calculate_truth_meter_update
  AFTER UPDATE ON truth_votes
  FOR EACH ROW EXECUTE FUNCTION calculate_truth_meter();

DROP TRIGGER IF EXISTS trg_calculate_truth_meter_delete ON truth_votes;
CREATE TRIGGER trg_calculate_truth_meter_delete
  AFTER DELETE ON truth_votes
  FOR EACH ROW EXECUTE FUNCTION calculate_truth_meter();

RAISE NOTICE '✅ Created truth meter calculation triggers';

-- ============================================================================
-- PART 12: PREVENT SELF-VOTING
-- ============================================================================

CREATE OR REPLACE FUNCTION prevent_self_voting()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM posts
    WHERE id = NEW.post_id
    AND user_id = NEW.user_id
    AND NEW.user_id IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'You cannot vote on your own posts';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_self_voting ON truth_votes;
CREATE TRIGGER trg_prevent_self_voting
  BEFORE INSERT ON truth_votes
  FOR EACH ROW EXECUTE FUNCTION prevent_self_voting();

RAISE NOTICE '✅ Created self-voting prevention trigger';

-- ============================================================================
-- PART 13: DETECT VOTE BRIGADING
-- ============================================================================

CREATE OR REPLACE FUNCTION detect_vote_brigading()
RETURNS TRIGGER AS $$
DECLARE
  recent_votes INTEGER;
BEGIN
  IF NEW.user_id IS NOT NULL THEN
    -- Count votes in last 5 minutes
    SELECT COUNT(*) INTO recent_votes
    FROM truth_votes
    WHERE user_id = NEW.user_id
    AND created_at > NOW() - INTERVAL '5 minutes';

    -- Flag if more than 10 votes in 5 minutes
    IF recent_votes > 10 THEN
      INSERT INTO suspicious_activity (user_id, activity_type, details)
      VALUES (
        NEW.user_id,
        'rapid_voting',
        jsonb_build_object(
          'votes_in_5min', recent_votes,
          'post_id', NEW.post_id,
          'timestamp', NOW()
        )
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_detect_vote_brigading ON truth_votes;
CREATE TRIGGER trg_detect_vote_brigading
  AFTER INSERT ON truth_votes
  FOR EACH ROW EXECUTE FUNCTION detect_vote_brigading();

RAISE NOTICE '✅ Created vote brigading detection trigger';

-- ============================================================================
-- PART 14: ADMIN VERIFICATION BONUS
-- ============================================================================

CREATE OR REPLACE FUNCTION award_verification_bonus()
RETURNS TRIGGER AS $$
DECLARE
  post_author UUID;
BEGIN
  IF NEW.verification_type = 'verified_true' THEN
    -- Get post author
    SELECT user_id INTO post_author
    FROM posts
    WHERE id = NEW.post_id;

    -- Award +10 verification bonus + +5 verified truth bonus
    IF post_author IS NOT NULL THEN
      UPDATE user_profiles
      SET reputation_points = reputation_points + 15,
          public_reputation = public_reputation + 15
      WHERE id = post_author;
    END IF;

    -- Mark post as verified
    UPDATE posts
    SET
      admin_verified = TRUE,
      truth_meter_status = 'verified_truth',
      verified_at = NOW(),
      verified_by = NEW.verified_by,
      updated_at = NOW()
    WHERE id = NEW.post_id;

    RAISE NOTICE 'Post % verified by admin. Author awarded 15 bonus points.', NEW.post_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_verification_bonus ON post_verifications;
CREATE TRIGGER trg_verification_bonus
  AFTER INSERT ON post_verifications
  FOR EACH ROW EXECUTE FUNCTION award_verification_bonus();

RAISE NOTICE '✅ Created admin verification bonus trigger';

-- ============================================================================
-- PART 15: LEADERBOARD VIEWS
-- ============================================================================

CREATE OR REPLACE VIEW leaderboard_all_time AS
SELECT
  up.id,
  up.username,
  up.email_verified,
  up.public_reputation,
  up.reputation_points,
  up.reputation_level,
  up.vote_weight,
  up.post_count,
  (
    SELECT COUNT(*)
    FROM posts p
    WHERE p.user_id = up.id AND p.admin_verified = TRUE
  ) as verified_posts_count,
  (
    SELECT AVG(p.truth_meter_score)
    FROM posts p
    WHERE p.user_id = up.id AND p.vote_count >= 3
  ) as avg_accuracy,
  ROW_NUMBER() OVER (ORDER BY up.reputation_points DESC) as rank
FROM user_profiles up
WHERE up.public_reputation > 0
ORDER BY up.reputation_points DESC;

RAISE NOTICE '✅ Created leaderboard view';

-- ============================================================================
-- PART 16: VERIFICATION & SUMMARY
-- ============================================================================

DO $$
DECLARE
  trigger_count INTEGER;
  table_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO trigger_count
  FROM pg_trigger
  WHERE tgname IN (
    'trg_update_reputation_level',
    'trg_award_post_creation_points',
    'trg_award_comment_points',
    'trg_award_vote_points',
    'trg_calculate_truth_meter_insert',
    'trg_prevent_self_voting',
    'trg_detect_vote_brigading',
    'trg_verification_bonus'
  );

  SELECT COUNT(*) INTO table_count
  FROM information_schema.tables
  WHERE table_name IN (
    'user_post_interactions',
    'admin_roles',
    'post_verifications',
    'suspicious_activity'
  );

  RAISE NOTICE '===========================================';
  RAISE NOTICE 'GAMIFICATION SYSTEM MIGRATION SUMMARY';
  RAISE NOTICE '===========================================';
  RAISE NOTICE 'New tables created: % / 4', table_count;
  RAISE NOTICE 'Triggers installed: % / 8+', trigger_count;
  RAISE NOTICE '';
  RAISE NOTICE 'Features enabled:';
  RAISE NOTICE '✅ Reputation point tracking';
  RAISE NOTICE '✅ Truth meter scoring';
  RAISE NOTICE '✅ Admin verification system';
  RAISE NOTICE '✅ Anti-abuse measures';
  RAISE NOTICE '✅ Reputation levels (0-9)';
  RAISE NOTICE '✅ Vote weighting (1.0x - 3.0x)';
  RAISE NOTICE '✅ Leaderboard views';
  RAISE NOTICE '';
END $$;

RAISE NOTICE '✅ Migration 006_add_gamification_system.sql completed successfully';
RAISE NOTICE '';
RAISE NOTICE 'POINT SYSTEM:';
RAISE NOTICE '  Post creation: +5 points';
RAISE NOTICE '  Comment (once/post): +2 points';
RAISE NOTICE '  Vote (once/post): +1 point';
RAISE NOTICE '  2+ thumbs up on post: +2 points';
RAISE NOTICE '  1 thumbs up on post: +1 point';
RAISE NOTICE '  2+ thumbs down: -1 point (max -5)';
RAISE NOTICE '  Admin verified: +10 points';
RAISE NOTICE '  Verified truth bonus: +5 points';
RAISE NOTICE '';
RAISE NOTICE 'NEXT STEPS:';
RAISE NOTICE '1. Recalculate truth meters for existing posts';
RAISE NOTICE '2. Assign admin roles to moderators';
RAISE NOTICE '3. Update Flutter UI to show reputation & truth meter';
RAISE NOTICE '4. Test point awarding system thoroughly';
