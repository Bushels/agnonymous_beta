# Wave 2: PDQ Cash Prices + My Farm — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Give farmers daily cash prices from PDQ and a personal breakeven calculator ("My Farm") that shows whether selling today makes money or loses it.

**Architecture:** Database-first approach — create all Supabase migrations in Phase 1, then dispatch two parallel agents for Phase 2. Agent 1 builds the PDQ pipeline (Edge Function + model + provider + UI). Agent 2 builds My Farm (models + providers + 4-step onboarding + breakeven dashboard). Both agents share the `local_cash_prices` table but have no code coupling.

**Tech Stack:** Flutter 3.38.3, Dart 3.10.1, flutter_riverpod 3.0.3, Supabase (PostgreSQL 15+, Edge Functions in Deno/TypeScript), fl_chart 1.1.1, flutter_animate 4.5.2

---

## Phase 1: Database Migrations (Sequential)

### Task 1: Create `local_cash_prices` migration

**Files:**
- Create: `supabase/migrations/20260304120000_local_cash_prices.sql`

**Step 1: Write the migration**

```sql
-- Wave 2 Part 1: Local Cash Prices (PDQ + future farmer reports)
CREATE TABLE local_cash_prices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source TEXT NOT NULL DEFAULT 'pdq',
  elevator_name TEXT NOT NULL,
  company TEXT,
  location_city TEXT,
  location_province TEXT NOT NULL,
  commodity TEXT NOT NULL,
  grade TEXT,
  bid_price_cad DECIMAL(10,2),
  bid_unit TEXT DEFAULT 'tonne',
  basis DECIMAL(10,2),
  futures_reference TEXT,
  price_date DATE NOT NULL,
  fetched_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(source, elevator_name, commodity, grade, price_date)
);

CREATE INDEX idx_cash_prices_commodity ON local_cash_prices(commodity);
CREATE INDEX idx_cash_prices_province ON local_cash_prices(location_province);
CREATE INDEX idx_cash_prices_date ON local_cash_prices(price_date DESC);
CREATE INDEX idx_cash_prices_source_date ON local_cash_prices(source, price_date DESC);

ALTER TABLE local_cash_prices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read cash prices"
  ON local_cash_prices FOR SELECT USING (true);

-- RPC: Get cash prices with filtering
CREATE OR REPLACE FUNCTION get_cash_prices(
  p_commodity TEXT DEFAULT NULL,
  p_province TEXT DEFAULT NULL,
  p_source TEXT DEFAULT NULL,
  p_days INTEGER DEFAULT 30
)
RETURNS SETOF local_cash_prices AS $$
BEGIN
  p_days := LEAST(p_days, 365);

  RETURN QUERY
  SELECT *
  FROM local_cash_prices
  WHERE (p_commodity IS NULL OR commodity = p_commodity)
    AND (p_province IS NULL OR location_province = p_province)
    AND (p_source IS NULL OR source = p_source)
    AND price_date >= CURRENT_DATE - p_days
  ORDER BY price_date DESC, elevator_name ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Seed data_source_config for PDQ
INSERT INTO data_source_config (source_name, display_name, description, url, format, schedule, is_active, config)
VALUES (
  'pdq',
  'PDQ Cash Prices',
  'Alberta Grains PDQ daily cash grain prices and basis for western Canadian elevators',
  'https://www.albertagrains.com/markets/pdq/',
  'html_scrape',
  'daily_6pm_mst',
  true,
  '{"timezone": "America/Edmonton", "coverage": ["AB", "SK", "MB"]}'::jsonb
)
ON CONFLICT (source_name) DO NOTHING;
```

**Step 2: Apply migration to Supabase**

Run: `npx supabase db push` or apply via Supabase dashboard
Expected: Tables and RPC created successfully

**Step 3: Commit**

```bash
git add supabase/migrations/20260304120000_local_cash_prices.sql
git commit -m "feat: add local_cash_prices table for Wave 2 PDQ data"
```

---

### Task 2: Create `farm_profiles` + `crop_plans` + `provincial_cost_defaults` migration

**Files:**
- Create: `supabase/migrations/20260304120100_my_farm_tables.sql`

**Step 1: Write the migration**

```sql
-- Wave 2 Part 2: My Farm — farm profiles, crop plans, provincial defaults

-- ===== farm_profiles =====
CREATE TABLE farm_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  province TEXT NOT NULL CHECK (province IN ('SK', 'AB', 'MB')),
  nearest_city TEXT,
  total_acres INTEGER,
  location GEOGRAPHY(POINT, 4326),
  engagement_level INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id)
);

CREATE INDEX idx_farm_profiles_user ON farm_profiles(user_id);
CREATE INDEX idx_farm_profiles_province ON farm_profiles(province);

ALTER TABLE farm_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their own farm profile"
  ON farm_profiles FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own farm profile"
  ON farm_profiles FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own farm profile"
  ON farm_profiles FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own farm profile"
  ON farm_profiles FOR DELETE USING (auth.uid() = user_id);

-- ===== crop_plans =====
CREATE TABLE crop_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_profile_id UUID NOT NULL REFERENCES farm_profiles(id) ON DELETE CASCADE,
  crop_year TEXT NOT NULL DEFAULT '2025-2026',
  commodity TEXT NOT NULL,
  planned_acres DECIMAL(10,1),
  target_yield_bu_per_acre DECIMAL(10,1),
  seed_cost_per_acre DECIMAL(10,2),
  fertilizer_cost_per_acre DECIMAL(10,2),
  chemical_cost_per_acre DECIMAL(10,2),
  fuel_cost_per_acre DECIMAL(10,2),
  crop_insurance_per_acre DECIMAL(10,2),
  land_cost_per_acre DECIMAL(10,2),
  equipment_cost_per_acre DECIMAL(10,2),
  labour_cost_per_acre DECIMAL(10,2),
  other_cost_per_acre DECIMAL(10,2),
  total_cost_per_acre DECIMAL(10,2) GENERATED ALWAYS AS (
    COALESCE(seed_cost_per_acre, 0) + COALESCE(fertilizer_cost_per_acre, 0) +
    COALESCE(chemical_cost_per_acre, 0) + COALESCE(fuel_cost_per_acre, 0) +
    COALESCE(crop_insurance_per_acre, 0) + COALESCE(land_cost_per_acre, 0) +
    COALESCE(equipment_cost_per_acre, 0) + COALESCE(labour_cost_per_acre, 0) +
    COALESCE(other_cost_per_acre, 0)
  ) STORED,
  breakeven_price_per_bu DECIMAL(10,2) GENERATED ALWAYS AS (
    CASE WHEN COALESCE(target_yield_bu_per_acre, 0) > 0
    THEN (COALESCE(seed_cost_per_acre, 0) + COALESCE(fertilizer_cost_per_acre, 0) +
          COALESCE(chemical_cost_per_acre, 0) + COALESCE(fuel_cost_per_acre, 0) +
          COALESCE(crop_insurance_per_acre, 0) + COALESCE(land_cost_per_acre, 0) +
          COALESCE(equipment_cost_per_acre, 0) + COALESCE(labour_cost_per_acre, 0) +
          COALESCE(other_cost_per_acre, 0)) / target_yield_bu_per_acre
    ELSE NULL END
  ) STORED,
  costs_source TEXT DEFAULT 'provincial_average',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(farm_profile_id, crop_year, commodity)
);

CREATE INDEX idx_crop_plans_farm ON crop_plans(farm_profile_id);
CREATE INDEX idx_crop_plans_commodity ON crop_plans(commodity);

ALTER TABLE crop_plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their own crop plans"
  ON crop_plans FOR SELECT
  USING (farm_profile_id IN (SELECT id FROM farm_profiles WHERE user_id = auth.uid()));
CREATE POLICY "Users can insert their own crop plans"
  ON crop_plans FOR INSERT
  WITH CHECK (farm_profile_id IN (SELECT id FROM farm_profiles WHERE user_id = auth.uid()));
CREATE POLICY "Users can update their own crop plans"
  ON crop_plans FOR UPDATE
  USING (farm_profile_id IN (SELECT id FROM farm_profiles WHERE user_id = auth.uid()));
CREATE POLICY "Users can delete their own crop plans"
  ON crop_plans FOR DELETE
  USING (farm_profile_id IN (SELECT id FROM farm_profiles WHERE user_id = auth.uid()));

-- ===== provincial_cost_defaults =====
CREATE TABLE provincial_cost_defaults (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  province TEXT NOT NULL,
  crop_year TEXT NOT NULL,
  commodity TEXT NOT NULL,
  seed_cost_per_acre DECIMAL(10,2),
  fertilizer_cost_per_acre DECIMAL(10,2),
  chemical_cost_per_acre DECIMAL(10,2),
  fuel_cost_per_acre DECIMAL(10,2),
  crop_insurance_per_acre DECIMAL(10,2),
  land_cost_per_acre DECIMAL(10,2),
  equipment_cost_per_acre DECIMAL(10,2),
  labour_cost_per_acre DECIMAL(10,2),
  other_cost_per_acre DECIMAL(10,2),
  total_cost_per_acre DECIMAL(10,2),
  default_yield_bu_per_acre DECIMAL(10,1),
  breakeven_price_per_bu DECIMAL(10,2),
  source_document TEXT,
  UNIQUE(province, crop_year, commodity)
);

ALTER TABLE provincial_cost_defaults ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Provincial defaults are public"
  ON provincial_cost_defaults FOR SELECT USING (true);

-- ===== Seed Manitoba data from crop production guide =====
INSERT INTO provincial_cost_defaults (province, crop_year, commodity, seed_cost_per_acre, fertilizer_cost_per_acre, chemical_cost_per_acre, fuel_cost_per_acre, crop_insurance_per_acre, land_cost_per_acre, equipment_cost_per_acre, labour_cost_per_acre, other_cost_per_acre, total_cost_per_acre, default_yield_bu_per_acre, breakeven_price_per_bu, source_document)
VALUES
  ('MB', '2025-2026', 'Canola',    82.50, 150.30, 68.75, 32.51, 22.91, 106.24, 110.34, 5.60, 90.84, 669.99, 45.0, 14.89, 'MB Crop Production Guidelines 2026'),
  ('MB', '2025-2026', 'Wheat HRS', 42.00, 118.20, 53.50, 30.10, 20.50, 106.24, 110.34, 5.60, 97.98, 584.46, 66.0, 8.86, 'MB Crop Production Guidelines 2026'),
  ('MB', '2025-2026', 'Soybeans',  78.00, 45.00, 62.00, 28.50, 18.00, 106.24, 110.34, 5.60, 79.71, 533.39, 42.0, 12.70, 'MB Crop Production Guidelines 2026'),
  ('MB', '2025-2026', 'Oats',      35.00, 95.50, 38.00, 28.50, 18.00, 106.24, 110.34, 5.60, 101.37, 538.55, 120.0, 4.49, 'MB Crop Production Guidelines 2026'),
  ('MB', '2025-2026', 'Barley',    38.00, 105.00, 42.00, 28.50, 18.00, 106.24, 110.34, 5.60, 55.12, 508.80, 80.0, 6.36, 'MB Crop Production Guidelines 2026'),
  ('MB', '2025-2026', 'Peas',      65.00, 52.00, 68.00, 28.50, 18.00, 106.24, 110.34, 5.60, 49.99, 503.67, 55.0, 9.16, 'MB Crop Production Guidelines 2026'),
  ('MB', '2025-2026', 'Corn',      120.00, 180.00, 72.00, 35.00, 22.00, 106.24, 110.34, 5.60, 198.10, 849.28, 145.0, 5.86, 'MB Crop Production Guidelines 2026'),
  ('MB', '2025-2026', 'Lentils',   55.00, 48.00, 75.00, 28.50, 18.00, 106.24, 110.34, 5.60, 53.61, 500.29, 29.0, 17.25, 'MB Crop Production Guidelines 2026'),
  ('MB', '2025-2026', 'Flaxseed',  48.00, 85.00, 55.00, 28.50, 18.00, 106.24, 110.34, 5.60, 43.61, 500.29, 29.0, 17.25, 'MB Crop Production Guidelines 2026')
ON CONFLICT (province, crop_year, commodity) DO NOTHING;

-- ===== RPC: Get farm profile with crop plans =====
CREATE OR REPLACE FUNCTION get_my_farm()
RETURNS JSON AS $$
DECLARE
  v_farm_id UUID;
  v_result JSON;
BEGIN
  SELECT id INTO v_farm_id FROM farm_profiles WHERE user_id = auth.uid();

  IF v_farm_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT json_build_object(
    'farm', (SELECT row_to_json(f) FROM farm_profiles f WHERE f.id = v_farm_id),
    'crop_plans', (
      SELECT COALESCE(json_agg(row_to_json(cp)), '[]'::json)
      FROM crop_plans cp
      WHERE cp.farm_profile_id = v_farm_id
      ORDER BY cp.commodity
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ===== RPC: Get provincial defaults for a province =====
CREATE OR REPLACE FUNCTION get_provincial_defaults(
  p_province TEXT,
  p_crop_year TEXT DEFAULT '2025-2026'
)
RETURNS SETOF provincial_cost_defaults AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM provincial_cost_defaults
  WHERE province = p_province
    AND crop_year = p_crop_year
  ORDER BY commodity;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
```

**Step 2: Apply migration**

Run: `npx supabase db push` or apply via Supabase dashboard
Expected: 3 tables + 2 RPCs + MB seed data created

**Step 3: Commit**

```bash
git add supabase/migrations/20260304120100_my_farm_tables.sql
git commit -m "feat: add farm_profiles, crop_plans, provincial_cost_defaults for My Farm"
```

---

## Phase 2, Agent 1: PDQ Cash Prices Pipeline

> **Parallel with Agent 2.** No shared files — only the `local_cash_prices` table (created in Phase 1).

### Task 3: Evaluate PDQ data source

**Files:**
- None (research task)

**Step 1: Check PDQ Terms of Service**
- Visit https://www.albertagrains.com/terms or equivalent
- Look for: automated access policy, scraping restrictions, API availability
- Check if PDQ data comes from Barchart (different ToS may apply)

**Step 2: Document findings**
- If ToS allows: proceed to Task 4
- If ToS unclear or restrictive: report to user with alternatives:
  1. Contact Alberta Grains for a data feed
  2. Alberta Wheat Commission data partnership
  3. Provincial open data portals
  4. Manual data entry as interim fallback

**Step 3: Examine PDQ page structure**
- Fetch the PDQ page, inspect the HTML table structure
- Document: column names, commodity format, price format, update frequency
- Note any JavaScript rendering requirements (would need different scraping approach)

---

### Task 4: Create `CashPrice` model

**Files:**
- Create: `lib/models/cash_price.dart`
- Create: `_test/models/cash_price_test.dart`

**Step 1: Write failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/models/cash_price.dart';

void main() {
  group('CashPrice', () {
    group('fromMap', () {
      test('parses valid map with all fields', () {
        final map = {
          'id': 'cp-uuid-001',
          'source': 'pdq',
          'elevator_name': 'Viterra Rosetown',
          'company': 'Viterra',
          'location_city': 'Rosetown',
          'location_province': 'SK',
          'commodity': 'Canola',
          'grade': '#1',
          'bid_price_cad': 14.25,
          'bid_unit': 'bushel',
          'basis': -0.85,
          'futures_reference': 'ICE Canola Nov 2026',
          'price_date': '2026-03-03',
          'fetched_at': '2026-03-03T18:00:00Z',
          'created_at': '2026-03-03T18:00:00Z',
        };

        final price = CashPrice.fromMap(map);

        expect(price.id, 'cp-uuid-001');
        expect(price.source, 'pdq');
        expect(price.elevatorName, 'Viterra Rosetown');
        expect(price.company, 'Viterra');
        expect(price.locationProvince, 'SK');
        expect(price.commodity, 'Canola');
        expect(price.grade, '#1');
        expect(price.bidPriceCad, 14.25);
        expect(price.bidUnit, 'bushel');
        expect(price.basis, -0.85);
        expect(price.priceDate, DateTime.parse('2026-03-03'));
      });

      test('handles null optional fields gracefully', () {
        final map = {
          'id': 'cp-uuid-002',
          'source': 'pdq',
          'elevator_name': 'Unknown Elevator',
          'location_province': 'AB',
          'commodity': 'Wheat',
          'price_date': '2026-03-03',
        };

        final price = CashPrice.fromMap(map);

        expect(price.company, isNull);
        expect(price.grade, isNull);
        expect(price.bidPriceCad, isNull);
        expect(price.basis, isNull);
        expect(price.bidUnit, 'tonne', reason: 'should default to tonne');
      });

      test('handles integer bid_price_cad as double', () {
        final map = {
          'id': 'cp-uuid-003',
          'source': 'pdq',
          'elevator_name': 'Test',
          'location_province': 'MB',
          'commodity': 'Barley',
          'price_date': '2026-03-03',
          'bid_price_cad': 275,
        };

        final price = CashPrice.fromMap(map);
        expect(price.bidPriceCad, 275.0);
      });
    });

    group('formatting', () {
      test('formattedBid returns price with unit', () {
        final price = CashPrice(
          id: 'test',
          source: 'pdq',
          elevatorName: 'Test',
          locationProvince: 'SK',
          commodity: 'Canola',
          priceDate: DateTime(2026, 3, 3),
          bidPriceCad: 14.25,
          bidUnit: 'bushel',
        );

        expect(price.formattedBid, 'C\$14.25/bu');
      });

      test('formattedBid handles null price', () {
        final price = CashPrice(
          id: 'test',
          source: 'pdq',
          elevatorName: 'Test',
          locationProvince: 'SK',
          commodity: 'Canola',
          priceDate: DateTime(2026, 3, 3),
        );

        expect(price.formattedBid, 'N/A');
      });

      test('formattedBasis shows negative basis correctly', () {
        final price = CashPrice(
          id: 'test',
          source: 'pdq',
          elevatorName: 'Test',
          locationProvince: 'SK',
          commodity: 'Canola',
          priceDate: DateTime(2026, 3, 3),
          basis: -0.85,
        );

        expect(price.formattedBasis, '-\$0.85');
      });
    });
  });

  group('CashPriceParams', () {
    test('equality — same params are equal', () {
      const a = CashPriceParams(commodity: 'Canola', province: 'SK');
      const b = CashPriceParams(commodity: 'Canola', province: 'SK');
      expect(a, equals(b));
    });

    test('hashCode — equal params produce same hash', () {
      const a = CashPriceParams(commodity: 'Canola', province: 'SK');
      const b = CashPriceParams(commodity: 'Canola', province: 'SK');
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality — different params are not equal', () {
      const a = CashPriceParams(commodity: 'Canola', province: 'SK');
      const b = CashPriceParams(commodity: 'Wheat', province: 'SK');
      expect(a, isNot(equals(b)));
    });
  });
}
```

**Step 2: Run tests to verify they fail**

Run: `flutter test _test/models/cash_price_test.dart`
Expected: FAIL — `cash_price.dart` does not exist

**Step 3: Write the model**

```dart
// lib/models/cash_price.dart

class CashPrice {
  final String id;
  final String source;
  final String elevatorName;
  final String? company;
  final String? locationCity;
  final String locationProvince;
  final String commodity;
  final String? grade;
  final double? bidPriceCad;
  final String bidUnit;
  final double? basis;
  final String? futuresReference;
  final DateTime priceDate;
  final DateTime? fetchedAt;
  final DateTime? createdAt;

  CashPrice({
    required this.id,
    required this.source,
    required this.elevatorName,
    this.company,
    this.locationCity,
    required this.locationProvince,
    required this.commodity,
    this.grade,
    this.bidPriceCad,
    this.bidUnit = 'tonne',
    this.basis,
    this.futuresReference,
    required this.priceDate,
    this.fetchedAt,
    this.createdAt,
  });

  factory CashPrice.fromMap(Map<String, dynamic> map) {
    return CashPrice(
      id: map['id'] as String,
      source: map['source'] as String,
      elevatorName: map['elevator_name'] as String,
      company: map['company'] as String?,
      locationCity: map['location_city'] as String?,
      locationProvince: map['location_province'] as String,
      commodity: map['commodity'] as String,
      grade: map['grade'] as String?,
      bidPriceCad: map['bid_price_cad'] != null
          ? (map['bid_price_cad'] as num).toDouble()
          : null,
      bidUnit: (map['bid_unit'] as String?) ?? 'tonne',
      basis: map['basis'] != null
          ? (map['basis'] as num).toDouble()
          : null,
      futuresReference: map['futures_reference'] as String?,
      priceDate: DateTime.parse(map['price_date'] as String),
      fetchedAt: map['fetched_at'] != null
          ? DateTime.parse(map['fetched_at'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  String get formattedBid {
    if (bidPriceCad == null) return 'N/A';
    final unit = bidUnit == 'bushel' ? 'bu' : 'tn';
    return 'C\$${bidPriceCad!.toStringAsFixed(2)}/$unit';
  }

  String get formattedBasis {
    if (basis == null) return 'N/A';
    final sign = basis! < 0 ? '-' : '+';
    return '$sign\$${basis!.abs().toStringAsFixed(2)}';
  }

  String get displayLabel => '$elevatorName — $commodity${grade != null ? " $grade" : ""}';
}

class CashPriceParams {
  final String? commodity;
  final String? province;
  final String? source;
  final int days;

  const CashPriceParams({
    this.commodity,
    this.province,
    this.source,
    this.days = 30,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CashPriceParams &&
          commodity == other.commodity &&
          province == other.province &&
          source == other.source &&
          days == other.days;

  @override
  int get hashCode => Object.hash(commodity, province, source, days);
}
```

**Step 4: Run tests to verify they pass**

Run: `flutter test _test/models/cash_price_test.dart`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add lib/models/cash_price.dart _test/models/cash_price_test.dart
git commit -m "feat: add CashPrice model with fromMap, formatting, and tests"
```

---

### Task 5: Create `localCashPricesProvider`

**Files:**
- Create: `lib/providers/local_cash_prices_provider.dart`

**Step 1: Write the provider**

```dart
// lib/providers/local_cash_prices_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cash_price.dart';

final _logger = Logger(level: Level.debug);

final localCashPricesProvider = FutureProvider.family<List<CashPrice>, CashPriceParams>(
  (ref, params) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc('get_cash_prices', params: {
        'p_commodity': params.commodity,
        'p_province': params.province,
        'p_source': params.source,
        'p_days': params.days,
      });

      final list = List<Map<String, dynamic>>.from(response as List);
      return list.map((e) => CashPrice.fromMap(e)).toList();
    } catch (e) {
      _logger.e('Error fetching cash prices', error: e);
      rethrow;
    }
  },
);

/// Get latest bid for a specific commodity across all elevators
final latestBidProvider = FutureProvider.family<CashPrice?, String>(
  (ref, commodity) async {
    final prices = await ref.watch(
      localCashPricesProvider(CashPriceParams(commodity: commodity, days: 7)).future,
    );
    return prices.isNotEmpty ? prices.first : null;
  },
);
```

**Step 2: Commit**

```bash
git add lib/providers/local_cash_prices_provider.dart
git commit -m "feat: add localCashPricesProvider for PDQ cash price queries"
```

---

### Task 6: Create `fetch-pdq-prices` Edge Function

**Files:**
- Create: `supabase/functions/fetch-pdq-prices/index.ts`

**Step 1: Write the Edge Function**

Follow existing patterns from `fetch-cgc-grain-data/index.ts` and `fetch-cot-data/index.ts`.

```typescript
// supabase/functions/fetch-pdq-prices/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const PDQ_URL = "https://www.albertagrains.com/markets/pdq/";

const MAX_RETRIES = 3;
const RETRY_BACKOFF_MS = [1000, 3000, 8000];

const HEADERS = {
  "User-Agent": "Agnonymous-Ag-Dashboard/1.0 (agricultural data aggregator; contact: admin@agnonymous.com)",
  "Accept": "text/html,application/xhtml+xml",
};

interface PriceRow {
  elevator_name: string;
  company: string | null;
  location_city: string | null;
  location_province: string;
  commodity: string;
  grade: string | null;
  bid_price_cad: number | null;
  bid_unit: string;
  basis: number | null;
  futures_reference: string | null;
  price_date: string;
}

async function fetchWithRetry(url: string, headers: Record<string, string>): Promise<Response> {
  let lastError: Error | null = null;

  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    try {
      const response = await fetch(url, { headers });

      if (response.ok) return response;

      if (response.status === 429 || response.status >= 500) {
        lastError = new Error(`HTTP ${response.status}`);
        if (attempt < MAX_RETRIES - 1) {
          await new Promise((r) => setTimeout(r, RETRY_BACKOFF_MS[attempt]));
          continue;
        }
      }

      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    } catch (err) {
      lastError = err instanceof Error ? err : new Error(String(err));
      if (attempt < MAX_RETRIES - 1) {
        await new Promise((r) => setTimeout(r, RETRY_BACKOFF_MS[attempt]));
      }
    }
  }

  throw lastError ?? new Error("fetchWithRetry exhausted all retries");
}

function parsePdqHtml(html: string, priceDate: string): PriceRow[] {
  // NOTE: This parser will need to be adapted based on actual PDQ HTML structure.
  // The structure below is a reasonable starting point based on typical Barchart-fed tables.
  // After Task 3 (data source evaluation), update this parser to match the real format.

  const rows: PriceRow[] = [];

  // Simple regex-based table parsing (adapt after seeing actual HTML)
  const tableRegex = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
  const cellRegex = /<td[^>]*>([\s\S]*?)<\/td>/gi;

  let match;
  while ((match = tableRegex.exec(html)) !== null) {
    const rowHtml = match[1];
    const cells: string[] = [];
    let cellMatch;

    while ((cellMatch = cellRegex.exec(rowHtml)) !== null) {
      cells.push(cellMatch[1].replace(/<[^>]*>/g, "").trim());
    }

    // Skip header rows or rows with too few cells
    if (cells.length < 4) continue;

    // Parse based on expected column order (adapt after evaluation)
    // Expected: Location, Company, Commodity, Grade, Bid, Basis
    const bidStr = cells[4]?.replace(/[^0-9.-]/g, "");
    const basisStr = cells[5]?.replace(/[^0-9.-]/g, "");

    if (cells[0] && cells[2]) {
      rows.push({
        elevator_name: cells[0],
        company: cells[1] || null,
        location_city: null,
        location_province: "AB", // PDQ is primarily Alberta
        commodity: cells[2],
        grade: cells[3] || null,
        bid_price_cad: bidStr ? parseFloat(bidStr) : null,
        bid_unit: "tonne",
        basis: basisStr ? parseFloat(basisStr) : null,
        futures_reference: null,
        price_date: priceDate,
      });
    }
  }

  return rows;
}

Deno.serve(async (req) => {
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Create pipeline log entry
  const { data: logEntry } = await supabase
    .from("data_pipeline_logs")
    .insert({
      source_name: "pdq",
      status: "running",
      started_at: new Date().toISOString(),
    })
    .select("id")
    .single();

  const logId = logEntry?.id;
  const startTime = Date.now();

  try {
    // Fetch PDQ page
    const response = await fetchWithRetry(PDQ_URL, HEADERS);
    const html = await response.text();

    if (!html || html.length < 100) {
      throw new Error("PDQ page returned empty or minimal content");
    }

    // Parse today's date for price_date
    const today = new Date().toISOString().split("T")[0];

    // Parse HTML into price rows
    const prices = parsePdqHtml(html, today);

    if (prices.length === 0) {
      // Log warning but don't fail — could be a weekend/holiday
      if (logId) {
        await supabase
          .from("data_pipeline_logs")
          .update({
            status: "warning",
            error_message: "No prices parsed from PDQ page — may be weekend/holiday",
            completed_at: new Date().toISOString(),
          })
          .eq("id", logId);
      }

      return new Response(
        JSON.stringify({ status: "warning", message: "No prices found", rows: 0 }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    // Batch upsert
    const batchSize = 500;
    let totalInserted = 0;

    for (let i = 0; i < prices.length; i += batchSize) {
      const batch = prices.slice(i, i + batchSize).map((p) => ({
        source: "pdq",
        ...p,
        fetched_at: new Date().toISOString(),
      }));

      const { error } = await supabase
        .from("local_cash_prices")
        .upsert(batch, {
          onConflict: "source,elevator_name,commodity,grade,price_date",
          ignoreDuplicates: false,
        });

      if (error) throw error;
      totalInserted += batch.length;
    }

    // Update pipeline log
    const durationMs = Date.now() - startTime;
    if (logId) {
      await supabase
        .from("data_pipeline_logs")
        .update({
          status: "success",
          completed_at: new Date().toISOString(),
          rows_affected: totalInserted,
          duration_ms: durationMs,
        })
        .eq("id", logId);
    }

    // Update data_source_config
    await supabase
      .from("data_source_config")
      .update({
        last_fetch_at: new Date().toISOString(),
        last_fetch_status: "success",
        last_fetch_rows: totalInserted,
      })
      .eq("source_name", "pdq");

    return new Response(
      JSON.stringify({
        status: "success",
        rows: totalInserted,
        duration_ms: durationMs,
      }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    const errorMessage = err instanceof Error ? err.message : String(err);
    const durationMs = Date.now() - startTime;

    // Update pipeline log with error
    if (logId) {
      await supabase
        .from("data_pipeline_logs")
        .update({
          status: "error",
          error_message: errorMessage.substring(0, 500),
          completed_at: new Date().toISOString(),
          duration_ms: durationMs,
        })
        .eq("id", logId);
    }

    // Update data_source_config
    await supabase
      .from("data_source_config")
      .update({
        last_fetch_at: new Date().toISOString(),
        last_fetch_status: "error",
      })
      .eq("source_name", "pdq");

    return new Response(
      JSON.stringify({ status: "error", message: "Pipeline encountered an issue" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
```

**Step 2: Commit**

```bash
git add supabase/functions/fetch-pdq-prices/
git commit -m "feat: add fetch-pdq-prices Edge Function for daily PDQ pipeline"
```

---

### Task 7: Add cash prices UI to Markets screen

**Files:**
- Modify: `lib/screens/market/markets_screen.dart` — add Cash Prices tab or section
- Create: `lib/widgets/cash_price_card.dart` — reusable price card widget

**Step 1: Create CashPriceCard widget**

A glassmorphism card showing elevator name, commodity, bid price, basis, and price date. Use `GlassContainer` wrapper, green/red color coding based on basis sign, formatted price from `CashPrice.formattedBid`.

**Step 2: Add to Markets screen**

Add a "Cash Prices" tab to the existing TabBar in `markets_screen.dart` (alongside Grains / Fertilizer / Crop Stats). The tab shows a list of `CashPriceCard` widgets, filterable by commodity and province dropdowns.

Watch `localCashPricesProvider` with appropriate params. Show loading shimmer while data loads, empty state ("No cash prices available yet — PDQ data updates daily at 6pm MST") when no data.

**Step 3: Write widget smoke tests**

```dart
// _test/widgets/cash_price_card_test.dart
void main() {
  testWidgets('CashPriceCard renders elevator name and price', (tester) async {
    final price = CashPrice(
      id: 'test',
      source: 'pdq',
      elevatorName: 'Viterra Rosetown',
      locationProvince: 'SK',
      commodity: 'Canola',
      priceDate: DateTime(2026, 3, 3),
      bidPriceCad: 14.25,
      bidUnit: 'bushel',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CashPriceCard(price: price)),
    ));

    expect(find.text('Viterra Rosetown'), findsOneWidget);
    expect(find.textContaining('14.25'), findsOneWidget);
  });
}
```

**Step 4: Commit**

```bash
git add lib/widgets/cash_price_card.dart lib/screens/market/markets_screen.dart _test/widgets/cash_price_card_test.dart
git commit -m "feat: add Cash Prices tab to Markets screen with CashPriceCard widget"
```

---

## Phase 2, Agent 2: My Farm Feature

> **Parallel with Agent 1.** Touches `lib/models/`, `lib/providers/`, `lib/screens/`, `_test/`. No overlap with Agent 1 files.

### Task 8: Create `FarmProfile` model

**Files:**
- Create: `lib/models/farm_profile.dart`
- Create: `_test/models/farm_profile_test.dart`

**Step 1: Write failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/models/farm_profile.dart';

void main() {
  group('FarmProfile', () {
    group('fromMap', () {
      test('parses valid map with all fields', () {
        final map = {
          'id': 'fp-uuid-001',
          'user_id': 'user-uuid-001',
          'province': 'SK',
          'nearest_city': 'Rosetown',
          'total_acres': 2400,
          'engagement_level': 2,
          'created_at': '2026-03-03T10:00:00Z',
          'updated_at': '2026-03-03T10:00:00Z',
        };

        final profile = FarmProfile.fromMap(map);

        expect(profile.id, 'fp-uuid-001');
        expect(profile.userId, 'user-uuid-001');
        expect(profile.province, 'SK');
        expect(profile.nearestCity, 'Rosetown');
        expect(profile.totalAcres, 2400);
        expect(profile.engagementLevel, 2);
      });

      test('handles null optional fields', () {
        final map = {
          'id': 'fp-uuid-002',
          'user_id': 'user-uuid-002',
          'province': 'AB',
        };

        final profile = FarmProfile.fromMap(map);

        expect(profile.nearestCity, isNull);
        expect(profile.totalAcres, isNull);
        expect(profile.engagementLevel, 1, reason: 'should default to 1');
      });
    });

    group('toMap', () {
      test('converts to map for insert (excludes id and generated fields)', () {
        final profile = FarmProfile(
          id: 'fp-uuid-001',
          userId: 'user-uuid-001',
          province: 'MB',
          nearestCity: 'Brandon',
          totalAcres: 1800,
        );

        final map = profile.toInsertMap();

        expect(map['user_id'], 'user-uuid-001');
        expect(map['province'], 'MB');
        expect(map['nearest_city'], 'Brandon');
        expect(map['total_acres'], 1800);
        expect(map.containsKey('id'), isFalse, reason: 'id is server-generated');
      });
    });

    test('province validation — only SK, AB, MB allowed', () {
      expect(FarmProfile.validProvinces, containsAll(['SK', 'AB', 'MB']));
      expect(FarmProfile.validProvinces.length, 3);
    });
  });
}
```

**Step 2: Run tests to verify they fail**

Run: `flutter test _test/models/farm_profile_test.dart`
Expected: FAIL

**Step 3: Write the model**

```dart
// lib/models/farm_profile.dart

class FarmProfile {
  final String id;
  final String userId;
  final String province;
  final String? nearestCity;
  final int? totalAcres;
  final int engagementLevel;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const validProvinces = ['SK', 'AB', 'MB'];

  FarmProfile({
    required this.id,
    required this.userId,
    required this.province,
    this.nearestCity,
    this.totalAcres,
    this.engagementLevel = 1,
    this.createdAt,
    this.updatedAt,
  });

  factory FarmProfile.fromMap(Map<String, dynamic> map) {
    return FarmProfile(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      province: map['province'] as String,
      nearestCity: map['nearest_city'] as String?,
      totalAcres: map['total_acres'] as int?,
      engagementLevel: (map['engagement_level'] as int?) ?? 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'user_id': userId,
      'province': province,
      if (nearestCity != null) 'nearest_city': nearestCity,
      if (totalAcres != null) 'total_acres': totalAcres,
      'engagement_level': engagementLevel,
    };
  }

  FarmProfile copyWith({
    String? province,
    String? nearestCity,
    int? totalAcres,
    int? engagementLevel,
  }) {
    return FarmProfile(
      id: id,
      userId: userId,
      province: province ?? this.province,
      nearestCity: nearestCity ?? this.nearestCity,
      totalAcres: totalAcres ?? this.totalAcres,
      engagementLevel: engagementLevel ?? this.engagementLevel,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
```

**Step 4: Run tests to verify they pass**

Run: `flutter test _test/models/farm_profile_test.dart`
Expected: All PASS

**Step 5: Commit**

```bash
git add lib/models/farm_profile.dart _test/models/farm_profile_test.dart
git commit -m "feat: add FarmProfile model with fromMap, toInsertMap, and tests"
```

---

### Task 9: Create `CropPlan` model

**Files:**
- Create: `lib/models/crop_plan.dart`
- Create: `_test/models/crop_plan_test.dart`

**Step 1: Write failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/models/crop_plan.dart';

void main() {
  group('CropPlan', () {
    group('fromMap', () {
      test('parses valid map with all costs and generated columns', () {
        final map = {
          'id': 'cp-uuid-001',
          'farm_profile_id': 'fp-uuid-001',
          'crop_year': '2025-2026',
          'commodity': 'Canola',
          'planned_acres': 1200.0,
          'target_yield_bu_per_acre': 45.0,
          'seed_cost_per_acre': 82.50,
          'fertilizer_cost_per_acre': 150.30,
          'chemical_cost_per_acre': 68.75,
          'fuel_cost_per_acre': 32.51,
          'crop_insurance_per_acre': 22.91,
          'land_cost_per_acre': 106.24,
          'equipment_cost_per_acre': 110.34,
          'labour_cost_per_acre': 5.60,
          'other_cost_per_acre': 90.84,
          'total_cost_per_acre': 669.99,
          'breakeven_price_per_bu': 14.89,
          'costs_source': 'provincial_average',
        };

        final plan = CropPlan.fromMap(map);

        expect(plan.commodity, 'Canola');
        expect(plan.plannedAcres, 1200.0);
        expect(plan.targetYieldBuPerAcre, 45.0);
        expect(plan.seedCostPerAcre, 82.50);
        expect(plan.totalCostPerAcre, 669.99);
        expect(plan.breakevenPricePerBu, 14.89);
      });

      test('handles null optional costs', () {
        final map = {
          'id': 'cp-uuid-002',
          'farm_profile_id': 'fp-uuid-002',
          'crop_year': '2025-2026',
          'commodity': 'Wheat HRS',
        };

        final plan = CropPlan.fromMap(map);

        expect(plan.seedCostPerAcre, isNull);
        expect(plan.fertilizerCostPerAcre, isNull);
        expect(plan.costsSource, 'provincial_average', reason: 'default value');
      });
    });

    group('computed breakeven', () {
      test('calculates breakeven from local costs and yield', () {
        final plan = CropPlan(
          id: 'test',
          farmProfileId: 'fp-test',
          cropYear: '2025-2026',
          commodity: 'Canola',
          targetYieldBuPerAcre: 45.0,
          seedCostPerAcre: 82.50,
          fertilizerCostPerAcre: 150.30,
          chemicalCostPerAcre: 68.75,
          fuelCostPerAcre: 32.51,
          cropInsuranceCostPerAcre: 22.91,
          landCostPerAcre: 106.24,
          equipmentCostPerAcre: 110.34,
          labourCostPerAcre: 5.60,
          otherCostPerAcre: 90.84,
        );

        // 669.99 / 45 = 14.888... ≈ 14.89
        expect(plan.calculatedTotalCost, closeTo(669.99, 0.01));
        expect(plan.calculatedBreakeven, closeTo(14.89, 0.01));
      });

      test('returns null breakeven when yield is zero', () {
        final plan = CropPlan(
          id: 'test',
          farmProfileId: 'fp-test',
          cropYear: '2025-2026',
          commodity: 'Canola',
          targetYieldBuPerAcre: 0,
          seedCostPerAcre: 100.0,
        );

        expect(plan.calculatedBreakeven, isNull);
      });

      test('returns null breakeven when yield is null', () {
        final plan = CropPlan(
          id: 'test',
          farmProfileId: 'fp-test',
          cropYear: '2025-2026',
          commodity: 'Canola',
        );

        expect(plan.calculatedBreakeven, isNull);
      });
    });

    group('toInsertMap', () {
      test('excludes generated columns (total_cost, breakeven)', () {
        final plan = CropPlan(
          id: 'test',
          farmProfileId: 'fp-test',
          cropYear: '2025-2026',
          commodity: 'Canola',
          seedCostPerAcre: 82.50,
        );

        final map = plan.toInsertMap();

        expect(map.containsKey('id'), isFalse);
        expect(map.containsKey('total_cost_per_acre'), isFalse,
            reason: 'generated column — cannot INSERT');
        expect(map.containsKey('breakeven_price_per_bu'), isFalse,
            reason: 'generated column — cannot INSERT');
        expect(map['seed_cost_per_acre'], 82.50);
        expect(map['farm_profile_id'], 'fp-test');
      });
    });
  });

  group('ProvincialCostDefault', () {
    test('fromMap parses MB canola defaults correctly', () {
      final map = {
        'id': 'pcd-uuid-001',
        'province': 'MB',
        'crop_year': '2025-2026',
        'commodity': 'Canola',
        'seed_cost_per_acre': 82.50,
        'fertilizer_cost_per_acre': 150.30,
        'chemical_cost_per_acre': 68.75,
        'fuel_cost_per_acre': 32.51,
        'crop_insurance_per_acre': 22.91,
        'land_cost_per_acre': 106.24,
        'equipment_cost_per_acre': 110.34,
        'labour_cost_per_acre': 5.60,
        'other_cost_per_acre': 90.84,
        'total_cost_per_acre': 669.99,
        'default_yield_bu_per_acre': 45.0,
        'breakeven_price_per_bu': 14.89,
        'source_document': 'MB Crop Production Guidelines 2026',
      };

      final defaults = ProvincialCostDefault.fromMap(map);

      expect(defaults.province, 'MB');
      expect(defaults.commodity, 'Canola');
      expect(defaults.totalCostPerAcre, 669.99);
      expect(defaults.defaultYieldBuPerAcre, 45.0);
      expect(defaults.breakevenPricePerBu, 14.89);
      expect(defaults.sourceDocument, contains('MB Crop Production'));
    });
  });
}
```

**Step 2: Run tests to verify they fail**

Run: `flutter test _test/models/crop_plan_test.dart`
Expected: FAIL

**Step 3: Write the models**

```dart
// lib/models/crop_plan.dart

class CropPlan {
  final String id;
  final String farmProfileId;
  final String cropYear;
  final String commodity;
  final double? plannedAcres;
  final double? targetYieldBuPerAcre;
  final double? seedCostPerAcre;
  final double? fertilizerCostPerAcre;
  final double? chemicalCostPerAcre;
  final double? fuelCostPerAcre;
  final double? cropInsuranceCostPerAcre;
  final double? landCostPerAcre;
  final double? equipmentCostPerAcre;
  final double? labourCostPerAcre;
  final double? otherCostPerAcre;
  // Read-only from DB (generated columns)
  final double? totalCostPerAcre;
  final double? breakevenPricePerBu;
  final String costsSource;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CropPlan({
    required this.id,
    required this.farmProfileId,
    required this.cropYear,
    required this.commodity,
    this.plannedAcres,
    this.targetYieldBuPerAcre,
    this.seedCostPerAcre,
    this.fertilizerCostPerAcre,
    this.chemicalCostPerAcre,
    this.fuelCostPerAcre,
    this.cropInsuranceCostPerAcre,
    this.landCostPerAcre,
    this.equipmentCostPerAcre,
    this.labourCostPerAcre,
    this.otherCostPerAcre,
    this.totalCostPerAcre,
    this.breakevenPricePerBu,
    this.costsSource = 'provincial_average',
    this.createdAt,
    this.updatedAt,
  });

  factory CropPlan.fromMap(Map<String, dynamic> map) {
    return CropPlan(
      id: map['id'] as String,
      farmProfileId: map['farm_profile_id'] as String,
      cropYear: (map['crop_year'] as String?) ?? '2025-2026',
      commodity: map['commodity'] as String,
      plannedAcres: _toDouble(map['planned_acres']),
      targetYieldBuPerAcre: _toDouble(map['target_yield_bu_per_acre']),
      seedCostPerAcre: _toDouble(map['seed_cost_per_acre']),
      fertilizerCostPerAcre: _toDouble(map['fertilizer_cost_per_acre']),
      chemicalCostPerAcre: _toDouble(map['chemical_cost_per_acre']),
      fuelCostPerAcre: _toDouble(map['fuel_cost_per_acre']),
      cropInsuranceCostPerAcre: _toDouble(map['crop_insurance_per_acre']),
      landCostPerAcre: _toDouble(map['land_cost_per_acre']),
      equipmentCostPerAcre: _toDouble(map['equipment_cost_per_acre']),
      labourCostPerAcre: _toDouble(map['labour_cost_per_acre']),
      otherCostPerAcre: _toDouble(map['other_cost_per_acre']),
      totalCostPerAcre: _toDouble(map['total_cost_per_acre']),
      breakevenPricePerBu: _toDouble(map['breakeven_price_per_bu']),
      costsSource: (map['costs_source'] as String?) ?? 'provincial_average',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Local calculation (mirrors DB generated column)
  double get calculatedTotalCost =>
      (seedCostPerAcre ?? 0) +
      (fertilizerCostPerAcre ?? 0) +
      (chemicalCostPerAcre ?? 0) +
      (fuelCostPerAcre ?? 0) +
      (cropInsuranceCostPerAcre ?? 0) +
      (landCostPerAcre ?? 0) +
      (equipmentCostPerAcre ?? 0) +
      (labourCostPerAcre ?? 0) +
      (otherCostPerAcre ?? 0);

  /// Local calculation (mirrors DB generated column)
  double? get calculatedBreakeven {
    final yield_ = targetYieldBuPerAcre;
    if (yield_ == null || yield_ <= 0) return null;
    return calculatedTotalCost / yield_;
  }

  /// For INSERT/UPDATE — excludes id and generated columns
  Map<String, dynamic> toInsertMap() {
    return {
      'farm_profile_id': farmProfileId,
      'crop_year': cropYear,
      'commodity': commodity,
      if (plannedAcres != null) 'planned_acres': plannedAcres,
      if (targetYieldBuPerAcre != null) 'target_yield_bu_per_acre': targetYieldBuPerAcre,
      if (seedCostPerAcre != null) 'seed_cost_per_acre': seedCostPerAcre,
      if (fertilizerCostPerAcre != null) 'fertilizer_cost_per_acre': fertilizerCostPerAcre,
      if (chemicalCostPerAcre != null) 'chemical_cost_per_acre': chemicalCostPerAcre,
      if (fuelCostPerAcre != null) 'fuel_cost_per_acre': fuelCostPerAcre,
      if (cropInsuranceCostPerAcre != null) 'crop_insurance_per_acre': cropInsuranceCostPerAcre,
      if (landCostPerAcre != null) 'land_cost_per_acre': landCostPerAcre,
      if (equipmentCostPerAcre != null) 'equipment_cost_per_acre': equipmentCostPerAcre,
      if (labourCostPerAcre != null) 'labour_cost_per_acre': labourCostPerAcre,
      if (otherCostPerAcre != null) 'other_cost_per_acre': otherCostPerAcre,
      'costs_source': costsSource,
    };
  }

  CropPlan copyWith({
    double? plannedAcres,
    double? targetYieldBuPerAcre,
    double? seedCostPerAcre,
    double? fertilizerCostPerAcre,
    double? chemicalCostPerAcre,
    double? fuelCostPerAcre,
    double? cropInsuranceCostPerAcre,
    double? landCostPerAcre,
    double? equipmentCostPerAcre,
    double? labourCostPerAcre,
    double? otherCostPerAcre,
    String? costsSource,
  }) {
    return CropPlan(
      id: id,
      farmProfileId: farmProfileId,
      cropYear: cropYear,
      commodity: commodity,
      plannedAcres: plannedAcres ?? this.plannedAcres,
      targetYieldBuPerAcre: targetYieldBuPerAcre ?? this.targetYieldBuPerAcre,
      seedCostPerAcre: seedCostPerAcre ?? this.seedCostPerAcre,
      fertilizerCostPerAcre: fertilizerCostPerAcre ?? this.fertilizerCostPerAcre,
      chemicalCostPerAcre: chemicalCostPerAcre ?? this.chemicalCostPerAcre,
      fuelCostPerAcre: fuelCostPerAcre ?? this.fuelCostPerAcre,
      cropInsuranceCostPerAcre: cropInsuranceCostPerAcre ?? this.cropInsuranceCostPerAcre,
      landCostPerAcre: landCostPerAcre ?? this.landCostPerAcre,
      equipmentCostPerAcre: equipmentCostPerAcre ?? this.equipmentCostPerAcre,
      labourCostPerAcre: labourCostPerAcre ?? this.labourCostPerAcre,
      otherCostPerAcre: otherCostPerAcre ?? this.otherCostPerAcre,
      costsSource: costsSource ?? this.costsSource,
      totalCostPerAcre: totalCostPerAcre,
      breakevenPricePerBu: breakevenPricePerBu,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class ProvincialCostDefault {
  final String id;
  final String province;
  final String cropYear;
  final String commodity;
  final double? seedCostPerAcre;
  final double? fertilizerCostPerAcre;
  final double? chemicalCostPerAcre;
  final double? fuelCostPerAcre;
  final double? cropInsuranceCostPerAcre;
  final double? landCostPerAcre;
  final double? equipmentCostPerAcre;
  final double? labourCostPerAcre;
  final double? otherCostPerAcre;
  final double? totalCostPerAcre;
  final double? defaultYieldBuPerAcre;
  final double? breakevenPricePerBu;
  final String? sourceDocument;

  ProvincialCostDefault({
    required this.id,
    required this.province,
    required this.cropYear,
    required this.commodity,
    this.seedCostPerAcre,
    this.fertilizerCostPerAcre,
    this.chemicalCostPerAcre,
    this.fuelCostPerAcre,
    this.cropInsuranceCostPerAcre,
    this.landCostPerAcre,
    this.equipmentCostPerAcre,
    this.labourCostPerAcre,
    this.otherCostPerAcre,
    this.totalCostPerAcre,
    this.defaultYieldBuPerAcre,
    this.breakevenPricePerBu,
    this.sourceDocument,
  });

  factory ProvincialCostDefault.fromMap(Map<String, dynamic> map) {
    return ProvincialCostDefault(
      id: map['id'] as String,
      province: map['province'] as String,
      cropYear: map['crop_year'] as String,
      commodity: map['commodity'] as String,
      seedCostPerAcre: CropPlan._toDouble(map['seed_cost_per_acre']),
      fertilizerCostPerAcre: CropPlan._toDouble(map['fertilizer_cost_per_acre']),
      chemicalCostPerAcre: CropPlan._toDouble(map['chemical_cost_per_acre']),
      fuelCostPerAcre: CropPlan._toDouble(map['fuel_cost_per_acre']),
      cropInsuranceCostPerAcre: CropPlan._toDouble(map['crop_insurance_per_acre']),
      landCostPerAcre: CropPlan._toDouble(map['land_cost_per_acre']),
      equipmentCostPerAcre: CropPlan._toDouble(map['equipment_cost_per_acre']),
      labourCostPerAcre: CropPlan._toDouble(map['labour_cost_per_acre']),
      otherCostPerAcre: CropPlan._toDouble(map['other_cost_per_acre']),
      totalCostPerAcre: CropPlan._toDouble(map['total_cost_per_acre']),
      defaultYieldBuPerAcre: CropPlan._toDouble(map['default_yield_bu_per_acre']),
      breakevenPricePerBu: CropPlan._toDouble(map['breakeven_price_per_bu']),
      sourceDocument: map['source_document'] as String?,
    );
  }
}
```

**Step 4: Run tests to verify they pass**

Run: `flutter test _test/models/crop_plan_test.dart`
Expected: All PASS

**Step 5: Commit**

```bash
git add lib/models/crop_plan.dart _test/models/crop_plan_test.dart
git commit -m "feat: add CropPlan + ProvincialCostDefault models with tests"
```

---

### Task 10: Create My Farm providers

**Files:**
- Create: `lib/providers/my_farm_provider.dart`

**Step 1: Write the providers**

```dart
// lib/providers/my_farm_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/farm_profile.dart';
import '../models/crop_plan.dart';

final _logger = Logger(level: Level.debug);

/// Current user's farm profile (null if not set up)
final farmProfileProvider = FutureProvider<FarmProfile?>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;

  try {
    final response = await supabase
        .from('farm_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return FarmProfile.fromMap(response);
  } catch (e) {
    _logger.e('Error fetching farm profile', error: e);
    rethrow;
  }
});

/// Current user's crop plans
final cropPlansProvider = FutureProvider<List<CropPlan>>((ref) async {
  final supabase = Supabase.instance.client;
  final farmProfile = await ref.watch(farmProfileProvider.future);
  if (farmProfile == null) return [];

  try {
    final response = await supabase
        .from('crop_plans')
        .select()
        .eq('farm_profile_id', farmProfile.id)
        .order('commodity');

    return (response as List)
        .map((e) => CropPlan.fromMap(e as Map<String, dynamic>))
        .toList();
  } catch (e) {
    _logger.e('Error fetching crop plans', error: e);
    rethrow;
  }
});

/// Provincial cost defaults for a given province
final provincialDefaultsProvider =
    FutureProvider.family<List<ProvincialCostDefault>, String>(
  (ref, province) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc('get_provincial_defaults', params: {
        'p_province': province,
        'p_crop_year': '2025-2026',
      });

      return (response as List)
          .map((e) => ProvincialCostDefault.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.e('Error fetching provincial defaults', error: e);
      rethrow;
    }
  },
);

/// Whether current user has a farm profile set up
final hasFarmProfileProvider = FutureProvider<bool>((ref) async {
  final profile = await ref.watch(farmProfileProvider.future);
  return profile != null;
});
```

**Step 2: Commit**

```bash
git add lib/providers/my_farm_provider.dart
git commit -m "feat: add My Farm providers (farmProfile, cropPlans, provincialDefaults)"
```

---

### Task 11: Build My Farm onboarding screens

**Files:**
- Create: `lib/screens/my_farm/my_farm_onboarding_screen.dart`
- Create: `_test/screens/my_farm_onboarding_test.dart`

**Step 1: Build the 4-step onboarding screen**

A single `ConsumerStatefulWidget` with a `PageView` controller for the 4 steps:

1. **Province Selection** — 3 large glass cards for SK, AB, MB. Tap to select. `GlassContainer` with green border on selected.

2. **Crop Selection** — Grid of crop cards (Canola, Wheat HRS, Barley, Oats, Peas, Lentils, Flaxseed, Corn, Soybeans, Durum). Tap to toggle on/off. When on, show acres input field. Pre-select top 3 for chosen province (MB: Canola, Wheat HRS, Soybeans; SK: Canola, Wheat HRS, Lentils; AB: Canola, Wheat HRS, Barley).

3. **Cost Entry** — For each selected crop: list of cost fields pre-populated from `provincialDefaultsProvider`. Each field is editable. "Use provincial average" reset button per crop. Shows running total cost and live breakeven at the bottom. Uses `TextFormField` with `inputFormatters` for decimal input.

4. **Breakeven Dashboard** — Summary cards per crop showing: commodity, breakeven price, total cost per acre, target yield. Color-coded: green text if a latest bid from `local_cash_prices` is above breakeven, red if below, grey if no bid data yet. "Done — Go to Dashboard" button.

**Key implementation details:**
- Background: `Color(0xFF0F172A)`
- All cards: `GlassContainer` with appropriate blur/opacity
- Typography: `GoogleFonts.outfit()` for headers, `GoogleFonts.inter()` for body
- Progress indicator: dot indicator showing which step (1-4)
- Animations: `flutter_animate` for step transitions
- Responsive: verified at 390px width with `LayoutBuilder` or `MediaQuery`
- On complete: upsert `farm_profiles` + `crop_plans` to Supabase, then invalidate `farmProfileProvider`

**Step 2: Write widget smoke tests**

```dart
// _test/screens/my_farm_onboarding_test.dart

void main() {
  testWidgets('Step 1: Province selection renders 3 province cards', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ProvinceSelectionStep(onSelected: _noOp)),
    ));

    expect(find.text('Saskatchewan'), findsOneWidget);
    expect(find.text('Alberta'), findsOneWidget);
    expect(find.text('Manitoba'), findsOneWidget);
  });

  testWidgets('Step 2: Crop selection shows at least 8 crop options', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CropSelectionStep(province: 'SK', onSelected: _noOp)),
    ));

    expect(find.text('Canola'), findsOneWidget);
    expect(find.text('Wheat HRS'), findsOneWidget);
    expect(find.text('Barley'), findsOneWidget);
  });
}

void _noOp(dynamic _) {}
```

**Step 3: Commit**

```bash
git add lib/screens/my_farm/ _test/screens/my_farm_onboarding_test.dart
git commit -m "feat: add My Farm 4-step onboarding flow with province, crops, costs, breakeven"
```

---

### Task 12: Integrate My Farm into Dashboard

**Files:**
- Modify: `lib/screens/dashboard/home_dashboard_screen.dart`

**Step 1: Add farm profile-aware sections**

In `HomeDashboardScreen.build()`, after the greeting header and before grain highlights:

```dart
// Watch farm profile state
final hasFarm = ref.watch(hasFarmProfileProvider);

// Add conditional section
hasFarm.when(
  data: (hasProfile) {
    if (!hasProfile) {
      return _buildSetupFarmCTA();  // "Set Up My Farm" card
    }
    return _buildBreakevenSummary(ref);  // Breakeven cards
  },
  loading: () => const SizedBox.shrink(),
  error: (_, __) => const SizedBox.shrink(),
);
```

**_buildSetupFarmCTA():** A `GlassContainer` card with:
- Icon: grain/farm icon
- Title: "Set Up My Farm"
- Subtitle: "Track your breakeven price and see if selling today makes money"
- Tap: Navigate to `MyFarmOnboardingScreen`

**_buildBreakevenSummary():** A horizontal `ListView` of compact breakeven cards, one per crop plan. Each shows: commodity name, breakeven price, gap vs latest bid. Taps navigate to detailed crop plan view.

**Step 2: Add route for onboarding screen**

Add the route in the app's router/navigation (wherever routes are defined — likely `main.dart` or a router file).

**Step 3: Commit**

```bash
git add lib/screens/dashboard/home_dashboard_screen.dart
git commit -m "feat: integrate My Farm breakeven cards and setup CTA into dashboard"
```

---

## Task Summary

| Task | Phase | Agent | Description |
|------|-------|-------|-------------|
| 1 | Phase 1 | Main | `local_cash_prices` migration |
| 2 | Phase 1 | Main | `farm_profiles` + `crop_plans` + `provincial_cost_defaults` migration |
| 3 | Phase 2 | Agent 1 | PDQ data source evaluation |
| 4 | Phase 2 | Agent 1 | `CashPrice` model + tests |
| 5 | Phase 2 | Agent 1 | `localCashPricesProvider` |
| 6 | Phase 2 | Agent 1 | `fetch-pdq-prices` Edge Function |
| 7 | Phase 2 | Agent 1 | Cash prices UI in Markets screen |
| 8 | Phase 2 | Agent 2 | `FarmProfile` model + tests |
| 9 | Phase 2 | Agent 2 | `CropPlan` + `ProvincialCostDefault` models + tests |
| 10 | Phase 2 | Agent 2 | My Farm providers |
| 11 | Phase 2 | Agent 2 | My Farm onboarding screens (4-step) + tests |
| 12 | Phase 2 | Agent 2 | Dashboard integration (breakeven cards + setup CTA) |
