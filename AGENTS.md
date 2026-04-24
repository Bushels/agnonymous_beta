# Agnonymous Beta - Codex Project Context

## April 2026 Relaunch Override

This section is the current source of truth and overrides older dashboard, market-intelligence, input-pricing, and gamification plans in this repo.

Agnonymous is being relaunched as a **mobile-first anonymous posting board**:

- No sign up or sign in.
- Anonymous reading, posting, commenting, and voting.
- Monette is the first-class launch room.
- Monette posts can optionally reference a public farming area from the Monette-only area menu.
- The bottom post control is icon-only.
- Watch state is tied to the anonymous device ID, not an account.
- The truth meter uses three board signals: thumbs up, neutral, thumbs down.
- Funny reactions are removed from the UI.
- Market intelligence, fertilizer/input pricing, marketplace pricing, My Farm, My Bins, elevator maps, and commodity dashboards are out of v1.

Read first for current work:

| Document | Purpose |
|----------|---------|
| [PRODUCT_VISION.md](PRODUCT_VISION.md) | Current anonymous-board product vision |
| [docs/plans/2026-04-23-anonymous-board-relaunch.md](docs/plans/2026-04-23-anonymous-board-relaunch.md) | Relaunch status, decisions, audit checklist |

Before reverting anything, read `docs/plans/2026-04-23-anonymous-board-relaunch.md` → "2026-04-24 Ship Log". It lists the files deleted in the relaunch (including everything under `lib/screens/**`), the header-enforcement security migration, the analyzer excludes, and the two Vercel deploy fixes (`build.sh` exec bit, removing `.env` from pubspec assets). Undoing any of those will either break production or re-introduce v2-scope code the product deliberately cut.

Legacy documents below remain useful only for historical context. Do not use them to justify adding pricing, dashboards, sign-in, or market intelligence back into v1.

## Quick Links

| Document | Purpose |
|----------|---------|
| [PRODUCT_VISION.md](PRODUCT_VISION.md) | Complete product vision and feature specifications |
| [TECHNICAL_ARCHITECTURE.md](TECHNICAL_ARCHITECTURE.md) | Tech stack, database schema, API design |
| [IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md) | Phase-by-phase implementation plan |
| [INPUT_PRICING_SYSTEM.md](INPUT_PRICING_SYSTEM.md) | Fertilizer/chemical/seed pricing feature |
| [GAMIFICATION_SYSTEM.md](GAMIFICATION_SYSTEM.md) | Point system and reputation design |
| | |
| **Strategy Documents (March 2026)** | |
| [AGRICULTURAL_WORLDVIEW.md](AGRICULTURAL_WORLDVIEW.md) | **READ FIRST** — Farmer philosophy, trust principles, platform values |
| [STRATEGIC_BLUEPRINT.md](STRATEGIC_BLUEPRINT.md) | Flutter architecture, file restructure plan, tool comparison |
| [DATA_SOURCE_ARCHITECTURE.md](DATA_SOURCE_ARCHITECTURE.md) | 15 data sources, build waves, Mapbox plan |
| [FARMER_TARGETS_FEATURE.md](FARMER_TARGETS_FEATURE.md) | "My Farm" — cost/yield/breakeven, provincial defaults |
| [CONTEXTUAL_CHAT_AND_INVENTORY.md](CONTEXTUAL_CHAT_AND_INVENTORY.md) | Contextual chat rooms, "My Bins" inventory, publish-to-elevator |
| [AGENT_HIERARCHY.md](AGENT_HIERARCHY.md) | 19-agent 3-tier hierarchy, communication protocol |
| [AGENT_STRATEGY.md](AGENT_STRATEGY.md) | Original agent strategy (superseded by AGENT_HIERARCHY) |
| | |
| **Wave 2 (March 2026)** | |
| [WAVE2_IMPLEMENTATION.md](WAVE2_IMPLEMENTATION.md) | Complete Wave 2 roadmap — PDQ, My Farm, Elevator Map, Farmer Reporting |
| [WAVE2_ADVICE.md](WAVE2_ADVICE.md) | High-level advice, gotchas, and session prompting tips for Wave 2 |

---

## Mission Statement

> **"Transparency in Agriculture. The farmer takes back control."**

Agnonymous is a **farmer-first intelligence dashboard** — a "Bloomberg Terminal for Agriculture" that transforms government data into actionable insights for western Canadian prairie farmers (SK, AB, MB). The dashboard is the superstar; community features support it. Every agent MUST read [AGRICULTURAL_WORLDVIEW.md](AGRICULTURAL_WORLDVIEW.md) before building anything.

### Platform Pillars
1. **Data Intelligence**: Automated pipelines from CGC, StatsCan, USDA, CFTC, PDQ, and more (see [DATA_SOURCE_ARCHITECTURE.md](DATA_SOURCE_ARCHITECTURE.md))
2. **Local Price Intelligence**: Elevator-level pricing on interactive Mapbox map — the feature no one else has
3. **My Farm**: Farmer inputs their own costs/yields → sees live breakeven vs elevator bids (see [FARMER_TARGETS_FEATURE.md](FARMER_TARGETS_FEATURE.md))
4. **Beautiful Visualization**: fl_chart + CustomPainter in glassmorphism containers
5. **Community Layer**: Contextual chat per data section + Agnonymous posts with truth meter
6. **Revenue**: Ad-supported free model (Google AdSense/AdMob), future premium tier

---

## Tech Stack

| Layer | Technology | Version |
|-------|------------|---------|
| Frontend | Flutter | 3.41.7 |
| Language | Dart | 3.11.5 |
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

## Navigation (5-Tab Layout)

```
[Dashboard]   [Markets]   [+Post]   [Community]   [Profile]
```

| Tab | Screen | Purpose |
|-----|--------|---------|
| Dashboard | `HomeDashboardScreen` | Personalized overview, key metrics, grain highlights, community pulse |
| Markets | `MarketsScreen` | Tabbed: Grains / Fertilizer / Crop Stats with fl_chart visualizations |
| + Post | `CreatePostScreen` | Create post or submit price (opens as overlay) |
| Community | `HomeScreen` | Anonymous posts, voting, comments, truth meter |
| Profile | `ProfileScreen` | User profile, settings, notifications |

## File Structure

```
lib/
├── main.dart                           # App entry, theme, navigation shell, Post/Comment models
├── create_post_screen.dart             # Post creation
│
├── models/
│   ├── user_profile.dart               # User profile + reputation logic
│   ├── pricing_models.dart             # Product, Retailer, PriceEntry
│   ├── notification_model.dart         # UserNotification
│   └── fertilizer_ticker_models.dart   # Fertilizer ticker data
│
├── providers/
│   ├── auth_provider.dart              # Authentication state
│   ├── grain_data_provider.dart        # Grain data (delegates to live provider)
│   ├── grain_data_live_provider.dart   # Supabase-backed grain data
│   ├── crop_stats_provider.dart        # StatsCan + USDA crop stats
│   ├── fertilizer_ticker_provider.dart # Real-time fertilizer prices
│   ├── leaderboard_provider.dart
│   ├── notifications_provider.dart
│   └── presence_provider.dart
│
├── screens/
│   ├── dashboard/
│   │   ├── home_dashboard_screen.dart  # Main data dashboard (landing)
│   │   ├── grain_dashboard_screen.dart # Grain markets grid
│   │   └── grain_detail_screen.dart    # Individual grain detail
│   ├── market/
│   │   ├── markets_screen.dart         # Unified tabbed markets
│   │   ├── crop_stats_tab.dart         # StatsCan + USDA crop statistics
│   │   ├── market_dashboard_screen.dart
│   │   └── fertilizer_detail_screen.dart
│   ├── auth/ ...
│   ├── profile/ ...
│   └── pricing/ ...
│
├── widgets/
│   ├── glass_container.dart            # Glassmorphism components
│   ├── glass_bottom_nav.dart           # 5-tab glass navigation bar
│   ├── charts/
│   │   ├── grain_line_chart.dart       # fl_chart line chart wrapper
│   │   ├── price_comparison_chart.dart # fl_chart bar chart wrapper
│   │   ├── metric_card.dart            # Reusable metric card + TrendIndicator
│   │   └── insight_card.dart           # Auto-generated data insights
│   ├── ticker/
│   │   ├── fertilizer_ticker.dart      # Real-time price ticker
│   │   ├── sparkline_widget.dart       # Mini trend charts
│   │   └── ...
│   └── ads/
│       ├── smart_ad_banner.dart        # Unified AdSense/AdMob banner
│       ├── ad_helper.dart              # Platform ad unit IDs
│       └── responsive_ad_banner.dart   # Responsive banner loading
│
├── services/
│   ├── grain_db/                       # SQLite grain data (offline fallback)
│   ├── rate_limiter.dart
│   ├── analytics_service.dart
│   └── anonymous_id_service.dart
│
supabase/
├── functions/
│   ├── fetch-cgc-grain-data/index.ts   # CGC data pipeline Edge Function
│   ├── fetch-statscan-crops/index.ts   # Statistics Canada crop data pipeline
│   ├── fetch-usda-nass/index.ts        # USDA NASS QuickStats pipeline
│   └── pipeline-health/index.ts        # Pipeline health monitoring
├── migrations/
│   ├── 20260220120000_grain_data_live.sql  # Data foundation tables
│   ├── 20260221120000_crop_stats_usda.sql  # Crop stats + USDA tables
│   └── ...
│
.Codex/agents/                          # 15 Codex agents
├── vision-agent.md                      # Feature ideation
├── improvement-agent.md                 # Site optimization
├── innovation-agent.md                  # Tech trend research
├── security-agent.md                    # Vulnerability monitoring
├── dashboard-agent.md                   # Data display building
├── data-analytics-agent.md              # SQL insights
├── data-research-agent.md               # New data sources
├── monetization-agent.md                # Ad revenue optimization
├── community-agent.md                   # Community features
├── supabase-architect.md                # Database design
├── glassmorphism-ui.md                  # UI patterns
├── auth-flow-builder.md                 # Auth flows
├── profile-builder.md                   # Profile features
├── gamification-builder.md              # Reputation system
└── agnonymous-debugger.md               # Debugging
```

---

## Database Schema Overview

### Core Tables
- `user_profiles` - User accounts with reputation
- `posts` - Posts with author info and vote counts
- `comments` - Comments on posts
- `truth_votes` - Votes on posts
- `user_post_interactions` - Track point farming prevention

### Data Pipeline Tables (NEW)
- `grain_data_live` - Live grain delivery data from CGC (replaces bundled SQLite)
- `data_source_config` - Tracks all data sources and fetch schedules
- `data_pipeline_logs` - Execution audit trail for data fetches

### Pricing Tables
- `products` - Fertilizers, chemicals, seeds
- `retailers` - Agriculture retailers/co-ops
- `price_entries` - Crowdsourced prices
- `price_alerts` - User watchlists
- `fertilizer_ticker_entries` - Real-time fertilizer prices

### Gamification Tables
- `reputation_logs` - Audit trail of point changes
- `admin_roles` - Moderator/admin permissions
- `post_verifications` - Admin-verified posts

### Data Pipeline Architecture
```
[CGC/StatsCan/USDA] → [Supabase Edge Functions] → [PostgreSQL] → [Flutter App]
                       (pg_cron scheduled)          (RLS)         (Riverpod providers)
```
- CGC grain data: Weekly fetch via `fetch-cgc-grain-data` Edge Function
- StatsCan crop stats: Monthly fetch via `fetch-statscan-crops` Edge Function
- USDA QuickStats: Weekly fetch via `fetch-usda-nass` Edge Function
- Pipeline health: Daily check via `pipeline-health` Edge Function

---

## Current Implementation Status

### Core Platform
| Feature | Status | Notes |
|---------|--------|-------|
| Basic app structure | Complete | - |
| Post viewing/filtering | Complete | With pagination (20 per page) |
| Real-time updates | Complete | Supabase channels |
| Truth meter | Complete | 0-100% credibility |
| Voting system | Complete | With rate limiting |
| Comment system | Complete | With rate limiting, no edit/delete |
| Auth screens | Complete | Login, signup, verify, forgot password |
| User profile model | Complete | With reputation logic |
| Glassmorphism UI | Complete | - |
| Rate limiting | Complete | Votes, comments, posts |
| Pagination | Complete | Infinite scroll, 20 per page |
| Edit/Delete posts | Complete | Append-only, 5-sec delete window |
| Error boundaries | Complete | Custom error UI |
| Full gamification | Complete | DB triggers, reputation, vote weights |
| Input pricing | Complete | Add via Create Post > Input Prices |

### Data Intelligence (NEW - Feb 2026)
| Feature | Status | Notes |
|---------|--------|-------|
| 5-tab GlassBottomNav | Complete | Dashboard, Markets, +Post, Community, Profile |
| Home dashboard | Complete | Metrics, grain highlights, community pulse |
| Markets screen | Complete | Tabbed: Grains / Fertilizer / Crop Stats |
| CGC data pipeline | Complete | Edge Function + pg_cron, weekly auto-fetch |
| Supabase grain providers | Complete | Replaces bundled SQLite |
| fl_chart visualizations | Complete | LineChart, BarChart, MetricCard, InsightCard |
| Agent swarm (9 agents) | Complete | .Codex/agents/ definitions |
| SmartAdBanner | Complete | Unified AdSense (web) / AdMob (mobile) |
| StatsCan integration | Complete | Edge Function + crop_stats table, monthly fetch |
| USDA QuickStats | Complete | Edge Function + crop_stats table, weekly fetch |
| Pipeline health monitor | Complete | Edge Function, data freshness indicators |
| Crop Stats tab | Complete | Filterable by source/group, YoY charts, price comparison |
| Weather overlay | Not Started | Phase 6 - Open-Meteo |
| Notifications | Partial | Screen exists, push alerts coming |

### Gamification System (Database Triggers Active)
- Post creation: +5 points (anonymous or public reputation)
- Comment creation: +2 points (first comment per post)
- Vote casting: +1 point (first vote per post)
- Auto-calculate reputation level (0-9) and vote weight (1.0-3.0x)
- Anti-abuse: tracks user_post_interactions to prevent duplicate points

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

### Completed Phases (1-5)
- Data foundation (Supabase grain_data_live, Edge Functions, providers)
- 5-tab navigation (Dashboard, Markets, +Post, Community, Profile)
- Data visualization (fl_chart charts, MetricCard, InsightCard)
- Agent swarm (9 Codex agents) + ad integration (SmartAdBanner)
- Statistics Canada + USDA NASS data pipelines, crop_stats table, Crop Stats tab

### Phase 6: Polish & Optimization (NEXT)
- Extract Post/Comment models from main.dart into dedicated files
- Offline cache service for Supabase data
- Admin analytics dashboard
- Push notifications via FCM

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

## Remaining Work (Priority Order)
See [DATA_SOURCE_ARCHITECTURE.md](DATA_SOURCE_ARCHITECTURE.md) for full build waves.

### Wave 1: Foundation Strengthening
- Canola thesis deep-dive dashboard (enhanced CGC visualization)
- CFTC COT data pipeline (weekly CSV, trader positioning)
- ICE canola futures connection
- File restructure: Extract Post/Comment models from main.dart

### Wave 2: Local Price Intelligence
- Mapbox elevator map (CGC GEICO locations)
- PDQ cash prices & basis integration
- Farmer price reporting UX ("Publish to Elevator")
- "My Farm" cost/yield/breakeven feature

### Wave 3: Supply Chain Intelligence
- Grain Monitor (port/exports)
- CN Rail grain reports
- CPKC grain scorecard
- "My Bins" grain inventory with valuation

### Wave 4: News & Engagement
- Ag news RSS aggregation
- Contextual chat rooms per data section
- Weather overlay (Open-Meteo)
- Push notifications via FCM

### Ongoing
- Offline cache service
- Admin analytics dashboard
- Price alerts functionality

---

## Codex Agent Hierarchy (19 Agents, 3 Tiers)

**Full spec:** [AGENT_HIERARCHY.md](AGENT_HIERARCHY.md)

### Tier 1: Super Agent
| Agent | Purpose |
|-------|---------|
| `super-agent` | Final quality gate — validates all work against AGRICULTURAL_WORLDVIEW.md |

### Tier 2: Sub-Agents (Domain Leads)
| Agent | Team | Manages |
|-------|------|---------|
| `product-lead` | Product & Experience | UI, UX, Mobile, Community, Farmer Input |
| `data-lead` | Data & Intelligence | Pipeline, Supabase, Insight, News, Map |
| `ops-lead` | Operations & Quality | Debugger, Security, Memory/Docs, Innovation, Agent Ops |

### Tier 3: Worker Agents
| Agent | Team | Focus |
|-------|------|-------|
| `ui-engineer` | Product | Widgets, glassmorphism, styling, layout |
| `ux-engineer` | Product | Interaction design, flows, states |
| `mobile-specialist` | Product | 390px viewport, touch targets, scroll perf |
| `community-features` | Product | Agnonymous posts, contextual chat, voting |
| `farmer-input` | Product | Cost entry, yield targets, publish-to-elevator, My Bins |
| `data-pipeline` | Data | All Edge Functions (CGC, COT, PDQ, rail, news) |
| `supabase-architect` | Data | Schema, RLS, indexes, RPC, triggers, migrations |
| `insight-engine` | Data | Auto-generated insights, breakeven calcs, narratives |
| `news-intelligence` | Data | RSS feeds, sentiment, commodity tagging |
| `map-intelligence` | Data | Mapbox, elevator markers, geo-queries, offline tiles |
| `debugger` | Ops | Bug fixing, `flutter analyze`, crash analysis |
| `security-agent` | Ops | RLS audits, auth, anonymization, privacy |
| `memory-docs` | Ops | Documentation currency, .Codex/memory/ cleanup, weekly reports |
| `innovation-scout` | Ops | Flutter packages, ag-tech trends, competitor monitoring |
| `agent-ops` | Ops | Agent effectiveness grading, upgrade recommendations |

### Agent Communication
Agents communicate via status files in `.Codex/memory/`. See AGENT_HIERARCHY.md for the full communication protocol, review gates, and workflow patterns.

### Shared Context Files
Reference data in `.Codex/context/`:
- `data-dictionary.md` — All database tables, columns, types
- `design-tokens.md` — Colors, typography, spacing, glassmorphism specs
- `api-contracts.md` — RPC signatures, Edge Function interfaces, provider contracts
- `scraping-targets.md` — URLs, selectors, schedules for all data sources

---

*Last Updated: March 3, 2026*
