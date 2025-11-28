-- 023_fix_truth_votes_column.sql
-- Add is_anonymous column to truth_votes table idempotently
-- This fixes the "column is_anonymous of relation truth_votes does not exist" error

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'truth_votes'
      AND column_name = 'is_anonymous'
  ) THEN
    ALTER TABLE public.truth_votes
    ADD COLUMN is_anonymous boolean;

    -- Backfill existing rows
    UPDATE public.truth_votes
    SET is_anonymous = TRUE
    WHERE is_anonymous IS NULL;

    -- Set default for future inserts
    ALTER TABLE public.truth_votes
    ALTER COLUMN is_anonymous SET DEFAULT TRUE;

    RAISE NOTICE 'Added is_anonymous column to public.truth_votes and backfilled.';
  ELSE
    -- Ensure default exists even if column already present (idempotent hardening)
    ALTER TABLE public.truth_votes
    ALTER COLUMN is_anonymous SET DEFAULT TRUE;

    -- Optional backfill in case of partial state
    UPDATE public.truth_votes
    SET is_anonymous = TRUE
    WHERE is_anonymous IS NULL;

    RAISE NOTICE 'is_anonymous already exists. Default ensured and values backfilled.';
  END IF;
END $$;
