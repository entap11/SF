CREATE TABLE IF NOT EXISTS vs_ops_config_revisions (
  revision_id UUID PRIMARY KEY,
  revision_seq BIGSERIAL NOT NULL UNIQUE,
  config_version TEXT NOT NULL UNIQUE,
  schema_version INTEGER NOT NULL DEFAULT 1 CHECK (schema_version = 1),
  min_supported_build BIGINT NOT NULL DEFAULT 0 CHECK (min_supported_build >= 0),
  expires_at TIMESTAMPTZ,
  feature_flags JSONB NOT NULL,
  config_hash TEXT NOT NULL CHECK (config_hash ~ '^[0-9a-f]{64}$'),
  publication_reason TEXT NOT NULL,
  published_by TEXT NOT NULL,
  published_at TIMESTAMPTZ NOT NULL,
  previous_revision_id UUID REFERENCES vs_ops_config_revisions(revision_id) ON DELETE RESTRICT,
  rollback_of_revision_id UUID REFERENCES vs_ops_config_revisions(revision_id) ON DELETE RESTRICT,
  request_id TEXT NOT NULL UNIQUE,
  active BOOLEAN NOT NULL DEFAULT FALSE,
  CHECK (jsonb_typeof(feature_flags) = 'object')
);

CREATE UNIQUE INDEX IF NOT EXISTS vs_ops_config_one_active_idx
  ON vs_ops_config_revisions (active) WHERE active;

CREATE INDEX IF NOT EXISTS vs_ops_config_history_idx
  ON vs_ops_config_revisions (revision_seq DESC);

CREATE TABLE IF NOT EXISTS vs_ops_reconciliation_runs (
  run_id UUID PRIMARY KEY,
  started_at TIMESTAMPTZ NOT NULL,
  finished_at TIMESTAMPTZ NOT NULL,
  started_by TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('OK', 'ALERT')),
  result JSONB NOT NULL,
  CHECK (jsonb_typeof(result) = 'object')
);

CREATE INDEX IF NOT EXISTS vs_ops_reconciliation_runs_started_idx
  ON vs_ops_reconciliation_runs (started_at DESC);

CREATE TABLE IF NOT EXISTS vs_ops_alerts (
  alert_id UUID PRIMARY KEY,
  alert_key TEXT NOT NULL,
  severity TEXT NOT NULL CHECK (severity IN ('WARNING', 'CRITICAL')),
  status TEXT NOT NULL CHECK (status IN ('OPEN', 'RESOLVED')),
  details JSONB NOT NULL,
  first_seen_at TIMESTAMPTZ NOT NULL,
  last_seen_at TIMESTAMPTZ NOT NULL,
  resolved_at TIMESTAMPTZ,
  UNIQUE (alert_key, status),
  CHECK (jsonb_typeof(details) = 'object')
);

COMMENT ON TABLE vs_ops_config_revisions IS
  'Authenticated, append-only public-mode rollout configuration with single-active revision and rollback lineage.';
COMMENT ON TABLE vs_ops_reconciliation_runs IS
  'Support-visible audit trail for public-mode repair/reconciliation jobs.';
COMMENT ON TABLE vs_ops_alerts IS
  'Durable operational alerts emitted by public-mode reconciliation.';
