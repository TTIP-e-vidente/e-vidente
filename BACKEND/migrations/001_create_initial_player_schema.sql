CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username VARCHAR(80) UNIQUE NOT NULL,
  email VARCHAR(255) UNIQUE,
  password_hash VARCHAR(255),
  display_name VARCHAR(120),
  age INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS player_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  exp_count INTEGER NOT NULL DEFAULT 0,
  current_restriction VARCHAR(30),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS player_streaks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  current_count INTEGER NOT NULL DEFAULT 0,
  best_count INTEGER NOT NULL DEFAULT 0,
  last_activity_day DATE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS player_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  restriction_type VARCHAR(30) NOT NULL,
  total_exp INTEGER NOT NULL DEFAULT 0,
  completed_nodes_count INTEGER NOT NULL DEFAULT 0,
  completed_games_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT player_progress_restriction_type_check CHECK (
    restriction_type IN ('CELIAQUIA', 'VEG', 'VYG', 'KETO')
  ),
  CONSTRAINT player_progress_user_restriction_unique UNIQUE (user_id, restriction_type)
);

CREATE TABLE IF NOT EXISTS game_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  progress_id UUID REFERENCES player_progress(id) ON DELETE SET NULL,
  game_type VARCHAR(80) NOT NULL,
  node_id VARCHAR(120),
  accuracy NUMERIC(5, 2),
  score INTEGER NOT NULL DEFAULT 0,
  completed BOOLEAN NOT NULL DEFAULT false,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS completed_nodes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  progress_id UUID REFERENCES player_progress(id) ON DELETE SET NULL,
  node_id VARCHAR(120) NOT NULL,
  node_type VARCHAR(80),
  completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  best_score INTEGER,
  best_accuracy NUMERIC(5, 2),
  CONSTRAINT completed_nodes_user_node_unique UNIQUE (user_id, node_id)
);

CREATE TABLE IF NOT EXISTS unlocked_content (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content_id VARCHAR(120) NOT NULL,
  content_type VARCHAR(80) NOT NULL,
  unlocked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  source VARCHAR(120),
  CONSTRAINT unlocked_content_user_content_unique UNIQUE (user_id, content_id)
);

CREATE TABLE IF NOT EXISTS user_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  image_key VARCHAR(120) NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_player_progress_user_id ON player_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_game_sessions_user_id ON game_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_completed_nodes_user_id ON completed_nodes(user_id);
CREATE INDEX IF NOT EXISTS idx_unlocked_content_user_id ON unlocked_content(user_id);
