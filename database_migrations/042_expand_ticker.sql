-- ============================================
-- FERTILIZER TICKER EXPANSION
-- Version: 042
-- Description: Adds delivery_mode, S15 fertilizer, and updates constraints
-- ============================================

-- 1. ADD delivery_mode COLUMN
-- We first check if it exists to be safe
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='fertilizer_ticker_entries' AND column_name='delivery_mode') THEN
        ALTER TABLE fertilizer_ticker_entries ADD COLUMN delivery_mode TEXT NOT NULL DEFAULT 'picked_up';
        
        -- Add constraint for delivery_mode
        ALTER TABLE fertilizer_ticker_entries ADD CONSTRAINT check_delivery_mode 
            CHECK (delivery_mode IN ('picked_up', 'delivered'));
    END IF;
END $$;

-- 2. UPDATE FERTILIZER TYPE CONSTRAINT
-- We need to drop the old check constraint to allow S15
-- Note: Postgres constraints often have auto-generated names if not named explicitly in CREATE TABLE.
-- in 041 we did: fertilizer_type IN ('NH3', '46-0-0') directly in column definition.
-- This usually creates a constraint named table_col_check.
-- We will try to drop the constraint on fertilizer_type if we can find it.

DO $$
DECLARE 
    con_name text;
BEGIN
    SELECT con.conname INTO con_name
    FROM pg_catalog.pg_constraint con
    INNER JOIN pg_catalog.pg_class rel ON rel.oid = con.conrelid
    INNER JOIN pg_catalog.pg_attribute att ON att.attrelid = rel.oid AND att.attnum = ANY(con.conkey)
    WHERE rel.relname = 'fertilizer_ticker_entries' AND att.attname = 'fertilizer_type' AND con.contype = 'c';
    
    IF con_name IS NOT NULL THEN
        EXECUTE 'ALTER TABLE fertilizer_ticker_entries DROP CONSTRAINT ' || con_name;
    END IF;
END $$;

-- Re-add constraint with new types (NH3, 46-0-0, S15)
-- We allow relaxing it later by just not having a check, or updating it here.
-- Let's stick to specific allowed types for data integrity.
ALTER TABLE fertilizer_ticker_entries ADD CONSTRAINT check_fertilizer_type_v2
    CHECK (fertilizer_type IN ('NH3', '46-0-0', 'S15'));

-- 3. UPDATE VIEWS

-- Update Averages View to group by Delivery Mode
DROP VIEW IF EXISTS fertilizer_ticker_averages;

CREATE OR REPLACE VIEW fertilizer_ticker_averages AS
SELECT
  province_state,
  fertilizer_type,
  delivery_mode,
  ROUND(AVG(price), 2) as avg_price,
  unit,
  currency,
  COUNT(*) as entry_count,
  MAX(created_at) as last_updated
FROM fertilizer_ticker_entries
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY province_state, fertilizer_type, delivery_mode, unit, currency
ORDER BY province_state, fertilizer_type, delivery_mode;

-- Update Recent View to include Delivery Mode and limit 50
DROP VIEW IF EXISTS fertilizer_ticker_recent;

CREATE OR REPLACE VIEW fertilizer_ticker_recent AS
SELECT
  id,
  province_state,
  fertilizer_type,
  delivery_mode,
  price,
  unit,
  currency,
  created_at
FROM fertilizer_ticker_entries
ORDER BY created_at DESC
LIMIT 50;

-- 4. UPDATE RPC FUNCTION
-- We need to drop the old one first because signature changes
DROP FUNCTION IF EXISTS submit_fertilizer_ticker_price(TEXT, DECIMAL, TEXT, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION submit_fertilizer_ticker_price(
  p_fertilizer_type TEXT,
  p_price DECIMAL(10,2),
  p_unit TEXT,
  p_currency TEXT,
  p_province_state TEXT,
  p_anonymous_user_id TEXT,
  p_delivery_mode TEXT DEFAULT 'picked_up'
)
RETURNS UUID AS $$
DECLARE
  v_last_submission TIMESTAMPTZ;
  v_new_id UUID;
BEGIN
  -- Check rate limit: 1 submission per fertilizer type per 24 hours
  -- (We don't strictly separate rate limit by delivery mode to prevent spamming both)
  SELECT created_at INTO v_last_submission
  FROM fertilizer_ticker_entries
  WHERE anonymous_user_id = p_anonymous_user_id
    AND fertilizer_type = p_fertilizer_type
    AND created_at > NOW() - INTERVAL '24 hours'
  ORDER BY created_at DESC
  LIMIT 1;
  
  IF v_last_submission IS NOT NULL THEN
     RAISE EXCEPTION 'Rate limit: You can only submit one % price per 24 hours.', p_fertilizer_type;
  END IF;
  
  -- Insert the entry
  INSERT INTO fertilizer_ticker_entries (
    fertilizer_type,
    price,
    unit,
    currency,
    province_state,
    anonymous_user_id,
    delivery_mode
  ) VALUES (
    p_fertilizer_type,
    p_price,
    p_unit,
    p_currency,
    p_province_state,
    p_anonymous_user_id,
    p_delivery_mode
  )
  RETURNING id INTO v_new_id;
  
  RETURN v_new_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute to anon/authenticated for new function signature
GRANT EXECUTE ON FUNCTION submit_fertilizer_ticker_price(TEXT, DECIMAL, TEXT, TEXT, TEXT, TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION submit_fertilizer_ticker_price(TEXT, DECIMAL, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- Grants for views (re-applying just in case)
GRANT SELECT ON fertilizer_ticker_averages TO anon;
GRANT SELECT ON fertilizer_ticker_averages TO authenticated;
GRANT SELECT ON fertilizer_ticker_recent TO anon;
GRANT SELECT ON fertilizer_ticker_recent TO authenticated;
