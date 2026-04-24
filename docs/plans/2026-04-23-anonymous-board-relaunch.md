# Agnonymous Anonymous Board Relaunch

Date: 2026-04-23
Updated: 2026-04-24

## Decision

Agnonymous returns to its original purpose: a low-friction anonymous agriculture board for posts, comments, votes, refresh, and active discussion.

This is not a market-intelligence relaunch. Do not add price tracking, fertilizer input pricing, marketplace pricing, My Farm, My Bins, elevator bids, or commodity dashboards to v1.

## Current Implementation Status

### Completed In Current Relaunch Pass

- Upgraded local Flutter/Dart toolchain to Flutter 3.41.7 and Dart 3.11.5.
- Rebuilt the app shell around a mobile-first anonymous board.
- Removed sign-in/sign-up from the main board flow.
- Made Monette the first room.
- Removed the old bottom nav (`Board / Post / Latest`).
- Kept only an icon-only bottom post button.
- Removed the top composer-style post prompt.
- Removed the empty-state duplicate post button.
- Added refreshed prairie visual system.
- Replaced the old anonymous-person icon with the sprout/signal mark.
- Reworked the web loading screen to match the current app.
- Added `BoardPostCard`.
- Added `BoardTruthMeter`.
- Added watched-thread state through anonymous device ID.
- Added new-comment marker behavior for watched threads.
- Removed the Funny button from the UI.
- Kept legacy `funny` vote rows in the database to avoid unnecessary historical mutation.

### Current Visible Vote System

Visible board signals:

- Thumbs up: yes / likely true.
- Neutral: `partial` in the database.
- Thumbs down: no / likely false.

Legacy hidden signal:

- `funny` remains a valid old database value but is no longer shown as an action.

### Current Watch System

- Watches save locally immediately using the anonymous device ID.
- Watches sync to Supabase through the `anonymous_post_watches` migration/RPCs once applied.
- Opening comments marks a watched thread seen.
- Posting a thread auto-watches it.
- Commenting on a thread auto-watches it.

### Current Brand/Loading Assets

- `assets/images/agnonymous_mark.svg`
- `assets/images/app_icon.png`
- `assets/images/app_icon_foreground.png`
- `web/favicon.png`
- `web/icons/Icon-192.png`
- `web/icons/Icon-512.png`
- `web/icons/Icon-maskable-192.png`
- `web/icons/Icon-maskable-512.png`
- `web/icons/agnonymous-mark.svg`
- `web/index.html`
- `web/manifest.json`

### Current Verification

Last verified locally:

- Targeted analyzer passed for recently changed UI files.
- Full Flutter test suite passed: 111 tests.
- Release web build passed.
- Local preview returned HTTP 200 at `http://127.0.0.1:5000/`.
- Mobile screenshots checked for loaded app and loading screen.

## Documentation Source Of Truth

Use these first:

1. `PRODUCT_VISION.md`
2. `docs/plans/2026-04-23-anonymous-board-relaunch.md`
3. `AGENTS.md` April 2026 Relaunch Override

Legacy documents that mention pricing dashboards, input pricing, My Farm, My Bins, elevator maps, market intelligence, or signup-first flows are historical context only.

## Why The Flutter 3.41 / Dart 3.11 Upgrade Matters

Sources:
- Flutter 3.41 announcement: https://blog.flutter.dev/whats-new-in-flutter-3-41-302ec140e632
- Flutter 3.41 release notes: https://docs.flutter.dev/release/release-notes/release-notes-3.41.0
- Dart 3.11 announcement: https://dart.dev/blog/announcing-dart-3-11
- Dart and Flutter MCP server docs: https://docs.flutter.dev/ai/mcp-server

### Genuine Upgrades

1. Predictable release cadence
   - Flutter published 2026 release windows: 3.41 in February, 3.44 in May, 3.47 in August, 3.50 in November.
   - Product impact: schedule quarterly upgrade gates instead of random churn.

2. Better agent workflow
   - Dart 3.11 improves analyzer performance and package URI support for the Dart and Flutter MCP server.
   - Product impact: better AI-assisted refactors, dependency inspection, and Flutter-specific debugging.

3. Mobile reading polish
   - Flutter 3.41 improves scroll/nav behavior, including overscroll and pinned header fixes.
   - Product impact: better feed refresh, thread reading, and "active comments" loops.

4. Accessibility improvements
   - Flutter 3.41 improves progress semantics and respects web text spacing overrides.
   - Product impact: better public-facing readability and less embarrassing first-use friction.

5. Animation primitives
   - `RepeatingAnimationBuilder` gives a clean way to build subtle live-state affordances.
   - Product impact: restrained "new comments", "live", and refresh indicators without heavy custom animation code.

6. Platform-specific assets
   - Flutter 3.41 supports platform-scoped assets.
   - Product impact: remove old data-dashboard payloads from the board app and keep the bundle lean.

### Nice-To-Have Later

- Widget Previews: useful for component QA later, but experimental.
- Fragment shader improvements: visually interesting, but not needed for v1 board value.
- Add-to-app content-sized views: useful only if Agnonymous is embedded inside another native app later.

### Token Burn For This Relaunch

- Market dashboards, price charts, input-price capture, data pipelines, shader experiments, desktop windows, and native add-to-app work.
- These do not help anonymous posting, commenting, reading, refreshing, or moderation.

## Product Direction

### V1 Product Promise

"Anonymous agriculture discussion, with Monette first-class, no sign up, no sign in, fast comments, active threads, and enough moderation to keep it credible."

### P0 Relaunch Features

- Anonymous read/post/comment/vote with no account prompt.
- Monette category first.
- Latest and Active feeds.
- Pull-to-refresh and visible refresh affordance.
- Comment count, vote count, and active thread sorting.
- Mobile-first post composer with optional region and category only.
- RLS and RPCs that allow anonymous posting while preventing obvious self-vote abuse.
- Icon-only bottom post button.
- No top duplicate post prompt.
- No funny reaction button.

### P1 Retention Features

- Watched threads: anonymous-device list with Supabase mirror once migrations are applied.
- New comment markers: show "new since you opened this" based on last seen comment count.
- Active pulse: a subtle indicator when a thread receives comments or votes.
- Draft autosave: local-only post/comment draft recovery.
- Shareable thread links for Monette posts.
- "Jump to newest comment" in long threads.

### P2 High-Value Board Products

- Monette room: category-specific feed with pinned context and active posts.
- Evidence prompts: optional "what did you see / where / when" structure, not required file upload.
- Moderation queue: flag, hide, restore, and audit actions without revealing anonymous user mappings.
- Legal-risk labels: lightweight reminders around naming people, fraud allegations, and unverifiable claims.
- Public read-only archive: permanent links to high-value discussions, still no accounts.

## Hard No

- No fertilizer ticker.
- No input price reporting.
- No marketplace pricing.
- No cash bid tracking.
- No My Farm, My Bins, breakeven calculators, or elevator map.
- No sign-up wall.
- No username-first posting.
- No gamification-first design.

## Current Technical Risk

The linked Supabase project is named `Bushel Board`, but the app `.env` points to the same project ref as the CLI link. The remote migration history has drifted from local files, so do not run a broad `supabase db push`.

Local SQL files added for the relaunch:

- `supabase/migrations/20260423150000_anonymous_board_v1.sql`
- `supabase/migrations/20260423162000_anonymous_post_watches.sql`
- `supabase/migrations/20260423170000_anonymous_board_backfill.sql`

Safe database path:
1. Verify remote columns and RPCs through REST or targeted SQL.
2. Apply only the anonymous-board SQL needed for posts, comments, votes, RLS, and RPCs.
3. Repair migration history only after schema truth is confirmed.
4. Then browser-test anonymous post, comment, vote, active sort, and refresh against production Supabase.

## Next Build Order

1. Database safety: apply targeted relaunch migrations, not broad `db push`.
2. Live-cycle proof: real anonymous post, comment, watch, refresh, and three-way vote.
3. Old-post audit: confirm old categories were remapped and counts backfilled.
4. Mobile polish: density with real posts, long titles, long comments, and small phones.
5. Moderation: report/hide flow and admin-only review path.
6. Launch: Monette-specific route and shareable thread links.
