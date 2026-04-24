-- Hide production QA rows created during anonymous-board live proof.
-- Exact title/id prefix keeps this from touching farmer posts.

WITH proof_posts AS (
  SELECT id
  FROM posts
  WHERE title LIKE 'Codex live proof%'
    AND anonymous_user_id LIKE 'codex-live-proof-%'
)
UPDATE comments
SET is_deleted = TRUE
WHERE post_id IN (SELECT id FROM proof_posts);

WITH proof_posts AS (
  SELECT id
  FROM posts
  WHERE title LIKE 'Codex live proof%'
    AND anonymous_user_id LIKE 'codex-live-proof-%'
)
DELETE FROM anonymous_post_watches
WHERE post_id IN (SELECT id FROM proof_posts);

WITH proof_posts AS (
  SELECT id
  FROM posts
  WHERE title LIKE 'Codex live proof%'
    AND anonymous_user_id LIKE 'codex-live-proof-%'
)
DELETE FROM truth_votes
WHERE post_id IN (SELECT id FROM proof_posts);

UPDATE posts
SET is_deleted = TRUE
WHERE title LIKE 'Codex live proof%'
  AND anonymous_user_id LIKE 'codex-live-proof-%';
