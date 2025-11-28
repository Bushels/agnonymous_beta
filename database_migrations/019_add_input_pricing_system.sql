-- ============================================
-- INPUT PRICING SYSTEM MIGRATION
-- Version: 019
-- Description: Create tables for crowdsourced input pricing
-- ============================================

-- Enable pg_trgm extension for fuzzy text search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================
-- RETAILER CHAINS TABLE
-- Known retailer chains with aliases for matching
-- ============================================
CREATE TABLE IF NOT EXISTS retailer_chains (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  aliases TEXT[] DEFAULT '{}',
  logo_url TEXT,
  website TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed common retailer chains
INSERT INTO retailer_chains (name, aliases) VALUES
  ('Nutrien Ag Solutions', ARRAY['Nutrien', 'Nutrien Ag', 'Agrium']),
  ('Richardson Pioneer', ARRAY['Richardson', 'Pioneer Grain']),
  ('Cargill', ARRAY['Cargill Ag', 'Cargill Grain']),
  ('Parrish & Heimbecker', ARRAY['P&H', 'Parrish Heimbecker']),
  ('Viterra', ARRAY['Viterra Grain']),
  ('G3 Canada', ARRAY['G3']),
  ('UFA', ARRAY['United Farmers of Alberta']),
  ('Federated Co-op', ARRAY['Co-op', 'FCL']),
  ('CHS Inc', ARRAY['CHS']),
  ('ADM', ARRAY['Archer Daniels Midland']),
  ('Bunge', ARRAY['Bunge North America']),
  ('Helena Agri-Enterprises', ARRAY['Helena', 'Helena Chemical']),
  ('Simplot', ARRAY['J.R. Simplot', 'Simplot Grower Solutions']),
  ('Wilbur-Ellis', ARRAY['Wilbur Ellis'])
ON CONFLICT (name) DO NOTHING;

-- ============================================
-- RETAILERS TABLE
-- Individual retailer locations
-- ============================================
CREATE TABLE IF NOT EXISTS retailers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Identity
  name TEXT NOT NULL,
  chain_id UUID REFERENCES retailer_chains(id),

  -- Location
  city TEXT NOT NULL,
  province_state TEXT NOT NULL,
  country TEXT NOT NULL DEFAULT 'Canada',
  address TEXT,
  postal_code TEXT,

  -- Geo (for future mapping)
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,

  -- Deduplication
  duplicate_of UUID REFERENCES retailers(id),
  verified BOOLEAN DEFAULT FALSE,

  -- Stats
  price_entry_count INTEGER DEFAULT 0,

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES user_profiles(id),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraint
  CONSTRAINT unique_retailer UNIQUE (name, city, province_state)
);

-- Trigram index for fuzzy search
CREATE INDEX IF NOT EXISTS idx_retailers_name_trgm ON retailers USING GIN (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_retailers_location ON retailers (province_state, city);
CREATE INDEX IF NOT EXISTS idx_retailers_chain ON retailers (chain_id);

-- ============================================
-- PRODUCTS TABLE
-- Agricultural products (fertilizers, seeds, chemicals, equipment)
-- ============================================
CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Type: fertilizer, seed, chemical, equipment
  product_type TEXT NOT NULL CHECK (
    product_type IN ('fertilizer', 'seed', 'chemical', 'equipment')
  ),

  -- Product identification
  product_name TEXT NOT NULL,      -- "Urea", "InVigor L340P", "Liberty 150"
  brand_name TEXT,                 -- "Bayer", "BASF", "Pioneer"
  formulation TEXT,                -- "Granular", "Liquid", "Liberty Link"

  -- Type-specific attributes
  analysis TEXT,                   -- "46-0-0" for fertilizer
  active_ingredient TEXT,          -- For chemicals
  crop_type TEXT,                  -- For seeds
  trait_platform TEXT,             -- "LL", "RR", "Clearfield"

  -- Categorization
  sub_category TEXT,               -- "Nitrogen", "Herbicide", etc.

  -- Metadata
  default_unit TEXT,
  is_proprietary BOOLEAN DEFAULT FALSE,
  price_entry_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES user_profiles(id),

  -- Prevent duplicates
  UNIQUE(product_type, product_name, brand_name, formulation)
);

-- Full text search index
CREATE INDEX IF NOT EXISTS idx_products_search ON products
  USING GIN (to_tsvector('english',
    COALESCE(product_name, '') || ' ' ||
    COALESCE(brand_name, '') || ' ' ||
    COALESCE(formulation, '')
  ));
CREATE INDEX IF NOT EXISTS idx_products_type ON products (product_type);
CREATE INDEX IF NOT EXISTS idx_products_name_trgm ON products USING GIN (product_name gin_trgm_ops);

-- Seed common products
INSERT INTO products (product_type, product_name, analysis, sub_category, default_unit) VALUES
  -- Nitrogen fertilizers
  ('fertilizer', 'Urea', '46-0-0', 'Nitrogen', 'tonne'),
  ('fertilizer', 'Anhydrous Ammonia', '82-0-0', 'Nitrogen', 'tonne'),
  ('fertilizer', 'UAN 28%', '28-0-0', 'Nitrogen', 'tonne'),
  ('fertilizer', 'UAN 32%', '32-0-0', 'Nitrogen', 'tonne'),
  ('fertilizer', 'Ammonium Nitrate', '34-0-0', 'Nitrogen', 'tonne'),
  -- Phosphate fertilizers
  ('fertilizer', 'MAP', '11-52-0', 'Phosphate', 'tonne'),
  ('fertilizer', 'DAP', '18-46-0', 'Phosphate', 'tonne'),
  ('fertilizer', 'Triple Superphosphate', '0-46-0', 'Phosphate', 'tonne'),
  -- Potash
  ('fertilizer', 'Muriate of Potash', '0-0-60', 'Potash', 'tonne'),
  ('fertilizer', 'Sulfate of Potash', '0-0-50', 'Potash', 'tonne'),
  -- Sulfur
  ('fertilizer', 'Ammonium Sulfate', '21-0-0-24S', 'Sulfur', 'tonne'),
  ('fertilizer', 'Elemental Sulfur', '0-0-0-90S', 'Sulfur', 'tonne')
ON CONFLICT DO NOTHING;

-- ============================================
-- PRICE ENTRIES TABLE
-- Crowdsourced price data
-- ============================================
CREATE TABLE IF NOT EXISTS price_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Links
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  retailer_id UUID NOT NULL REFERENCES retailers(id) ON DELETE CASCADE,

  -- Price data
  price DECIMAL(10,2) NOT NULL,
  unit TEXT NOT NULL,
  currency TEXT NOT NULL DEFAULT 'CAD' CHECK (currency IN ('CAD', 'USD')),
  price_date DATE NOT NULL DEFAULT CURRENT_DATE,

  -- User
  user_id UUID REFERENCES user_profiles(id),
  is_anonymous BOOLEAN DEFAULT TRUE,

  -- Notes
  notes TEXT,

  -- Quality/Validation
  report_count INTEGER DEFAULT 0,
  thumbs_up_count INTEGER DEFAULT 0,
  thumbs_down_count INTEGER DEFAULT 0,
  confidence_score DECIMAL(3,2) DEFAULT 0.5,

  -- Link to post (if created via post)
  post_id UUID REFERENCES posts(id),

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- Prevent duplicate entries same day from same user
  UNIQUE(product_id, retailer_id, price_date, user_id)
);

CREATE INDEX IF NOT EXISTS idx_price_entries_product ON price_entries (product_id);
CREATE INDEX IF NOT EXISTS idx_price_entries_retailer ON price_entries (retailer_id);
CREATE INDEX IF NOT EXISTS idx_price_entries_date ON price_entries (price_date DESC);
CREATE INDEX IF NOT EXISTS idx_price_entries_location ON price_entries (retailer_id, price_date DESC);

-- ============================================
-- PRICE ALERTS TABLE
-- User-configured price alerts
-- ============================================
CREATE TABLE IF NOT EXISTS price_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- User
  user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,

  -- What to watch
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  product_type TEXT,  -- If watching a category
  province_state TEXT,

  -- Conditions
  target_price DECIMAL(10,2),
  alert_type TEXT NOT NULL CHECK (alert_type IN ('below', 'above', 'any')),

  -- Status
  is_active BOOLEAN DEFAULT TRUE,
  last_triggered TIMESTAMPTZ,
  trigger_count INTEGER DEFAULT 0,

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_price_alerts_user ON price_alerts (user_id);
CREATE INDEX IF NOT EXISTS idx_price_alerts_product ON price_alerts (product_id);

-- ============================================
-- FUNCTIONS
-- ============================================

-- Smart retailer search with fuzzy matching
CREATE OR REPLACE FUNCTION search_retailers_smart(
  search_term TEXT,
  province_state_in TEXT,
  city_in TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  city TEXT,
  province_state TEXT,
  chain_name TEXT,
  match_type TEXT,
  similarity_score FLOAT
) AS $$
BEGIN
  RETURN QUERY

  -- Exact matches
  SELECT
    r.id, r.name, r.city, r.province_state,
    rc.name as chain_name,
    'exact'::TEXT as match_type,
    1.0::FLOAT as similarity_score
  FROM retailers r
  LEFT JOIN retailer_chains rc ON r.chain_id = rc.id
  WHERE r.duplicate_of IS NULL
    AND r.province_state = province_state_in
    AND (city_in IS NULL OR r.city ILIKE '%' || city_in || '%')
    AND r.name ILIKE '%' || search_term || '%'

  UNION ALL

  -- Fuzzy matches
  SELECT
    r.id, r.name, r.city, r.province_state,
    rc.name as chain_name,
    'fuzzy'::TEXT as match_type,
    similarity(r.name, search_term)::FLOAT as similarity_score
  FROM retailers r
  LEFT JOIN retailer_chains rc ON r.chain_id = rc.id
  WHERE r.duplicate_of IS NULL
    AND r.province_state = province_state_in
    AND similarity(r.name, search_term) > 0.3
    AND r.name NOT ILIKE '%' || search_term || '%'

  ORDER BY similarity_score DESC, match_type
  LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- Smart product search
CREATE OR REPLACE FUNCTION search_products_smart(
  search_term TEXT,
  product_type_in TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  product_type TEXT,
  product_name TEXT,
  brand_name TEXT,
  formulation TEXT,
  analysis TEXT,
  sub_category TEXT,
  default_unit TEXT,
  similarity_score FLOAT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.product_type,
    p.product_name,
    p.brand_name,
    p.formulation,
    p.analysis,
    p.sub_category,
    p.default_unit,
    GREATEST(
      similarity(p.product_name, search_term),
      COALESCE(similarity(p.brand_name, search_term), 0),
      COALESCE(similarity(p.analysis, search_term), 0)
    )::FLOAT as similarity_score
  FROM products p
  WHERE (product_type_in IS NULL OR p.product_type = product_type_in)
    AND (
      p.product_name ILIKE '%' || search_term || '%'
      OR p.brand_name ILIKE '%' || search_term || '%'
      OR p.analysis ILIKE '%' || search_term || '%'
      OR similarity(p.product_name, search_term) > 0.3
    )
  ORDER BY similarity_score DESC
  LIMIT 20;
END;
$$ LANGUAGE plpgsql;

-- Get price stats for a product in a region
CREATE OR REPLACE FUNCTION get_price_stats(
  product_id_in UUID,
  province_state_in TEXT DEFAULT NULL,
  days_back INTEGER DEFAULT 90
)
RETURNS TABLE (
  avg_price DECIMAL(10,2),
  min_price DECIMAL(10,2),
  max_price DECIMAL(10,2),
  entry_count BIGINT,
  latest_price DECIMAL(10,2),
  latest_date DATE
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    ROUND(AVG(pe.price), 2) as avg_price,
    MIN(pe.price) as min_price,
    MAX(pe.price) as max_price,
    COUNT(*) as entry_count,
    (SELECT pe2.price FROM price_entries pe2
     JOIN retailers r2 ON pe2.retailer_id = r2.id
     WHERE pe2.product_id = product_id_in
     AND (province_state_in IS NULL OR r2.province_state = province_state_in)
     ORDER BY pe2.price_date DESC LIMIT 1) as latest_price,
    (SELECT pe2.price_date FROM price_entries pe2
     JOIN retailers r2 ON pe2.retailer_id = r2.id
     WHERE pe2.product_id = product_id_in
     AND (province_state_in IS NULL OR r2.province_state = province_state_in)
     ORDER BY pe2.price_date DESC LIMIT 1) as latest_date
  FROM price_entries pe
  JOIN retailers r ON pe.retailer_id = r.id
  WHERE pe.product_id = product_id_in
    AND (province_state_in IS NULL OR r.province_state = province_state_in)
    AND pe.price_date >= CURRENT_DATE - days_back;
END;
$$ LANGUAGE plpgsql;

-- Update product/retailer counts when price entry is added
CREATE OR REPLACE FUNCTION update_price_entry_counts()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE products SET price_entry_count = price_entry_count + 1 WHERE id = NEW.product_id;
    UPDATE retailers SET price_entry_count = price_entry_count + 1 WHERE id = NEW.retailer_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE products SET price_entry_count = price_entry_count - 1 WHERE id = OLD.product_id;
    UPDATE retailers SET price_entry_count = price_entry_count - 1 WHERE id = OLD.retailer_id;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_price_counts
  AFTER INSERT OR DELETE ON price_entries
  FOR EACH ROW EXECUTE FUNCTION update_price_entry_counts();

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

ALTER TABLE retailer_chains ENABLE ROW LEVEL SECURITY;
ALTER TABLE retailers ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE price_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE price_alerts ENABLE ROW LEVEL SECURITY;

-- Retailer chains: public read
CREATE POLICY "Retailer chains are viewable by everyone"
  ON retailer_chains FOR SELECT
  USING (true);

-- Retailers: public read, authenticated insert
CREATE POLICY "Retailers are viewable by everyone"
  ON retailers FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can create retailers"
  ON retailers FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Products: public read, authenticated insert
CREATE POLICY "Products are viewable by everyone"
  ON products FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can create products"
  ON products FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Price entries: public read, authenticated insert
CREATE POLICY "Price entries are viewable by everyone"
  ON price_entries FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can create price entries"
  ON price_entries FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Users can update own price entries"
  ON price_entries FOR UPDATE
  USING (auth.uid() = user_id);

-- Price alerts: user-specific
CREATE POLICY "Users can view own alerts"
  ON price_alerts FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create own alerts"
  ON price_alerts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own alerts"
  ON price_alerts FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own alerts"
  ON price_alerts FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================
-- VIEWS
-- ============================================

-- Price entries with full details
CREATE OR REPLACE VIEW price_entries_full AS
SELECT
  pe.*,
  p.product_type,
  p.product_name,
  p.brand_name,
  p.formulation,
  p.analysis,
  p.sub_category,
  r.name as retailer_name,
  r.city as retailer_city,
  r.province_state as retailer_province_state,
  rc.name as chain_name
FROM price_entries pe
JOIN products p ON pe.product_id = p.id
JOIN retailers r ON pe.retailer_id = r.id
LEFT JOIN retailer_chains rc ON r.chain_id = rc.id;

-- Recent prices by product
CREATE OR REPLACE VIEW recent_prices_by_product AS
SELECT
  p.id as product_id,
  p.product_type,
  p.product_name,
  p.analysis,
  COUNT(pe.id) as entry_count,
  ROUND(AVG(pe.price), 2) as avg_price,
  MIN(pe.price) as min_price,
  MAX(pe.price) as max_price,
  MAX(pe.price_date) as latest_date
FROM products p
LEFT JOIN price_entries pe ON p.id = pe.product_id
  AND pe.price_date >= CURRENT_DATE - 30
GROUP BY p.id, p.product_type, p.product_name, p.analysis;

COMMENT ON TABLE retailer_chains IS 'Known retailer chains with aliases for matching';
COMMENT ON TABLE retailers IS 'Individual retailer locations for price tracking';
COMMENT ON TABLE products IS 'Agricultural products (fertilizers, seeds, chemicals, equipment)';
COMMENT ON TABLE price_entries IS 'Crowdsourced price data entries';
COMMENT ON TABLE price_alerts IS 'User-configured price alerts';
