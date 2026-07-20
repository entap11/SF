CREATE TABLE IF NOT EXISTS vs_public_contest_evidence (
  evidence_id UUID PRIMARY KEY,
  contest_id UUID NOT NULL REFERENCES vs_public_contests(contest_id) ON DELETE RESTRICT,
  attempt_id UUID NOT NULL UNIQUE REFERENCES vs_public_contest_attempts(attempt_id) ON DELETE RESTRICT,
  player_id UUID NOT NULL,
  submission_id TEXT NOT NULL,
  request_hash CHAR(64) NOT NULL CHECK (request_hash ~ '^[0-9a-f]{64}$'),
  evidence_json JSONB NOT NULL,
  status TEXT NOT NULL DEFAULT 'PENDING'
    CHECK (status IN ('PENDING', 'LEASED', 'VERIFIED', 'REJECTED')),
  worker_id TEXT,
  lease_token UUID,
  lease_expires_at TIMESTAMPTZ,
  delivery_attempts INTEGER NOT NULL DEFAULT 0 CHECK (delivery_attempts >= 0),
  contest_result_id UUID REFERENCES vs_public_contest_results(contest_result_id) ON DELETE RESTRICT,
  rejection_code TEXT,
  submitted_at TIMESTAMPTZ NOT NULL,
  resolved_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (contest_id, player_id, submission_id),
  FOREIGN KEY (contest_id, player_id)
    REFERENCES vs_public_contest_roster(contest_id, player_id) ON DELETE RESTRICT,
  CHECK ((status = 'LEASED' AND worker_id IS NOT NULL AND lease_token IS NOT NULL AND lease_expires_at IS NOT NULL)
    OR status <> 'LEASED')
);

CREATE INDEX IF NOT EXISTS vs_public_contest_evidence_lease_idx
  ON vs_public_contest_evidence (status, submitted_at, evidence_id)
  WHERE status IN ('PENDING', 'LEASED');

COMMENT ON TABLE vs_public_contest_evidence IS
  'Player diagnostic evidence only. Rows cannot enter a public leaderboard until a trusted worker commits a verified result.';
