# Wave 2 Parts 3 & 4 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Build an interactive elevator map with farmer price reporting and confirmation tracking for western Canadian prairie farmers.

**Architecture:** Database-first migrations (elevator_locations, farmer_price_reports, confirmations), then two parallel agents — one for the flutter_map UI, one for the reporting flow. PostGIS spatial queries power nearest-elevator lookups. Farmer reports promote to local_cash_prices after 3+ community confirmations.

**Tech Stack:** Flutter 3.38.3, flutter_map 8.x, flutter_map_marker_cluster_plus, Supabase PostgreSQL with PostGIS, Riverpod 3.x FutureProvider/Notifier patterns.

---

## Phase 1: Database Migrations (Sequential — Main Agent)

### Task 1: Create `elevator_locations` Migration

**Files:**
- Create: `supabase/migrations/20260304120200_elevator_locations.sql`

**Step 1: Write the migration file**

```sql
-- =============================================================================
-- WAVE 2 PART 3: ELEVATOR LOCATIONS
-- Licensed grain elevators across western Canada with PostGIS spatial queries.
-- Source: CGC (Canadian Grain Commission) open data.
-- =============================================================================

-- PostGIS already enabled in 20260304120100_my_farm_tables.sql

CREATE TABLE elevator_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cgc_license_number TEXT UNIQUE,
  facility_name TEXT NOT NULL,
  company TEXT NOT NULL,
  address TEXT,
  city TEXT NOT NULL,
  province TEXT NOT NULL CHECK (province IN ('SK', 'AB', 'MB')),
  postal_code TEXT,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  location GEOGRAPHY(POINT, 4326) GENERATED ALWAYS AS (
    ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
  ) STORED,
  licensed_capacity_tonnes DECIMAL(12,1),
  grain_types TEXT[],
  facility_type TEXT DEFAULT 'primary',  -- 'primary', 'terminal', 'process'
  is_active BOOLEAN DEFAULT true,
  last_verified DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Spatial index for nearest-elevator queries
CREATE INDEX idx_elevator_geo ON elevator_locations USING GIST(location);
CREATE INDEX idx_elevator_province ON elevator_locations(province);
CREATE INDEX idx_elevator_company ON elevator_locations(company);
CREATE INDEX idx_elevator_active ON elevator_locations(is_active) WHERE is_active = true;

ALTER TABLE elevator_locations ENABLE ROW LEVEL SECURITY;

-- Public read (elevator locations are public reference data)
CREATE POLICY "Anyone can read elevator locations"
  ON elevator_locations FOR SELECT USING (true);

-- Auto-update updated_at
CREATE TRIGGER update_elevator_locations_updated_at
  BEFORE UPDATE ON elevator_locations
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- RPC: GET NEAREST ELEVATORS (PostGIS spatial query)
-- =============================================================================

CREATE OR REPLACE FUNCTION get_nearest_elevators(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_radius_km INTEGER DEFAULT 50,
  p_commodity TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 20
)
RETURNS TABLE(
  id UUID,
  facility_name TEXT,
  company TEXT,
  city TEXT,
  province TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  distance_km DECIMAL,
  latest_bid DECIMAL,
  bid_commodity TEXT,
  bid_date DATE
) AS $$
BEGIN
  p_limit := LEAST(p_limit, 50);
  p_radius_km := LEAST(p_radius_km, 200);

  RETURN QUERY
  SELECT
    e.id, e.facility_name, e.company, e.city, e.province,
    e.latitude, e.longitude,
    ROUND((ST_Distance(
      e.location,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
    ) / 1000)::numeric, 1) as distance_km,
    lcp.bid_price_cad as latest_bid,
    lcp.commodity as bid_commodity,
    lcp.price_date as bid_date
  FROM elevator_locations e
  LEFT JOIN LATERAL (
    SELECT l.bid_price_cad, l.commodity, l.price_date
    FROM local_cash_prices l
    WHERE l.elevator_name = e.facility_name
      AND (p_commodity IS NULL OR l.commodity = p_commodity)
    ORDER BY l.price_date DESC
    LIMIT 1
  ) lcp ON true
  WHERE ST_DWithin(
    e.location,
    ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
    p_radius_km * 1000
  )
    AND e.is_active = true
  ORDER BY ST_Distance(
    e.location,
    ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
  )
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- =============================================================================
-- RPC: GET ELEVATORS BY PROVINCE (simpler, non-spatial)
-- =============================================================================

CREATE OR REPLACE FUNCTION get_elevators_by_province(
  p_province TEXT DEFAULT NULL,
  p_company TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 100
)
RETURNS SETOF elevator_locations AS $$
BEGIN
  p_limit := LEAST(p_limit, 500);

  RETURN QUERY
  SELECT *
  FROM elevator_locations
  WHERE (p_province IS NULL OR province = p_province)
    AND (p_company IS NULL OR company = p_company)
    AND is_active = true
  ORDER BY province, city, facility_name
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- =============================================================================
-- SEED DATA: Major prairie elevators (representative sample)
-- Full dataset loaded separately via Edge Function from CGC GeoJSON
-- =============================================================================

INSERT INTO elevator_locations (facility_name, company, city, province, latitude, longitude, facility_type, grain_types, is_active, last_verified)
VALUES
  -- Saskatchewan
  ('Viterra Weyburn', 'Viterra', 'Weyburn', 'SK', 49.6608, -103.8512, 'primary', ARRAY['Canola','Wheat','Barley','Oats','Peas','Lentils'], true, '2025-11-01'),
  ('Richardson Pioneer Yorkton', 'Richardson Pioneer', 'Yorkton', 'SK', 51.2139, -102.4628, 'primary', ARRAY['Canola','Wheat','Barley','Oats','Flax'], true, '2025-11-01'),
  ('Cargill Saskatoon', 'Cargill', 'Saskatoon', 'SK', 52.1579, -106.6702, 'primary', ARRAY['Canola','Wheat','Barley'], true, '2025-11-01'),
  ('P&H Moose Jaw', 'Parrish & Heimbecker', 'Moose Jaw', 'SK', 50.3934, -105.5519, 'primary', ARRAY['Canola','Wheat','Barley','Oats','Peas'], true, '2025-11-01'),
  ('Viterra Regina', 'Viterra', 'Regina', 'SK', 50.4452, -104.6189, 'primary', ARRAY['Canola','Wheat','Barley','Lentils','Peas'], true, '2025-11-01'),
  ('AGT Foods Regina', 'AGT Foods', 'Regina', 'SK', 50.4500, -104.6150, 'process', ARRAY['Peas','Lentils'], true, '2025-11-01'),
  ('Richardson Pioneer Swift Current', 'Richardson Pioneer', 'Swift Current', 'SK', 50.2851, -107.7975, 'primary', ARRAY['Canola','Wheat','Durum','Barley'], true, '2025-11-01'),
  ('Viterra North Battleford', 'Viterra', 'North Battleford', 'SK', 52.7575, -108.2866, 'primary', ARRAY['Canola','Wheat','Barley','Oats'], true, '2025-11-01'),
  ('Cargill Rosetown', 'Cargill', 'Rosetown', 'SK', 51.5504, -108.0010, 'primary', ARRAY['Canola','Wheat','Durum'], true, '2025-11-01'),
  ('G3 Melville', 'G3 Canada', 'Melville', 'SK', 50.9303, -102.8078, 'primary', ARRAY['Canola','Wheat','Barley','Oats'], true, '2025-11-01'),
  ('Viterra Kindersley', 'Viterra', 'Kindersley', 'SK', 51.4661, -109.1667, 'primary', ARRAY['Canola','Wheat','Durum','Barley'], true, '2025-11-01'),
  ('LDC Rosetown', 'Louis Dreyfus Company', 'Rosetown', 'SK', 51.5520, -107.9950, 'primary', ARRAY['Canola','Wheat'], true, '2025-11-01'),

  -- Alberta
  ('Viterra Lethbridge', 'Viterra', 'Lethbridge', 'AB', 49.6936, -112.8328, 'primary', ARRAY['Canola','Wheat','Barley'], true, '2025-11-01'),
  ('Richardson Pioneer Calgary', 'Richardson Pioneer', 'Calgary', 'AB', 51.0486, -114.0708, 'primary', ARRAY['Canola','Wheat','Barley'], true, '2025-11-01'),
  ('Cargill Claresholm', 'Cargill', 'Claresholm', 'AB', 50.0264, -113.5863, 'primary', ARRAY['Canola','Wheat','Barley','Oats'], true, '2025-11-01'),
  ('P&H Drumheller', 'Parrish & Heimbecker', 'Drumheller', 'AB', 51.4636, -112.7072, 'primary', ARRAY['Canola','Wheat','Barley'], true, '2025-11-01'),
  ('Viterra Camrose', 'Viterra', 'Camrose', 'AB', 53.0167, -112.8340, 'primary', ARRAY['Canola','Wheat','Barley','Peas'], true, '2025-11-01'),
  ('G3 Olds', 'G3 Canada', 'Olds', 'AB', 51.7926, -114.1066, 'primary', ARRAY['Canola','Wheat','Barley'], true, '2025-11-01'),
  ('Richardson Pioneer Red Deer', 'Richardson Pioneer', 'Red Deer', 'AB', 52.2681, -113.8112, 'primary', ARRAY['Canola','Wheat','Barley'], true, '2025-11-01'),
  ('Viterra Vermilion', 'Viterra', 'Vermilion', 'AB', 53.3540, -110.8585, 'primary', ARRAY['Canola','Wheat','Barley','Peas'], true, '2025-11-01'),

  -- Manitoba
  ('Viterra Winnipeg', 'Viterra', 'Winnipeg', 'MB', 49.8951, -97.1384, 'terminal', ARRAY['Canola','Wheat','Barley','Oats','Soybeans'], true, '2025-11-01'),
  ('Richardson Pioneer Winnipeg', 'Richardson Pioneer', 'Winnipeg', 'MB', 49.8800, -97.1500, 'terminal', ARRAY['Canola','Wheat','Barley'], true, '2025-11-01'),
  ('Cargill Morris', 'Cargill', 'Morris', 'MB', 49.3550, -97.3659, 'primary', ARRAY['Canola','Wheat','Soybeans','Corn'], true, '2025-11-01'),
  ('P&H Brandon', 'Parrish & Heimbecker', 'Brandon', 'MB', 49.8440, -99.9539, 'primary', ARRAY['Canola','Wheat','Barley','Oats'], true, '2025-11-01'),
  ('Viterra Portage la Prairie', 'Viterra', 'Portage la Prairie', 'MB', 49.9728, -98.2925, 'primary', ARRAY['Canola','Wheat','Barley','Oats','Soybeans'], true, '2025-11-01'),
  ('G3 Glenlea', 'G3 Canada', 'Glenlea', 'MB', 49.6460, -97.1117, 'primary', ARRAY['Canola','Wheat','Soybeans'], true, '2025-11-01'),
  ('Richardson Pioneer Dauphin', 'Richardson Pioneer', 'Dauphin', 'MB', 51.1496, -100.0498, 'primary', ARRAY['Canola','Wheat','Barley','Oats'], true, '2025-11-01'),
  ('Viterra Virden', 'Viterra', 'Virden', 'MB', 49.8508, -100.9320, 'primary', ARRAY['Canola','Wheat','Barley','Oats'], true, '2025-11-01')
ON CONFLICT (cgc_license_number) DO NOTHING;

-- Seed data source config for CGC elevator data
INSERT INTO data_source_config (source_name, source_type, endpoint_url, fetch_schedule, config, is_active)
VALUES (
  'cgc_elevator_locations',
  'cgc_geojson',
  'https://open.canada.ca/data/en/dataset/a84859bd-68c7-43d2-942b-f894b9a4a2dc',
  '0 0 1 8 *',  -- Annual: August 1 (CGC publishes elevator list annually)
  '{"format": "geojson", "coverage": ["AB", "SK", "MB"], "note": "Annual bulk load from CGC open data"}'::jsonb,
  true
) ON CONFLICT (source_name) DO NOTHING;
```

**Step 2: Verify PostGIS is available**

PostGIS was already enabled in migration `20260304120100_my_farm_tables.sql`. The GENERATED ALWAYS column for `location` uses `ST_SetSRID(ST_MakePoint())` which requires PostGIS.

**Step 3: Commit**

```bash
git add supabase/migrations/20260304120200_elevator_locations.sql
git commit -m "feat: add elevator_locations table with PostGIS spatial queries and seed data"
```

---

### Task 2: Create `farmer_price_reports` Migration

**Files:**
- Create: `supabase/migrations/20260304120300_farmer_price_reports.sql`

**Step 1: Write the migration file**

```sql
-- =============================================================================
-- WAVE 2 PART 4: FARMER PRICE REPORTING & CONFIRMATION TRACKING
-- Farmers report elevator bids, community confirms, promoted prices appear on map.
-- =============================================================================

-- =============================================================================
-- FARMER PRICE REPORTS
-- =============================================================================

CREATE TABLE farmer_price_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID NOT NULL REFERENCES auth.users(id),
  elevator_location_id UUID REFERENCES elevator_locations(id),
  elevator_name TEXT NOT NULL,
  commodity TEXT NOT NULL,
  grade TEXT,
  reported_bid_cad DECIMAL(10,2) NOT NULL,
  bid_unit TEXT DEFAULT 'bushel' CHECK (bid_unit IN ('bushel', 'tonne')),
  notes TEXT,
  confirm_count INTEGER DEFAULT 0,
  outdated_count INTEGER DEFAULT 0,
  is_promoted BOOLEAN DEFAULT false,
  reputation_points_awarded BOOLEAN DEFAULT false,
  reported_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_price_reports_elevator ON farmer_price_reports(elevator_location_id);
CREATE INDEX idx_price_reports_reporter ON farmer_price_reports(reporter_id);
CREATE INDEX idx_price_reports_commodity ON farmer_price_reports(commodity);
CREATE INDEX idx_price_reports_date ON farmer_price_reports(reported_at DESC);

ALTER TABLE farmer_price_reports ENABLE ROW LEVEL SECURITY;

-- Anyone can read reports (market data is public)
CREATE POLICY "Anyone can read price reports"
  ON farmer_price_reports FOR SELECT USING (true);
-- Authenticated users can insert their own reports
CREATE POLICY "Users can insert their own reports"
  ON farmer_price_reports FOR INSERT
  WITH CHECK (auth.uid() = reporter_id);

-- =============================================================================
-- PRICE REPORT CONFIRMATIONS
-- =============================================================================

CREATE TABLE price_report_confirmations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id UUID NOT NULL REFERENCES farmer_price_reports(id) ON DELETE CASCADE,
  confirmer_id UUID NOT NULL REFERENCES auth.users(id),
  confirmation_type TEXT NOT NULL CHECK (confirmation_type IN ('confirm', 'outdated')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(report_id, confirmer_id)
);

CREATE INDEX idx_confirmations_report ON price_report_confirmations(report_id);

ALTER TABLE price_report_confirmations ENABLE ROW LEVEL SECURITY;

-- Anyone can read confirmations
CREATE POLICY "Anyone can read confirmations"
  ON price_report_confirmations FOR SELECT USING (true);
-- Authenticated users can insert their own confirmations
CREATE POLICY "Users can insert their own confirmations"
  ON price_report_confirmations FOR INSERT
  WITH CHECK (auth.uid() = confirmer_id);

-- =============================================================================
-- TRIGGER: Update confirm/outdated counts on confirmation INSERT
-- =============================================================================

CREATE OR REPLACE FUNCTION update_confirmation_counts()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.confirmation_type = 'confirm' THEN
    UPDATE farmer_price_reports
    SET confirm_count = confirm_count + 1
    WHERE id = NEW.report_id;
  ELSIF NEW.confirmation_type = 'outdated' THEN
    UPDATE farmer_price_reports
    SET outdated_count = outdated_count + 1
    WHERE id = NEW.report_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_confirmation_insert
  AFTER INSERT ON price_report_confirmations
  FOR EACH ROW EXECUTE FUNCTION update_confirmation_counts();

-- =============================================================================
-- TRIGGER: Promote to local_cash_prices when 3+ confirmations
-- =============================================================================

CREATE OR REPLACE FUNCTION promote_confirmed_report()
RETURNS TRIGGER AS $$
DECLARE
  v_report farmer_price_reports%ROWTYPE;
BEGIN
  -- Only run when confirm_count was just updated
  IF NEW.confirm_count >= 3
    AND NEW.outdated_count < NEW.confirm_count
    AND NEW.is_promoted = false
  THEN
    -- Insert into local_cash_prices as farmer-verified price
    INSERT INTO local_cash_prices (
      source, elevator_name, commodity, grade,
      bid_price_cad, bid_unit, price_date
    ) VALUES (
      'farmer_report',
      NEW.elevator_name,
      NEW.commodity,
      NEW.grade,
      NEW.reported_bid_cad,
      NEW.bid_unit,
      NEW.reported_at::date
    )
    ON CONFLICT (source, elevator_name, commodity, grade, price_date)
    DO UPDATE SET bid_price_cad = EXCLUDED.bid_price_cad, fetched_at = NOW();

    -- Mark as promoted
    UPDATE farmer_price_reports SET is_promoted = true WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_report_count_update
  AFTER UPDATE OF confirm_count ON farmer_price_reports
  FOR EACH ROW EXECUTE FUNCTION promote_confirmed_report();

-- =============================================================================
-- REPUTATION INTEGRATION
-- =============================================================================

-- Award +3 points for submitting a price report
CREATE OR REPLACE FUNCTION award_report_reputation()
RETURNS TRIGGER AS $$
BEGIN
  -- Award reputation points to reporter
  UPDATE user_profiles
  SET reputation_points = COALESCE(reputation_points, 0) + 3
  WHERE id = (SELECT id FROM user_profiles WHERE user_id = NEW.reporter_id LIMIT 1);

  -- Log the reputation change
  INSERT INTO reputation_logs (user_id, action, points_change, details)
  VALUES (
    NEW.reporter_id,
    'price_report',
    3,
    'Submitted price report for ' || NEW.commodity || ' at ' || NEW.elevator_name
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_price_report_insert
  AFTER INSERT ON farmer_price_reports
  FOR EACH ROW EXECUTE FUNCTION award_report_reputation();

-- Award +1 point for confirming a price report
CREATE OR REPLACE FUNCTION award_confirmation_reputation()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.confirmation_type = 'confirm' THEN
    UPDATE user_profiles
    SET reputation_points = COALESCE(reputation_points, 0) + 1
    WHERE id = (SELECT id FROM user_profiles WHERE user_id = NEW.confirmer_id LIMIT 1);

    INSERT INTO reputation_logs (user_id, action, points_change, details)
    VALUES (
      NEW.confirmer_id,
      'price_confirmation',
      1,
      'Confirmed a price report'
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_confirmation_reputation
  AFTER INSERT ON price_report_confirmations
  FOR EACH ROW EXECUTE FUNCTION award_confirmation_reputation();

-- =============================================================================
-- SOCIAL PROOF STATS
-- =============================================================================

CREATE TABLE price_report_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  period TEXT NOT NULL,
  total_reports INTEGER DEFAULT 0,
  total_farmers_helped INTEGER DEFAULT 0,
  total_confirmations INTEGER DEFAULT 0,
  region TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(period, region)
);

ALTER TABLE price_report_stats ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read report stats"
  ON price_report_stats FOR SELECT USING (true);

-- =============================================================================
-- RPC: GET ELEVATOR REPORTS (recent reports for an elevator)
-- =============================================================================

CREATE OR REPLACE FUNCTION get_elevator_reports(
  p_elevator_id UUID,
  p_days INTEGER DEFAULT 7
)
RETURNS TABLE(
  id UUID,
  commodity TEXT,
  grade TEXT,
  reported_bid_cad DECIMAL,
  bid_unit TEXT,
  confirm_count INTEGER,
  outdated_count INTEGER,
  is_promoted BOOLEAN,
  reported_at TIMESTAMPTZ,
  reporter_display_name TEXT,
  reporter_reputation_level INTEGER
) AS $$
BEGIN
  p_days := LEAST(p_days, 30);

  RETURN QUERY
  SELECT
    r.id, r.commodity, r.grade, r.reported_bid_cad, r.bid_unit,
    r.confirm_count, r.outdated_count, r.is_promoted, r.reported_at,
    COALESCE(up.display_name, 'Anonymous') as reporter_display_name,
    COALESCE(up.reputation_level, 0) as reporter_reputation_level
  FROM farmer_price_reports r
  LEFT JOIN user_profiles up ON up.user_id = r.reporter_id
  WHERE r.elevator_location_id = p_elevator_id
    AND r.reported_at >= NOW() - (p_days || ' days')::interval
  ORDER BY r.reported_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- =============================================================================
-- RPC: GET MONTHLY REPORT STATS (social proof counter)
-- =============================================================================

CREATE OR REPLACE FUNCTION get_monthly_report_stats(
  p_region TEXT DEFAULT NULL
)
RETURNS TABLE(
  total_reports BIGINT,
  total_confirmations BIGINT,
  unique_reporters BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*)::bigint as total_reports,
    COALESCE(SUM(r.confirm_count), 0)::bigint as total_confirmations,
    COUNT(DISTINCT r.reporter_id)::bigint as unique_reporters
  FROM farmer_price_reports r
  WHERE r.reported_at >= date_trunc('month', NOW())
    AND (p_region IS NULL OR
      r.elevator_name IN (
        SELECT e.facility_name FROM elevator_locations e WHERE e.province = p_region
      )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
```

**Step 2: Commit**

```bash
git add supabase/migrations/20260304120300_farmer_price_reports.sql
git commit -m "feat: add farmer_price_reports with confirmation tracking and auto-promotion trigger"
```

---

## Phase 2: Parallel Agent Work

### Agent 1 — Elevator Map (Tasks 3-7)

---

### Task 3: ElevatorLocation + NearestElevator Models

**Files:**
- Create: `lib/models/elevator_location.dart`
- Create: `_test/models/elevator_location_test.dart`

**Context:** These models represent grain elevator facilities. `ElevatorLocation` maps directly to the `elevator_locations` table. `NearestElevator` is the result from `get_nearest_elevators` RPC which includes distance and latest bid data.

**Requirements:**
- `ElevatorLocation` class with all table fields
- `fromMap()` factory (not fromJson — project convention)
- `toInsertMap()` excluding id, location (generated), created_at, updated_at
- `copyWith()` method
- `companyColor` getter that returns a Color based on company name (Viterra=blue, Richardson=green, Cargill=orange, P&H=purple, others=grey)
- `NearestElevator` class with: id, facilityName, company, city, province, latitude, longitude, distanceKm, latestBid, bidCommodity, bidDate
- `fromMap()` factory with safe `_toDouble()` helper (handles num/String/int → double)
- `formattedDistance` getter: "34.2 km"
- `formattedBid` getter: "C$14.25/bu" or "No bid"
- `ElevatorFilterParams` class with province, company, commodity — override `==` and `hashCode`

**Tests (minimum 15):**
- ElevatorLocation: fromMap with all fields, fromMap with nulls, toInsertMap excludes generated columns, copyWith, companyColor for each major company
- NearestElevator: fromMap, formattedDistance, formattedBid with data, formattedBid with null
- ElevatorFilterParams: equality, hashCode

---

### Task 4: Elevator Providers

**Files:**
- Create: `lib/providers/elevator_locations_provider.dart`

**Context:** Providers for loading elevator locations. Two main providers: one for all elevators by province (map markers), one for nearest elevators (PostGIS query when user has farm location).

**Requirements:**
- `elevatorLocationsProvider` — `FutureProvider.family<List<ElevatorLocation>, ElevatorFilterParams>` calling `get_elevators_by_province` RPC
- `nearestElevatorsProvider` — `FutureProvider.family<List<NearestElevator>, NearestElevatorParams>` calling `get_nearest_elevators` RPC
- `NearestElevatorParams` class: lat, lng, radiusKm, commodity, limit — override `==` and `hashCode`
- Both providers use Supabase `rpc()` calls
- Import models from `elevator_location.dart`

**Pattern to follow:** See `lib/providers/local_cash_prices_provider.dart` for the FutureProvider.family + Params pattern.

---

### Task 5: Elevator Map Screen

**Files:**
- Create: `lib/screens/map/elevator_map_screen.dart`

**Context:** Interactive map showing grain elevators across western Canada. Uses flutter_map with CartoDB dark tiles. Markers are clustered at low zoom levels.

**Dependencies:** Add `flutter_map_marker_cluster_plus` to pubspec.yaml (compatible with flutter_map v8). Add `latlong2` if not already present (flutter_map uses LatLng from this package).

**Requirements:**
- `ElevatorMapScreen` as `ConsumerStatefulWidget`
- FlutterMap with dark CartoDB tiles: `https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png`
- Subdomains: `['a', 'b', 'c', 'd']`
- Default center: `LatLng(52.0, -106.0)` (central SK), zoom 6
- Min zoom: 4, Max zoom: 18
- MarkerClusterLayerWidget wrapping elevator markers
- Each marker: grain elevator icon (FontAwesome warehouse or similar), colored by company
- Marker tap → calls `_showElevatorDetail()` (bottom sheet, Task 6)
- Province filter chips at top (All, SK, AB, MB)
- Commodity filter dropdown
- Loading shimmer while data loads
- Error state with retry button
- If user has farm_profile with location: show farm pin (home icon, green) + semi-transparent distance rings at 25/50/100km
- Watch `elevatorLocationsProvider` with current filter params
- Watch `farmProfileProvider` for farm location (if logged in)

**UI Style:**
- Background: Color(0xFF0F172A)
- Filter bar: GlassContainer with blur
- Markers: 32x32 circular icons with company color border
- Cluster badge: circular count indicator with primary green background

---

### Task 6: Elevator Detail Bottom Sheet

**Files:**
- Create: `lib/widgets/map/elevator_detail_sheet.dart`

**Context:** When user taps an elevator marker, this bottom sheet slides up showing elevator details, PDQ bids, and farmer reports.

**Requirements:**
- `ElevatorDetailSheet` as `ConsumerWidget`, takes `ElevatorLocation` or `NearestElevator` as parameter
- Shows: facility_name, company, city + province, distance (if available)
- "Latest Bids" section: watches `localCashPricesProvider` filtered by elevator_name
- "Farmer Reports" section: watches a provider for recent farmer reports at this elevator (from `get_elevator_reports` RPC)
- Each farmer report shows: commodity, bid, time ago, confirm count, confirm/outdated buttons
- "Report a Price" button at bottom → navigates to report screen (Task 10)
- GlassContainer styling, dark theme
- DraggableScrollableSheet with snap points at 0.4 and 0.85

---

### Task 7: Map Integration into Navigation

**Files:**
- Modify: `lib/screens/market/markets_screen.dart` (add Map tab, change TabController length to 5)
- Modify: `lib/screens/dashboard/home_dashboard_screen.dart` (add "Nearby Elevators" card)

**Context:** The elevator map needs to be accessible from two places: as a tab in Markets, and as a card on the Dashboard.

**Requirements for markets_screen.dart:**
- Add 5th tab "Map" with ElevatorMapScreen
- Update TabController length from 4 to 5
- Tab order: Grains, Fertilizer, Cash Prices, Crop Stats, Map

**Requirements for home_dashboard_screen.dart:**
- Add "Nearby Elevators" section below existing My Farm section
- Only visible when user has farm_profile with location
- Shows 3 nearest elevators as compact GlassContainer cards (facility name, distance, latest bid)
- "See All on Map →" link navigates to Markets screen Map tab

---

### Agent 2 — Farmer Reporting (Tasks 8-12)

---

### Task 8: FarmerPriceReport + PriceReportConfirmation Models

**Files:**
- Create: `lib/models/farmer_price_report.dart`
- Create: `_test/models/farmer_price_report_test.dart`

**Context:** Models for farmer-submitted price reports and community confirmations. Reports can be promoted to local_cash_prices after 3+ confirmations.

**Requirements:**
- `FarmerPriceReport` class with all table fields: id, reporterId, elevatorLocationId, elevatorName, commodity, grade, reportedBidCad, bidUnit, notes, confirmCount, outdatedCount, isPromoted, reportedAt
- `fromMap()` factory with safe `_toDouble()` for numeric fields
- `toInsertMap()` excluding id, confirm_count, outdated_count, is_promoted, reputation_points_awarded, created_at (server-managed)
- `formattedBid` getter: "C$14.25/bu" or "C$520.00/t"
- `timeAgo` getter: "2h ago", "Yesterday", "3d ago" (relative to now)
- `isReliable` getter: confirmCount >= 3 && outdatedCount < confirmCount
- `PriceReportConfirmation` class: id, reportId, confirmerId, confirmationType, createdAt
- `fromMap()` factory
- `toInsertMap()` excluding id, created_at
- `MonthlyReportStats` class: totalReports, totalConfirmations, uniqueReporters
- `fromMap()` factory

**Tests (minimum 15):**
- FarmerPriceReport: fromMap, toInsertMap, formattedBid bushel, formattedBid tonne, timeAgo recent, timeAgo old, isReliable true, isReliable false (low confirms), isReliable false (high outdated)
- PriceReportConfirmation: fromMap, toInsertMap, confirmation types
- MonthlyReportStats: fromMap, default values

---

### Task 9: Farmer Reporting Providers

**Files:**
- Create: `lib/providers/farmer_reports_provider.dart`

**Context:** Providers for submitting price reports, confirming reports, and loading report stats.

**Requirements:**
- `elevatorReportsProvider` — `FutureProvider.family<List<FarmerPriceReport>, ElevatorReportsParams>` calling `get_elevator_reports` RPC
- `ElevatorReportsParams`: elevatorId (UUID string), days (default 7) — override `==` and `hashCode`
- `monthlyReportStatsProvider` — `FutureProvider.family<MonthlyReportStats, String?>` calling `get_monthly_report_stats` RPC (param is optional region)
- `submitPriceReport` function: inserts into farmer_price_reports table, returns the created report
- `submitConfirmation` function: inserts into price_report_confirmations, handles UNIQUE constraint violation gracefully (user already confirmed)
- `hasUserConfirmedProvider` — `FutureProvider.family<bool, UserConfirmParams>` checks if current user has already confirmed a specific report

**Pattern to follow:** See `lib/providers/local_cash_prices_provider.dart` and `lib/providers/my_farm_provider.dart`

---

### Task 10: Report Price Screen

**Files:**
- Create: `lib/screens/reporting/report_price_screen.dart`

**Context:** 3-tap flow for farmers to report elevator bid prices. Can be opened from elevator detail sheet (pre-filled) or from My Farm screen.

**Requirements:**
- `ReportPriceScreen` as `ConsumerStatefulWidget`
- Takes optional `elevatorLocationId`, `elevatorName`, `preselectedCommodity` parameters
- **Step 1 — Select Elevator:** If not pre-filled, show searchable list of elevators (from elevatorLocationsProvider). Search field with GlassTextField, results in ListView
- **Step 2 — Enter Price:** Large number input field for bid price. Grade dropdown (optional): '#1', '#2', '#3', 'Feed', 'Sample'. Unit toggle: $/bushel (default) or $/tonne. Optional notes TextField. Pre-select commodity from user's crop_plans if available
- **Step 3 — Publish:** Submit button with social proof counter ("147 farmers helped this month" from monthlyReportStatsProvider). On submit: call submitPriceReport, show success feedback with flutter_animate, display "+3 reputation points", show "X farmers in your area will see this"
- Use PageView for step navigation (like My Farm onboarding)
- GlassContainer styling, dark theme, 390px viewport compatible
- Validation: bid price > 0 required, elevator required, commodity required

---

### Task 11: Confirmation UI Widget

**Files:**
- Create: `lib/widgets/reporting/confirmation_buttons.dart`
- Create: `_test/widgets/confirmation_buttons_test.dart`

**Context:** Reusable widget showing Confirm/Outdated buttons for a farmer price report. Used in elevator detail bottom sheet.

**Requirements:**
- `ConfirmationButtons` as `ConsumerWidget`, takes `FarmerPriceReport` as parameter
- Shows current confirm_count and outdated_count
- Two buttons: "Confirm" (green, thumbs up) and "Outdated" (orange, thumbs down)
- Disabled if user not logged in (show "Login to confirm")
- Disabled if user has already confirmed (check hasUserConfirmedProvider)
- On tap: calls submitConfirmation, shows brief success animation
- Displays "+1 reputation" feedback after confirming
- Error handling for duplicate confirmation (UNIQUE constraint)

**Tests (minimum 5):**
- Renders with report data
- Shows correct counts
- Disabled state for already confirmed
- Disabled state for not logged in
- Handles both confirmation types

---

### Task 12: Social Proof & Stats Integration

**Files:**
- Create: `lib/widgets/reporting/social_proof_counter.dart`
- Modify: `lib/screens/dashboard/home_dashboard_screen.dart` (add community price reporting card)

**Context:** Social proof elements that encourage price reporting by showing community impact.

**Requirements for social_proof_counter.dart:**
- `SocialProofCounter` as `ConsumerWidget`, takes optional `region` parameter
- Watches `monthlyReportStatsProvider`
- Displays: "🌾 {totalReports} prices reported this month"
- Secondary line: "{uniqueReporters} farmers contributing"
- GlassContainer with subtle green border
- Animated counter (CountUp style with flutter_animate)

**Requirements for home_dashboard_screen.dart:**
- Add "Community Prices" card section below existing sections
- Shows social proof counter
- Shows 2-3 latest farmer reports across all elevators
- "Report a Price →" CTA button
- Only visible to logged-in users

---

## Dependency Notes

- **flutter_map_marker_cluster_plus**: Must be added to pubspec.yaml. Compatible with flutter_map v8.
- **latlong2**: Check if already transitive dependency of flutter_map. If not, add explicitly.
- **PostGIS**: Already enabled from Part 2 migration. No action needed.
- **data_source_config table**: Already exists from Wave 1 migrations. Seed data INSERT uses ON CONFLICT.
- **user_profiles table**: Already exists with reputation_points and reputation_level columns. Reputation triggers reference these.
- **reputation_logs table**: Already exists from gamification system. Reputation triggers INSERT into this.
- **local_cash_prices table**: Already exists from Part 1 migration. Promotion trigger INSERTs farmer-confirmed prices here.

## Test Summary Target

| Component | Test Count |
|-----------|-----------|
| ElevatorLocation model | 10 |
| NearestElevator model | 5 |
| FarmerPriceReport model | 9 |
| PriceReportConfirmation model | 3 |
| MonthlyReportStats model | 2 |
| ConfirmationButtons widget | 5 |
| ElevatorMapScreen widget | 3 |
| ReportPriceScreen widget | 3 |
| **Total** | **40** |
