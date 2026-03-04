# Wave 2 Parts 1 & 2 Design — PDQ Prices + My Farm

**Date:** 2026-03-03
**Approach:** Database-first, then parallel agent execution
**Reference specs:** WAVE2_IMPLEMENTATION.md, FARMER_TARGETS_FEATURE.md, DATA_SOURCE_ARCHITECTURE.md

---

## Execution Strategy

### Phase 1: Database Migrations (Sequential)
Create all Wave 2 tables in one coordinated pass to avoid migration conflicts between parallel agents.

### Phase 2: Parallel Agent Work
- **Agent 1 — PDQ Pipeline:** Edge Function + model + provider + tests
- **Agent 2 — My Farm:** Models + providers + onboarding screens + seed data + tests

---

## Phase 1: Database Migrations

### Migration A: `local_cash_prices`
Schema from WAVE2_IMPLEMENTATION.md:
- Columns: `source`, `elevator_name`, `company`, `location_city`, `location_province`, `commodity`, `grade`, `bid_price_cad`, `bid_unit`, `basis`, `futures_reference`, `price_date`, `fetched_at`
- Unique constraint: `(source, elevator_name, commodity, grade, price_date)`
- RLS: public read, service role write
- Indexes: commodity, province, date DESC

### Migration B: `farm_profiles` + `crop_plans` + `provincial_cost_defaults`

**farm_profiles:**
- Columns: `user_id` (FK auth.users), `province` (CHECK SK/AB/MB), `nearest_city`, `total_acres`, `location` (GEOGRAPHY POINT optional), `engagement_level`
- RLS: users see/edit only their own (auth.uid() = user_id)
- Unique on user_id

**crop_plans:**
- FK to farm_profiles(id) ON DELETE CASCADE
- Cost columns (WAVE2 naming): `seed_cost_per_acre`, `fertilizer_cost_per_acre`, `chemical_cost_per_acre`, `fuel_cost_per_acre`, `crop_insurance_per_acre`, `land_cost_per_acre`, `equipment_cost_per_acre`, `labour_cost_per_acre`, `other_cost_per_acre`
- Generated columns: `total_cost_per_acre`, `breakeven_price_per_bu` (computed from costs / target_yield)
- RLS: users see/edit only their own via farm_profiles FK chain

**provincial_cost_defaults:**
- Public read reference data
- Pre-seeded with Manitoba crop production guide numbers:
  - Canola: $669.99 total, 45 bu/ac yield, $14.89/bu breakeven
  - Wheat HRS: $584.46, 66 bu/ac, $8.86/bu
  - Soybeans: $533.39, 42 bu/ac, $12.70/bu
  - Oats: $538.55, 120 bu/ac, $4.49/bu
  - Barley: $508.80, 80 bu/ac, $6.36/bu
  - Peas: $503.67, 55 bu/ac, $9.16/bu
  - Corn: $849.28, 145 bu/ac, $5.86/bu
  - Lentils: $500.29, 29 bu/ac, $17.25/bu
  - Flaxseed: $500.29, 29 bu/ac, $17.25/bu

---

## Phase 2, Agent 1: PDQ Cash Prices Pipeline

### Step 1: Data Source Evaluation
- Check Alberta Grains / PDQ Terms of Service for automated access
- Identify whether an API exists or if HTML scraping is required
- If ToS blocks scraping: investigate Alberta Grains data feed contact, provincial open data portals
- **Report to user before writing any pipeline code**

### Step 2: Edge Function `fetch-pdq-prices`
- Schedule: Daily at 6pm MST (after markets close) via pg_cron
- Follow existing patterns from `fetch-cgc-grain-data/index.ts`
- Use `fetchWithRetry()`, generic error messages, honest User-Agent
- Parse PDQ HTML tables into structured price data
- Upsert to `local_cash_prices` with source='pdq'
- Log to `data_pipeline_logs`

### Step 3: Flutter Integration
- **Model:** `CashPrice` in `lib/models/cash_price.dart`
  - Fields: source, elevatorName, company, locationCity, locationProvince, commodity, grade, bidPriceCad, bidUnit, basis, futuresReference, priceDate
  - fromJson/toJson, equality, copyWith
- **Provider:** `localCashPricesProvider` in `lib/providers/local_cash_prices_provider.dart`
  - FutureProvider.family with CashPriceParams (commodity, province, days)
  - Calls Supabase RPC `get_cash_prices`
- **UI:** Cash prices section integrated into Markets screen (within Grains tab or as new sub-tab)

### Step 4: Tests
- CashPrice model: fromJson, toJson, equality, null field handling
- CashPriceParams: validation, defaults
- Edge Function: mock HTML response parsing

---

## Phase 2, Agent 2: My Farm Feature

### Step 1: Models
- `FarmProfile` in `lib/models/farm_profile.dart`
  - Fields: id, userId, province, nearestCity, totalAcres, engagementLevel
  - fromJson/toJson, copyWith
- `CropPlan` in `lib/models/crop_plan.dart`
  - Fields: all cost columns + planned_acres, target_yield, commodity, cropYear
  - Computed: totalCostPerAcre, breakevenPricePerBu (mirrors DB generated columns)
  - fromJson/toJson, copyWith
- `ProvincialCostDefault` in `lib/models/provincial_cost_default.dart`
  - Same cost fields, plus sourceDocument
  - fromJson/toJson

### Step 2: Providers
- `farmProfileProvider` — Notifier, CRUD for user's farm profile
- `cropPlanProvider` — Notifier, CRUD for crop plans, auto-populate from provincial defaults
- `provincialDefaultsProvider` — FutureProvider, loads defaults for a province
- `breakevenProvider` — FutureProvider.family, computes breakeven vs current market price per commodity

### Step 3: Screens (4-step onboarding)
All in glassmorphism dark theme, verified at 390px width.

1. **Province Selection** — single tap SK/AB/MB, triggers loading provincial defaults
2. **Crop Selection** — grid of crop cards, tap to toggle, enter acres. Pre-selected: top 3 for province
3. **Cost Entry** — per selected crop, pre-populated from defaults. Farmer adjusts key values. "Use provincial average" reset button. Shows live breakeven as numbers change
4. **Breakeven Dashboard** — breakeven per crop, color-coded gap vs current bids (green = profitable, red = below breakeven)

### Step 4: Seed Data
Manitoba crop production guide data inserted via migration into `provincial_cost_defaults`.
Saskatchewan: partial (populate what's available, "Coming soon" for gaps).
Alberta: placeholder with "Coming soon" messaging.

### Step 5: Tests
- FarmProfile model: fromJson, toJson, engagement level
- CropPlan model: breakeven calculation, cost totaling, null handling
- ProvincialCostDefault model: all MB crops
- Widget smoke tests: each onboarding step renders without error

---

## Navigation Integration

### Dashboard behavior by auth state:
- **Not logged in:** Existing dashboard (grain highlights, community pulse, metrics)
- **Logged in, no farm profile:** "Set Up My Farm" glass CTA card on dashboard
- **Logged in, farm set up:** Breakeven summary cards per crop above grain highlights

### PDQ <-> My Farm connection:
`breakevenProvider` reads from `local_cash_prices` for current bid per commodity.
No direct coupling between Agent 1 and Agent 2 code — shared via the database.

---

## Out of Scope (Deferred)
- Elevator Map (Part 3) — needs PostGIS + Part 1
- Farmer Price Reporting (Part 4) — needs Parts 2 + 3
- Multi-year tracking, scenario modeling, hedging calculator — Wave 5+
- Breakeven alerts / push notifications — later
- Saskatchewan/Alberta full cost data — populate as guides become available

---

## Success Criteria
- [ ] All 4 tables created with correct RLS policies
- [ ] Manitoba provincial defaults seeded with real data
- [ ] PDQ data source evaluated (ToS checked, approach decided)
- [ ] PDQ Edge Function fetching and upserting daily (if ToS allows)
- [ ] CashPrice model + provider working
- [ ] My Farm 4-step onboarding flow complete and functional
- [ ] Breakeven cards visible on dashboard for logged-in users with farm profiles
- [ ] Minimum 20 new tests across both parts
- [ ] All screens verified at 390px viewport width
