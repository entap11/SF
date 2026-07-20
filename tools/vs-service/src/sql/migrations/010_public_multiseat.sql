ALTER TABLE vs_match_queue_tickets
  DROP CONSTRAINT IF EXISTS vs_match_queue_tickets_mode_id_check;

ALTER TABLE vs_match_queue_tickets
  ADD CONSTRAINT vs_match_queue_tickets_mode_id_check
  CHECK (mode_id IN (
    'STANDARD_1V1', 'CTF_1V1', 'HCTF_1V1', 'CRUCIBLE_1V1',
    'STANDARD_3P_FFA', 'STANDARD_2V2', 'STANDARD_4P_FFA'
  ));

COMMENT ON CONSTRAINT vs_match_queue_tickets_mode_id_check ON vs_match_queue_tickets IS
  'Authenticated roster-v2 public queues. Mode-specific flags and frozen policy select two through four seats.';

CREATE TABLE IF NOT EXISTS vs_public_competitive_profiles (
  player_id UUID PRIMARY KEY,
  rank_value INTEGER NOT NULL DEFAULT 0,
  source_revision TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS vs_public_friend_relationships (
  player_a_id UUID NOT NULL,
  player_b_id UUID NOT NULL,
  source_revision TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (player_a_id, player_b_id),
  CHECK (player_a_id::text < player_b_id::text),
  CHECK (player_a_id <> player_b_id)
);

CREATE INDEX IF NOT EXISTS vs_public_friend_relationships_b_idx
  ON vs_public_friend_relationships (player_b_id, player_a_id) WHERE active;

CREATE TABLE IF NOT EXISTS vs_match_peer_acks (
  match_id UUID NOT NULL REFERENCES vs_match_contracts(match_id) ON DELETE RESTRICT,
  match_epoch INTEGER NOT NULL CHECK (match_epoch >= 1),
  player_id UUID NOT NULL,
  acknowledged_seq BIGINT NOT NULL DEFAULT 0 CHECK (acknowledged_seq >= 0),
  acknowledged_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (match_id, match_epoch, player_id)
);

CREATE TABLE IF NOT EXISTS vs_public_match_history (
  match_id UUID NOT NULL REFERENCES vs_match_contracts(match_id) ON DELETE RESTRICT,
  result_id UUID NOT NULL REFERENCES vs_terminal_results(result_id) ON DELETE RESTRICT,
  player_id UUID NOT NULL,
  mode_id TEXT NOT NULL,
  seat_id SMALLINT NOT NULL CHECK (seat_id BETWEEN 1 AND 4),
  team_id SMALLINT,
  placement SMALLINT NOT NULL CHECK (placement BETWEEN 1 AND 4),
  terminal_reason TEXT NOT NULL,
  verified_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (match_id, player_id),
  UNIQUE (result_id, player_id)
);

CREATE INDEX IF NOT EXISTS vs_public_match_history_player_idx
  ON vs_public_match_history (player_id, verified_at DESC, match_id);

CREATE TABLE IF NOT EXISTS vs_public_shadow_results (
  result_id UUID NOT NULL REFERENCES vs_terminal_results(result_id) ON DELETE RESTRICT,
  match_id UUID NOT NULL REFERENCES vs_match_contracts(match_id) ON DELETE RESTRICT,
  mode_id TEXT NOT NULL CHECK (mode_id IN ('STANDARD_3P_FFA', 'STANDARD_2V2', 'STANDARD_4P_FFA')),
  result_payload JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (result_id),
  UNIQUE (match_id)
);
