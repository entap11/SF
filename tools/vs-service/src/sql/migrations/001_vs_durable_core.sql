CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS vs_match_contracts (
  contract_id UUID PRIMARY KEY,
  match_id UUID NOT NULL UNIQUE,
  legacy_session_id TEXT UNIQUE,
  protocol_version INTEGER NOT NULL CHECK (protocol_version = 2),
  command_schema_version INTEGER NOT NULL CHECK (command_schema_version = 1),
  result_schema_version INTEGER NOT NULL CHECK (result_schema_version = 1),
  minimum_client_build TEXT NOT NULL,
  sim_build_id TEXT NOT NULL,
  mode_id TEXT NOT NULL,
  ruleset_id TEXT NOT NULL,
  ruleset_hash CHAR(64) NOT NULL CHECK (ruleset_hash ~ '^[0-9a-f]{64}$'),
  map_id TEXT NOT NULL,
  map_hash CHAR(64) NOT NULL CHECK (map_hash ~ '^[0-9a-f]{64}$'),
  seed NUMERIC(20, 0) NOT NULL CHECK (seed >= 0),
  authority_tier TEXT NOT NULL CHECK (authority_tier IN ('RELAY_ATTESTED', 'AUTHORITY_VERIFIED')),
  match_epoch INTEGER NOT NULL DEFAULT 1 CHECK (match_epoch >= 1),
  required_players INTEGER NOT NULL CHECK (required_players BETWEEN 2 AND 4),
  status TEXT NOT NULL CHECK (status IN ('FORMING', 'FROZEN', 'RUNNING', 'RECONNECTING', 'VERIFYING', 'TERMINAL', 'CANCELLED')),
  contract_hash CHAR(64) NOT NULL CHECK (contract_hash ~ '^[0-9a-f]{64}$'),
  contract_json JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (contract_id, match_id),
  CHECK (expires_at > created_at)
);

CREATE INDEX IF NOT EXISTS vs_match_contracts_active_idx
  ON vs_match_contracts (status, expires_at)
  WHERE status IN ('FORMING', 'FROZEN', 'RUNNING', 'RECONNECTING', 'VERIFYING');

CREATE TABLE IF NOT EXISTS vs_match_roster (
  contract_id UUID NOT NULL REFERENCES vs_match_contracts(contract_id) ON DELETE RESTRICT,
  player_id UUID,
  public_entap_id TEXT,
  display_name TEXT NOT NULL,
  participant_type TEXT NOT NULL CHECK (participant_type IN ('HUMAN', 'BOT')),
  bot_profile_id TEXT,
  seat_id INTEGER NOT NULL CHECK (seat_id BETWEEN 1 AND 4),
  team_id INTEGER,
  color_id TEXT NOT NULL,
  party_id UUID,
  rank_value INTEGER,
  ready_state TEXT NOT NULL CHECK (ready_state IN ('NOT_READY', 'READY', 'LOCKED')),
  connection_state TEXT NOT NULL CHECK (connection_state IN ('CONNECTED', 'GRACE', 'DISCONNECTED')),
  joined_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (contract_id, seat_id),
  UNIQUE (contract_id, player_id),
  CHECK ((participant_type = 'HUMAN' AND player_id IS NOT NULL AND bot_profile_id IS NULL)
    OR (participant_type = 'BOT' AND player_id IS NULL AND bot_profile_id IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS vs_match_reconnect_state (
  match_id UUID NOT NULL REFERENCES vs_match_contracts(match_id) ON DELETE RESTRICT,
  player_id UUID NOT NULL,
  match_epoch INTEGER NOT NULL CHECK (match_epoch >= 1),
  reconnect_epoch INTEGER NOT NULL DEFAULT 0 CHECK (reconnect_epoch >= 0),
  connection_state TEXT NOT NULL CHECK (connection_state IN ('CONNECTED', 'GRACE', 'DISCONNECTED')),
  grace_deadline_at TIMESTAMPTZ,
  last_seen_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (match_id, player_id),
  CHECK ((connection_state = 'GRACE' AND grace_deadline_at IS NOT NULL) OR connection_state <> 'GRACE')
);

CREATE TABLE IF NOT EXISTS vs_match_lifecycle_events (
  event_id UUID PRIMARY KEY,
  match_id UUID NOT NULL REFERENCES vs_match_contracts(match_id) ON DELETE RESTRICT,
  match_epoch INTEGER NOT NULL CHECK (match_epoch >= 1),
  event_type TEXT NOT NULL,
  event_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  occurred_at TIMESTAMPTZ NOT NULL,
  UNIQUE (match_id, match_epoch, event_id)
);

CREATE TABLE IF NOT EXISTS vs_command_streams (
  match_id UUID NOT NULL REFERENCES vs_match_contracts(match_id) ON DELETE RESTRICT,
  match_epoch INTEGER NOT NULL CHECK (match_epoch >= 1),
  next_seq BIGINT NOT NULL DEFAULT 1 CHECK (next_seq >= 1),
  last_execute_tick BIGINT NOT NULL DEFAULT -1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (match_id, match_epoch)
);

CREATE TABLE IF NOT EXISTS vs_command_events (
  match_id UUID NOT NULL,
  match_epoch INTEGER NOT NULL,
  command_seq BIGINT NOT NULL CHECK (command_seq >= 1),
  contract_id UUID NOT NULL REFERENCES vs_match_contracts(contract_id) ON DELETE RESTRICT,
  player_id UUID NOT NULL,
  seat_id INTEGER NOT NULL CHECK (seat_id BETWEEN 1 AND 4),
  client_command_id TEXT NOT NULL,
  command_schema_version INTEGER NOT NULL CHECK (command_schema_version = 1),
  issued_tick BIGINT NOT NULL CHECK (issued_tick >= 0),
  requested_execute_tick BIGINT NOT NULL CHECK (requested_execute_tick >= 0),
  execute_tick BIGINT NOT NULL CHECK (execute_tick >= 0),
  request_hash CHAR(64) NOT NULL CHECK (request_hash ~ '^[0-9a-f]{64}$'),
  command_hash CHAR(64) NOT NULL CHECK (command_hash ~ '^[0-9a-f]{64}$'),
  command_payload JSONB NOT NULL,
  received_at TIMESTAMPTZ NOT NULL,
  committed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (match_id, match_epoch, command_seq),
  UNIQUE (match_id, match_epoch, client_command_id),
  CHECK (length(client_command_id) BETWEEN 1 AND 128),
  FOREIGN KEY (contract_id, match_id) REFERENCES vs_match_contracts(contract_id, match_id) ON DELETE RESTRICT,
  FOREIGN KEY (match_id, match_epoch) REFERENCES vs_command_streams(match_id, match_epoch) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS vs_command_events_replay_idx
  ON vs_command_events (match_id, match_epoch, command_seq);

CREATE TABLE IF NOT EXISTS vs_terminal_results (
  result_id UUID PRIMARY KEY,
  match_id UUID NOT NULL REFERENCES vs_match_contracts(match_id) ON DELETE RESTRICT,
  contract_id UUID NOT NULL REFERENCES vs_match_contracts(contract_id) ON DELETE RESTRICT,
  match_epoch INTEGER NOT NULL CHECK (match_epoch >= 1),
  result_schema_version INTEGER NOT NULL CHECK (result_schema_version = 1),
  terminal_reason TEXT NOT NULL,
  contract_hash CHAR(64) NOT NULL CHECK (contract_hash ~ '^[0-9a-f]{64}$'),
  final_command_seq BIGINT NOT NULL CHECK (final_command_seq >= 0),
  command_log_hash CHAR(64) NOT NULL CHECK (command_log_hash ~ '^[0-9a-f]{64}$'),
  payload_hash CHAR(64) NOT NULL CHECK (payload_hash ~ '^[0-9a-f]{64}$'),
  result_json JSONB NOT NULL,
  verified_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (match_id, match_epoch),
  FOREIGN KEY (contract_id, match_id) REFERENCES vs_match_contracts(contract_id, match_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS vs_idempotency_receipts (
  namespace TEXT NOT NULL,
  authoritative_subject TEXT NOT NULL,
  idempotency_key TEXT NOT NULL,
  request_hash CHAR(64) NOT NULL CHECK (request_hash ~ '^[0-9a-f]{64}$'),
  status TEXT NOT NULL CHECK (status IN ('PENDING', 'COMPLETED', 'FAILED')),
  response_json JSONB,
  side_effect_ref TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (namespace, authoritative_subject, idempotency_key),
  CHECK (length(namespace) BETWEEN 1 AND 128),
  CHECK (length(authoritative_subject) BETWEEN 1 AND 256),
  CHECK (length(idempotency_key) BETWEEN 1 AND 256)
);

CREATE TABLE IF NOT EXISTS vs_outbox_events (
  event_id UUID PRIMARY KEY,
  topic TEXT NOT NULL,
  recipient_player_id UUID,
  aggregate_type TEXT NOT NULL,
  aggregate_id TEXT NOT NULL,
  dedupe_namespace TEXT NOT NULL,
  dedupe_key TEXT NOT NULL,
  request_hash CHAR(64) NOT NULL CHECK (request_hash ~ '^[0-9a-f]{64}$'),
  payload JSONB NOT NULL,
  status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'DELIVERED', 'DEAD_LETTER')),
  delivery_attempts INTEGER NOT NULL DEFAULT 0 CHECK (delivery_attempts >= 0),
  available_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  delivered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (dedupe_namespace, dedupe_key)
);

CREATE INDEX IF NOT EXISTS vs_outbox_pending_idx
  ON vs_outbox_events (available_at, event_id)
  WHERE status = 'PENDING';
