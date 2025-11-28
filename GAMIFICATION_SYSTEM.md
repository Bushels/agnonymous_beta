# Gamification & Reputation System Design

## 🎮 System Overview

Transform Agnonymous into a **reputation-driven truth platform** where users build credibility through accurate reporting, even while posting anonymously. The system rewards quality contributions and discourages misinformation through a sophisticated point-based gamification system.

---

## 🎯 Core Principles

1. **Anonymous Reputation Building** - Points accumulate privately even for anonymous posts
2. **Quality Over Quantity** - Rewards accuracy, not spam
3. **Community Validation** - Collective voting determines credibility
4. **Anti-Abuse Protection** - Sophisticated measures prevent gaming
5. **Transparency** - Clear rules, visible scoring

---

## 📊 Point System Design

### **Earning Points**

| Action | Points | Max Per Post | Notes |
|--------|--------|--------------|-------|
| **Create Post** | +5 | 5 | Immediate reward for contribution |
| **Comment on Post** | +2 | 2 | Once per post, not per reply |
| **Vote on Post** | +1 | 1 | Participation reward |
| **Post Gets 2+ Thumbs Up** | +2 | Variable | Community validates accuracy |
| **Post Gets 1 Thumbs Up** | +1 | Variable | Partial validation |
| **Post Gets 1 Thumbs Down** | 0 | 0 | Neutral - no penalty yet |
| **Post Gets 2+ Thumbs Down** | -1 | -5 | Lose 1 point (max -5 total) |
| **Admin Verifies Post** | +10 | 10 | Truth confirmed |
| **Post Marked as Verified Truth** | +5 | 5 | One-time bonus |

**Maximum Loss Per Post:** -5 points (you can lose your initial 5 points, but not more)

**Maximum Gain Per Post Interaction (excluding your own post):** 3 points (1 vote + 2 comment)

---

## 🎲 Vote-to-Points Calculation Algorithm

### **Current Vote Types:**
- `thumbs_up` - True/Accurate
- `partial` - Partially true
- `thumbs_down` - False/Inaccurate
- `funny` - Humorous (doesn't affect score)

### **Post Score Calculation:**

```javascript
// Calculate net score based on vote distribution
function calculatePostScore(votes) {
  const thumbsUp = votes.filter(v => v.type === 'thumbs_up').length;
  const partial = votes.filter(v => v.type === 'partial').length;
  const thumbsDown = votes.filter(v => v.type === 'thumbs_down').length;
  const funny = votes.filter(v => v.type === 'funny').length;

  // Weighted score (partial counts as 0.5)
  const totalScore = thumbsUp + (partial * 0.5) - thumbsDown;
  const totalVotes = thumbsUp + partial + thumbsDown;

  if (totalVotes === 0) return { points: 0, status: 'unrated' };

  // Calculate percentage
  const accuracy = (thumbsUp + partial * 0.5) / totalVotes;

  // Determine points earned from votes
  let votePoints = 0;
  if (thumbsUp >= 2) {
    votePoints = 2;
  } else if (thumbsUp === 1 && thumbsDown === 0) {
    votePoints = 1;
  } else if (thumbsDown >= 2) {
    votePoints = -1;
  }

  // Cap losses at -5 (initial post points)
  const finalPoints = Math.max(votePoints, -5);

  return {
    points: finalPoints,
    totalScore: totalScore,
    accuracy: accuracy,
    status: determineTruthMeterStatus(accuracy, totalVotes)
  };
}
```

---

## 🌡️ Truth Meter / Rumour Mill System

### **Visual Status Indicators**

Based on vote accuracy percentage and total vote count:

| Status | Accuracy | Min Votes | Color | Icon | Description |
|--------|----------|-----------|-------|------|-------------|
| **Unrated** | N/A | 0 | Gray | ❓ | No votes yet |
| **Rumour** | < 30% | 3+ | Red | 🚨 | Likely false |
| **Questionable** | 30-49% | 3+ | Orange | ⚠️ | Mixed signals |
| **Partially True** | 50-69% | 3+ | Yellow | 🟡 | Some truth |
| **Likely True** | 70-89% | 3+ | Light Green | ✓ | Probably accurate |
| **Verified by Community** | 90%+ | 5+ | Green | ✓✓ | Highly credible |
| **Verified Truth** | Admin | N/A | Blue | 🛡️ | Admin confirmed |

### **Visual Design:**

```
┌─────────────────────────────────────┐
│ 🛡️ VERIFIED TRUTH                  │  ← Admin verified
│ @farmer_john ✅ Verified            │
│ "Factory farm caught dumping..."    │
│ Truth Meter: ████████████ 95%      │
│ 45 👍  2 🟡  1 👎  (48 votes)      │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ ✓✓ LIKELY TRUE                      │  ← Community verified
│ 🎭 Anonymous                        │
│ "Witnessed price fixing at..."      │
│ Truth Meter: ████████░░ 85%        │
│ 12 👍  3 🟡  2 👎  (17 votes)      │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ ⚠️ QUESTIONABLE                     │  ← Mixed reviews
│ @newuser ⚠️ Unverified              │
│ "Heard rumors about..."             │
│ Truth Meter: ████░░░░░░ 45%        │
│ 3 👍  2 🟡  4 👎  (9 votes)        │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ 🚨 LIKELY FALSE                     │  ← Community flagged
│ 🎭 Anonymous                        │
│ "Conspiracy theory about..."        │
│ Truth Meter: ██░░░░░░░░ 15%        │
│ 1 👍  0 🟡  8 👎  (9 votes)        │
└─────────────────────────────────────┘
```

---

## 🏆 Reputation Levels & Badges

### **Reputation Tiers**

| Level | Points Required | Badge | Title | Perks |
|-------|----------------|-------|-------|-------|
| 0 | 0-49 | 🌱 | **Seedling** | Basic posting |
| 1 | 50-149 | 🌿 | **Sprout** | - |
| 2 | 150-299 | 🌾 | **Growing** | Vote weight: 1.1x |
| 3 | 300-499 | 🌳 | **Established** | Vote weight: 1.2x |
| 4 | 500-749 | ⭐ | **Reliable Source** | Vote weight: 1.3x |
| 5 | 750-999 | ⭐⭐ | **Trusted Reporter** | Vote weight: 1.5x, Can nominate posts for admin review |
| 6 | 1000-1499 | ⭐⭐⭐ | **Expert Whistleblower** | Vote weight: 1.7x, Can see partial voter stats |
| 7 | 1500-2499 | 🏅 | **Truth Guardian** | Vote weight: 2x, Can request admin verification |
| 8 | 2500-4999 | 🏅🏅 | **Master Investigator** | Vote weight: 2.5x, Eligible for moderator role |
| 9 | 5000+ | 👑 | **Legend** | Vote weight: 3x, Special badge, Leaderboard top tier |

### **Vote Weight System**

Higher reputation = more influential votes:

```javascript
function calculateVoteWeight(userReputation) {
  if (userReputation < 150) return 1.0;
  if (userReputation < 300) return 1.1;
  if (userReputation < 500) return 1.2;
  if (userReputation < 750) return 1.3;
  if (userReputation < 1000) return 1.5;
  if (userReputation < 1500) return 1.7;
  if (userReputation < 2500) return 2.0;
  if (userReputation < 5000) return 2.5;
  return 3.0; // Legend
}
```

**Why Vote Weighting?**
- Incentivizes building reputation
- Makes experienced users more influential
- Self-regulating: bad actors lose reputation, lose influence
- Protects against vote manipulation from new accounts

---

## 🛡️ Anti-Abuse Measures

### **1. Vote Manipulation Prevention**

```sql
-- Prevent users from voting on their own posts
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

CREATE TRIGGER trg_prevent_self_voting
  BEFORE INSERT ON truth_votes
  FOR EACH ROW EXECUTE FUNCTION prevent_self_voting();
```

### **2. Duplicate Account Detection**

```sql
-- Track suspicious activity
CREATE TABLE suspicious_activity (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES user_profiles(id),
  activity_type TEXT,
  details JSONB,
  ip_address TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Flag potential vote brigading
CREATE OR REPLACE FUNCTION detect_vote_brigading()
RETURNS TRIGGER AS $$
DECLARE
  recent_votes INTEGER;
BEGIN
  -- Check if user voted on 10+ posts in last 5 minutes
  SELECT COUNT(*) INTO recent_votes
  FROM truth_votes
  WHERE user_id = NEW.user_id
  AND created_at > NOW() - INTERVAL '5 minutes';

  IF recent_votes > 10 THEN
    INSERT INTO suspicious_activity (user_id, activity_type, details)
    VALUES (
      NEW.user_id,
      'rapid_voting',
      jsonb_build_object('votes_in_5min', recent_votes, 'post_id', NEW.post_id)
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### **3. Comment Points Limit**

Only award comment points ONCE per user per post:

```sql
-- Track which posts user has commented on for points
CREATE TABLE user_post_interactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  has_commented BOOLEAN DEFAULT FALSE,
  has_voted BOOLEAN DEFAULT FALSE,
  comment_points_awarded BOOLEAN DEFAULT FALSE,
  vote_points_awarded BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, post_id)
);

-- Award comment points only once per post
CREATE OR REPLACE FUNCTION award_comment_points()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.user_id IS NOT NULL THEN
    -- Check if this is first comment on this post
    INSERT INTO user_post_interactions (user_id, post_id, has_commented, comment_points_awarded)
    VALUES (NEW.user_id, NEW.post_id, TRUE, FALSE)
    ON CONFLICT (user_id, post_id) DO UPDATE
    SET has_commented = TRUE;

    -- Award points only if not already awarded
    IF NOT (
      SELECT comment_points_awarded
      FROM user_post_interactions
      WHERE user_id = NEW.user_id AND post_id = NEW.post_id
    ) THEN
      UPDATE user_profiles
      SET reputation_points = reputation_points + 2,
          updated_at = NOW()
      WHERE id = NEW.user_id;

      UPDATE user_post_interactions
      SET comment_points_awarded = TRUE
      WHERE user_id = NEW.user_id AND post_id = NEW.post_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### **4. Time Decay for Old Posts**

Older posts give reduced points to prevent necro-posting spam:

```javascript
function calculateTimeDecay(postAge) {
  const daysOld = postAge / (1000 * 60 * 60 * 24);

  if (daysOld < 7) return 1.0;      // Full points (1 week)
  if (daysOld < 30) return 0.75;    // 75% (1 month)
  if (daysOld < 90) return 0.5;     // 50% (3 months)
  if (daysOld < 365) return 0.25;   // 25% (1 year)
  return 0.1;                        // 10% (over 1 year)
}
```

### **5. Reputation Loss Limits**

```sql
-- Prevent reputation from going negative
CREATE OR REPLACE FUNCTION enforce_reputation_floor()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.reputation_points < 0 THEN
    NEW.reputation_points = 0;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_reputation_floor
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION enforce_reputation_floor();
```

---

## 👨‍💼 Admin Verification System

### **Admin Roles**

```sql
CREATE TABLE admin_roles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('moderator', 'admin', 'super_admin')),
  granted_by UUID REFERENCES user_profiles(id),
  granted_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, role)
);

-- Admin permissions
-- moderator: Can verify posts, remove spam
-- admin: Can grant moderator role, ban users
-- super_admin: Full control
```

### **Post Verification**

```sql
CREATE TABLE post_verifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  verified_by UUID REFERENCES user_profiles(id),
  verification_type TEXT CHECK (verification_type IN ('verified_true', 'verified_false', 'needs_investigation')),
  verification_notes TEXT,
  evidence_links TEXT[],
  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(post_id)
);

-- Award bonus points when admin verifies post as true
CREATE OR REPLACE FUNCTION award_verification_bonus()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.verification_type = 'verified_true' THEN
    -- Award +10 points to post author
    UPDATE user_profiles
    SET reputation_points = reputation_points + 10
    WHERE id = (SELECT user_id FROM posts WHERE id = NEW.post_id)
    AND (SELECT user_id FROM posts WHERE id = NEW.post_id) IS NOT NULL;

    -- Mark post as verified
    UPDATE posts
    SET admin_verified = TRUE,
        truth_meter_status = 'verified_truth',
        updated_at = NOW()
    WHERE id = NEW.post_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_verification_bonus
  AFTER INSERT ON post_verifications
  FOR EACH ROW EXECUTE FUNCTION award_verification_bonus();
```

---

## 💰 Anonymous Reputation Tracking

### **Public vs Private Reputation**

```sql
ALTER TABLE user_profiles
  ADD COLUMN reputation_points INTEGER DEFAULT 0,
  ADD COLUMN public_reputation INTEGER DEFAULT 0,
  ADD COLUMN anonymous_reputation INTEGER DEFAULT 0;

-- Track reputation separately
-- reputation_points = total (public + anonymous)
-- public_reputation = from non-anonymous posts/comments
-- anonymous_reputation = from anonymous contributions

-- When user posts anonymously
CREATE OR REPLACE FUNCTION track_anonymous_contribution()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_anonymous = TRUE AND NEW.user_id IS NOT NULL THEN
    -- Points go to anonymous_reputation
    UPDATE user_profiles
    SET anonymous_reputation = anonymous_reputation + 5,
        reputation_points = reputation_points + 5
    WHERE id = NEW.user_id;
  ELSIF NEW.is_anonymous = FALSE AND NEW.user_id IS NOT NULL THEN
    -- Points go to public_reputation
    UPDATE user_profiles
    SET public_reputation = public_reputation + 5,
        reputation_points = reputation_points + 5
    WHERE id = NEW.user_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

**Why Separate Tracking?**
- Users can build reputation privately (anonymous posts)
- Total reputation determines perks (vote weight, badges)
- Public reputation is displayed on profile
- Anonymous reputation is private (only user sees it)

**Display Logic:**
```
User Profile:
┌─────────────────────────────────────┐
│ @farmer_john ✅ Verified            │
│ ⭐⭐ Trusted Reporter               │
│                                     │
│ Public Reputation: 450 points       │
│ Anonymous Contributions: 🔒 Private │
│ Total Level: 4 (Reliable Source)    │
└─────────────────────────────────────┘
```

---

## 📈 Leaderboard System

### **Leaderboard Types**

1. **Top Contributors (All Time)**
   - Ranked by total reputation_points
   - Shows public_reputation only
   - Top 100 displayed

2. **Most Verified Posts**
   - Users with most admin-verified posts
   - Ranked by verification count

3. **Most Accurate Reporters**
   - Highest average truth meter score
   - Minimum 10 posts to qualify

4. **This Month's Heroes**
   - Points earned in last 30 days
   - Resets monthly

```sql
-- Leaderboard view
CREATE OR REPLACE VIEW leaderboard_all_time AS
SELECT
  up.id,
  up.username,
  up.email_verified,
  up.public_reputation,
  up.reputation_points,
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
  ) as avg_accuracy
FROM user_profiles up
WHERE up.public_reputation > 0
ORDER BY up.reputation_points DESC
LIMIT 100;
```

---

## 🎮 Gamification UI Elements

### **User Profile Stats**

```
┌─────────────────────────────────────┐
│ @farmer_john ✅ Verified            │
│ ⭐⭐ Trusted Reporter (Level 5)     │
│                                     │
│ 📊 Reputation: 756 points           │
│ Progress to Expert: ████░░ 244 pts  │
│                                     │
│ 📝 Posts: 45 (12 verified)          │
│ 💬 Comments: 128                    │
│ 👍 Votes Cast: 234                  │
│                                     │
│ 🎯 Truth Rate: 87% (Highly Accurate)│
│ 🏆 Rank: #23 All Time               │
│                                     │
│ 🎖️ Achievements:                    │
│ ✓ First Verified Post               │
│ ✓ 100 Votes Cast                    │
│ ✓ 10 Verified Posts                 │
│ ✓ 500 Reputation                    │
└─────────────────────────────────────┘
```

### **Post Reputation Breakdown**

```
┌─────────────────────────────────────┐
│ Your Post: "Factory farm dumping"   │
├─────────────────────────────────────┤
│ Points Earned:                      │
│ + 5  Post created                   │
│ + 2  Community votes (85% accuracy) │
│ + 10 Admin verified                 │
│ + 5  Verified truth bonus           │
│ ─────────────────────────────────   │
│ = 22 Total Points                   │
│                                     │
│ Truth Meter: ████████░░ 85%        │
│ Status: 🛡️ VERIFIED TRUTH          │
└─────────────────────────────────────┘
```

---

## 🔢 Complete Point Calculation Example

**Scenario:** User creates a post about pesticide misuse

```
User: @farmer_john (Current reputation: 450 points)
Action: Create post about pesticide dumping

Timeline:
─────────────────────────────────────────
T+0min:  Post created
         +5 points (posting bonus)
         Reputation: 455

T+10min: 3 users vote thumbs up
         Truth meter: 100% (3/3)
         Status: "Likely True"
         No points yet (need 2 net thumbs up)

T+30min: 5 more thumbs up, 1 partial
         Truth meter: 94% (8.5/9)
         Vote score: +2 (has 2+ thumbs up)
         Reputation: 457

T+2hrs:  15 users comment (various threads)
         User @newuser comments on this post (first time)
         @newuser gets +2 points

T+1day:  20 thumbs up, 3 partial, 2 thumbs down
         Truth meter: 87% (21.5/25)
         Status: "Verified by Community"
         Vote score still: +2

T+3days: Admin reviews and marks "Verified True"
         +10 admin verification bonus
         +5 verified truth one-time bonus
         Reputation: 472 (5 + 2 + 10 + 5)

Final Points for This Post: +22
```

**Another User Interacting:**

```
User: @newuser (Current reputation: 25 points)

Actions on @farmer_john's post:
1. Votes thumbs up
   +1 point

2. Comments "I can confirm this"
   +2 points (first comment on this post)

3. Replies 5 times in same thread
   +0 points (already got comment bonus)

Total earned from this post: +3 points (max allowed)
New reputation: 28 points
```

---

## 🎯 Implementation Priority

### **Phase 1: Core Point System** (Week 1)
- [ ] Add reputation columns to user_profiles
- [ ] Create user_post_interactions table
- [ ] Implement post creation points (+5)
- [ ] Implement comment points (+2, once per post)
- [ ] Implement vote points (+1)

### **Phase 2: Vote-Based Scoring** (Week 2)
- [ ] Implement vote-to-points calculation
- [ ] Add truth_meter_score to posts
- [ ] Create automatic score recalculation trigger
- [ ] Add time decay logic

### **Phase 3: Truth Meter UI** (Week 3)
- [ ] Create truth meter visual component
- [ ] Display post credibility status
- [ ] Show vote breakdown
- [ ] Color-coded indicators

### **Phase 4: Reputation Levels** (Week 4)
- [ ] Implement level/badge system
- [ ] Create reputation level widget
- [ ] Add vote weighting based on reputation
- [ ] Display user level on posts/comments

### **Phase 5: Admin Verification** (Week 5)
- [ ] Create admin_roles table
- [ ] Create post_verifications table
- [ ] Build admin verification UI
- [ ] Implement verification bonus points

### **Phase 6: Anti-Abuse** (Week 6)
- [ ] Prevent self-voting
- [ ] Detect vote brigading
- [ ] Implement suspicious activity logging
- [ ] Add reputation floor (can't go negative)

### **Phase 7: Leaderboards** (Week 7)
- [ ] Create leaderboard views
- [ ] Build leaderboard UI
- [ ] Implement different leaderboard types
- [ ] Add user ranking display

---

## ✅ Success Metrics

After implementation, track:
- Average post truth meter score (target: >70%)
- % of posts that get verified (target: >10%)
- User retention (target: 40% return monthly)
- Vote participation rate (target: 50% of users vote)
- Top user reputation growth (target: 5+ users >1000 pts/month)

---

**Ready to implement?** This is a comprehensive system. Let me know if you want me to start building the database migrations and Flutter UI!
