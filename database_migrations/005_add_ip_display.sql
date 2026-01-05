-- ============================================================================
-- MIGRATION 005: Add IP-Based Display (No Authentication)
-- ============================================================================
-- Simple solution: Show last 3 digits of IP address on posts/comments
-- No accounts, no login, just minimal identity for continuity
-- ============================================================================

-- 1. Add IP display field to posts
ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS ip_last_3 TEXT;

-- 2. Add IP display field to comments
ALTER TABLE comments
  ADD COLUMN IF NOT EXISTS ip_last_3 TEXT;

-- 3. Add index for searching by IP (optional, for moderation)
CREATE INDEX IF NOT EXISTS idx_posts_ip_last_3 ON posts(ip_last_3) WHERE ip_last_3 IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_comments_ip_last_3 ON comments(ip_last_3) WHERE ip_last_3 IS NOT NULL;

-- 4. Create function to extract last 3 digits from IP
CREATE OR REPLACE FUNCTION get_ip_last_3(ip_address TEXT)
RETURNS TEXT AS $$
DECLARE
  ip_parts TEXT[];
  last_octet TEXT;
BEGIN
  -- Handle IPv4 (e.g., "192.168.1.123" -> "123")
  IF ip_address ~ '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' THEN
    ip_parts := string_to_array(ip_address, '.');
    last_octet := ip_parts[4];
    -- Pad with leading zeros if needed (e.g., "5" -> "005")
    RETURN LPAD(last_octet, 3, '0');
  END IF;

  -- Handle IPv6 (take last 3 hex digits)
  IF ip_address ~ ':' THEN
    -- Get last segment and take last 3 characters
    ip_parts := string_to_array(ip_address, ':');
    last_octet := ip_parts[array_length(ip_parts, 1)];
    RETURN RIGHT(last_octet, 3);
  END IF;

  -- Fallback: return 'xxx'
  RETURN 'xxx';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_ip_last_3(TEXT) TO authenticated, anon;

-- 5. Verify migration
DO $$
DECLARE
  posts_column_exists BOOLEAN;
  comments_column_exists BOOLEAN;
  test_ipv4 TEXT;
  test_ipv6 TEXT;
BEGIN
  -- Check columns exist
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'posts' AND column_name = 'ip_last_3'
  ) INTO posts_column_exists;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'comments' AND column_name = 'ip_last_3'
  ) INTO comments_column_exists;

  -- Test the function
  test_ipv4 := get_ip_last_3('192.168.1.123');
  test_ipv6 := get_ip_last_3('2001:0db8:85a3:0000:0000:8a2e:0370:7334');

  IF posts_column_exists AND comments_column_exists THEN
    RAISE NOTICE '✅ Posts table: ip_last_3 column added';
    RAISE NOTICE '✅ Comments table: ip_last_3 column added';
    RAISE NOTICE '✅ IP extraction function created';
    RAISE NOTICE 'Test IPv4 (192.168.1.123) -> %', test_ipv4;
    RAISE NOTICE 'Test IPv6 -> %', test_ipv6;
    RAISE NOTICE '';
    RAISE NOTICE '📝 Posts will now show: "Posted by: ...%"', test_ipv4;
  ELSE
    RAISE WARNING '⚠️ Migration may be incomplete';
  END IF;
END $$;

RAISE NOTICE '✅ Migration 005_add_ip_display.sql completed';
