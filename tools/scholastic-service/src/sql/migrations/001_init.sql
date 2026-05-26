CREATE TABLE IF NOT EXISTS scholastic_profiles (
  player_id TEXT PRIMARY KEY,
  profile JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS scholastic_schools (
  school_id TEXT PRIMARY KEY,
  program JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS scholastic_colleges (
  program_id TEXT PRIMARY KEY,
  program JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS scholastic_tournaments (
  tournament_id TEXT PRIMARY KEY,
  ecosystem TEXT NOT NULL,
  tournament JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS scholastic_audit_events (
  id BIGSERIAL PRIMARY KEY,
  event_type TEXT NOT NULL,
  player_id TEXT NOT NULL DEFAULT '',
  related_id TEXT NOT NULL DEFAULT '',
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_scholastic_audit_player_id ON scholastic_audit_events(player_id);
CREATE INDEX IF NOT EXISTS idx_scholastic_audit_event_type ON scholastic_audit_events(event_type);
CREATE INDEX IF NOT EXISTS idx_scholastic_tournaments_ecosystem ON scholastic_tournaments(ecosystem);
