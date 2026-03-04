-- =============================================================================
-- WAVE 2 PART 4: FARMER PRICE REPORTING & CONFIRMATION TRACKING
-- Farmers report elevator bids, community confirms, promoted prices appear on map.
-- =============================================================================

-- =============================================================================
-- FARMER PRICE REPORTS
-- =============================================================================

CREATE TABLE farmer_price_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID NOT NULL REFERENCES auth.users(id),
  elevator_location_id UUID REFERENCES elevator_locations(id),
  elevator_name TEXT NOT NULL,
  commodity TEXT NOT NULL,
  grade TEXT,
  reported_bid_cad DECIMAL(10,2) NOT NULL,
  bid_unit TEXT DEFAULT 'bushel' CHECK (bid_unit IN ('bushel', 'tonne')),
  notes TEXT,
  confirm_count INTEGER DEFAULT 0,
  outdated_count INTEGER DEFAULT 0,
  is_promoted BOOLEAN DEFAULT false,
  reported_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_price_reports_elevator ON farmer_price_reports(elevator_location_id);
CREATE INDEX idx_price_reports_reporter ON farmer_price_reports(reporter_id);
CREATE INDEX idx_price_reports_commodity ON farmer_price_reports(commodity);
CREATE INDEX idx_price_reports_date ON farmer_price_reports(reported_at DESC);

ALTER TABLE farmer_price_reports ENABLE ROW LEVEL SECURITY;

-- Anyone can read reports (market data is public)
CREATE POLICY "Anyone can read price reports"
  ON farmer_price_reports FOR SELECT USING (true);
-- Authenticated users can insert their own reports
CREATE POLICY "Users can insert their own reports"
  ON farmer_price_reports FOR INSERT
  WITH CHECK (auth.uid() = reporter_id);

-- =============================================================================
-- PRICE REPORT CONFIRMATIONS
-- =============================================================================

CREATE TABLE price_report_confirmations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id UUID NOT NULL REFERENCES farmer_price_reports(id) ON DELETE CASCADE,
  confirmer_id UUID NOT NULL REFERENCES auth.users(id),
  confirmation_type TEXT NOT NULL CHECK (confirmation_type IN ('confirm', 'outdated')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(report_id, confirmer_id)
);

CREATE INDEX idx_confirmations_report ON price_report_confirmations(report_id);

ALTER TABLE price_report_confirmations ENABLE ROW LEVEL SECURITY;

-- Anyone can read confirmations
CREATE POLICY "Anyone can read confirmations"
  ON price_report_confirmations FOR SELECT USING (true);
-- Authenticated users can insert their own confirmations
CREATE POLICY "Users can insert their own confirmations"
  ON price_report_confirmations FOR INSERT
  WITH CHECK (auth.uid() = confirmer_id);

-- =============================================================================
-- TRIGGER: Update confirm/outdated counts on confirmation INSERT
-- =============================================================================

CREATE OR REPLACE FUNCTION update_confirmation_counts()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.confirmation_type = 'confirm' THEN
    UPDATE farmer_price_reports
    SET confirm_count = confirm_count + 1
    WHERE id = NEW.report_id;
  ELSIF NEW.confirmation_type = 'outdated' THEN
    UPDATE farmer_price_reports
    SET outdated_count = outdated_count + 1
    WHERE id = NEW.report_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_confirmation_insert
  AFTER INSERT ON price_report_confirmations
  FOR EACH ROW EXECUTE FUNCTION update_confirmation_counts();

-- =============================================================================
-- TRIGGER: Promote to local_cash_prices when 3+ confirmations
-- =============================================================================

CREATE OR REPLACE FUNCTION promote_confirmed_report()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.confirm_count >= 3
    AND NEW.outdated_count < NEW.confirm_count
    AND NEW.is_promoted = false
  THEN
    -- Insert into local_cash_prices as farmer-verified price
    INSERT INTO local_cash_prices (
      source, elevator_name, commodity, grade,
      bid_price_cad, bid_unit, price_date
    ) VALUES (
      'farmer_report',
      NEW.elevator_name,
      NEW.commodity,
      NEW.grade,
      NEW.reported_bid_cad,
      NEW.bid_unit,
      NEW.reported_at::date
    )
    ON CONFLICT (source, elevator_name, commodity, grade, price_date)
    DO UPDATE SET bid_price_cad = EXCLUDED.bid_price_cad, fetched_at = NOW();

    -- Mark as promoted
    UPDATE farmer_price_reports SET is_promoted = true WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_report_count_update
  AFTER UPDATE OF confirm_count ON farmer_price_reports
  FOR EACH ROW EXECUTE FUNCTION promote_confirmed_report();

-- =============================================================================
-- REPUTATION: +3 points for submitting a price report
-- =============================================================================

CREATE OR REPLACE FUNCTION award_report_reputation()
RETURNS TRIGGER AS $$
DECLARE
  v_profile_id UUID;
BEGIN
  -- Look up user_profiles.id from auth user id
  SELECT id INTO v_profile_id
  FROM user_profiles
  WHERE user_id = NEW.reporter_id
  LIMIT 1;

  IF v_profile_id IS NOT NULL THEN
    UPDATE user_profiles
    SET reputation_points = COALESCE(reputation_points, 0) + 3
    WHERE id = v_profile_id;

    INSERT INTO reputation_logs (user_id, points_change, reason)
    VALUES (
      v_profile_id,
      3,
      'Submitted price report for ' || NEW.commodity || ' at ' || NEW.elevator_name
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_price_report_insert
  AFTER INSERT ON farmer_price_reports
  FOR EACH ROW EXECUTE FUNCTION award_report_reputation();

-- =============================================================================
-- REPUTATION: +1 point for confirming a price report
-- =============================================================================

CREATE OR REPLACE FUNCTION award_confirmation_reputation()
RETURNS TRIGGER AS $$
DECLARE
  v_profile_id UUID;
BEGIN
  IF NEW.confirmation_type = 'confirm' THEN
    SELECT id INTO v_profile_id
    FROM user_profiles
    WHERE user_id = NEW.confirmer_id
    LIMIT 1;

    IF v_profile_id IS NOT NULL THEN
      UPDATE user_profiles
      SET reputation_points = COALESCE(reputation_points, 0) + 1
      WHERE id = v_profile_id;

      INSERT INTO reputation_logs (user_id, points_change, reason)
      VALUES (
        v_profile_id,
        1,
        'Confirmed a price report'
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_confirmation_reputation
  AFTER INSERT ON price_report_confirmations
  FOR EACH ROW EXECUTE FUNCTION award_confirmation_reputation();

-- =============================================================================
-- SOCIAL PROOF STATS
-- =============================================================================

CREATE TABLE price_report_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  period TEXT NOT NULL,
  total_reports INTEGER DEFAULT 0,
  total_farmers_helped INTEGER DEFAULT 0,
  total_confirmations INTEGER DEFAULT 0,
  region TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(period, region)
);

ALTER TABLE price_report_stats ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read report stats"
  ON price_report_stats FOR SELECT USING (true);

-- =============================================================================
-- RPC: GET ELEVATOR REPORTS (recent reports for an elevator)
-- =============================================================================

CREATE OR REPLACE FUNCTION get_elevator_reports(
  p_elevator_id UUID,
  p_days INTEGER DEFAULT 7
)
RETURNS TABLE(
  id UUID,
  commodity TEXT,
  grade TEXT,
  reported_bid_cad DECIMAL,
  bid_unit TEXT,
  confirm_count INTEGER,
  outdated_count INTEGER,
  is_promoted BOOLEAN,
  reported_at TIMESTAMPTZ,
  reporter_display_name TEXT,
  reporter_reputation_level INTEGER
) AS $$
BEGIN
  p_days := LEAST(p_days, 30);

  RETURN QUERY
  SELECT
    r.id, r.commodity, r.grade, r.reported_bid_cad, r.bid_unit,
    r.confirm_count, r.outdated_count, r.is_promoted, r.reported_at,
    COALESCE(up.username, 'Anonymous') as reporter_display_name,
    COALESCE(up.reputation_level, 0) as reporter_reputation_level
  FROM farmer_price_reports r
  LEFT JOIN user_profiles up ON up.user_id = r.reporter_id
  WHERE r.elevator_location_id = p_elevator_id
    AND r.reported_at >= NOW() - (p_days || ' days')::interval
  ORDER BY r.reported_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- =============================================================================
-- RPC: GET MONTHLY REPORT STATS (social proof counter)
-- =============================================================================

CREATE OR REPLACE FUNCTION get_monthly_report_stats(
  p_region TEXT DEFAULT NULL
)
RETURNS TABLE(
  total_reports BIGINT,
  total_confirmations BIGINT,
  unique_reporters BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*)::bigint as total_reports,
    COALESCE(SUM(r.confirm_count), 0)::bigint as total_confirmations,
    COUNT(DISTINCT r.reporter_id)::bigint as unique_reporters
  FROM farmer_price_reports r
  WHERE r.reported_at >= date_trunc('month', NOW())
    AND (p_region IS NULL OR
      r.elevator_name IN (
        SELECT e.facility_name FROM elevator_locations e WHERE e.province = p_region
      )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
