# Wave 2 Parts 3 & 4 Design — Elevator Map + Farmer Price Reporting

**Date:** 2026-03-04
**Approach:** Database-first, then parallel agent execution (same as Parts 1 & 2)
**Reference specs:** WAVE2_IMPLEMENTATION.md, CONTEXTUAL_CHAT_AND_INVENTORY.md

---

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Map package | `flutter_map` (already installed) | Free, no API key, already in pubspec |
| Dark tiles | CartoDB dark_matter | Free, matches #0F172A theme |
| Clustering | `flutter_map_marker_cluster_plus` | Compatible with flutter_map v8 |
| Elevator data source | CGC GeoJSON from Open Canada portal | Government open data, includes lat/lng, no geocoding needed |
| PostGIS | Already enabled (Part 2 migration) | GEOGRAPHY(POINT, 4326) for spatial queries |
| Confirmation threshold | 3+ confirms, outdated < confirms | Per WAVE2 spec |

---

## Execution Strategy

### Phase 1: Database Migrations (Sequential)

**Migration C: `elevator_locations` + seed data + RPC**
- elevator_locations table with PostGIS GEOGRAPHY column + GIST index
- get_nearest_elevators RPC with LEFT JOIN to local_cash_prices
- get_elevators_by_province RPC (simpler, non-spatial query)
- Seed ~200-500 major elevators from parsed CGC GeoJSON data

**Migration D: `farmer_price_reports` + `price_report_confirmations` + triggers**
- farmer_price_reports table (reporter_id FK auth.users, elevator_location_id FK)
- price_report_confirmations table (UNIQUE report_id + confirmer_id)
- Trigger: update confirm/outdated counts on confirmation INSERT
- Trigger: promote to local_cash_prices when confirm_count >= 3
- price_report_stats table for social proof counters
- Reputation integration: trigger for +3 points on report, +1 on confirm

### Phase 2: Parallel Agents

**Agent 1 — Elevator Map:**
- ElevatorLocation model (fromMap, PostGIS point parsing)
- NearestElevator model (includes distance_km, latest_bid)
- elevatorLocationsProvider + nearestElevatorsProvider
- ElevatorMapScreen with flutter_map + dark tiles + clustering
- Elevator detail bottom sheet (name, company, bids, distance)
- Farm location pin + distance rings (if user has farm_profile.location)
- Integration into Markets screen as 5th tab or Dashboard section

**Agent 2 — Farmer Reporting:**
- FarmerPriceReport model + PriceReportConfirmation model
- farmerPriceReportsProvider + priceReportStatsProvider
- ReportPriceScreen (3-tap flow: select elevator → enter price → publish)
- Confirmation UI on elevator detail sheet (Confirm / Outdated buttons)
- Social proof counter ("147 farmers helped this month")
- Reputation point integration (+3 report, +1 confirm)

---

## Part 3: Elevator Map — Technical Detail

### Map Configuration
- **Tile URL:** `https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png`
- **Subdomains:** `['a', 'b', 'c', 'd']`
- **Default center:** LatLng(52.0, -106.0) — central Saskatchewan
- **Default zoom:** 6 (shows all 3 provinces)
- **Min zoom:** 4, Max zoom: 18

### Map Layers
1. **Elevator markers** — Custom grain elevator icon, color by company:
   - Viterra/Glencore: blue
   - Richardson/Pioneer: green
   - Cargill: orange
   - Parrish & Heimbecker: purple
   - Others: grey
2. **Price badges** — Small chip on marker showing latest PDQ bid (green if above user's breakeven, red if below)
3. **Farm pin** — Home icon if user has farm_profile with location
4. **Distance rings** — Semi-transparent circles at 25/50/100km from farm

### Elevator Detail Bottom Sheet
When user taps a marker:
```
┌─────────────────────────────────┐
│  🏭 Viterra Weyburn              │
│  Weyburn, SK — 34 km away       │
│  ─────────────────────────────  │
│  Latest Bids (PDQ):             │
│  Canola #1: $14.25/bu           │
│  CWRS #1:   $7.95/bu            │
│  ─────────────────────────────  │
│  Farmer Reports:                │
│  Canola: $14.10/bu (2h ago)     │
│  👍 3 confirmed                  │
│  ─────────────────────────────  │
│  [Report a Price]  [Directions] │
└─────────────────────────────────┘
```

### Navigation Placement
- New tab in Markets screen: "Map" (5th tab alongside Grains, Fertilizer, Crop Stats, Cash Prices)
- Also accessible from Dashboard via "Nearby Elevators" card

---

## Part 4: Farmer Price Reporting — Technical Detail

### 3-Tap Flow
1. **Select elevator** — tap marker on map OR search by name
   - Pre-fills: elevator_name, elevator_location_id
   - Pre-selects commodity from user's crop_plans (if logged in)
2. **Enter price** — large number input
   - Grade dropdown (optional): #1, #2, Feed, etc.
   - Unit toggle: $/bushel (default) or $/tonne
   - Optional notes field
3. **Publish** — submit + instant feedback
   - +3 reputation points
   - "Thanks! 23 farmers in your area will see this."
   - Social proof: "You've helped X farmers this crop year"

### Confirmation Mechanism
- On elevator detail sheet, farmer reports show with Confirm/Outdated buttons
- Confirm: +1 to confirm_count, +1 reputation point for confirmer
- Outdated: +1 to outdated_count
- UNIQUE constraint: one confirmation per user per report
- When confirm_count >= 3 AND outdated_count < confirm_count:
  → PostgreSQL trigger promotes report to local_cash_prices with source='farmer_report'

### Social Proof Stats
- price_report_stats table: monthly aggregates per region
- Updated via trigger on farmer_price_reports INSERT
- Displayed on report screen: "147 farmers helped this month"

---

## Out of Scope (Deferred)
- My Bins grain inventory (Wave 3)
- Contextual chat rooms (Wave 4)
- Sell Calculator (Wave 3)
- Offline map tiles
- Elevator directions/routing
- Multi-province comparison views

---

## Success Criteria
- [ ] elevator_locations table with PostGIS + GIST index
- [ ] ~200+ elevators seeded from CGC open data
- [ ] get_nearest_elevators RPC working with distance + latest bid
- [ ] flutter_map rendering with dark tiles and clustered markers
- [ ] Elevator detail bottom sheet with PDQ bids
- [ ] farmer_price_reports + confirmation tracking tables
- [ ] 3-tap reporting flow functional
- [ ] Confirmation trigger promoting to local_cash_prices
- [ ] Reputation points awarded (+3 report, +1 confirm)
- [ ] Social proof counter displayed
- [ ] Minimum 30 new tests across both parts
