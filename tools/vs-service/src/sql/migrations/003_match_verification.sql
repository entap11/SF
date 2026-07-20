CREATE TABLE IF NOT EXISTS vs_match_client_terminal_reports (
  report_id UUID PRIMARY KEY,
  match_id UUID NOT NULL REFERENCES vs_match_contracts(match_id) ON DELETE RESTRICT,
  contract_id UUID NOT NULL REFERENCES vs_match_contracts(contract_id) ON DELETE RESTRICT,
  match_epoch INTEGER NOT NULL CHECK (match_epoch >= 1),
  player_id UUID NOT NULL,
  request_id TEXT NOT NULL,
  request_hash CHAR(64) NOT NULL CHECK (request_hash ~ '^[0-9a-f]{64}$'),
  final_state_hash CHAR(64) NOT NULL CHECK (final_state_hash ~ '^[0-9a-f]{64}$'),
  elapsed_sim_ticks BIGINT NOT NULL CHECK (elapsed_sim_ticks >= 0),
  claimed_terminal_reason TEXT NOT NULL,
  claimed_winner_player_id UUID,
  report_json JSONB NOT NULL,
  submitted_at TIMESTAMPTZ NOT NULL,
  UNIQUE (match_id, match_epoch, player_id),
  UNIQUE (player_id, request_id),
  FOREIGN KEY (contract_id, match_id) REFERENCES vs_match_contracts(contract_id, match_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS vs_match_verification_jobs (
  job_id UUID PRIMARY KEY,
  result_id UUID NOT NULL UNIQUE,
  match_id UUID NOT NULL REFERENCES vs_match_contracts(match_id) ON DELETE RESTRICT,
  contract_id UUID NOT NULL REFERENCES vs_match_contracts(contract_id) ON DELETE RESTRICT,
  match_epoch INTEGER NOT NULL CHECK (match_epoch >= 1),
  contract_hash CHAR(64) NOT NULL CHECK (contract_hash ~ '^[0-9a-f]{64}$'),
  input_hash CHAR(64) NOT NULL CHECK (input_hash ~ '^[0-9a-f]{64}$'),
  status TEXT NOT NULL CHECK (status IN ('PENDING', 'LEASED', 'RETRY', 'COMPLETED', 'QUARANTINED', 'FAILED')),
  authority_method TEXT NOT NULL CHECK (authority_method IN ('SIM_REPLAY', 'SERVER_LIFECYCLE')),
  attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  max_attempts INTEGER NOT NULL DEFAULT 5 CHECK (max_attempts BETWEEN 1 AND 20),
  lease_owner TEXT,
  lease_token UUID,
  lease_expires_at TIMESTAMPTZ,
  available_at TIMESTAMPTZ NOT NULL,
  receipt_issued_at TIMESTAMPTZ NOT NULL,
  completion_hash CHAR(64) CHECK (completion_hash IS NULL OR completion_hash ~ '^[0-9a-f]{64}$'),
  last_error_code TEXT,
  last_error_detail JSONB,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  UNIQUE (match_id, match_epoch),
  FOREIGN KEY (contract_id, match_id) REFERENCES vs_match_contracts(contract_id, match_id) ON DELETE RESTRICT,
  CHECK ((status = 'LEASED' AND lease_owner IS NOT NULL AND lease_token IS NOT NULL AND lease_expires_at IS NOT NULL)
    OR status <> 'LEASED')
);

CREATE INDEX IF NOT EXISTS vs_match_verification_jobs_lease_idx
  ON vs_match_verification_jobs (available_at, created_at, job_id)
  WHERE status IN ('PENDING', 'RETRY', 'LEASED');

CREATE TABLE IF NOT EXISTS vs_match_verification_runs (
  run_id UUID PRIMARY KEY,
  job_id UUID NOT NULL REFERENCES vs_match_verification_jobs(job_id) ON DELETE RESTRICT,
  attempt INTEGER NOT NULL CHECK (attempt >= 1),
  worker_id TEXT NOT NULL,
  worker_build_id TEXT NOT NULL,
  input_hash CHAR(64) NOT NULL CHECK (input_hash ~ '^[0-9a-f]{64}$'),
  output_hash CHAR(64) CHECK (output_hash IS NULL OR output_hash ~ '^[0-9a-f]{64}$'),
  final_state_hash CHAR(64) CHECK (final_state_hash IS NULL OR final_state_hash ~ '^[0-9a-f]{64}$'),
  status TEXT NOT NULL CHECK (status IN ('COMPLETED', 'RETRYABLE_FAILURE', 'PERMANENT_FAILURE', 'REJECTED')),
  error_code TEXT,
  run_json JSONB NOT NULL,
  started_at TIMESTAMPTZ NOT NULL,
  finished_at TIMESTAMPTZ NOT NULL,
  UNIQUE (job_id, attempt)
);

CREATE TABLE IF NOT EXISTS vs_verifier_signed_receipts (
  result_id UUID PRIMARY KEY REFERENCES vs_terminal_results(result_id) ON DELETE RESTRICT,
  job_id UUID NOT NULL UNIQUE REFERENCES vs_match_verification_jobs(job_id) ON DELETE RESTRICT,
  authority_method TEXT NOT NULL CHECK (authority_method IN ('SIM_REPLAY', 'SERVER_LIFECYCLE')),
  worker_id TEXT NOT NULL,
  worker_build_id TEXT NOT NULL,
  sim_build_id TEXT NOT NULL,
  verifier_key_id TEXT NOT NULL,
  signature_algorithm TEXT NOT NULL CHECK (signature_algorithm = 'ES256'),
  signed_payload_hash CHAR(64) NOT NULL CHECK (signed_payload_hash ~ '^[0-9a-f]{64}$'),
  signature TEXT NOT NULL,
  signed_payload JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL
);
