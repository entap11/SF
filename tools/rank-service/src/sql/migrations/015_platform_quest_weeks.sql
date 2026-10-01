ALTER TABLE platform_quest_progress ADD COLUMN IF NOT EXISTS week_start TIMESTAMPTZ;
CREATE TABLE IF NOT EXISTS platform_quest_weeks (
  epoch_id TEXT NOT NULL REFERENCES platform_economy_epochs(epoch_id) ON DELETE RESTRICT,
  player_id UUID NOT NULL REFERENCES rank_players(id) ON DELETE RESTRICT,
  week_start TIMESTAMPTZ NOT NULL,
  week_end TIMESTAMPTZ NOT NULL,
  catalog_version TEXT NOT NULL,
  assignment_count INTEGER NOT NULL CHECK (assignment_count = 25),
  bonus_bps INTEGER NOT NULL CHECK (bonus_bps BETWEEN 0 AND 10000),
  bonus_eligible BOOLEAN NOT NULL,
  bonus_transaction_id UUID REFERENCES platform_journal_transactions(transaction_id) ON DELETE RESTRICT,
  bonus_centi BIGINT NOT NULL DEFAULT 0 CHECK (bonus_centi >= 0),
  PRIMARY KEY (epoch_id, player_id, week_start)
);
CREATE TABLE IF NOT EXISTS platform_quest_activity_facts (
  epoch_id TEXT NOT NULL REFERENCES platform_economy_epochs(epoch_id) ON DELETE RESTRICT,
  player_id UUID NOT NULL REFERENCES rank_players(id) ON DELETE RESTRICT,
  subject_id UUID NOT NULL,
  family TEXT NOT NULL CHECK (family IN ('LIVE', 'ASYNC_MAP_SET', 'TIME_PUZZLE', 'GAUNTLET')),
  fact_hash CHAR(64) NOT NULL,
  platform_event_id UUID NOT NULL REFERENCES platform_event_receipts(platform_event_id) ON DELETE RESTRICT,
  occurred_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (epoch_id, player_id, subject_id)
);
CREATE INDEX IF NOT EXISTS platform_quest_progress_week_idx
  ON platform_quest_progress(epoch_id, player_id, week_start);
