# Agnonymous - Technical Architecture

## Technology Stack

### Frontend
| Technology | Version | Purpose |
|------------|---------|---------|
| Flutter | 3.38.3 | Cross-platform UI framework |
| Dart | 3.10.1 | Programming language |
| flutter_riverpod | 3.0.3 | State management (Notifier pattern) |
| google_fonts | 6.3.2 | Typography |
| font_awesome_flutter | 10.12.0 | Icons |
| supabase_flutter | 2.10.3 | Backend client |
| intl | 0.20.2 | Internationalization/formatting |
| flutter_dotenv | 6.0.0 | Environment configuration |
| logger | 2.0.2 | Logging utility |
| html_unescape | 2.0.0 | XSS prevention |

### Backend
| Technology | Purpose |
|------------|---------|
| Supabase | Backend-as-a-Service |
| PostgreSQL | Primary database |
| Supabase Auth | Authentication |
| Supabase Realtime | Live subscriptions |
| Row-Level Security | Data access control |

### Infrastructure
| Service | Purpose |
|---------|---------|
| Firebase Hosting | Web deployment |
| GitHub | Source control |
| Supabase Cloud | Database hosting |

---

## Architecture Patterns

### State Management: Riverpod 3.x Notifier Pattern

We use the modern `Notifier` pattern (NOT deprecated `StateNotifier`):

```dart
// CORRECT pattern for this project
class MyNotifier extends Notifier<MyState> {
  @override
  MyState build() {
    // Initialize state
    ref.onDispose(() {
      // Cleanup subscriptions, etc.
    });
    return MyState();
  }

  void updateState() {
    state = state.copyWith(...);
  }
}

final myProvider = NotifierProvider<MyNotifier, MyState>(MyNotifier.new);
```

### Family Providers for Parameterized Queries

```dart
// Stream provider for comments on a specific post
final commentsProvider = StreamProvider.family<List<Comment>, String>((ref, postId) {
  return supabase
      .from('comments')
      .stream(primaryKey: ['id'])
      .eq('post_id', postId)
      .order('created_at')
      .map((list) => list.map((m) => Comment.fromMap(m)).toList());
});
```

### Real-time Subscriptions with Cleanup

```dart
// Inside a Notifier
@override
MyState build() {
  final channel = supabase
      .channel('my_channel')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'my_table',
        callback: (payload) => _handleUpdate(payload),
      )
      .subscribe();

  ref.onDispose(() {
    channel.unsubscribe();
  });

  return MyState();
}
```

---

## Database Schema

### Core Tables

```sql
-- User Profiles (linked to Supabase Auth)
CREATE TABLE user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE NOT NULL,
  email TEXT NOT NULL,
  email_verified BOOLEAN DEFAULT FALSE,
  province_state TEXT,
  bio TEXT,

  -- Reputation
  reputation_points INTEGER DEFAULT 0,
  public_reputation INTEGER DEFAULT 0,
  anonymous_reputation INTEGER DEFAULT 0,

  -- Statistics
  post_count INTEGER DEFAULT 0,
  comment_count INTEGER DEFAULT 0,
  vote_count INTEGER DEFAULT 0,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Posts
CREATE TABLE posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  category TEXT NOT NULL,
  province_state TEXT,

  -- User Association
  user_id UUID REFERENCES user_profiles(id),
  is_anonymous BOOLEAN DEFAULT TRUE,
  author_username TEXT,
  author_verified BOOLEAN DEFAULT FALSE,

  -- Vote Counts (denormalized for performance)
  vote_count INTEGER DEFAULT 0,
  comment_count INTEGER DEFAULT 0,
  thumbs_up_count INTEGER DEFAULT 0,
  thumbs_down_count INTEGER DEFAULT 0,
  partial_count INTEGER DEFAULT 0,
  funny_count INTEGER DEFAULT 0,

  -- Truth Meter
  truth_meter_score DOUBLE PRECISION DEFAULT 0.0,
  truth_meter_status TEXT DEFAULT 'unrated',
  admin_verified BOOLEAN DEFAULT FALSE,
  verified_at TIMESTAMPTZ,
  verified_by UUID REFERENCES user_profiles(id),

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Comments
CREATE TABLE comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  content TEXT NOT NULL,

  -- User Association
  user_id UUID REFERENCES user_profiles(id),
  is_anonymous BOOLEAN DEFAULT TRUE,
  author_username TEXT,
  author_verified BOOLEAN DEFAULT FALSE,

  -- Legacy (for existing anonymous comments)
  anonymous_user_id UUID,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Truth Votes
CREATE TABLE truth_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,

  -- User Association
  user_id UUID REFERENCES user_profiles(id),
  anonymous_user_id UUID,

  -- Vote Data
  vote_type TEXT NOT NULL CHECK (vote_type IN ('thumbs_up', 'partial', 'thumbs_down', 'funny')),
  vote_weight DOUBLE PRECISION DEFAULT 1.0,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Input Pricing Tables (NEW)

```sql
-- Retailers
CREATE TABLE retailers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  address TEXT,
  city TEXT NOT NULL,
  province_state TEXT NOT NULL,
  country TEXT NOT NULL DEFAULT 'Canada',
  postal_code TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,

  -- Metadata
  verified BOOLEAN DEFAULT FALSE,
  created_by UUID REFERENCES user_profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Prevent duplicates
  UNIQUE(name, city, province_state)
);

-- Products
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_type TEXT NOT NULL CHECK (product_type IN ('fertilizer', 'chemical', 'seed')),

  -- Product Info
  brand_name TEXT,
  product_name TEXT NOT NULL,
  formulation TEXT,
  is_proprietary BOOLEAN DEFAULT FALSE,

  -- Unit Info
  default_unit TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- Prevent duplicates
  UNIQUE(product_type, brand_name, product_name, formulation)
);

-- Price Entries
CREATE TABLE price_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  retailer_id UUID REFERENCES retailers(id) ON DELETE CASCADE,

  -- Price Data
  price DECIMAL(10,2) NOT NULL,
  unit TEXT NOT NULL,
  currency TEXT NOT NULL DEFAULT 'CAD',
  price_date DATE NOT NULL DEFAULT CURRENT_DATE,

  -- User who submitted
  user_id UUID REFERENCES user_profiles(id),
  is_anonymous BOOLEAN DEFAULT TRUE,

  -- Verification
  verified BOOLEAN DEFAULT FALSE,
  report_count INTEGER DEFAULT 0,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Price Alerts (Watchlist)
CREATE TABLE price_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  province_state TEXT,

  -- Alert Config
  alert_on_new_price BOOLEAN DEFAULT TRUE,
  alert_threshold DECIMAL(10,2), -- Alert if price below this

  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Gamification Tables

```sql
-- User Post Interactions (prevent point farming)
CREATE TABLE user_post_interactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,

  has_commented BOOLEAN DEFAULT FALSE,
  has_voted BOOLEAN DEFAULT FALSE,
  comment_points_awarded BOOLEAN DEFAULT FALSE,
  vote_points_awarded BOOLEAN DEFAULT FALSE,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, post_id)
);

-- Reputation Logs (audit trail)
CREATE TABLE reputation_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  points_change INTEGER NOT NULL,
  reason TEXT NOT NULL,
  related_post_id UUID REFERENCES posts(id),
  related_comment_id UUID REFERENCES comments(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Admin Roles
CREATE TABLE admin_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('moderator', 'admin', 'super_admin')),
  granted_by UUID REFERENCES user_profiles(id),
  granted_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, role)
);
```

### Notification Tables (NEW)

```sql
-- Notification Preferences
CREATE TABLE notification_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,

  -- Content Alerts
  province_state_alerts TEXT[], -- Array of provinces to watch
  category_alerts TEXT[], -- Array of categories to watch
  keyword_alerts TEXT[], -- Array of keywords to watch

  -- Price Alerts handled in price_alerts table

  -- Delivery Preferences
  email_notifications BOOLEAN DEFAULT TRUE,
  push_notifications BOOLEAN DEFAULT TRUE,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id)
);

-- Notification Queue
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,

  notification_type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT,
  data JSONB,

  read BOOLEAN DEFAULT FALSE,
  sent_at TIMESTAMPTZ DEFAULT NOW(),
  read_at TIMESTAMPTZ
);
```

---

## Row-Level Security Policies

```sql
-- User Profiles: Public read, self-update only
CREATE POLICY "Profiles viewable by everyone"
  ON user_profiles FOR SELECT USING (true);

CREATE POLICY "Users can update own profile"
  ON user_profiles FOR UPDATE USING (id = auth.uid());

-- Posts: Public read, authenticated create
CREATE POLICY "Posts viewable by everyone"
  ON posts FOR SELECT USING (true);

CREATE POLICY "Authenticated users can create posts"
  ON posts FOR INSERT TO authenticated
  WITH CHECK (auth.uid() IS NOT NULL);

-- Votes: Authenticated users only
CREATE POLICY "Authenticated users can vote"
  ON truth_votes FOR INSERT TO authenticated
  WITH CHECK (auth.uid() IS NOT NULL);

-- Price Entries: Public read, authenticated create
CREATE POLICY "Prices viewable by everyone"
  ON price_entries FOR SELECT USING (true);

CREATE POLICY "Authenticated users can add prices"
  ON price_entries FOR INSERT TO authenticated
  WITH CHECK (auth.uid() IS NOT NULL);
```

---

## File Structure

```
lib/
├── main.dart                    # App entry, theme, core providers
├── create_post_screen.dart      # Post creation
├── web_helper.dart              # Web-specific utilities
├── stub_web.dart                # Web stubs for platform detection
│
├── models/
│   ├── user_profile.dart        # User profile model + reputation logic
│   ├── admin_role.dart          # Admin role model
│   ├── product.dart             # Product model (NEW)
│   ├── retailer.dart            # Retailer model (NEW)
│   └── price_entry.dart         # Price entry model (NEW)
│
├── providers/
│   ├── auth_provider.dart       # Authentication state
│   ├── leaderboard_provider.dart # Leaderboard data
│   ├── pricing_provider.dart    # Input pricing state (NEW)
│   └── notification_provider.dart # Notifications state (NEW)
│
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   ├── signup_screen.dart
│   │   └── verify_email_screen.dart
│   ├── profile/
│   │   └── profile_screen.dart
│   ├── landing/
│   │   └── landing_screen.dart
│   ├── pricing/                 # (NEW)
│   │   ├── pricing_home_screen.dart
│   │   ├── add_price_screen.dart
│   │   ├── product_search_screen.dart
│   │   └── retailer_search_screen.dart
│   └── notifications/           # (NEW)
│       └── notifications_screen.dart
│
└── widgets/
    ├── glass_container.dart     # Glassmorphism container
    ├── truth_meter.dart         # Animated truth meter
    ├── user_badge.dart          # User verification badge
    ├── reputation_badge.dart    # Reputation level badge
    ├── trending_posts.dart      # Trending section
    ├── header_bar.dart          # App header
    ├── post_card.dart           # Post display (NEW - extract from main)
    ├── bottom_nav.dart          # Bottom navigation (NEW)
    └── price_card.dart          # Price display card (NEW)
```

---

## API / RPC Functions

### Existing Functions

```sql
-- Get vote statistics for a post
CREATE FUNCTION get_post_vote_stats(post_id_in UUID)
RETURNS TABLE (
  thumbs_up_votes INTEGER,
  partial_votes INTEGER,
  thumbs_down_votes INTEGER,
  funny_votes INTEGER
);

-- Get global statistics
CREATE FUNCTION get_global_stats()
RETURNS TABLE (
  total_posts INTEGER,
  total_votes INTEGER,
  total_comments INTEGER
);

-- Get trending stats
CREATE FUNCTION get_trending_stats()
RETURNS TABLE (
  trending_category TEXT,
  most_popular_post_title TEXT
);

-- Cast a vote (with upsert)
CREATE FUNCTION cast_user_vote(
  post_id_in UUID,
  user_id_in UUID,
  vote_type_in TEXT
);
```

### New Functions Needed

```sql
-- Search products
CREATE FUNCTION search_products(
  search_term TEXT,
  product_type TEXT DEFAULT NULL
)
RETURNS SETOF products;

-- Get price history for product
CREATE FUNCTION get_price_history(
  product_id_in UUID,
  province_state_in TEXT DEFAULT NULL,
  limit_count INTEGER DEFAULT 50
)
RETURNS TABLE (
  price DECIMAL,
  currency TEXT,
  price_date DATE,
  retailer_name TEXT,
  city TEXT
);

-- Get regional price comparison
CREATE FUNCTION get_regional_prices(
  product_id_in UUID
)
RETURNS TABLE (
  province_state TEXT,
  avg_price DECIMAL,
  min_price DECIMAL,
  max_price DECIMAL,
  entry_count INTEGER
);

-- Award reputation points (server-side)
CREATE FUNCTION award_reputation_points(
  user_id_in UUID,
  points INTEGER,
  reason TEXT,
  related_post_id UUID DEFAULT NULL
);
```

---

## Security Considerations

### Input Sanitization

```dart
/// Sanitize user input to prevent XSS attacks
String sanitizeInput(String input) {
  // Remove any HTML tags
  String sanitized = input.replaceAll(RegExp(r'<[^>]*>'), '');
  // Decode HTML entities
  sanitized = htmlUnescape.convert(sanitized);
  // Trim whitespace
  sanitized = sanitized.trim();
  return sanitized;
}
```

### Anonymous User Protection

1. **Never log** anonymous_user_id with identifying information
2. **No IP tracking** on post/comment creation
3. **Separate authentication** from anonymous posting
4. **RLS policies** prevent cross-user data access

### Rate Limiting

```sql
-- Detect rapid voting (anti-brigade)
CREATE FUNCTION detect_vote_brigading()
RETURNS TRIGGER AS $$
BEGIN
  IF (SELECT COUNT(*) FROM truth_votes
      WHERE user_id = NEW.user_id
      AND created_at > NOW() - INTERVAL '5 minutes') > 10 THEN
    INSERT INTO suspicious_activity (user_id, activity_type)
    VALUES (NEW.user_id, 'rapid_voting');
  END IF;
  RETURN NEW;
END;
$$;
```

---

## Environment Configuration

### Development (.env)

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

### Production (Firebase Hosting)

Environment variables injected via:
1. Flutter build arguments: `--dart-define=SUPABASE_URL=...`
2. Or `web/index.html` JavaScript injection

### Build Commands

```bash
# Development
flutter run -d chrome --web-port=5000

# Production build
flutter build web --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

---

## Performance Optimizations

### Pagination

```dart
// Category-specific pagination to reduce initial load
class PaginatedPostsNotifier extends Notifier<PaginatedPostsState> {
  final int _pageSize = 50;

  Future<void> loadPostsForCategory(String category, {bool isRefresh = false}) async {
    // Load only requested category
    // Maintain separate state per category
    // Support infinite scroll
  }
}
```

### Real-time Updates

```dart
// Efficient real-time updates - update only affected items
.onPostgresChanges(
  event: PostgresChangeEvent.update,
  callback: (payload) {
    final updatedPost = Post.fromMap(payload.newRecord);
    // Update only this post in state, not full refresh
    _updateSinglePost(updatedPost);
  },
)
```

### Denormalized Counts

Vote and comment counts stored directly on posts table:
- Avoids expensive COUNT queries
- Updated by database triggers
- Real-time sync via Postgres changes

---

## Testing Strategy

### Unit Tests
- Model parsing (Post.fromMap, UserProfile.fromMap)
- Point calculation logic
- Input sanitization

### Widget Tests
- Truth meter rendering
- Vote button states
- Form validation

### Integration Tests
- Full auth flow
- Post creation → voting → scoring
- Price entry submission

---

## Future Technical Considerations

### AI Integration (OpenRouter)
- Auto-categorization of posts
- Duplicate detection for prices
- Sentiment analysis for trends

### Push Notifications
- Firebase Cloud Messaging integration
- Notification scheduling
- Deep linking

### Offline Support
- Drift (SQLite) for local cache
- Queue posts/votes when offline
- Sync on reconnect

---

*Document Version: 1.0*
*Last Updated: November 24, 2025*
