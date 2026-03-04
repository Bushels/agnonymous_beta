-- =============================================================================
-- WAVE 2 PART 3: ELEVATOR LOCATIONS
-- Licensed grain elevators across western Canada with PostGIS spatial queries.
-- Source: CGC (Canadian Grain Commission) open data.
-- PostGIS already enabled in 20260304120100_my_farm_tables.sql
-- =============================================================================

CREATE TABLE elevator_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cgc_license_number TEXT,
  facility_name TEXT NOT NULL,
  company TEXT NOT NULL,
  address TEXT,
  city TEXT NOT NULL,
  province TEXT NOT NULL CHECK (province IN ('SK', 'AB', 'MB')),
  postal_code TEXT,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  location GEOGRAPHY(POINT, 4326),
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
CREATE INDEX idx_elevator_facility_name ON elevator_locations(facility_name);

ALTER TABLE elevator_locations ENABLE ROW LEVEL SECURITY;

-- Public read (elevator locations are public reference data)
CREATE POLICY "Anyone can read elevator locations"
  ON elevator_locations FOR SELECT USING (true);

-- Auto-update updated_at
CREATE TRIGGER update_elevator_locations_updated_at
  BEFORE UPDATE ON elevator_locations
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- TRIGGER: Auto-populate location GEOGRAPHY from lat/lng on insert/update
-- =============================================================================

CREATE OR REPLACE FUNCTION set_elevator_location()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
    NEW.location := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_elevator_location_trigger
  BEFORE INSERT OR UPDATE OF latitude, longitude ON elevator_locations
  FOR EACH ROW EXECUTE FUNCTION set_elevator_location();

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
  grain_types TEXT[],
  facility_type TEXT,
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
    e.latitude, e.longitude, e.grain_types, e.facility_type,
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

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
  WHERE (p_province IS NULL OR elevator_locations.province = p_province)
    AND (p_company IS NULL OR elevator_locations.company = p_company)
    AND elevator_locations.is_active = true
  ORDER BY elevator_locations.province, elevator_locations.city, elevator_locations.facility_name
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

-- =============================================================================
-- SEED DATA: Major prairie elevators (representative sample)
-- Coordinates are approximate city-center locations.
-- Full dataset can be loaded from CGC Open Canada GeoJSON portal.
-- =============================================================================

INSERT INTO elevator_locations (facility_name, company, city, province, latitude, longitude, facility_type, grain_types, is_active, last_verified)
VALUES
  -- Saskatchewan (12 elevators)
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

  -- Alberta (8 elevators)
  ('Viterra Lethbridge', 'Viterra', 'Lethbridge', 'AB', 49.6936, -112.8328, 'primary', ARRAY['Canola','Wheat','Barley'], true, '2025-11-01'),
  ('Richardson Pioneer Calgary', 'Richardson Pioneer', 'Calgary', 'AB', 51.0486, -114.0708, 'primary', ARRAY['Canola','Wheat','Barley'], true, '2025-11-01'),
  ('Cargill Claresholm', 'Cargill', 'Claresholm', 'AB', 50.0264, -113.5863, 'primary', ARRAY['Canola','Wheat','Barley','Oats'], true, '2025-11-01'),
  ('P&H Drumheller', 'Parrish & Heimbecker', 'Drumheller', 'AB', 51.4636, -112.7072, 'primary', ARRAY['Canola','Wheat','Barley'], true, '2025-11-01'),
  ('Viterra Camrose', 'Viterra', 'Camrose', 'AB', 53.0167, -112.8340, 'primary', ARRAY['Canola','Wheat','Barley','Peas'], true, '2025-11-01'),
  ('G3 Olds', 'G3 Canada', 'Olds', 'AB', 51.7926, -114.1066, 'primary', ARRAY['Canola','Wheat','Barley'], true, '2025-11-01'),
  ('Richardson Pioneer Red Deer', 'Richardson Pioneer', 'Red Deer', 'AB', 52.2681, -113.8112, 'primary', ARRAY['Canola','Wheat','Barley'], true, '2025-11-01'),
  ('Viterra Vermilion', 'Viterra', 'Vermilion', 'AB', 53.3540, -110.8585, 'primary', ARRAY['Canola','Wheat','Barley','Peas'], true, '2025-11-01'),

  -- Manitoba (8 elevators)
  ('Viterra Winnipeg', 'Viterra', 'Winnipeg', 'MB', 49.8951, -97.1384, 'terminal', ARRAY['Canola','Wheat','Barley','Oats','Soybeans'], true, '2025-11-01'),
  ('Richardson Pioneer Winnipeg', 'Richardson Pioneer', 'Winnipeg', 'MB', 49.8800, -97.1500, 'terminal', ARRAY['Canola','Wheat','Barley'], true, '2025-11-01'),
  ('Cargill Morris', 'Cargill', 'Morris', 'MB', 49.3550, -97.3659, 'primary', ARRAY['Canola','Wheat','Soybeans','Corn'], true, '2025-11-01'),
  ('P&H Brandon', 'Parrish & Heimbecker', 'Brandon', 'MB', 49.8440, -99.9539, 'primary', ARRAY['Canola','Wheat','Barley','Oats'], true, '2025-11-01'),
  ('Viterra Portage la Prairie', 'Viterra', 'Portage la Prairie', 'MB', 49.9728, -98.2925, 'primary', ARRAY['Canola','Wheat','Barley','Oats','Soybeans'], true, '2025-11-01'),
  ('G3 Glenlea', 'G3 Canada', 'Glenlea', 'MB', 49.6460, -97.1117, 'primary', ARRAY['Canola','Wheat','Soybeans'], true, '2025-11-01'),
  ('Richardson Pioneer Dauphin', 'Richardson Pioneer', 'Dauphin', 'MB', 51.1496, -100.0498, 'primary', ARRAY['Canola','Wheat','Barley','Oats'], true, '2025-11-01'),
  ('Viterra Virden', 'Viterra', 'Virden', 'MB', 49.8508, -100.9320, 'primary', ARRAY['Canola','Wheat','Barley','Oats'], true, '2025-11-01');

-- Seed data source config for CGC elevator data
INSERT INTO data_source_config (source_name, source_type, endpoint_url, fetch_schedule, config, is_active)
VALUES (
  'cgc_elevator_locations',
  'cgc_geojson',
  'https://open.canada.ca/data/en/dataset/a84859bd-68c7-43d2-942b-f894b9a4a2dc',
  '0 0 1 8 *',
  '{"format": "geojson", "coverage": ["AB", "SK", "MB"], "note": "Annual bulk load from CGC open data"}'::jsonb,
  true
) ON CONFLICT (source_name) DO NOTHING;
