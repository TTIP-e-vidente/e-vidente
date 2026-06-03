ALTER TABLE player_streaks
  ADD COLUMN IF NOT EXISTS profile_id UUID;

ALTER TABLE player_progress
  ADD COLUMN IF NOT EXISTS profile_id UUID;

ALTER TABLE unlocked_content
  ADD COLUMN IF NOT EXISTS progress_id UUID;

INSERT INTO player_profiles (user_id)
SELECT DISTINCT source.user_id
FROM (
  SELECT user_id FROM player_streaks
  UNION
  SELECT user_id FROM player_progress
  UNION
  SELECT user_id FROM unlocked_content
) AS source
WHERE NOT EXISTS (
  SELECT 1
  FROM player_profiles existing_profile
  WHERE existing_profile.user_id = source.user_id
)
ON CONFLICT (user_id) DO NOTHING;

UPDATE player_streaks
SET profile_id = player_profiles.id
FROM player_profiles
WHERE player_streaks.user_id = player_profiles.user_id
  AND player_streaks.profile_id IS NULL;

UPDATE player_progress
SET profile_id = player_profiles.id
FROM player_profiles
WHERE player_progress.user_id = player_profiles.user_id
  AND player_progress.profile_id IS NULL;

UPDATE unlocked_content
SET progress_id = latest_progress.id
FROM (
  SELECT DISTINCT ON (user_id) id, user_id
  FROM player_progress
  ORDER BY user_id, updated_at DESC, created_at DESC
) AS latest_progress
WHERE unlocked_content.user_id = latest_progress.user_id
  AND unlocked_content.progress_id IS NULL;

ALTER TABLE player_streaks
  ALTER COLUMN profile_id SET NOT NULL;

ALTER TABLE player_progress
  ALTER COLUMN profile_id SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'player_streaks_profile_id_fkey'
  ) THEN
    ALTER TABLE player_streaks
      ADD CONSTRAINT player_streaks_profile_id_fkey
      FOREIGN KEY (profile_id) REFERENCES player_profiles(id) ON DELETE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'player_streaks_profile_id_unique'
  ) THEN
    ALTER TABLE player_streaks
      ADD CONSTRAINT player_streaks_profile_id_unique UNIQUE (profile_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'player_progress_profile_id_fkey'
  ) THEN
    ALTER TABLE player_progress
      ADD CONSTRAINT player_progress_profile_id_fkey
      FOREIGN KEY (profile_id) REFERENCES player_profiles(id) ON DELETE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'player_progress_profile_restriction_unique'
  ) THEN
    ALTER TABLE player_progress
      ADD CONSTRAINT player_progress_profile_restriction_unique
      UNIQUE (profile_id, restriction_type);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'unlocked_content_progress_id_fkey'
  ) THEN
    ALTER TABLE unlocked_content
      ADD CONSTRAINT unlocked_content_progress_id_fkey
      FOREIGN KEY (progress_id) REFERENCES player_progress(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_player_streaks_profile_id
  ON player_streaks(profile_id);

CREATE INDEX IF NOT EXISTS idx_player_progress_profile_id
  ON player_progress(profile_id);

CREATE INDEX IF NOT EXISTS idx_unlocked_content_progress_id
  ON unlocked_content(progress_id);
