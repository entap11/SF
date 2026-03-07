CREATE TABLE IF NOT EXISTS rank_audit_events (
  id BIGSERIAL PRIMARY KEY,
  event_type TEXT NOT NULL,
  player_id TEXT NOT NULL DEFAULT '',
  related_player_id TEXT NOT NULL DEFAULT '',
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rank_audit_events_created_at ON rank_audit_events (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rank_audit_events_event_type_created_at ON rank_audit_events (event_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rank_audit_events_player_created_at ON rank_audit_events (player_id, created_at DESC);
