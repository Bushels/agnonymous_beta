-- Enable UUID extension if not already
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. User Profiles
CREATE TABLE IF NOT EXISTS user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE NOT NULL,
  email TEXT NOT NULL,
  email_verified BOOLEAN DEFAULT FALSE,
  province_state TEXT,
  bio TEXT,
  reputation_points INTEGER DEFAULT 0,
  public_reputation INTEGER DEFAULT 0,
  anonymous_reputation INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT username_length CHECK (LENGTH(username) >= 3 AND LENGTH(username) <= 30),
  CONSTRAINT username_format CHECK (username ~ '^[a-zA-Z0-9_-]+$'),
  CONSTRAINT bio_length CHECK (LENGTH(bio) <= 500)
);

-- 2. Input Prices
DO $$ BEGIN
    CREATE TYPE currency_type AS ENUM ('CAD', 'USD');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE input_category AS ENUM ('Fertilizer', 'Chemical', 'Seed');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS input_prices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
  location_name TEXT NOT NULL,
  -- For simplicity using TEXT for location first, can upgrade to PostGIS later if needed
  province_state TEXT NOT NULL,
  category input_category NOT NULL,
  brand TEXT NOT NULL,
  product_name TEXT NOT NULL,
  price DECIMAL(10, 2) NOT NULL,
  currency currency_type NOT NULL,
  unit TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Reputation Logs
CREATE TABLE IF NOT EXISTS reputation_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  action_type TEXT NOT NULL,
  points_change INTEGER NOT NULL,
  related_item_id UUID, -- Can be post_id, comment_id, etc.
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Update Existing Tables
-- Using DO blocks to avoid errors if columns already exist
DO $$ BEGIN
    ALTER TABLE posts ADD COLUMN user_id UUID REFERENCES user_profiles(id) ON DELETE SET NULL;
EXCEPTION
    WHEN duplicate_column THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE posts ADD COLUMN is_anonymous BOOLEAN DEFAULT TRUE;
EXCEPTION
    WHEN duplicate_column THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE posts ADD COLUMN author_username TEXT;
EXCEPTION
    WHEN duplicate_column THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE posts ADD COLUMN author_verified BOOLEAN DEFAULT FALSE;
EXCEPTION
    WHEN duplicate_column THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE posts ADD COLUMN truth_meter_score DECIMAL(5, 2) DEFAULT 0.0;
EXCEPTION
    WHEN duplicate_column THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE comments ADD COLUMN user_id UUID REFERENCES user_profiles(id) ON DELETE SET NULL;
EXCEPTION
    WHEN duplicate_column THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE comments ADD COLUMN is_anonymous BOOLEAN DEFAULT TRUE;
EXCEPTION
    WHEN duplicate_column THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE comments ADD COLUMN author_username TEXT;
EXCEPTION
    WHEN duplicate_column THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE comments ADD COLUMN author_verified BOOLEAN DEFAULT FALSE;
EXCEPTION
    WHEN duplicate_column THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE truth_votes ADD COLUMN user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE;
EXCEPTION
    WHEN duplicate_column THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE truth_votes ADD COLUMN is_anonymous BOOLEAN DEFAULT TRUE;
EXCEPTION
    WHEN duplicate_column THEN null;
END $$;

-- 5. Triggers (User Profile Creation)
CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_profiles (id, email, email_verified, username, province_state)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.email_confirmed_at IS NOT NULL,
    NEW.raw_user_meta_data->>'username',
    NEW.raw_user_meta_data->>'province_state'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION create_user_profile();

-- 6. RLS Policies
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON user_profiles;
CREATE POLICY "Public profiles are viewable by everyone" ON user_profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
CREATE POLICY "Users can update own profile" ON user_profiles FOR UPDATE USING (id = auth.uid());

ALTER TABLE input_prices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Input prices are viewable by everyone" ON input_prices;
CREATE POLICY "Input prices are viewable by everyone" ON input_prices FOR SELECT USING (true);

DROP POLICY IF EXISTS "Authenticated users can insert prices" ON input_prices;
CREATE POLICY "Authenticated users can insert prices" ON input_prices FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
