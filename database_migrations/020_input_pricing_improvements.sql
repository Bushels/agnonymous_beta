-- ============================================
-- INPUT PRICING SYSTEM IMPROVEMENTS
-- Version: 020
-- Description: Add indexes, triggers, and policy improvements
-- ============================================

-- ============================================
-- ADDITIONAL INDEXES FOR PERFORMANCE
-- ============================================

-- RLS predicate indexes
CREATE INDEX IF NOT EXISTS idx_price_entries_user ON price_entries (user_id);
CREATE INDEX IF NOT EXISTS idx_price_alerts_user_active ON price_alerts (user_id, is_active);

-- Duplicate tracking index
CREATE INDEX IF NOT EXISTS idx_retailers_duplicate ON retailers (duplicate_of) WHERE duplicate_of IS NOT NULL;

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_price_entries_product_date ON price_entries (product_id, price_date DESC);
CREATE INDEX IF NOT EXISTS idx_price_entries_retailer_date ON price_entries (retailer_id, price_date DESC);

-- ============================================
-- UPDATED_AT TRIGGERS
-- ============================================

-- Generic updated_at function (may already exist)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Retailers updated_at trigger
DROP TRIGGER IF EXISTS trigger_retailers_updated_at ON retailers;
CREATE TRIGGER trigger_retailers_updated_at
  BEFORE UPDATE ON retailers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Price alerts updated_at trigger
DROP TRIGGER IF EXISTS trigger_price_alerts_updated_at ON price_alerts;
CREATE TRIGGER trigger_price_alerts_updated_at
  BEFORE UPDATE ON price_alerts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- IMPROVED RLS POLICY FOR PRICE ENTRIES
-- ============================================

-- Drop and recreate price_entries INSERT policy with better check
DROP POLICY IF EXISTS "Authenticated users can create price entries" ON price_entries;

CREATE POLICY "Authenticated users can create price entries"
  ON price_entries FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND (
      -- Anonymous submissions don't require user_id match
      is_anonymous = TRUE
      -- Non-anonymous submissions must match authenticated user
      OR user_id = auth.uid()
    )
  );

-- ============================================
-- GRANT SELECT ON VIEWS
-- ============================================

-- Ensure authenticated users can access views
GRANT SELECT ON price_entries_full TO authenticated;
GRANT SELECT ON recent_prices_by_product TO authenticated;

-- Also allow anon access for public browsing
GRANT SELECT ON price_entries_full TO anon;
GRANT SELECT ON recent_prices_by_product TO anon;

-- ============================================
-- FUNCTION: Get trending products
-- ============================================

CREATE OR REPLACE FUNCTION get_trending_products(
  days_back INTEGER DEFAULT 7,
  limit_count INTEGER DEFAULT 10
)
RETURNS TABLE (
  product_id UUID,
  product_type TEXT,
  product_name TEXT,
  analysis TEXT,
  entry_count BIGINT,
  avg_price DECIMAL(10,2),
  price_change DECIMAL(5,2)
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id as product_id,
    p.product_type,
    p.product_name,
    p.analysis,
    COUNT(pe.id) as entry_count,
    ROUND(AVG(pe.price), 2) as avg_price,
    ROUND(
      (AVG(CASE WHEN pe.price_date >= CURRENT_DATE - (days_back / 2) THEN pe.price END) -
       AVG(CASE WHEN pe.price_date < CURRENT_DATE - (days_back / 2) THEN pe.price END)) /
      NULLIF(AVG(CASE WHEN pe.price_date < CURRENT_DATE - (days_back / 2) THEN pe.price END), 0) * 100,
      2
    ) as price_change
  FROM products p
  JOIN price_entries pe ON p.id = pe.product_id
  WHERE pe.price_date >= CURRENT_DATE - days_back
  GROUP BY p.id, p.product_type, p.product_name, p.analysis
  HAVING COUNT(pe.id) >= 2
  ORDER BY entry_count DESC, price_change DESC NULLS LAST
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Get price history for charting
-- ============================================

CREATE OR REPLACE FUNCTION get_price_history(
  product_id_in UUID,
  province_state_in TEXT DEFAULT NULL,
  days_back INTEGER DEFAULT 365
)
RETURNS TABLE (
  price_date DATE,
  avg_price DECIMAL(10,2),
  min_price DECIMAL(10,2),
  max_price DECIMAL(10,2),
  entry_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    pe.price_date,
    ROUND(AVG(pe.price), 2) as avg_price,
    MIN(pe.price) as min_price,
    MAX(pe.price) as max_price,
    COUNT(*) as entry_count
  FROM price_entries pe
  JOIN retailers r ON pe.retailer_id = r.id
  WHERE pe.product_id = product_id_in
    AND (province_state_in IS NULL OR r.province_state = province_state_in)
    AND pe.price_date >= CURRENT_DATE - days_back
  GROUP BY pe.price_date
  ORDER BY pe.price_date;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_trending_products IS 'Get products with most price entries and biggest price changes';
COMMENT ON FUNCTION get_price_history IS 'Get daily price history for charting';
