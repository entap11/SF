CREATE TABLE sf_beta_participants (
  player_id UUID PRIMARY KEY REFERENCES rank_players(id) ON DELETE CASCADE,
  participant_key TEXT NOT NULL UNIQUE,
  cohort TEXT NOT NULL DEFAULT 'unknown' CHECK (cohort IN ('unknown', 'owner', 'new', 'intermediate', 'experienced'))
);
CREATE TABLE sf_beta_captures (
  id BIGSERIAL PRIMARY KEY,
  player_id UUID NOT NULL REFERENCES sf_beta_participants(player_id) ON DELETE CASCADE,
  capture_id TEXT NOT NULL,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  build TEXT NOT NULL,
  map_id TEXT NOT NULL,
  mode TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('completed', 'abandoned', 'interrupted')),
  sim_ms BIGINT NOT NULL,
  winner_seat INTEGER NOT NULL,
  sha256 TEXT NOT NULL,
  summary JSONB NOT NULL,
  payload_gzip BYTEA NOT NULL,
  UNIQUE(player_id, capture_id)
);
CREATE INDEX sf_beta_captures_received_idx ON sf_beta_captures(received_at);
CREATE INDEX sf_beta_captures_build_map_idx ON sf_beta_captures(build, map_id);
