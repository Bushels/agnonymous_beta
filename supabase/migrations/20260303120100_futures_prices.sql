-- Migration: Create futures_prices table for ICE/CBOT futures price data
-- Date: 2026-03-03
-- Purpose: Store futures contract prices for canola (ICE), wheat, corn, soybeans (CBOT)
--          Pipeline scrapes Barchart.com for settlement and trading data

-- =============================================================================
-- FUTURES PRICES TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS futures_prices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  commodity TEXT NOT NULL,              -- 'CANOLA', 'WHEAT', 'CORN', 'SOYBEANS'
  exchange TEXT NOT NULL,               -- 'ICE', 'CBOT'
  contract_month TEXT NOT NULL,         -- e.g. 'Jul26', 'Nov26', 'Jan27'
  contract_code TEXT,                   -- e.g. 'RSN26', 'RSX26'
  trade_date DATE NOT NULL,            -- the date this price was for
  last_price DECIMAL(10,4),
  change_amount DECIMAL(10,4),          -- daily price change
  change_percent DECIMAL(6,3),          -- daily % change
  open_price DECIMAL(10,4),
  high_price DECIMAL(10,4),
  low_price DECIMAL(10,4),
  settle_price DECIMAL(10,4),           -- settlement price
  prev_close DECIMAL(10,4),
  volume BIGINT,
  open_interest BIGINT,
  is_front_month BOOLEAN DEFAULT false,
  currency TEXT DEFAULT 'CAD',          -- 'CAD' for ICE canola, 'USD' for CBOT
  price_unit TEXT,                      -- e.g. 'CAD/tonne', 'cents/bushel'
  fetched_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(commodity, exchange, contract_month, trade_date)
);

-- =============================================================================
-- INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_futures_commodity_date
  ON futures_prices(commodity, exchange, fetched_at DESC);

CREATE INDEX IF NOT EXISTS idx_futures_front_month
  ON futures_prices(commodity, exchange, is_front_month)
  WHERE is_front_month = true;

CREATE INDEX IF NOT EXISTS idx_futures_contract
  ON futures_prices(commodity, exchange, contract_month, trade_date DESC);

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================

ALTER TABLE futures_prices ENABLE ROW LEVEL SECURITY;

-- Public SELECT (anyone can read — this is market data)
CREATE POLICY "Futures prices are viewable by everyone"
  ON futures_prices FOR SELECT
  USING (true);

-- Only service role can write (Edge Functions use service role)
-- No INSERT/UPDATE/DELETE policies for anon/authenticated = only service role can modify

-- =============================================================================
-- SEED DATA SOURCE CONFIG
-- =============================================================================

INSERT INTO data_source_config (source_name, source_type, endpoint_url, fetch_schedule, config, is_active)
VALUES (
  'barchart_futures',
  'web_scrape',
  'https://www.barchart.com/futures/quotes/RS*0/all-futures',
  '0 */4 * * 1-5',  -- Every 4 hours, weekdays only (market hours)
  '{"format": "html_scrape", "commodities": ["CANOLA","WHEAT","CORN","SOYBEANS"], "symbols": {"CANOLA": "RS*0", "WHEAT": "ZW*0", "CORN": "ZC*0", "SOYBEANS": "ZS*0"}}'::jsonb,
  true
) ON CONFLICT (source_name) DO NOTHING;

-- =============================================================================
-- RPC FUNCTIONS
-- =============================================================================

-- Get latest N days of front-month price for a commodity
CREATE OR REPLACE FUNCTION get_front_month_price(
  target_commodity TEXT,
  num_days INT DEFAULT 30
)
RETURNS TABLE(
  id UUID,
  commodity TEXT,
  exchange TEXT,
  contract_month TEXT,
  contract_code TEXT,
  trade_date DATE,
  last_price DECIMAL(10,4),
  change_amount DECIMAL(10,4),
  change_percent DECIMAL(6,3),
  open_price DECIMAL(10,4),
  high_price DECIMAL(10,4),
  low_price DECIMAL(10,4),
  settle_price DECIMAL(10,4),
  prev_close DECIMAL(10,4),
  volume BIGINT,
  open_interest BIGINT,
  is_front_month BOOLEAN,
  currency TEXT,
  price_unit TEXT,
  fetched_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    fp.id,
    fp.commodity,
    fp.exchange,
    fp.contract_month,
    fp.contract_code,
    fp.trade_date,
    fp.last_price,
    fp.change_amount,
    fp.change_percent,
    fp.open_price,
    fp.high_price,
    fp.low_price,
    fp.settle_price,
    fp.prev_close,
    fp.volume,
    fp.open_interest,
    fp.is_front_month,
    fp.currency,
    fp.price_unit,
    fp.fetched_at,
    fp.created_at
  FROM futures_prices fp
  WHERE fp.commodity = target_commodity
    AND fp.is_front_month = true
  ORDER BY fp.trade_date DESC
  LIMIT num_days;
END;
$$ LANGUAGE plpgsql STABLE;

-- Get all active contract months with latest price for building the futures curve
CREATE OR REPLACE FUNCTION get_contract_curve(
  target_commodity TEXT
)
RETURNS TABLE(
  id UUID,
  commodity TEXT,
  exchange TEXT,
  contract_month TEXT,
  contract_code TEXT,
  trade_date DATE,
  last_price DECIMAL(10,4),
  change_amount DECIMAL(10,4),
  change_percent DECIMAL(6,3),
  open_price DECIMAL(10,4),
  high_price DECIMAL(10,4),
  low_price DECIMAL(10,4),
  settle_price DECIMAL(10,4),
  prev_close DECIMAL(10,4),
  volume BIGINT,
  open_interest BIGINT,
  is_front_month BOOLEAN,
  currency TEXT,
  price_unit TEXT,
  fetched_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT ON (fp.contract_month)
    fp.id,
    fp.commodity,
    fp.exchange,
    fp.contract_month,
    fp.contract_code,
    fp.trade_date,
    fp.last_price,
    fp.change_amount,
    fp.change_percent,
    fp.open_price,
    fp.high_price,
    fp.low_price,
    fp.settle_price,
    fp.prev_close,
    fp.volume,
    fp.open_interest,
    fp.is_front_month,
    fp.currency,
    fp.price_unit,
    fp.fetched_at,
    fp.created_at
  FROM futures_prices fp
  WHERE fp.commodity = target_commodity
  ORDER BY fp.contract_month ASC, fp.trade_date DESC;
END;
$$ LANGUAGE plpgsql STABLE;
