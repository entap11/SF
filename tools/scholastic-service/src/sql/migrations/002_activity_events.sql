CREATE TABLE IF NOT EXISTS scholastic_activity_events (
  id BIGSERIAL PRIMARY KEY,
  event_id TEXT NOT NULL UNIQUE,
  player_id TEXT NOT NULL,
  ecosystem TEXT NOT NULL,
  event_date DATE NOT NULL,
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  is_new_player BOOLEAN NOT NULL DEFAULT false,
  props JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_scholastic_activity_event_date ON scholastic_activity_events(event_date);
CREATE INDEX IF NOT EXISTS idx_scholastic_activity_ecosystem_date ON scholastic_activity_events(ecosystem, event_date);
CREATE INDEX IF NOT EXISTS idx_scholastic_activity_player_id ON scholastic_activity_events(player_id);
