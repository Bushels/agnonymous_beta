# Agnonymous - Implementation Roadmap

## Current State Assessment

### Completed (Working)
- Basic Flutter app structure
- Supabase connection and auth
- Post viewing with category filtering
- Real-time post updates
- Truth meter visualization
- Vote casting (thumbs up, partial, thumbs down, funny)
- Comment system
- User profile model with reputation levels
- Auth screens (login, signup, email verification)
- Glassmorphism UI components
- Province/state dropdown (complete list)

### Partially Complete
- Authentication flow (85%)
  - Missing: Forgot password
- Gamification database schema (70%)
  - Missing: Point awarding triggers
- Profile screen (50%)
  - Missing: Edit capability, full stats

### Not Started
- "Post as" toggle (anonymous vs username)
- Full gamification point system
- Input pricing feature
- Bottom navigation
- Notification system
- Ad integration

---

## Implementation Phases

## PHASE 1: Core Authentication Polish
**Priority: HIGH | Effort: Small**

### 1.1 Fix Signup Flow
- [x] Password confirmation field (already implemented!)
- [ ] Form validation improvements
- [ ] Better error messages
- [ ] Loading states

### 1.2 Forgot Password Flow
```dart
// New screen: lib/screens/auth/forgot_password_screen.dart
// - Email input
// - Send reset link via Supabase
// - Success message
// - Back to login link
```

### 1.3 Email Verification UX
- [ ] Clear indication of verification status
- [ ] Resend verification email button
- [ ] Deep link handling for verification URL

### 1.4 Auth State Persistence
- [ ] Remember me functionality
- [ ] Auto-login on app restart
- [ ] Session refresh handling

**Deliverables:**
- Forgot password screen
- Improved signup UX
- Email verification flow

---

## PHASE 2: Post-As Toggle & Identity System
**Priority: HIGH | Effort: Medium**

### 2.1 Database Updates
```sql
-- Posts already have: user_id, is_anonymous, author_username, author_verified
-- Just need to ensure proper handling
```

### 2.2 Create Post Screen Updates
```dart
// Add toggle at top of create post form:
//
// [How do you want to post?]
// [Anonymous Mode]  [Post as @username]
//
// Show warning: "Note: You only earn reputation points when posting with your username"
```

### 2.3 Post Display Updates
```dart
// PostCard should show:
// - Anonymous: Mask icon + "Anonymous"
// - Username: Username + verification badge

Widget buildAuthorSection() {
  if (post.isAnonymous) {
    return Row(children: [
      Icon(FontAwesomeIcons.userSecret),
      Text('Anonymous'),
    ]);
  } else {
    return Row(children: [
      Text('@${post.authorUsername}'),
      if (post.authorVerified) VerifiedBadge(),
      if (!post.authorVerified) UnverifiedBadge(),
    ]);
  }
}
```

### 2.4 Comment Identity
- Same toggle for comments
- Display author info consistently

**Deliverables:**
- Post-as toggle on create screen
- Author display on posts/comments
- Verification badges

---

## PHASE 3: Full Gamification System
**Priority: HIGH | Effort: Large**

### 3.1 Point Awarding Triggers (Database)

```sql
-- Award 5 points for creating a post (if not anonymous)
CREATE OR REPLACE FUNCTION award_post_points()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.user_id IS NOT NULL AND NEW.is_anonymous = FALSE THEN
    UPDATE user_profiles
    SET reputation_points = reputation_points + 5,
        public_reputation = public_reputation + 5,
        post_count = post_count + 1,
        updated_at = NOW()
    WHERE id = NEW.user_id;

    INSERT INTO reputation_logs (user_id, points_change, reason, related_post_id)
    VALUES (NEW.user_id, 5, 'post_created', NEW.id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Award 1 point for voting (once per user)
CREATE OR REPLACE FUNCTION award_vote_points()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.user_id IS NOT NULL THEN
    INSERT INTO user_post_interactions (user_id, post_id, has_voted, vote_points_awarded)
    VALUES (NEW.user_id, NEW.post_id, TRUE, FALSE)
    ON CONFLICT (user_id, post_id) DO NOTHING;

    IF NOT (SELECT vote_points_awarded FROM user_post_interactions
            WHERE user_id = NEW.user_id AND post_id = NEW.post_id) THEN
      UPDATE user_profiles
      SET reputation_points = reputation_points + 1,
          vote_count = vote_count + 1
      WHERE id = NEW.user_id;

      UPDATE user_post_interactions
      SET vote_points_awarded = TRUE
      WHERE user_id = NEW.user_id AND post_id = NEW.post_id;

      INSERT INTO reputation_logs (user_id, points_change, reason, related_post_id)
      VALUES (NEW.user_id, 1, 'vote_cast', NEW.post_id);
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Award 2 points for first comment on a post
CREATE OR REPLACE FUNCTION award_comment_points()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.user_id IS NOT NULL AND NEW.is_anonymous = FALSE THEN
    INSERT INTO user_post_interactions (user_id, post_id, has_commented)
    VALUES (NEW.user_id, NEW.post_id, TRUE)
    ON CONFLICT (user_id, post_id) DO NOTHING;

    IF NOT (SELECT comment_points_awarded FROM user_post_interactions
            WHERE user_id = NEW.user_id AND post_id = NEW.post_id) THEN
      UPDATE user_profiles
      SET reputation_points = reputation_points + 2,
          comment_count = comment_count + 1
      WHERE id = NEW.user_id;

      UPDATE user_post_interactions
      SET comment_points_awarded = TRUE
      WHERE user_id = NEW.user_id AND post_id = NEW.post_id;

      INSERT INTO reputation_logs (user_id, points_change, reason, related_post_id)
      VALUES (NEW.user_id, 2, 'comment_posted', NEW.post_id);
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### 3.2 Vote-Based Scoring for Post Authors

```sql
-- Recalculate post author's points based on vote changes
CREATE OR REPLACE FUNCTION update_post_vote_score()
RETURNS TRIGGER AS $$
DECLARE
  post_author UUID;
  is_anon BOOLEAN;
  net_positive INTEGER;
  current_bonus INTEGER;
  new_bonus INTEGER;
BEGIN
  SELECT user_id, is_anonymous INTO post_author, is_anon
  FROM posts WHERE id = COALESCE(NEW.post_id, OLD.post_id);

  IF post_author IS NOT NULL AND is_anon = FALSE THEN
    -- Calculate net positive votes
    SELECT (thumbs_up_count - thumbs_down_count) INTO net_positive
    FROM posts WHERE id = COALESCE(NEW.post_id, OLD.post_id);

    -- Determine point bonus/penalty (capped at -5 to +5)
    new_bonus := GREATEST(-5, LEAST(5, net_positive));

    -- Get current bonus stored (if any) - would need tracking
    -- For simplicity, just update based on current state

    -- Update user reputation
    -- Note: This is simplified - production needs proper tracking
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;
```

### 3.3 Vote Weight Implementation

```dart
// When casting vote, include user's vote weight
Future<void> _castVote(String voteType) async {
  final userProfile = ref.read(currentUserProfileProvider);
  final voteWeight = userProfile?.voteWeight ?? 1.0;

  await supabase.rpc('cast_user_vote', params: {
    'post_id_in': postId,
    'user_id_in': userId,
    'vote_type_in': voteType,
    'vote_weight_in': voteWeight,
  });
}
```

### 3.4 UI: Reputation Display

```dart
// Profile screen improvements:
// - Level badge with emoji
// - Progress bar to next level
// - Point breakdown (public vs anonymous)
// - Recent point history

// Post card improvements:
// - Author reputation badge
// - Vote weight indicator for high-rep users
```

### 3.5 Post Bumping by Reputation

```dart
// Sort posts with reputation weight
final sortedPosts = posts.sorted((a, b) {
  // Base score: recency
  final recencyScore = b.createdAt.compareTo(a.createdAt);

  // Boost: author reputation level
  final aBoost = a.isAnonymous ? 0 : (a.authorReputationLevel * 0.1);
  final bBoost = b.isAnonymous ? 0 : (b.authorReputationLevel * 0.1);

  // Boost: truth meter score
  final aTruth = a.truthMeterScore * 0.05;
  final bTruth = b.truthMeterScore * 0.05;

  // Combined score
  return recencyScore + ((bBoost + bTruth) - (aBoost + aTruth)).toInt();
});
```

**Deliverables:**
- Database triggers for all point actions
- Vote weight implementation
- Reputation display in UI
- Post sorting by reputation

---

## PHASE 4: Input Pricing System
**Priority: MEDIUM | Effort: Large**

See [INPUT_PRICING_SYSTEM.md](INPUT_PRICING_SYSTEM.md) for detailed specification.

### 4.1 Database Tables
- retailers
- products
- price_entries
- price_alerts

### 4.2 Screens
- Pricing home (tab)
- Add price flow
- Product search
- Retailer search/add
- Price history view

### 4.3 Key Features
- USD/CAD detection by location
- Duplicate retailer detection
- Price history charts
- Regional comparison view

**Deliverables:**
- Complete pricing database
- Add price flow
- View/search prices
- Price alerts

---

## PHASE 5: Bottom Navigation & UI Polish
**Priority: MEDIUM | Effort: Medium**

### 5.1 Bottom Navigation Bar

```dart
// New structure:
// [Home] [Prices] [+Post] [Alerts] [Profile]

class MainApp extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(),
          PricingScreen(),
          Container(), // Post is modal
          NotificationsScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: GlassBottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        items: [
          BottomNavItem(icon: FontAwesomeIcons.house, label: 'Home'),
          BottomNavItem(icon: FontAwesomeIcons.dollarSign, label: 'Prices'),
          BottomNavItem(icon: FontAwesomeIcons.plus, label: 'Post'),
          BottomNavItem(icon: FontAwesomeIcons.bell, label: 'Alerts'),
          BottomNavItem(icon: FontAwesomeIcons.user, label: 'Profile'),
        ],
      ),
    );
  }
}
```

### 5.2 Glassmorphism Polish
- Consistent blur/opacity values
- Animated transitions
- Subtle shadows
- Green accent color (#84CC16)

### 5.3 Animation Improvements
- Truth meter bar animation
- Badge unlock celebration
- Pull-to-refresh feedback
- Vote button feedback

**Deliverables:**
- Bottom navigation bar
- Consistent glassmorphism
- Polished animations

---

## PHASE 6: Notification System
**Priority: MEDIUM | Effort: Medium**

### 6.1 Notification Preferences Screen
```dart
// Settings for:
// - Location alerts (select provinces)
// - Category alerts (select categories)
// - Keyword alerts (add keywords)
// - Price alerts (managed in pricing)
// - Reply notifications
```

### 6.2 Database Setup
```sql
-- Notification tables already designed
-- Need notification delivery function

CREATE OR REPLACE FUNCTION create_notification(
  user_id_in UUID,
  type_in TEXT,
  title_in TEXT,
  body_in TEXT,
  data_in JSONB DEFAULT NULL
)
RETURNS void AS $$
BEGIN
  INSERT INTO notifications (user_id, notification_type, title, body, data)
  VALUES (user_id_in, type_in, title_in, body_in, data_in);
END;
$$ LANGUAGE plpgsql;
```

### 6.3 Notification Screen
- List of notifications
- Mark as read
- Deep linking to content
- Clear all option

### 6.4 Push Notifications (Future)
- Firebase Cloud Messaging integration
- Token storage
- Notification scheduling

**Deliverables:**
- Notification preferences
- In-app notifications
- Deep linking

---

## PHASE 7: Categories & Smart Tagging
**Priority: LOW | Effort: Medium**

### 7.1 Recurring Theme Detection
```sql
-- Track frequently mentioned entities
CREATE TABLE entity_mentions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_name TEXT NOT NULL,
  entity_type TEXT, -- company, location, product, person
  post_id UUID REFERENCES posts(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- View for trending entities
CREATE VIEW trending_entities AS
SELECT entity_name, entity_type, COUNT(*) as mention_count
FROM entity_mentions
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY entity_name, entity_type
ORDER BY mention_count DESC
LIMIT 20;
```

### 7.2 AI Integration (OpenRouter)
```dart
// Auto-suggest category based on content
Future<String> suggestCategory(String title, String content) async {
  final response = await openRouter.chat(
    model: 'openai/gpt-4-turbo',
    messages: [
      Message(role: 'system', content: '''
        Analyze this agricultural post and suggest the best category.
        Categories: Farming, Livestock, Ranching, Crops, Markets, Weather,
        Chemicals, Equipment, Politics, General, Other.
        Return only the category name.
      '''),
      Message(role: 'user', content: 'Title: $title\n\nContent: $content'),
    ],
  );
  return response.choices[0].message.content;
}
```

### 7.3 Entity Extraction
```dart
// Extract company names, locations, products mentioned
Future<List<Entity>> extractEntities(String text) async {
  // Use AI to identify entities
  // Store in entity_mentions table
  // Enable "trending topics" feature
}
```

**Deliverables:**
- Entity extraction on post creation
- Trending entities view
- AI category suggestion

---

## PHASE 8: Monetization
**Priority: LOW | Effort: Small**

### 8.1 Google AdSense (Web)
```html
<!-- web/index.html -->
<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-XXXXX"
     crossorigin="anonymous"></script>
```

### 8.2 Google AdMob (Mobile)
```dart
// pubspec.yaml
// google_mobile_ads: ^5.x.x

// Initialize in main.dart
MobileAds.instance.initialize();

// Banner between posts
class AdBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AdWidget(ad: _bannerAd);
  }
}
```

### 8.3 Ad Placement Strategy
- Banner after every 5th post
- No ads for users > 500 reputation?
- Interstitial after posting (skip option)

**Deliverables:**
- AdSense integration (web)
- AdMob integration (mobile)
- Non-intrusive placement

---

## Phase Summary

| Phase | Priority | Effort | Dependencies |
|-------|----------|--------|--------------|
| 1. Auth Polish | HIGH | Small | None |
| 2. Post-As Toggle | HIGH | Medium | Phase 1 |
| 3. Gamification | HIGH | Large | Phase 2 |
| 4. Input Pricing | MEDIUM | Large | None |
| 5. Bottom Nav | MEDIUM | Medium | None |
| 6. Notifications | MEDIUM | Medium | Phase 5 |
| 7. Smart Tags | LOW | Medium | Phase 3 |
| 8. Monetization | LOW | Small | Phase 5 |

---

## Recommended Implementation Order

### Sprint 1: Foundation
1. Phase 1 (Auth Polish)
2. Phase 2 (Post-As Toggle)

### Sprint 2: Engagement
3. Phase 3 (Gamification)
4. Phase 5 (Bottom Nav)

### Sprint 3: Value-Add
5. Phase 4 (Input Pricing)
6. Phase 6 (Notifications)

### Sprint 4: Polish
7. Phase 7 (Smart Tags)
8. Phase 8 (Monetization)

---

## Success Criteria per Phase

### Phase 1 Complete When:
- User can reset password via email
- Clear verification status shown
- No auth-related console errors

### Phase 2 Complete When:
- Toggle visible on post creation
- Posts display correct author info
- Comments show author identity

### Phase 3 Complete When:
- Points awarded for all actions
- Leaderboard displays correctly
- Vote weights affect scoring
- Level-up triggers celebration

### Phase 4 Complete When:
- User can add price for product/retailer
- Price history viewable
- Regional comparison works
- Price alerts functional

### Phase 5 Complete When:
- Bottom nav navigates correctly
- Post button opens modal
- All screens accessible
- Consistent animation

### Phase 6 Complete When:
- User can set preferences
- Notifications appear in-app
- Deep linking works
- Mark as read functional

### Phase 7 Complete When:
- Entities extracted from posts
- Trending topics displayed
- Category suggestions offered

### Phase 8 Complete When:
- Ads display on web
- Ads display on mobile
- Non-intrusive experience
- Revenue tracking setup

---

*Document Version: 1.0*
*Last Updated: November 24, 2025*
