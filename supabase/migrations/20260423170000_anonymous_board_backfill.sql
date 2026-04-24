-- Relaunch backfill for legacy board content.
-- Keeps old posts visible under the new anonymous-board rooms and recalculates counters.

UPDATE posts
SET category = CASE
  WHEN LOWER(category) IN ('farming', 'ranching', 'livestock', 'other') THEN 'General'
  WHEN LOWER(category) IN ('crops', 'grain') THEN 'Grain'
  WHEN LOWER(category) IN (
    'markets',
    'market',
    'chemicals',
    'inputs',
    'input prices',
    'fertilizer',
    'fertilizers'
  ) THEN 'Ag Business'
  WHEN LOWER(category) = 'equipment' THEN 'Equipment'
  WHEN LOWER(category) = 'politics' THEN 'Politics'
  WHEN LOWER(category) = 'weather' THEN 'Weather'
  WHEN LOWER(category) = 'land' THEN 'Land'
  WHEN LOWER(category) = 'monette' THEN 'Monette'
  ELSE 'General'
END
WHERE category IS NULL
  OR category NOT IN (
    'Monette',
    'General',
    'Grain',
    'Ag Business',
    'Equipment',
    'Land',
    'Politics',
    'Weather'
  );

UPDATE posts
SET
  is_anonymous = TRUE,
  is_deleted = COALESCE(is_deleted, FALSE),
  comment_count = COALESCE((
    SELECT COUNT(*)::INTEGER
    FROM comments
    WHERE comments.post_id = posts.id
      AND COALESCE(comments.is_deleted, FALSE) = FALSE
  ), 0),
  thumbs_up_count = COALESCE((
    SELECT COUNT(*)::INTEGER
    FROM truth_votes
    WHERE truth_votes.post_id = posts.id
      AND truth_votes.vote_type = 'thumbs_up'
  ), 0),
  thumbs_down_count = COALESCE((
    SELECT COUNT(*)::INTEGER
    FROM truth_votes
    WHERE truth_votes.post_id = posts.id
      AND truth_votes.vote_type = 'thumbs_down'
  ), 0),
  partial_count = COALESCE((
    SELECT COUNT(*)::INTEGER
    FROM truth_votes
    WHERE truth_votes.post_id = posts.id
      AND truth_votes.vote_type = 'partial'
  ), 0),
  funny_count = COALESCE((
    SELECT COUNT(*)::INTEGER
    FROM truth_votes
    WHERE truth_votes.post_id = posts.id
      AND truth_votes.vote_type = 'funny'
  ), 0),
  vote_count = COALESCE((
    SELECT COUNT(*)::INTEGER
    FROM truth_votes
    WHERE truth_votes.post_id = posts.id
  ), 0);

UPDATE comments
SET
  is_anonymous = TRUE,
  is_deleted = COALESCE(is_deleted, FALSE);

UPDATE truth_votes
SET is_anonymous = TRUE
WHERE is_anonymous IS DISTINCT FROM TRUE;

CREATE UNIQUE INDEX IF NOT EXISTS uq_truth_votes_post_anonymous_user
  ON truth_votes(post_id, anonymous_user_id)
  WHERE anonymous_user_id IS NOT NULL;
