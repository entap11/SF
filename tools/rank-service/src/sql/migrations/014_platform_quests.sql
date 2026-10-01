-- Progress is Platform-owned and scoped to the economy epoch and UTC cycle.
CREATE TABLE IF NOT EXISTS platform_quest_progress (
  epoch_id TEXT NOT NULL REFERENCES platform_economy_epochs(epoch_id) ON DELETE RESTRICT,
  season_id TEXT NOT NULL,
  player_id UUID NOT NULL REFERENCES rank_players(id) ON DELETE RESTRICT,
  quest_id TEXT NOT NULL,
  cycle_start TIMESTAMPTZ NOT NULL,
  cycle_end TIMESTAMPTZ NOT NULL,
  definition_hash CHAR(64) NOT NULL,
  definition_json JSONB NOT NULL,
  progress_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  claimed_transaction_id UUID REFERENCES platform_journal_transactions(transaction_id) ON DELETE RESTRICT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (epoch_id, player_id, quest_id, cycle_start),
  CHECK (cycle_end > cycle_start)
);

-- Different producer event IDs for one game still count at most once.
CREATE TABLE IF NOT EXISTS platform_quest_match_facts (
  epoch_id TEXT NOT NULL REFERENCES platform_economy_epochs(epoch_id) ON DELETE RESTRICT,
  player_id UUID NOT NULL REFERENCES rank_players(id) ON DELETE RESTRICT,
  match_id UUID NOT NULL,
  platform_event_id UUID NOT NULL REFERENCES platform_event_receipts(platform_event_id) ON DELETE RESTRICT,
  occurred_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (epoch_id, player_id, match_id)
);
