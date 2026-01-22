# Agnonymous Beta - Claude Code Project Context

## Quick Links

| Document | Purpose |
|----------|---------|
| [PRODUCT_VISION.md](PRODUCT_VISION.md) | Complete product vision and feature specifications |
| [TECHNICAL_ARCHITECTURE.md](TECHNICAL_ARCHITECTURE.md) | Tech stack, database schema, API design |
| [IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md) | Phase-by-phase implementation plan |
| [INPUT_PRICING_SYSTEM.md](INPUT_PRICING_SYSTEM.md) | Fertilizer/chemical/seed pricing feature |
| [GAMIFICATION_SYSTEM.md](GAMIFICATION_SYSTEM.md) | Point system and reputation design |

---

## Mission Statement

> **"Transparency in Agriculture. The farmer takes back control."**

Agnonymous is a secure agricultural whistleblowing and transparency platform that protects anonymous users exposing harmful practices in farming and ranching communities. In an industry where reputation is everything and communities are tight-knit, speaking out can mean social isolation or economic ruin. Agnonymous changes that.

---

## Tech Stack

| Layer | Technology | Version |
|-------|------------|---------|
| Frontend | Flutter | 3.38.3 |
| Language | Dart | 3.10.1 |
| State Management | flutter_riverpod | 3.0.3 |
| Backend | Supabase | Cloud |
| Database | PostgreSQL | 15+ |
| Hosting | Firebase Hosting | - |

---

## Architecture Pattern: Riverpod 3.x Notifier

**IMPORTANT: Use `Notifier` pattern, NOT deprecated `StateNotifier`**

```dart
// CORRECT pattern for this project
class MyNotifier extends Notifier<MyState> {
  @override
  MyState build() {
    ref.onDispose(() { /* cleanup subscriptions */ });
    return MyState();
  }

  void updateSomething() {
    state = state.copyWith(something: newValue);
  }
}

final myProvider = NotifierProvider<MyNotifier, MyState>(MyNotifier.new);
```

### Real-time Subscriptions Pattern

```dart
// Inside build() method
final channel = supabase
    .channel('my_channel')
    .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'my_table',
      callback: (payload) => _handleUpdate(payload),
    )
    .subscribe();

ref.onDispose(() => channel.unsubscribe());
```

---

## Core Features

### 1. Anonymous Whistleblowing
- Posts can be completely anonymous or with username
- Anonymous posts = no reputation earned
- Username posts = full reputation points

### 2. Truth Meter System
Vote types: `thumbs_up`, `partial`, `thumbs_down`, `funny`

Visual credibility meter from 0-100% based on vote ratio.

### 3. Gamification & Reputation
| Action | Points |
|--------|--------|
| Create post (with username) | +5 |
| Vote on any post | +1 |
| First comment on post | +2 |
| Post receives positive votes | +/- variable |
| Admin verifies post | +10 |

**Max loss per post: -5 points**

Levels: Seedling -> Sprout -> Growing -> Established -> Reliable Source -> Trusted Reporter -> Expert Whistleblower -> Truth Guardian -> Master Investigator -> Legend

### 4. Input Pricing Database (NEW)
Crowdsourced prices for:
- Fertilizers (Urea, MAP, DAP, Potash, etc.)
- Chemicals (herbicides, fungicides, insecticides)
- Seeds (Canola, Wheat, Barley, Pulses, Corn, Soybeans)

Features:
- USD/CAD auto-detection by location
- Price history charts
- Regional comparison
- Price alerts

### 5. Verification Badges
- **Verified**: Email confirmed, checkmark icon
- **Unverified**: Email not confirmed, warning icon
- **Anonymous**: Post made without username, mask icon

---

## File Structure

```
lib/
├── main.dart                    # App entry, theme, core providers
├── create_post_screen.dart      # Post creation
│
├── models/
│   └── user_profile.dart        # User profile + reputation logic
│
├── providers/
│   ├── auth_provider.dart       # Authentication state
│   └── leaderboard_provider.dart
│
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   ├── signup_screen.dart
│   │   └── verify_email_screen.dart
│   ├── profile/
│   │   └── profile_screen.dart
│   └── landing/
│       └── landing_screen.dart
│
└── widgets/
    ├── glass_container.dart     # Glassmorphism component
    ├── truth_meter.dart
    ├── user_badge.dart
    ├── reputation_badge.dart
    ├── trending_posts.dart
    └── header_bar.dart
```

---

## Database Schema Overview

### Core Tables
- `user_profiles` - User accounts with reputation
- `posts` - Posts with author info and vote counts
- `comments` - Comments on posts
- `truth_votes` - Votes on posts
- `user_post_interactions` - Track point farming prevention

### Pricing Tables (To Build)
- `products` - Fertilizers, chemicals, seeds
- `retailers` - Agriculture retailers/co-ops
- `price_entries` - Crowdsourced prices
- `price_alerts` - User watchlists

### Gamification Tables
- `reputation_logs` - Audit trail of point changes
- `admin_roles` - Moderator/admin permissions
- `post_verifications` - Admin-verified posts

---

## Current Implementation Status

| Feature | Status | Notes |
|---------|--------|-------|
| Basic app structure | Complete | - |
| Post viewing/filtering | Complete | With pagination (20 per page) |
| Real-time updates | Complete | - |
| Truth meter | Complete | - |
| Voting system | Complete | With rate limiting |
| Comment system | Complete | With rate limiting, no edit/delete |
| Auth screens | Complete | Login, signup, verify, forgot password |
| User profile model | Complete | With reputation logic |
| Glassmorphism UI | Complete | - |
| Province/state list | Complete | Full CA + US |
| Rate limiting | Complete | Votes, comments, posts |
| Pagination | Complete | Infinite scroll, 20 per page |
| Edit/Delete posts | Complete | Append-only, 5-sec delete window |
| Error boundaries | Complete | Custom error UI |
| Forgot password | Complete | Phase 1 |
| Post-as toggle | Complete | Anonymous vs username UI toggle |
| Full gamification | Complete | DB triggers, reputation, vote weights |
| Input pricing | Complete | Add via Create Post > Input Prices |
| Bottom navigation | Complete | GlassBottomNav implemented |
| Notifications | Partial | Screen exists, alerts coming soon |
| Ads (AdSense/AdMob) | Not Started | Phase 8 |

### Gamification System (Database Triggers Active)
- Post creation: +5 points (anonymous or public reputation)
- Comment creation: +2 points (first comment per post)
- Vote casting: +1 point (first vote per post)
- Auto-calculate reputation level (0-9) and vote weight (1.0-3.0x)
- Anti-abuse: tracks user_post_interactions to prevent duplicate points

### Production Readiness (Completed Nov 28, 2025)
- Rate limiting: votes (10/min), comments (5/2min), posts (3/5min)
- Pagination: 20 posts per page with infinite scroll
- Edit/Delete: Append-only editing, 5-second delete window, no comment edit/delete
- Error boundaries: Custom ErrorWidget.builder, ErrorBoundary widget
- All critical TODOs resolved
- 142 unit tests passing

---

## Development Commands

```bash
# Run the app (web)
flutter run -d chrome --web-port=5000

# Run the app (with hot reload)
flutter run -d chrome

# Analyze code
flutter analyze

# Get dependencies
flutter pub get

# Build for web (production)
flutter build web --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

# Deploy to Firebase
firebase deploy --only hosting
```

---

## Security Requirements

### Anonymous User Protection
- **NEVER** log anonymous_user_id with identifying information
- **NO** IP tracking on post/comment creation
- **SEPARATE** authentication from anonymous posting
- **RLS policies** prevent cross-user data access

### Input Sanitization
```dart
String sanitizeInput(String input) {
  String sanitized = input.replaceAll(RegExp(r'<[^>]*>'), '');
  sanitized = htmlUnescape.convert(sanitized);
  return sanitized.trim();
}
```

### Rate Limiting
- Detect rapid voting (>10 votes in 5 minutes)
- Log suspicious activity
- Prevent self-voting

---

## Design System

### Colors
| Name | Hex | Usage |
|------|-----|-------|
| Primary Green | #84CC16 | CTAs, accents, positive |
| Secondary Orange | #F59E0B | Warnings, partial |
| Error Red | #EF4444 | Errors, negative |
| Background Dark | #111827 | Main background |
| Surface | #1F2937 | Cards, containers |
| Text Primary | #FFFFFF | Main text |
| Text Secondary | #9CA3AF | Secondary text |

### Glassmorphism Style
```dart
GlassContainer(
  blur: 10.0,
  opacity: 0.1,
  borderRadius: BorderRadius.circular(16),
  child: content,
)
```

### Typography
- Font: Google Fonts - Inter (body), Outfit (headers)
- Headings: Bold, white
- Body: Regular, white/grey

---

## Testing

### Run Tests
```bash
flutter test
```

### Test Structure
```
test/
├── widget_test.dart              # Smoke tests
├── models/
│   ├── user_profile_test.dart    # UserProfile, ReputationLevelInfo, TruthMeterStatus
│   ├── pricing_models_test.dart  # Product, Retailer, PriceEntry, PriceStats, PriceAlert
│   └── notification_model_test.dart  # UserNotification, NotificationType
├── providers/
│   └── auth_state_test.dart      # AuthState class tests
├── utils/
│   └── sanitize_input_test.dart  # Input sanitization tests
└── widgets/
    ├── glass_container_test.dart # GlassContainer, FrostedCard, GlassTextField, etc.
    └── reputation_badge_test.dart # ReputationBadge, ReputationProgress, ReputationStatsCard
```

### Test Categories
- Unit: Model parsing, point calculations, state management
- Widget: UI component rendering, user interactions
- Integration: Full user flows (requires Firebase/Supabase setup)

### Current Coverage
- **142+ tests** passing (models, services, widgets, utils)
- Models: ~90% coverage (user_profile, pricing_models, notification_model)
- Services: rate_limiter fully tested
- Widgets: Key components tested (glass_container, reputation_badge)
- Utils: sanitizeInput fully covered

---

## Environment Setup

### Local Development
Create `.env` file:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

### Production
Environment variables via Flutter build args or Firebase config.

---

## Implementation Priorities

### Phase 1: Auth Polish (HIGH)
- Forgot password flow
- Better error handling
- Email verification UX

### Phase 2: Post-As Toggle (HIGH)
- Anonymous vs username posting
- Author display on posts
- Verification badges

### Phase 3: Gamification (HIGH)
- Point awarding triggers
- Vote weight implementation
- Reputation display
- Post sorting by reputation

### Phase 4: Input Pricing (MEDIUM)
- Product/retailer database
- Price entry flow
- Price history/comparison
- Price alerts

### Phase 5: Navigation & UI (MEDIUM)
- Bottom navigation bar
- Consistent glassmorphism
- Animation polish

### Phase 6-8: Notifications, AI, Monetization (LOW)
- Alert system
- Smart categorization
- AdSense/AdMob integration

---

## Common Patterns

### Provider Access
```dart
// Read once
final value = ref.read(myProvider);

// Watch for changes
final value = ref.watch(myProvider);

// Call notifier method
ref.read(myProvider.notifier).doSomething();
```

### Supabase Queries
```dart
// Select
final data = await supabase.from('table').select().eq('id', id);

// Insert
await supabase.from('table').insert({'field': value});

// Update
await supabase.from('table').update({'field': value}).eq('id', id);

// RPC function
final result = await supabase.rpc('function_name', params: {'param': value});
```

### Error Handling
```dart
try {
  await someOperation();
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Success!')),
    );
  }
} catch (e) {
  logger.e('Error:', error: e);
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
    );
  }
}
```

---

## Key Conventions

1. **State Management**: Riverpod Notifier pattern (not StateNotifier)
2. **Sanitization**: All user input through `sanitizeInput()`
3. **Real-time**: Use `ref.onDispose()` for subscription cleanup
4. **Categories**: Case-sensitive in database
5. **Security**: RLS on all tables, never expose user mappings
6. **UI**: Glassmorphism containers, dark theme, green accents
7. **Currency**: Auto-detect CAD/USD from province/state

---

## Known Issues (Fixed)
- ~~Signup screen needs password confirmation field~~ (Already implemented)
- ~~USA states dropdown incomplete~~ (Full list now in PROVINCES_STATES)
- ~~Forgot password flow not implemented~~ (Fully implemented with Supabase resetPasswordForEmail)
- ~~Create post screen doesn't actually submit to database~~ (Fully implemented in create_post_screen.dart)
- ~~No error tracking~~ (Firebase Crashlytics integrated)
- ~~Minimal test coverage~~ (227 tests covering models, widgets, utils)

## Known Issues (Fixed - Nov 28, 2025)
- ~~Rate limiting not implemented~~ (Complete: votes, comments, posts)
- ~~Pagination not implemented~~ (Complete: 20 per page, infinite scroll)
- ~~Post/Comment edit & delete not implemented~~ (Complete: append-only edit, 5-sec delete, no comment edit/delete)
- ~~No error boundaries~~ (Complete: ErrorWidget.builder, ErrorBoundary widget)
- ~~Critical TODOs in navigation~~ (Complete: all navigation fixed)

## Remaining Work
- Price alerts functionality (notifications when prices change)
- Ad integration (AdSense/AdMob - Phase 8)
- AI category suggestions (Phase 7)
- Push notifications via FCM

---

*Last Updated: November 28, 2025*
