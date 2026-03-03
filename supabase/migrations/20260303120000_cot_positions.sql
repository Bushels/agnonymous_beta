-- Migration: Create cot_positions table for CFTC Commitments of Traders data
-- Date: 2026-03-03
-- Purpose: Store weekly COT reports for canola, wheat, corn, soybeans
--          Pipeline fetches from CFTC combined futures + options report

-- =============================================================================
-- COT POSITIONS TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS cot_positions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_date DATE NOT NULL,
  commodity TEXT NOT NULL,               -- 'CANOLA', 'WHEAT', 'CORN', 'SOYBEANS'
  exchange TEXT NOT NULL,                -- 'ICE', 'CBOT'
  report_type TEXT DEFAULT 'combined_futures_options',
  commercial_long BIGINT,
  commercial_short BIGINT,
  commercial_net BIGINT GENERATED ALWAYS AS (commercial_long - commercial_short) STORED,
  non_commercial_long BIGINT,
  non_commercial_short BIGINT,
  non_commercial_net BIGINT GENERATED ALWAYS AS (non_commercial_long - non_commercial_short) STORED,
  non_commercial_spreads BIGINT,
  open_interest BIGINT,
  commercial_net_change BIGINT,          -- vs previous week
  non_commercial_net_change BIGINT,      -- vs previous week
  open_interest_change BIGINT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(report_date, commodity, exchange)
);

-- =============================================================================
-- INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_cot_commodity_date
  ON cot_positions(commodity, exchange, report_date DESC);

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================

ALTER TABLE cot_positions ENABLE ROW LEVEL SECURITY;

-- Public SELECT (anyone can read — this is public government data)
CREATE POLICY "COT positions are viewable by everyone"
  ON cot_positions FOR SELECT
  USING (true);

-- Only service role can write (Edge Functions use service role)
-- No INSERT/UPDATE/DELETE policies for anon/authenticated = only service role can modify

-- =============================================================================
-- SEED DATA SOURCE CONFIG
-- =============================================================================

INSERT INTO data_source_config (source_name, source_type, endpoint_url, fetch_schedule, config, is_active)
VALUES (
  'cftc_cot_weekly',
  'csv_download',
  'https://www.cftc.gov/dea/newcot/deacom.txt',
  '0 6 * * 6',  -- Saturday 6am UTC — CFTC publishes Friday afternoon
  '{"format": "comma_delimited_text", "report": "combined_futures_options", "commodities": ["CANOLA","WHEAT","CORN","SOYBEANS"]}'::jsonb,
  true
) ON CONFLICT (source_name) DO NOTHING;

-- =============================================================================
-- RPC FUNCTIONS
-- =============================================================================

-- Get latest N weeks of COT data for a commodity
CREATE OR REPLACE FUNCTION get_latest_cot_positions(
  commodity_filter TEXT,
  num_weeks INT DEFAULT 12
)
RETURNS TABLE(
  id UUID,
  report_date DATE,
  commodity TEXT,
  exchange TEXT,
  report_type TEXT,
  commercial_long BIGINT,
  commercial_short BIGINT,
  commercial_net BIGINT,
  non_commercial_long BIGINT,
  non_commercial_short BIGINT,
  non_commercial_net BIGINT,
  non_commercial_spreads BIGINT,
  open_interest BIGINT,
  commercial_net_change BIGINT,
  non_commercial_net_change BIGINT,
  open_interest_change BIGINT,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    cp.id,
    cp.report_date,
    cp.commodity,
    cp.exchange,
    cp.report_type,
    cp.commercial_long,
    cp.commercial_short,
    cp.commercial_net,
    cp.non_commercial_long,
    cp.non_commercial_short,
    cp.non_commercial_net,
    cp.non_commercial_spreads,
    cp.open_interest,
    cp.commercial_net_change,
    cp.non_commercial_net_change,
    cp.open_interest_change,
    cp.created_at
  FROM cot_positions cp
  WHERE cp.commodity = commodity_filter
  ORDER BY cp.report_date DESC
  LIMIT LEAST(num_weeks, 52);
END;
$$ LANGUAGE plpgsql STABLE;

-- Get weekly net changes for a commodity (for sparkline / trend display)
CREATE OR REPLACE FUNCTION get_cot_net_change(
  target_commodity TEXT,
  num_weeks INT DEFAULT 4
)
RETURNS TABLE(
  report_date DATE,
  commercial_net BIGINT,
  commercial_net_change BIGINT,
  non_commercial_net BIGINT,
  non_commercial_net_change BIGINT,
  open_interest BIGINT,
  open_interest_change BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    cp.report_date,
    cp.commercial_net,
    cp.commercial_net_change,
    cp.non_commercial_net,
    cp.non_commercial_net_change,
    cp.open_interest,
    cp.open_interest_change
  FROM cot_positions cp
  WHERE cp.commodity = target_commodity
  ORDER BY cp.report_date DESC
  LIMIT LEAST(num_weeks, 52);
END;
$$ LANGUAGE plpgsql STABLE;
