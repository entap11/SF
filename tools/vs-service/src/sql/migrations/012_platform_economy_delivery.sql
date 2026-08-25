CREATE TABLE IF NOT EXISTS vs_platform_economy_deliveries (
  delivery_id UUID PRIMARY KEY,
  producer_event_id TEXT NOT NULL UNIQUE,
  operation TEXT NOT NULL CHECK (operation IN (
    'HONEY_ACTIVITY', 'NECTAR_MATCH', 'CRUCIBLE_RESERVE', 'CRUCIBLE_SETTLE', 'CRUCIBLE_REFUND'
  )),
  match_id UUID REFERENCES vs_match_contracts(match_id) ON DELETE RESTRICT,
  contract_id UUID REFERENCES vs_match_contracts(contract_id) ON DELETE RESTRICT,
  result_id UUID REFERENCES vs_terminal_results(result_id) ON DELETE RESTRICT,
  player_id UUID,
  economy_epoch TEXT NOT NULL,
  source_authority TEXT NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL,
  payload JSONB NOT NULL,
  request_hash CHAR(64) NOT NULL CHECK (request_hash ~ '^[0-9a-f]{64}$'),
  status TEXT NOT NULL CHECK (status IN ('PENDING', 'LEASED', 'RETRY', 'DELIVERED', 'FAILED')),
  attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  lease_owner TEXT,
  lease_token UUID,
  lease_expires_at TIMESTAMPTZ,
  available_at TIMESTAMPTZ NOT NULL,
  response_json JSONB,
  last_error_code TEXT,
  delivered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  CHECK ((status = 'LEASED' AND lease_owner IS NOT NULL AND lease_token IS NOT NULL
    AND lease_expires_at IS NOT NULL) OR status <> 'LEASED'),
  CHECK ((operation IN ('HONEY_ACTIVITY', 'NECTAR_MATCH', 'CRUCIBLE_RESERVE') AND player_id IS NOT NULL)
    OR operation IN ('CRUCIBLE_SETTLE', 'CRUCIBLE_REFUND')),
  CHECK ((contract_id IS NULL AND match_id IS NULL)
    OR (contract_id IS NOT NULL AND match_id IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS vs_platform_economy_delivery_lease_idx
  ON vs_platform_economy_deliveries (available_at, created_at, delivery_id)
  WHERE status IN ('PENDING', 'RETRY', 'LEASED');

CREATE INDEX IF NOT EXISTS vs_platform_economy_delivery_match_idx
  ON vs_platform_economy_deliveries (match_id, operation, status);

CREATE TABLE IF NOT EXISTS vs_platform_economy_delivery_attempts (
  attempt_id UUID PRIMARY KEY,
  delivery_id UUID NOT NULL REFERENCES vs_platform_economy_deliveries(delivery_id) ON DELETE RESTRICT,
  attempt INTEGER NOT NULL CHECK (attempt >= 1),
  worker_id TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('DELIVERED', 'RETRYABLE_FAILURE', 'PERMANENT_FAILURE')),
  request_hash CHAR(64) NOT NULL CHECK (request_hash ~ '^[0-9a-f]{64}$'),
  response_json JSONB NOT NULL,
  error_code TEXT,
  started_at TIMESTAMPTZ NOT NULL,
  finished_at TIMESTAMPTZ NOT NULL,
  UNIQUE (delivery_id, attempt)
);

INSERT INTO vs_match_lifecycle_events
  (event_id, match_id, match_epoch, event_type, event_payload, occurred_at)
SELECT gen_random_uuid(), c.match_id, c.match_epoch, 'MATCH_VERIFICATION_FAILED',
  jsonb_build_object(
    'error_code', COALESCE(j.last_error_code, 'PERMANENT_VERIFICATION_FAILURE'),
    'disposition', 'CANCELLED_NO_ECONOMY_EFFECT',
    'authority', 'migration_012_expired_failed_cleanup'
  ), now()
FROM vs_match_contracts c
JOIN vs_match_verification_jobs j
  ON j.match_id = c.match_id AND j.match_epoch = c.match_epoch
WHERE c.status = 'VERIFYING' AND c.expires_at < now() AND j.status = 'FAILED'
  AND NOT EXISTS (
    SELECT 1 FROM vs_terminal_results r
    WHERE r.match_id = c.match_id AND r.match_epoch = c.match_epoch
  )
  AND NOT EXISTS (
    SELECT 1 FROM vs_match_lifecycle_events e
    WHERE e.match_id = c.match_id AND e.match_epoch = c.match_epoch
      AND e.event_type = 'MATCH_VERIFICATION_FAILED'
  );

UPDATE vs_match_contracts c
SET status = 'CANCELLED', updated_at = now()
WHERE c.status = 'VERIFYING' AND c.expires_at < now()
  AND EXISTS (
    SELECT 1 FROM vs_match_verification_jobs j
    WHERE j.match_id = c.match_id AND j.match_epoch = c.match_epoch AND j.status = 'FAILED'
  )
  AND NOT EXISTS (
    SELECT 1 FROM vs_terminal_results r
    WHERE r.match_id = c.match_id AND r.match_epoch = c.match_epoch
  );
