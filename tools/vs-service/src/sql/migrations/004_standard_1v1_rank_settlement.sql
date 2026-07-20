CREATE TABLE IF NOT EXISTS vs_rank_settlement_jobs (
  settlement_id UUID PRIMARY KEY,
  result_id UUID NOT NULL UNIQUE REFERENCES vs_terminal_results(result_id) ON DELETE RESTRICT,
  rank_event_id UUID NOT NULL UNIQUE,
  match_id UUID NOT NULL REFERENCES vs_match_contracts(match_id) ON DELETE RESTRICT,
  contract_id UUID NOT NULL REFERENCES vs_match_contracts(contract_id) ON DELETE RESTRICT,
  match_epoch INTEGER NOT NULL CHECK (match_epoch >= 1),
  status TEXT NOT NULL CHECK (status IN ('PENDING', 'LEASED', 'RETRY', 'SETTLED', 'FAILED', 'NOT_APPLICABLE')),
  attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  max_attempts INTEGER NOT NULL DEFAULT 20 CHECK (max_attempts BETWEEN 1 AND 100),
  lease_owner TEXT,
  lease_token UUID,
  lease_expires_at TIMESTAMPTZ,
  available_at TIMESTAMPTZ NOT NULL,
  last_error_code TEXT,
  last_error_detail JSONB,
  rank_response JSONB,
  settled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  UNIQUE (match_id, match_epoch),
  FOREIGN KEY (contract_id, match_id) REFERENCES vs_match_contracts(contract_id, match_id) ON DELETE RESTRICT,
  CHECK ((status = 'LEASED' AND lease_owner IS NOT NULL AND lease_token IS NOT NULL AND lease_expires_at IS NOT NULL)
    OR status <> 'LEASED')
);

CREATE INDEX IF NOT EXISTS vs_rank_settlement_jobs_lease_idx
  ON vs_rank_settlement_jobs (available_at, created_at, settlement_id)
  WHERE status IN ('PENDING', 'RETRY', 'LEASED');

CREATE TABLE IF NOT EXISTS vs_rank_settlement_attempts (
  attempt_id UUID PRIMARY KEY,
  settlement_id UUID NOT NULL REFERENCES vs_rank_settlement_jobs(settlement_id) ON DELETE RESTRICT,
  attempt INTEGER NOT NULL CHECK (attempt >= 1),
  worker_id TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('SETTLED', 'RETRYABLE_FAILURE', 'PERMANENT_FAILURE')),
  request_hash CHAR(64) NOT NULL CHECK (request_hash ~ '^[0-9a-f]{64}$'),
  response_json JSONB NOT NULL,
  error_code TEXT,
  started_at TIMESTAMPTZ NOT NULL,
  finished_at TIMESTAMPTZ NOT NULL,
  UNIQUE (settlement_id, attempt)
);
