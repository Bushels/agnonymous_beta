-- =============================================================================
-- WAVE 2 PART 1: LOCAL CASH PRICES
-- PDQ daily cash grain prices and basis for western Canadian elevators.
-- Future sources: farmer_report, elevator_scrape
-- =============================================================================

CREATE TABLE local_cash_prices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source TEXT NOT NULL DEFAULT 'pdq',           -- 'pdq', 'farmer_report', 'elevator_scrape'
  elevator_name TEXT NOT NULL,
  company TEXT,
  location_city TEXT,
  location_province TEXT NOT NULL,              -- SK, AB, MB
  commodity TEXT NOT NULL,                      -- 'Canola', '1CWRS', etc.
  grade TEXT,                                   -- '#1', '#2', 'Feed', etc.
  bid_price_cad DECIMAL(10,2),                 -- Cash price in CAD/tonne or CAD/bushel
  bid_unit TEXT DEFAULT 'tonne',               -- 'tonne' or 'bushel'
  basis DECIMAL(10,2),                         -- Spread vs futures (negative = under)
  futures_reference TEXT,                       -- Which futures contract this basis is vs
  price_date DATE NOT NULL,
  fetched_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(source, elevator_name, commodity, grade, price_date)
);

-- Indexes for common query patterns
CREATE INDEX idx_cash_prices_commodity ON local_cash_prices(commodity);
CREATE INDEX idx_cash_prices_province ON local_cash_prices(location_province);
CREATE INDEX idx_cash_prices_date ON local_cash_prices(price_date DESC);
CREATE INDEX idx_cash_prices_source_date ON local_cash_prices(source, price_date DESC);

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================

ALTER TABLE local_cash_prices ENABLE ROW LEVEL SECURITY;

-- Public read (market data is public)
CREATE POLICY "Anyone can read cash prices"
  ON local_cash_prices FOR SELECT USING (true);

-- =============================================================================
-- RPC: GET CASH PRICES WITH FILTERING
-- =============================================================================

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

-- =============================================================================
-- SEED DATA SOURCE CONFIG
-- =============================================================================

INSERT INTO data_source_config (source_name, source_type, endpoint_url, fetch_schedule, config, is_active)
VALUES (
  'pdq_cash_prices',
  'pdq',
  'https://www.albertagrains.com/markets/pdq/',
  '0 1 * * 1-5',  -- Daily at 1am UTC (6pm MST previous day) on weekdays
  '{"format": "html_scrape", "timezone": "America/Edmonton", "coverage": ["AB", "SK", "MB"]}'::jsonb,
  true
) ON CONFLICT (source_name) DO NOTHING;
