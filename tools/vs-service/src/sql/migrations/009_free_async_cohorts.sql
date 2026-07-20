CREATE TABLE IF NOT EXISTS vs_public_contest_cohorts (
  contest_id UUID PRIMARY KEY REFERENCES vs_public_contests(contest_id) ON DELETE RESTRICT,
  cohort_family_id TEXT NOT NULL CHECK (cohort_family_id IN ('ASYNC_3_ROLLING_4P_V1', 'ASYNC_5_ROLLING_4P_V1')),
  roster_capacity INTEGER NOT NULL CHECK (roster_capacity = 4),
  completion_target INTEGER NOT NULL CHECK (completion_target = 4),
  roster_locked_at TIMESTAMPTZ,
  finalized_at TIMESTAMPTZ,
  qualified_player_count INTEGER NOT NULL DEFAULT 0 CHECK (qualified_player_count BETWEEN 0 AND 4),
  closure_snapshot_hash CHAR(64) CHECK (closure_snapshot_hash IS NULL OR closure_snapshot_hash ~ '^[0-9a-f]{64}$'),
  closure_snapshot JSONB,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  CHECK ((finalized_at IS NULL AND closure_snapshot IS NULL AND closure_snapshot_hash IS NULL)
    OR (finalized_at IS NOT NULL AND closure_snapshot IS NOT NULL AND closure_snapshot_hash IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS vs_public_contest_cohorts_open_idx
  ON vs_public_contest_cohorts (cohort_family_id, created_at)
  WHERE finalized_at IS NULL;

COMMENT ON TABLE vs_public_contest_cohorts IS
  'Free four-authenticated-player rolling cohorts. This table has no payout or escrow columns by design.';
