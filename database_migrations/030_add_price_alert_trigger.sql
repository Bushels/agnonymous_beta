-- 030_add_price_alert_trigger.sql
-- Description: Adds the missing trigger to check price alerts when a new price entry is submitted

-- ============================================
-- FUNCTION: Check Price Alerts
-- ============================================

CREATE OR REPLACE FUNCTION check_price_alerts()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  alert_record RECORD;
  product_name_val TEXT;
  retailer_province TEXT;
  alert_title TEXT;
  alert_message TEXT;
BEGIN
  -- Get product name
  SELECT product_name INTO product_name_val
  FROM products
  WHERE id = NEW.product_id;

  -- Get retailer province
  SELECT province_state INTO retailer_province
  FROM retailers
  WHERE id = NEW.retailer_id;

  -- Loop through active alerts that match this product
  FOR alert_record IN
    SELECT pa.*, up.username
    FROM price_alerts pa
    JOIN user_profiles up ON pa.user_id = up.id
    WHERE pa.is_active = true
      -- Match product
      AND (pa.product_id = NEW.product_id)
      -- Match region (if specified in alert)
      AND (pa.province_state IS NULL OR pa.province_state = retailer_province)
      -- Match condition
      AND (
        (pa.alert_type = 'below' AND NEW.price < pa.target_price) OR
        (pa.alert_type = 'above' AND NEW.price > pa.target_price) OR
        (pa.alert_type = 'any')
      )
      -- Don't alert the user who submitted the price
      AND pa.user_id != COALESCE(NEW.user_id, '00000000-0000-0000-0000-000000000000')
  LOOP
    -- Construct message
    IF alert_record.alert_type = 'below' THEN
      alert_title := '📉 Price Drop Alert: ' || product_name_val;
      alert_message := 'Good news! ' || product_name_val || ' is now available for ' || NEW.currency || '$' || NEW.price || '/' || NEW.unit || ' in ' || retailer_province || '.';
    ELSIF alert_record.alert_type = 'above' THEN
      alert_title := '📈 Price Spike Alert: ' || product_name_val;
      alert_message := 'Heads up! ' || product_name_val || ' has risen to ' || NEW.currency || '$' || NEW.price || '/' || NEW.unit || ' in ' || retailer_province || '.';
    ELSE
      alert_title := '💰 Price Alert: ' || product_name_val;
      alert_message := 'New price reported for ' || product_name_val || ': ' || NEW.currency || '$' || NEW.price || '/' || NEW.unit || '.';
    END IF;

    -- Create notification
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      post_id,
      actor_id,
      actor_is_anonymous
    ) VALUES (
      alert_record.user_id,
      'price_alert',
      alert_title,
      alert_message,
      NEW.post_id, -- Link to the post if available
      NEW.user_id, -- The user who submitted the price
      NEW.is_anonymous
    );

    -- Update alert stats
    UPDATE price_alerts
    SET last_triggered = NOW(),
        trigger_count = trigger_count + 1
    WHERE id = alert_record.id;

  END LOOP;

  RETURN NEW;
END;
$$;

-- ============================================
-- TRIGGER: Check Alerts on Price Entry Insert
-- ============================================

DROP TRIGGER IF EXISTS trigger_check_price_alerts ON price_entries;
CREATE TRIGGER trigger_check_price_alerts
  AFTER INSERT ON price_entries
  FOR EACH ROW
  EXECUTE FUNCTION check_price_alerts();
