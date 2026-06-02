CREATE EXTENSION IF NOT EXISTS "pgcrypto";

ALTER TABLE users ADD COLUMN IF NOT EXISTS name VARCHAR(120);
UPDATE users
SET name = COALESCE(name, display_name, username)
WHERE name IS NULL;
ALTER TABLE users ALTER COLUMN name SET NOT NULL;

ALTER TABLE users ADD COLUMN IF NOT EXISTS mail VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_mail_unique ON users(mail) WHERE mail IS NOT NULL;

CREATE TABLE IF NOT EXISTS images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  image_key VARCHAR(120) NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  exp_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS streaks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID UNIQUE NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  current_count INTEGER NOT NULL DEFAULT 0,
  best_count INTEGER NOT NULL DEFAULT 0,
  last_activity_day DATE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS progress_restrictions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  restriction VARCHAR(30) NOT NULL,
  exp_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT progress_restrictions_restriction_check CHECK (
    restriction IN ('CELIAQUIA', 'VEG', 'VYG', 'KETO')
  ),
  CONSTRAINT progress_restrictions_profile_restriction_unique UNIQUE (profile_id, restriction)
);

CREATE TABLE IF NOT EXISTS history_games (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  progress_id UUID NOT NULL REFERENCES progress_restrictions(id) ON DELETE CASCADE,
  completed BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS games (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  history_id UUID NOT NULL REFERENCES history_games(id) ON DELETE CASCADE,
  game_type VARCHAR(80),
  node_id VARCHAR(120),
  accuracy NUMERIC(5, 2),
  completed BOOLEAN NOT NULL DEFAULT false,
  score INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_images_user_id ON images(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_streaks_profile_id ON streaks(profile_id);
CREATE INDEX IF NOT EXISTS idx_progress_restrictions_profile_id ON progress_restrictions(profile_id);
CREATE INDEX IF NOT EXISTS idx_history_games_progress_id ON history_games(progress_id);
CREATE INDEX IF NOT EXISTS idx_games_history_id ON games(history_id);
