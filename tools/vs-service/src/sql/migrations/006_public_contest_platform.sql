CREATE TABLE IF NOT EXISTS vs_public_contests (
  contest_id UUID PRIMARY KEY,
  leaderboard_id UUID NOT NULL UNIQUE,
  contest_schema_version INTEGER NOT NULL CHECK (contest_schema_version = 1),
  series_key TEXT NOT NULL,
  generation INTEGER NOT NULL CHECK (generation >= 1),
  family TEXT NOT NULL CHECK (family IN ('TIME_PUZZLE', 'GAUNTLET', 'ASYNC_MAP_SET')),
  scope TEXT NOT NULL CHECK (scope IN ('WEEKLY', 'MONTHLY', 'SEASONAL', 'ROLLING_COHORT')),
  map_count INTEGER NOT NULL CHECK (map_count >= 1),
  status TEXT NOT NULL CHECK (status IN ('SCHEDULED', 'OPEN', 'FINALIZING', 'CLOSED')),
  map_pack_id TEXT NOT NULL,
  map_ids JSONB NOT NULL,
  content_hashes JSONB NOT NULL,
  sim_build_id TEXT NOT NULL,
  comparator_id TEXT NOT NULL CHECK (comparator_id IN ('TIME_TOTAL_V1', 'GAUNTLET_STARS_V1')),
  best_entry_policy TEXT NOT NULL CHECK (best_entry_policy IN ('BEST_PER_PLAYER', 'ONLY_SCORED_ATTEMPT')),
  attempt_policy JSONB NOT NULL,
  closure_policy JSONB NOT NULL,
  eligibility_policy JSONB NOT NULL,
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  opened_at TIMESTAMPTZ,
  closed_at TIMESTAMPTZ,
  definition_hash CHAR(64) NOT NULL CHECK (definition_hash ~ '^[0-9a-f]{64}$'),
  definition_json JSONB NOT NULL,
  leaderboard_version BIGINT NOT NULL DEFAULT 0 CHECK (leaderboard_version >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (series_key, generation),
  CHECK (ends_at > starts_at),
  CHECK (jsonb_typeof(map_ids) = 'array'),
  CHECK (jsonb_array_length(map_ids) = map_count)
);

CREATE INDEX IF NOT EXISTS vs_public_contests_current_idx
  ON vs_public_contests (family, scope, map_count, status, starts_at, ends_at);

CREATE TABLE IF NOT EXISTS vs_public_contest_roster (
  contest_id UUID NOT NULL REFERENCES vs_public_contests(contest_id) ON DELETE RESTRICT,
  player_id UUID NOT NULL,
  display_name TEXT NOT NULL,
  public_entap_id TEXT,
  joined_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (contest_id, player_id)
);

CREATE TABLE IF NOT EXISTS vs_public_contest_attempts (
  attempt_id UUID PRIMARY KEY,
  contest_id UUID NOT NULL REFERENCES vs_public_contests(contest_id) ON DELETE RESTRICT,
  player_id UUID NOT NULL,
  attempt_number INTEGER NOT NULL CHECK (attempt_number >= 1),
  definition_hash CHAR(64) NOT NULL CHECK (definition_hash ~ '^[0-9a-f]{64}$'),
  seed TEXT NOT NULL,
  issued_at TIMESTAMPTZ NOT NULL,
  submission_deadline_at TIMESTAMPTZ NOT NULL,
  grant_hash CHAR(64) NOT NULL CHECK (grant_hash ~ '^[0-9a-f]{64}$'),
  status TEXT NOT NULL CHECK (status IN ('ISSUED', 'COMMITTED', 'EXPIRED', 'VOID')),
  committed_result_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (contest_id, player_id, attempt_number),
  FOREIGN KEY (contest_id, player_id) REFERENCES vs_public_contest_roster(contest_id, player_id) ON DELETE RESTRICT,
  CHECK (submission_deadline_at > issued_at)
);

CREATE INDEX IF NOT EXISTS vs_public_contest_attempts_player_idx
  ON vs_public_contest_attempts (contest_id, player_id, attempt_number DESC);

CREATE TABLE IF NOT EXISTS vs_public_contest_results (
  contest_result_id UUID PRIMARY KEY,
  contest_id UUID NOT NULL REFERENCES vs_public_contests(contest_id) ON DELETE RESTRICT,
  attempt_id UUID NOT NULL UNIQUE REFERENCES vs_public_contest_attempts(attempt_id) ON DELETE RESTRICT,
  player_id UUID NOT NULL,
  submission_id TEXT NOT NULL,
  request_hash CHAR(64) NOT NULL CHECK (request_hash ~ '^[0-9a-f]{64}$'),
  verification_method TEXT NOT NULL,
  evidence_ref TEXT NOT NULL,
  result_json JSONB NOT NULL,
  competitive_primary BIGINT NOT NULL,
  competitive_secondary BIGINT NOT NULL DEFAULT 0,
  competitive_tertiary BIGINT NOT NULL DEFAULT 0,
  qualified_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (contest_id, attempt_id, submission_id),
  FOREIGN KEY (contest_id, player_id) REFERENCES vs_public_contest_roster(contest_id, player_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS vs_public_contest_best_results (
  contest_id UUID NOT NULL REFERENCES vs_public_contests(contest_id) ON DELETE RESTRICT,
  player_id UUID NOT NULL,
  contest_result_id UUID NOT NULL UNIQUE REFERENCES vs_public_contest_results(contest_result_id) ON DELETE RESTRICT,
  display_name TEXT NOT NULL,
  competitive_primary BIGINT NOT NULL,
  competitive_secondary BIGINT NOT NULL,
  competitive_tertiary BIGINT NOT NULL,
  qualified_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (contest_id, player_id),
  FOREIGN KEY (contest_id, player_id) REFERENCES vs_public_contest_roster(contest_id, player_id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS vs_public_contest_best_rank_idx
  ON vs_public_contest_best_results
    (contest_id, competitive_primary DESC, competitive_secondary DESC,
     competitive_tertiary DESC, qualified_at ASC, player_id ASC);

CREATE TABLE IF NOT EXISTS vs_public_contest_placements (
  contest_id UUID NOT NULL REFERENCES vs_public_contests(contest_id) ON DELETE RESTRICT,
  player_id UUID NOT NULL,
  contest_result_id UUID NOT NULL REFERENCES vs_public_contest_results(contest_result_id) ON DELETE RESTRICT,
  ordinal_place INTEGER NOT NULL CHECK (ordinal_place >= 1),
  competitive_place INTEGER NOT NULL CHECK (competitive_place >= 1),
  placed_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (contest_id, player_id),
  UNIQUE (contest_id, ordinal_place)
);

COMMENT ON TABLE vs_public_contests IS
  'Server-authored public contest authority. Bundled .tres and user:// fixtures never populate this table.';

