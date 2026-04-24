-- =============================================================================
-- PERMANENT PURGE: Wave 2 market-intelligence features
-- Date: 2026-04-24
-- Purpose: Remove all tables, functions, and triggers created for the
--          pricing/dashboard/elevator/My-Farm direction that was abandoned
--          in the 2026-04-23 relaunch back to an anonymous-only board.
--
-- Scope reference: PRODUCT_VISION.md and docs/plans/2026-04-23-anonymous-board-relaunch.md
-- Hard boundaries: no pricing, no dashboards, no My Farm, no elevator map,
--                  no farmer reporting, no gamification-dependent writes.
--
-- This migration is IDEMPOTENT and ONE-WAY. It is safe to run on:
--   - A fresh DB (everything is IF EXISTS, so no-ops).
--   - A DB where Wave 2 was fully applied (full cleanup).
--   - A DB where Wave 2 was partially applied (cleans what exists).
--
-- After this migration runs, the 8 Wave 2 source migrations are deleted
-- from supabase/migrations/ so `supabase db reset` produces the clean state.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- RPC FUNCTIONS (drop before tables so dependency order is explicit)
-- -----------------------------------------------------------------------------

DROP FUNCTION IF EXISTS get_cash_prices(TEXT, TEXT, TEXT, INTEGER)        CASCADE;
DROP FUNCTION IF EXISTS get_my_farm()                                     CASCADE;
DROP FUNCTION IF EXISTS get_provincial_defaults(TEXT, TEXT)               CASCADE;
DROP FUNCTION IF EXISTS get_latest_cot_positions(TEXT, INT)               CASCADE;
DROP FUNCTION IF EXISTS get_cot_net_change(TEXT, INT)                     CASCADE;
DROP FUNCTION IF EXISTS get_front_month_price(TEXT, INT)                  CASCADE;
DROP FUNCTION IF EXISTS get_contract_curve(TEXT)                          CASCADE;
DROP FUNCTION IF EXISTS get_crop_stats_summary(TEXT, TEXT, INTEGER)       CASCADE;
DROP FUNCTION IF EXISTS get_crop_yoy_comparison(TEXT, TEXT, INTEGER)      CASCADE;
DROP FUNCTION IF EXISTS get_available_commodities(TEXT)                   CASCADE;
DROP FUNCTION IF EXISTS get_elevator_reports(UUID, INTEGER)               CASCADE;
DROP FUNCTION IF EXISTS get_monthly_report_stats(TEXT)                    CASCADE;
DROP FUNCTION IF EXISTS get_grain_global_stats(INTEGER)                   CASCADE;
DROP FUNCTION IF EXISTS get_grain_data(TEXT, TEXT, TEXT, INTEGER, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS get_nearest_elevators(DOUBLE PRECISION, DOUBLE PRECISION, INTEGER, TEXT, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS get_elevators_by_province(TEXT, TEXT, INTEGER)    CASCADE;

-- -----------------------------------------------------------------------------
-- TRIGGER FUNCTIONS that reference soon-to-be-dropped tables
-- (CASCADE also drops any remaining triggers using them)
-- -----------------------------------------------------------------------------

DROP FUNCTION IF EXISTS update_confirmation_counts()      CASCADE;
DROP FUNCTION IF EXISTS promote_confirmed_report()        CASCADE;
DROP FUNCTION IF EXISTS award_report_reputation()         CASCADE;
DROP FUNCTION IF EXISTS award_confirmation_reputation()   CASCADE;
DROP FUNCTION IF EXISTS set_elevator_location()           CASCADE;
DROP FUNCTION IF EXISTS update_data_source_updated_at()   CASCADE;

-- Intentionally NOT dropped: update_updated_at_column()
--   It is a generic utility function that may be used by other unrelated
--   triggers in the current or future schema. Leaving it is harmless.

-- -----------------------------------------------------------------------------
-- TABLES (reverse dependency order; CASCADE sweeps remaining triggers/FKs)
-- -----------------------------------------------------------------------------

-- Wave 2 Part 4: Farmer price reporting
DROP TABLE IF EXISTS price_report_stats          CASCADE;
DROP TABLE IF EXISTS price_report_confirmations  CASCADE;
DROP TABLE IF EXISTS farmer_price_reports        CASCADE;

-- Wave 2 Part 3: Elevator map
DROP TABLE IF EXISTS elevator_locations          CASCADE;

-- Wave 2 Part 2: My Farm
DROP TABLE IF EXISTS crop_plans                  CASCADE;
DROP TABLE IF EXISTS farm_profiles               CASCADE;
DROP TABLE IF EXISTS provincial_cost_defaults    CASCADE;

-- Wave 2 Part 1: Local cash prices (PDQ)
DROP TABLE IF EXISTS local_cash_prices           CASCADE;

-- March 2026 Part 2: Futures
DROP TABLE IF EXISTS futures_prices              CASCADE;

-- March 2026 Part 1: CFTC COT
DROP TABLE IF EXISTS cot_positions               CASCADE;

-- February 2026 Part 2: USDA / StatsCan crop stats
DROP TABLE IF EXISTS crop_stats                  CASCADE;

-- February 2026 Part 1: CGC grain data pipeline
DROP TABLE IF EXISTS data_pipeline_logs          CASCADE;
DROP TABLE IF EXISTS data_source_config          CASCADE;
DROP TABLE IF EXISTS grain_data_live             CASCADE;

-- -----------------------------------------------------------------------------
-- POSTGIS EXTENSION
-- -----------------------------------------------------------------------------
-- Intentionally NOT dropped: postgis was enabled in my_farm_tables.sql but
-- removing an extension can affect unrelated schemas. Leaving it installed
-- is harmless and avoids cross-extension breakage if any other schema
-- references it. It does not ship anything to the client.

COMMIT;
