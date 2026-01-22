-- ============================================
-- TICKER AND ENGAGEMENT MIGRATION
-- Version: 040
-- Description: Add view for Fertilizer Ticker and online tracking helpers
-- ============================================

-- ============================================
-- TICKER VIEW
-- Group prices by Province/State and Product for the ticker
-- ============================================
CREATE OR REPLACE VIEW ticker_prices AS
SELECT
  r.province_state,
  p.product_name,
  p.product_type,
  ROUND(AVG(pe.price), 2) as avg_price,
  pe.unit,
  pe.currency,
  MAX(pe.created_at) as last_updated,
  COUNT(pe.id) as entry_count
FROM price_entries pe
JOIN products p ON pe.product_id = p.id
JOIN retailers r ON pe.retailer_id = r.id
WHERE pe.created_at >= NOW() - INTERVAL '7 days' -- Show prices from last 7 days
GROUP BY r.province_state, p.product_name, p.product_type, pe.unit, pe.currency
HAVING COUNT(pe.id) >= 1
ORDER BY last_updated DESC;

-- Grant access to public (for unauthenticated ticker)
GRANT SELECT ON ticker_prices TO anon;
GRANT SELECT ON ticker_prices TO authenticated;

COMMENT ON VIEW ticker_prices IS 'Aggregated prices by region for the top rolling ticker';
