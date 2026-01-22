-- ============================================
-- FERTILIZER TICKER MIGRATION
-- Version: 041
-- Description: Simplified fertilizer price ticker for anonymous submissions
-- ============================================

-- ============================================
-- FERTILIZER TICKER ENTRIES TABLE
-- Lightweight table for quick price submissions
-- ============================================
CREATE TABLE IF NOT EXISTS fertilizer_ticker_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Fertilizer Type
  fertilizer_type TEXT NOT NULL CHECK (
    fertilizer_type IN ('NH3', '46-0-0')
  ),
  
  -- Price Data
  price DECIMAL(10,2) NOT NULL CHECK (price > 0),
  unit TEXT NOT NULL CHECK (unit IN ('metric_tonne', 'short_ton')),
  currency TEXT NOT NULL DEFAULT 'CAD' CHECK (currency IN ('CAD', 'USD')),
  
  -- Location
  province_state TEXT NOT NULL,
  
  -- Tracking (for rate limiting, no user identity exposed)
  anonymous_user_id TEXT NOT NULL,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_fertilizer_ticker_province 
  ON fertilizer_ticker_entries (province_state);
CREATE INDEX IF NOT EXISTS idx_fertilizer_ticker_type 
  ON fertilizer_ticker_entries (fertilizer_type);
CREATE INDEX IF NOT EXISTS idx_fertilizer_ticker_created 
  ON fertilizer_ticker_entries (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fertilizer_ticker_anon_id 
  ON fertilizer_ticker_entries (anonymous_user_id, created_at DESC);

-- ============================================
-- VIEW: FERTILIZER TICKER AVERAGES
-- Average prices by province/state and type
-- ============================================
CREATE OR REPLACE VIEW fertilizer_ticker_averages AS
SELECT
  province_state,
  fertilizer_type,
  ROUND(AVG(price), 2) as avg_price,
  unit,
  currency,
  COUNT(*) as entry_count,
  MAX(created_at) as last_updated
FROM fertilizer_ticker_entries
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY province_state, fertilizer_type, unit, currency
ORDER BY province_state, fertilizer_type;

-- ============================================
-- VIEW: FERTILIZER TICKER RECENT
-- Last 20 price updates for the scrolling ticker
-- ============================================
CREATE OR REPLACE VIEW fertilizer_ticker_recent AS
SELECT
  id,
  province_state,
  fertilizer_type,
  price,
  unit,
  currency,
  created_at
FROM fertilizer_ticker_entries
ORDER BY created_at DESC
LIMIT 20;

-- ============================================
-- FUNCTION: Submit Ticker Price
-- Rate limited to 1 submission per type per 24 hours per user
-- ============================================
CREATE OR REPLACE FUNCTION submit_fertilizer_ticker_price(
  p_fertilizer_type TEXT,
  p_price DECIMAL(10,2),
  p_unit TEXT,
  p_currency TEXT,
  p_province_state TEXT,
  p_anonymous_user_id TEXT
)
RETURNS UUID AS $$
DECLARE
  v_last_submission TIMESTAMPTZ;
  v_new_id UUID;
BEGIN
  -- Check rate limit: 1 submission per fertilizer type per 24 hours
  SELECT created_at INTO v_last_submission
  FROM fertilizer_ticker_entries
  WHERE anonymous_user_id = p_anonymous_user_id
    AND fertilizer_type = p_fertilizer_type
    AND created_at > NOW() - INTERVAL '24 hours'
  ORDER BY created_at DESC
  LIMIT 1;
  
  IF v_last_submission IS NOT NULL THEN
    RAISE EXCEPTION 'Rate limit: You can only submit one % price per 24 hours. Please try again later.', p_fertilizer_type;
  END IF;
  
  -- Insert the entry
  INSERT INTO fertilizer_ticker_entries (
    fertilizer_type,
    price,
    unit,
    currency,
    province_state,
    anonymous_user_id
  ) VALUES (
    p_fertilizer_type,
    p_price,
    p_unit,
    p_currency,
    p_province_state,
    p_anonymous_user_id
  )
  RETURNING id INTO v_new_id;
  
  RETURN v_new_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================
ALTER TABLE fertilizer_ticker_entries ENABLE ROW LEVEL SECURITY;

-- Anyone can view ticker entries (public data)
DROP POLICY IF EXISTS "Ticker entries are viewable by everyone" ON fertilizer_ticker_entries;
CREATE POLICY "Ticker entries are viewable by everyone"
  ON fertilizer_ticker_entries FOR SELECT
  USING (true);

-- Anyone can insert via-- Allow RPC/Server-side to insert (we'll use a security definer function for inserts)
-- We DO NOT allow direct inserts from client to prevent spam/manipulation
DROP POLICY IF EXISTS "No direct inserts" ON public.fertilizer_ticker_entries;
CREATE POLICY "No direct inserts" 
ON public.fertilizer_ticker_entries FOR INSERT 
WITH CHECK (false);

-- No updates or deletes allowed
CREATE POLICY "No updates allowed"
  ON fertilizer_ticker_entries FOR UPDATE
  USING (false);

CREATE POLICY "No deletes allowed"
  ON fertilizer_ticker_entries FOR DELETE
  USING (false);

-- Grant execute on the submit function to anon and authenticated
GRANT EXECUTE ON FUNCTION submit_fertilizer_ticker_price TO anon;
GRANT EXECUTE ON FUNCTION submit_fertilizer_ticker_price TO authenticated;

-- Grant select on views
GRANT SELECT ON fertilizer_ticker_averages TO anon;
GRANT SELECT ON fertilizer_ticker_averages TO authenticated;
GRANT SELECT ON fertilizer_ticker_recent TO anon;
GRANT SELECT ON fertilizer_ticker_recent TO authenticated;

-- ============================================
-- COMMENTS
-- ============================================
COMMENT ON TABLE fertilizer_ticker_entries IS 'Anonymous fertilizer price submissions for the live ticker';
COMMENT ON VIEW fertilizer_ticker_averages IS 'Average fertilizer prices by region for display in ticker header';
COMMENT ON VIEW fertilizer_ticker_recent IS 'Last 20 fertilizer price submissions for scrolling ticker';
COMMENT ON FUNCTION submit_fertilizer_ticker_price IS 'Rate-limited function to submit fertilizer prices anonymously';
