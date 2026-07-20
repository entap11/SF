CREATE TABLE IF NOT EXISTS vs_match_queue_tickets (
  ticket_id UUID PRIMARY KEY,
  player_id UUID NOT NULL,
  public_entap_id TEXT,
  display_name TEXT NOT NULL,
  mode_id TEXT NOT NULL CHECK (mode_id = 'STANDARD_1V1'),
  protocol_version INTEGER NOT NULL CHECK (protocol_version = 2),
  client_build TEXT NOT NULL,
  request_id TEXT NOT NULL,
  request_hash CHAR(64) NOT NULL CHECK (request_hash ~ '^[0-9a-f]{64}$'),
  compatibility_hash CHAR(64) NOT NULL CHECK (compatibility_hash ~ '^[0-9a-f]{64}$'),
  queue_payload JSONB NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('WAITING', 'MATCHED', 'CANCELLED', 'EXPIRED')),
  contract_id UUID REFERENCES vs_match_contracts(contract_id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL,
  last_seen_at TIMESTAMPTZ NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  UNIQUE (player_id, mode_id, request_id),
  CHECK (expires_at > created_at),
  CHECK ((status = 'MATCHED' AND contract_id IS NOT NULL) OR (status <> 'MATCHED' AND contract_id IS NULL))
);

CREATE UNIQUE INDEX IF NOT EXISTS vs_match_queue_one_waiting_player_idx
  ON vs_match_queue_tickets (player_id, mode_id)
  WHERE status = 'WAITING';

CREATE INDEX IF NOT EXISTS vs_match_queue_waiting_idx
  ON vs_match_queue_tickets (mode_id, compatibility_hash, created_at, ticket_id)
  WHERE status = 'WAITING';

CREATE INDEX IF NOT EXISTS vs_match_roster_player_active_idx
  ON vs_match_roster (player_id, contract_id)
  WHERE player_id IS NOT NULL;
