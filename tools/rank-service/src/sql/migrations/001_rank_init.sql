CREATE TABLE IF NOT EXISTS rank_players (
  player_id TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  region TEXT NOT NULL,
  wax_score DOUBLE PRECISION NOT NULL,
  last_active_unix BIGINT NOT NULL,
  last_decay_day INTEGER NOT NULL DEFAULT -1,
  tier_id TEXT NOT NULL,
  color_id TEXT NOT NULL,
  rank_position INTEGER NOT NULL DEFAULT 0,
  percentile DOUBLE PRECISION NOT NULL DEFAULT 0,
  promotion_history JSONB NOT NULL DEFAULT '{}'::jsonb,
  friends JSONB NOT NULL DEFAULT '[]'::jsonb,
  apex_active BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rank_players_wax_desc ON rank_players (wax_score DESC, player_id ASC);
CREATE INDEX IF NOT EXISTS idx_rank_players_rank_position ON rank_players (rank_position ASC);
CREATE INDEX IF NOT EXISTS idx_rank_players_region_rank ON rank_players (region, rank_position ASC);

CREATE TABLE IF NOT EXISTS rank_meta (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS rank_processed_events (
  dedupe_key TEXT PRIMARY KEY,
  processed_unix BIGINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rank_processed_events_processed_unix ON rank_processed_events (processed_unix ASC);
