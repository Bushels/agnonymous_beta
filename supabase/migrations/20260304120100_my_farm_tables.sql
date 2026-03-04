-- =============================================================================
-- WAVE 2 PART 2: MY FARM — FARM PROFILES, CROP PLANS, PROVINCIAL DEFAULTS
-- Personal cost/yield/breakeven tracker for prairie farmers.
-- =============================================================================

-- Enable PostGIS for GEOGRAPHY columns (farm location, future elevator queries)
CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA extensions;

-- Ensure update_updated_at_column trigger function exists
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- FARM PROFILES (one per user)
-- =============================================================================

CREATE TABLE farm_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  province TEXT NOT NULL CHECK (province IN ('SK', 'AB', 'MB')),
  nearest_city TEXT,
  total_acres INTEGER,
  location GEOGRAPHY(POINT, 4326),              -- Optional, for nearest-elevator queries
  engagement_level INTEGER DEFAULT 1,            -- 0-4 progressive levels
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

-- Auto-update updated_at
CREATE TRIGGER update_farm_profiles_updated_at
  BEFORE UPDATE ON farm_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- CROP PLANS (per farm, per crop year, per commodity)
-- =============================================================================

CREATE TABLE crop_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_profile_id UUID NOT NULL REFERENCES farm_profiles(id) ON DELETE CASCADE,
  crop_year TEXT NOT NULL DEFAULT '2025-2026',
  commodity TEXT NOT NULL,
  planned_acres DECIMAL(10,1),
  target_yield_bu_per_acre DECIMAL(10,1),

  -- Cost columns (per acre)
  seed_cost_per_acre DECIMAL(10,2),
  fertilizer_cost_per_acre DECIMAL(10,2),
  chemical_cost_per_acre DECIMAL(10,2),
  fuel_cost_per_acre DECIMAL(10,2),
  crop_insurance_per_acre DECIMAL(10,2),
  land_cost_per_acre DECIMAL(10,2),
  equipment_cost_per_acre DECIMAL(10,2),
  labour_cost_per_acre DECIMAL(10,2),
  other_cost_per_acre DECIMAL(10,2),

  -- Generated columns (auto-calculated, read-only)
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

  costs_source TEXT DEFAULT 'provincial_average',  -- 'provincial_average', 'custom', 'mixed'
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

-- Auto-update updated_at
CREATE TRIGGER update_crop_plans_updated_at
  BEFORE UPDATE ON crop_plans
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- PROVINCIAL COST DEFAULTS (public reference data)
-- =============================================================================

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

-- =============================================================================
-- SEED MANITOBA DATA (from MB Crop Production Guidelines 2026)
-- =============================================================================

INSERT INTO provincial_cost_defaults (
  province, crop_year, commodity,
  seed_cost_per_acre, fertilizer_cost_per_acre, chemical_cost_per_acre,
  fuel_cost_per_acre, crop_insurance_per_acre, land_cost_per_acre,
  equipment_cost_per_acre, labour_cost_per_acre, other_cost_per_acre,
  total_cost_per_acre, default_yield_bu_per_acre, breakeven_price_per_bu,
  source_document
) VALUES
  ('MB', '2025-2026', 'Canola',
   82.50, 150.30, 68.75, 32.51, 22.91, 106.24, 110.34, 5.60, 90.84,
   669.99, 45.0, 14.89, 'MB Crop Production Guidelines 2026'),

  ('MB', '2025-2026', 'Wheat HRS',
   42.00, 118.20, 53.50, 30.10, 20.50, 106.24, 110.34, 5.60, 97.98,
   584.46, 66.0, 8.86, 'MB Crop Production Guidelines 2026'),

  ('MB', '2025-2026', 'Soybeans',
   78.00, 45.00, 62.00, 28.50, 18.00, 106.24, 110.34, 5.60, 79.71,
   533.39, 42.0, 12.70, 'MB Crop Production Guidelines 2026'),

  ('MB', '2025-2026', 'Oats',
   35.00, 95.50, 38.00, 28.50, 18.00, 106.24, 110.34, 5.60, 101.37,
   538.55, 120.0, 4.49, 'MB Crop Production Guidelines 2026'),

  ('MB', '2025-2026', 'Barley',
   38.00, 105.00, 42.00, 28.50, 18.00, 106.24, 110.34, 5.60, 55.12,
   508.80, 80.0, 6.36, 'MB Crop Production Guidelines 2026'),

  ('MB', '2025-2026', 'Peas',
   65.00, 52.00, 68.00, 28.50, 18.00, 106.24, 110.34, 5.60, 49.99,
   503.67, 55.0, 9.16, 'MB Crop Production Guidelines 2026'),

  ('MB', '2025-2026', 'Corn',
   120.00, 180.00, 72.00, 35.00, 22.00, 106.24, 110.34, 5.60, 198.10,
   849.28, 145.0, 5.86, 'MB Crop Production Guidelines 2026'),

  ('MB', '2025-2026', 'Lentils',
   55.00, 48.00, 75.00, 28.50, 18.00, 106.24, 110.34, 5.60, 53.61,
   500.29, 29.0, 17.25, 'MB Crop Production Guidelines 2026'),

  ('MB', '2025-2026', 'Flaxseed',
   48.00, 85.00, 55.00, 28.50, 18.00, 106.24, 110.34, 5.60, 43.61,
   500.29, 29.0, 17.25, 'MB Crop Production Guidelines 2026')
ON CONFLICT (province, crop_year, commodity) DO NOTHING;

-- =============================================================================
-- RPC: GET MY FARM (profile + crop plans in one call)
-- =============================================================================

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

-- =============================================================================
-- RPC: GET PROVINCIAL DEFAULTS
-- =============================================================================

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
