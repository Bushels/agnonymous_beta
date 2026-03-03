# Wave 1: Foundation Strengthening — Design Document

**Date:** 2026-03-03
**Author:** Claude Code + Kyle
**Status:** Approved
**Build Order:** File Restructure → CFTC COT Pipeline → ICE Futures Scraper → Canola Thesis Dashboard

---

## 1. File Restructure

### Goal
Decompose `main.dart` (3,262 lines) into a feature-based directory structure. All 18 files importing `main.dart` will be updated.

### Extraction Map

| Component | Current Location (main.dart) | New Location |
|-----------|------------------------------|--------------|
| Post model | Lines 177-290 | `lib/core/models/post.dart` |
| Comment model | Lines 292-350 | `lib/core/models/comment.dart` |
| VoteStats model | Lines 351-373 | `lib/core/models/vote_stats.dart` |
| GlobalStats model | Lines 375-393 | `lib/core/models/global_stats.dart` |
| TrendingStats model | Lines 395-410 | `lib/core/models/trending_stats.dart` |
| PaginatedPostsNotifier + state | Lines 431-650 | `lib/features/community/providers/paginated_posts_provider.dart` |
| postsProvider, commentsProvider, voteStatsProvider | Lines 652-741 | `lib/features/community/providers/community_providers.dart` |
| globalStatsProvider, trendingStatsProvider | Lines 743-834 | `lib/features/community/providers/stats_providers.dart` |
| feedSortModeProvider | Lines 662-671 | `lib/features/community/providers/feed_sort_provider.dart` |
| HomeScreen | Lines 1227-1407 | `lib/features/community/screens/community_feed_screen.dart` |
| PostCard | Lines 2163-2552 | `lib/features/community/widgets/post_card.dart` |
| PostFeedSliver | Lines 1412-1633 | `lib/features/community/widgets/post_feed_sliver.dart` |
| HeaderBar | Lines 1635-1820 | `lib/features/community/widgets/header_bar.dart` |
| CategoryChips | Lines 1898-2031 | `lib/features/community/widgets/category_chips.dart` |
| TrendingSectionDelegate | Lines 2033-2160 | `lib/features/community/widgets/trending_section.dart` |
| CommentSection | Lines 2774-3152 | `lib/features/community/widgets/comment_section.dart` |
| Skeleton widgets | Lines 3184-3261 | `lib/core/widgets/skeleton_loader.dart` |
| PROVINCES_STATES | Lines 98-172 | `lib/app/constants.dart` |
| Theme data | Lines 1055-1071 | `lib/app/theme.dart` |
| AuthWrapper + NavigationShell | Lines 1098-1225 | `lib/app/navigation_shell.dart` |
| sanitizeInput, globals | Lines 49-96 | `lib/core/utils/globals.dart` |

### Post-Restructure main.dart
~180 lines: `main()`, `ErrorApp`, `AgnonymousApp` only.

### New Directory Structure
```
lib/
├── main.dart                          # ~180 lines
├── app/
│   ├── constants.dart
│   ├── theme.dart
│   └── navigation_shell.dart
├── core/
│   ├── models/
│   │   ├── post.dart
│   │   ├── comment.dart
│   │   ├── vote_stats.dart
│   │   ├── global_stats.dart
│   │   └── trending_stats.dart
│   ├── utils/
│   │   └── globals.dart
│   └── widgets/
│       └── skeleton_loader.dart
├── features/
│   ├── community/
│   │   ├── screens/
│   │   │   └── community_feed_screen.dart
│   │   ├── widgets/
│   │   │   ├── post_card.dart
│   │   │   ├── post_feed_sliver.dart
│   │   │   ├── header_bar.dart
│   │   │   ├── category_chips.dart
│   │   │   ├── trending_section.dart
│   │   │   └── comment_section.dart
│   │   └── providers/
│   │       ├── paginated_posts_provider.dart
│   │       ├── community_providers.dart
│   │       ├── stats_providers.dart
│   │       └── feed_sort_provider.dart
│   ├── dashboard/
│   │   ├── screens/
│   │   │   ├── home_dashboard_screen.dart  (existing, moved)
│   │   │   └── canola_thesis_screen.dart   (NEW)
│   │   ├── widgets/
│   │   │   ├── delivery_pace_gauge.dart    (NEW)
│   │   │   ├── cot_positioning_card.dart   (NEW)
│   │   │   ├── futures_price_card.dart     (NEW)
│   │   │   ├── contract_curve_chart.dart   (NEW)
│   │   │   ├── export_flow_viz.dart        (NEW)
│   │   │   ├── weekly_briefing_card.dart   (NEW)
│   │   │   └── insight_cards.dart          (NEW)
│   │   └── providers/
│   │       ├── cot_positions_provider.dart  (NEW)
│   │       └── futures_provider.dart        (NEW)
│   ├── markets/
│   │   ├── screens/
│   │   │   ├── markets_screen.dart         (existing, moved)
│   │   │   ├── grain_dashboard_screen.dart (existing, moved)
│   │   │   ├── grain_detail_screen.dart    (existing, moved)
│   │   │   ├── crop_stats_tab.dart         (existing, moved)
│   │   │   ├── market_dashboard_screen.dart(existing, moved)
│   │   │   └── fertilizer_detail_screen.dart(existing, moved)
│   │   └── providers/
│   │       ├── grain_data_live_provider.dart(existing, moved)
│   │       ├── grain_data_provider.dart    (existing, moved)
│   │       ├── crop_stats_provider.dart    (existing, moved)
│   │       └── fertilizer_ticker_provider.dart(existing, moved)
│   ├── auth/
│   │   └── screens/                       (existing, moved)
│   └── profile/
│       └── screens/                       (existing, moved)
```

### Import Migration Strategy
1. Create new files with extracted code
2. Update imports in all 18 dependent files
3. Temporarily re-export from main.dart for any missed imports
4. Run `flutter analyze` to verify clean
5. Remove re-exports once all imports confirmed

---

## 2. CFTC COT Data Pipeline

### Data Source
CFTC Commitments of Traders — combined futures + options report. Published every Friday 3:30 PM ET.

### Database Schema
```sql
CREATE TABLE cot_positions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_date date NOT NULL,
  commodity text NOT NULL,
  exchange text NOT NULL,
  report_type text DEFAULT 'combined_futures_options',
  commercial_long bigint,
  commercial_short bigint,
  commercial_net bigint,
  non_commercial_long bigint,
  non_commercial_short bigint,
  non_commercial_net bigint,
  non_commercial_spreads bigint,
  open_interest bigint,
  commercial_net_change bigint,
  non_commercial_net_change bigint,
  open_interest_change bigint,
  created_at timestamptz DEFAULT now(),
  UNIQUE(report_date, commodity, exchange)
);
```

### Commodities Tracked
- ICE Canola (primary)
- CBOT Wheat (SRW)
- CBOT Corn
- CBOT Soybeans

### Edge Function: `fetch-cot-data`
- **Schedule:** Saturday 6am UTC via pg_cron
- **Source:** CFTC CSV download (current year combined futures+options)
- **Logic:** Download → parse → filter commodities → calculate changes → upsert

### Flutter Provider: `cot_positions_provider.dart`
- Fetches from `cot_positions`, filterable by commodity and date range
- Exposes latest + 12-week history

---

## 3. ICE Canola Futures Scraper

### Data Source
Barchart.com delayed futures data (15-20 min delay).

### Database Schema
```sql
CREATE TABLE futures_prices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  commodity text NOT NULL,
  exchange text NOT NULL,
  contract_month text NOT NULL,
  contract_symbol text,
  last_price decimal(10,4),
  price_change decimal(10,4),
  price_change_pct decimal(6,3),
  open_price decimal(10,4),
  high_price decimal(10,4),
  low_price decimal(10,4),
  prev_close decimal(10,4),
  volume bigint,
  open_interest bigint,
  settlement_price decimal(10,4),
  currency text DEFAULT 'CAD',
  fetched_at timestamptz NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(commodity, exchange, contract_month, fetched_at::date)
);

CREATE INDEX idx_futures_commodity_date
  ON futures_prices(commodity, exchange, fetched_at DESC);
```

### Edge Function: `fetch-futures-prices`
- **Schedule:** Every 4 hours Mon-Fri during market hours via pg_cron
- **Source:** Barchart.com canola futures overview
- **Commodities:** ICE canola (all months), CME wheat/corn/soybeans (front month)

### Flutter Provider: `futures_provider.dart`
- Latest prices by commodity
- Full contract curve for canola

---

## 4. Canola Thesis Dashboard

### Screen: `canola_thesis_screen.dart`
Accessible from Dashboard "Canola Thesis" card and from Markets > Grains > Canola.

### Components (scroll order)

1. **Futures Price Card** — ICE canola front-month price + sparkline
2. **Delivery Pace Gauge** — CustomPainter arc gauge: cumulative vs 5yr avg
3. **Weekly Briefing Card** — Auto-generated narrative from data heuristics
4. **COT Positioning Chart** — fl_chart BarChart: commercial vs speculative, 12 weeks
5. **Contract Curve** — fl_chart LineChart: all active canola futures months
6. **Export Flow Viz** — CustomPainter Sankey diagram: province → terminal grain flow
7. **AI Insight Cards** — Rule-based observations (pace, COT trends, regional, carry)

### Insight Generation (rule-based heuristics)
- Pace insight: cumulative deliveries vs 5yr avg → sentence
- COT insight: speculative net trend direction → sentence
- Regional insight: province-level WoW changes → sentence
- Carry insight: front-month vs deferred spread → sentence

No LLM API calls. Fast, free, deterministic.

---

*Approved: 2026-03-03*
