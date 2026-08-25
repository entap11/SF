CREATE TABLE IF NOT EXISTS platform_economy_epochs (
  epoch_id TEXT PRIMARY KEY,
  state TEXT NOT NULL CHECK (state IN ('DRAFT', 'PREPARED', 'RECONCILED', 'ACTIVE', 'ABORTED')),
  is_current BOOLEAN NOT NULL DEFAULT FALSE,
  season_id TEXT NOT NULL,
  opening_honey_centi BIGINT NOT NULL DEFAULT 0 CHECK (opening_honey_centi >= 0),
  opening_wax_millis BIGINT NOT NULL DEFAULT 0 CHECK (opening_wax_millis >= 0),
  opening_nectar_milli BIGINT NOT NULL DEFAULT 0 CHECK (opening_nectar_milli >= 0),
  artifact_digest CHAR(64) NOT NULL CHECK (artifact_digest ~ '^[0-9a-f]{64}$'),
  prepared_at TIMESTAMPTZ,
  reconciled_at TIMESTAMPTZ,
  activated_at TIMESTAMPTZ,
  aborted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS platform_one_active_epoch_idx
  ON platform_economy_epochs (is_current) WHERE is_current;

INSERT INTO platform_economy_epochs
  (epoch_id, state, is_current, season_id, artifact_digest, prepared_at, reconciled_at, activated_at)
VALUES
  ('legacy-pre-platform', 'ACTIVE', TRUE, 'legacy', repeat('0', 64), now(), now(), now())
ON CONFLICT (epoch_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS platform_economy_capabilities (
  capability TEXT PRIMARY KEY,
  enabled BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (capability IN ('NECTAR', 'HONEY_EARN', 'HONEY_SPEND', 'WAX_STANDARD', 'WAX_CRUCIBLE'))
);

INSERT INTO platform_economy_capabilities (capability, enabled)
VALUES ('NECTAR', FALSE), ('HONEY_EARN', FALSE), ('HONEY_SPEND', FALSE),
       ('WAX_STANDARD', FALSE), ('WAX_CRUCIBLE', FALSE)
ON CONFLICT (capability) DO NOTHING;

CREATE TABLE IF NOT EXISTS platform_economy_accounts (
  account_id TEXT PRIMARY KEY,
  epoch_id TEXT NOT NULL REFERENCES platform_economy_epochs(epoch_id) ON DELETE RESTRICT,
  asset TEXT NOT NULL CHECK (asset IN ('HONEY_CENTI', 'WAX_MILLIS', 'NECTAR_MILLI')),
  account_type TEXT NOT NULL CHECK (account_type IN ('PLAYER', 'ESCROW', 'AWARD_RESERVE', 'ISSUANCE', 'SINK')),
  owner_id TEXT NOT NULL,
  balance_units BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (epoch_id, asset, account_type, owner_id),
  CHECK (account_type IN ('ISSUANCE', 'SINK') OR balance_units >= 0),
  CHECK (account_type <> 'AWARD_RESERVE' OR (asset = 'WAX_MILLIS' AND owner_id = 'reserve:award'))
);

CREATE INDEX IF NOT EXISTS platform_economy_accounts_owner_idx
  ON platform_economy_accounts (epoch_id, owner_id, asset);

CREATE OR REPLACE FUNCTION platform_reject_immutable_change() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'platform_immutable_record';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION platform_guard_account_update() RETURNS trigger AS $$
BEGIN
  IF NEW.account_id <> OLD.account_id OR NEW.epoch_id <> OLD.epoch_id
     OR NEW.asset <> OLD.asset OR NEW.account_type <> OLD.account_type
     OR NEW.owner_id <> OLD.owner_id OR NEW.created_at <> OLD.created_at THEN
    RAISE EXCEPTION 'platform_account_identity_immutable';
  END IF;
  IF NEW.balance_units <> OLD.balance_units
     AND current_setting('platform.journal_write', TRUE) IS DISTINCT FROM 'on' THEN
    RAISE EXCEPTION 'platform_balance_requires_journal';
  END IF;
  IF OLD.account_type = 'AWARD_RESERVE' AND NEW.balance_units < OLD.balance_units THEN
    RAISE EXCEPTION 'platform_award_reserve_debit_forbidden';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS platform_economy_accounts_guard ON platform_economy_accounts;
CREATE TRIGGER platform_economy_accounts_guard
  BEFORE UPDATE ON platform_economy_accounts
  FOR EACH ROW EXECUTE FUNCTION platform_guard_account_update();

DROP TRIGGER IF EXISTS platform_economy_accounts_no_delete ON platform_economy_accounts;
CREATE TRIGGER platform_economy_accounts_no_delete
  BEFORE DELETE ON platform_economy_accounts
  FOR EACH ROW EXECUTE FUNCTION platform_reject_immutable_change();

CREATE TABLE IF NOT EXISTS platform_event_receipts (
  producer_service TEXT NOT NULL,
  producer_event_id TEXT NOT NULL,
  platform_event_id UUID NOT NULL DEFAULT rank_uuid_v7() UNIQUE,
  epoch_id TEXT NOT NULL REFERENCES platform_economy_epochs(epoch_id) ON DELETE RESTRICT,
  event_type TEXT NOT NULL,
  request_hash CHAR(64) NOT NULL CHECK (request_hash ~ '^[0-9a-f]{64}$'),
  status TEXT NOT NULL CHECK (status IN ('PENDING', 'COMPLETED', 'FAILED')),
  response_json JSONB,
  transaction_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (producer_service, producer_event_id),
  CHECK (length(producer_service) BETWEEN 1 AND 128),
  CHECK (length(producer_event_id) BETWEEN 1 AND 256),
  CHECK (length(event_type) BETWEEN 1 AND 128)
);

CREATE TABLE IF NOT EXISTS platform_journal_transactions (
  transaction_id UUID PRIMARY KEY DEFAULT rank_uuid_v7(),
  platform_event_id UUID NOT NULL UNIQUE REFERENCES platform_event_receipts(platform_event_id) ON DELETE RESTRICT,
  epoch_id TEXT NOT NULL REFERENCES platform_economy_epochs(epoch_id) ON DELETE RESTRICT,
  event_type TEXT NOT NULL,
  external_ref TEXT NOT NULL DEFAULT '',
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE platform_event_receipts
  DROP CONSTRAINT IF EXISTS platform_event_receipts_transaction_id_fkey;
ALTER TABLE platform_event_receipts
  ADD CONSTRAINT platform_event_receipts_transaction_id_fkey
  FOREIGN KEY (transaction_id) REFERENCES platform_journal_transactions(transaction_id) ON DELETE RESTRICT;

CREATE TABLE IF NOT EXISTS platform_journal_entries (
  entry_id BIGSERIAL PRIMARY KEY,
  transaction_id UUID NOT NULL REFERENCES platform_journal_transactions(transaction_id) ON DELETE RESTRICT,
  account_id TEXT NOT NULL REFERENCES platform_economy_accounts(account_id) ON DELETE RESTRICT,
  asset TEXT NOT NULL CHECK (asset IN ('HONEY_CENTI', 'WAX_MILLIS', 'NECTAR_MILLI')),
  delta_units BIGINT NOT NULL CHECK (delta_units <> 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS platform_journal_entries_account_idx
  ON platform_journal_entries (account_id, entry_id);

CREATE OR REPLACE FUNCTION platform_reject_immutable_change() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'platform_immutable_record';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS platform_journal_transactions_immutable ON platform_journal_transactions;
CREATE TRIGGER platform_journal_transactions_immutable
  BEFORE UPDATE OR DELETE ON platform_journal_transactions
  FOR EACH ROW EXECUTE FUNCTION platform_reject_immutable_change();

DROP TRIGGER IF EXISTS platform_journal_entries_immutable ON platform_journal_entries;
CREATE TRIGGER platform_journal_entries_immutable
  BEFORE UPDATE OR DELETE ON platform_journal_entries
  FOR EACH ROW EXECUTE FUNCTION platform_reject_immutable_change();

CREATE TABLE IF NOT EXISTS platform_honey_activity_history (
  producer_service TEXT NOT NULL,
  producer_event_id TEXT NOT NULL,
  epoch_id TEXT NOT NULL REFERENCES platform_economy_epochs(epoch_id) ON DELETE RESTRICT,
  player_id UUID NOT NULL REFERENCES rank_players(id) ON DELETE RESTRICT,
  activity_key TEXT NOT NULL,
  opponent_key TEXT NOT NULL DEFAULT '',
  occurred_at TIMESTAMPTZ NOT NULL,
  awarded_centi BIGINT NOT NULL CHECK (awarded_centi >= 0),
  PRIMARY KEY (producer_service, producer_event_id),
  FOREIGN KEY (producer_service, producer_event_id)
    REFERENCES platform_event_receipts(producer_service, producer_event_id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS platform_honey_activity_repeat_idx
  ON platform_honey_activity_history (player_id, activity_key, opponent_key, occurred_at DESC);

CREATE TABLE IF NOT EXISTS platform_nectar_progression (
  epoch_id TEXT NOT NULL REFERENCES platform_economy_epochs(epoch_id) ON DELETE RESTRICT,
  season_id TEXT NOT NULL,
  player_id UUID NOT NULL REFERENCES rank_players(id) ON DELETE RESTRICT,
  nectar_milli BIGINT NOT NULL DEFAULT 0 CHECK (nectar_milli >= 0),
  fractional_milli INTEGER NOT NULL DEFAULT 0 CHECK (fractional_milli BETWEEN 0 AND 999),
  entitlement_tier TEXT NOT NULL DEFAULT 'FREE' CHECK (entitlement_tier IN ('FREE', 'PREMIUM', 'ELITE')),
  pass_level INTEGER NOT NULL DEFAULT 1 CHECK (pass_level >= 1),
  revision BIGINT NOT NULL DEFAULT 0 CHECK (revision >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (epoch_id, season_id, player_id)
);

CREATE TABLE IF NOT EXISTS platform_nectar_award_history (
  producer_service TEXT NOT NULL,
  producer_event_id TEXT NOT NULL,
  epoch_id TEXT NOT NULL REFERENCES platform_economy_epochs(epoch_id) ON DELETE RESTRICT,
  season_id TEXT NOT NULL,
  player_id UUID NOT NULL REFERENCES rank_players(id) ON DELETE RESTRICT,
  mode_id TEXT NOT NULL,
  opponent_key TEXT NOT NULL DEFAULT '',
  occurred_at TIMESTAMPTZ NOT NULL,
  base_nectar_milli BIGINT NOT NULL CHECK (base_nectar_milli >= 0),
  awarded_nectar_milli BIGINT NOT NULL CHECK (awarded_nectar_milli >= 0),
  PRIMARY KEY (producer_service, producer_event_id),
  FOREIGN KEY (producer_service, producer_event_id)
    REFERENCES platform_event_receipts(producer_service, producer_event_id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS platform_nectar_award_player_day_idx
  ON platform_nectar_award_history (player_id, occurred_at DESC);

CREATE TABLE IF NOT EXISTS platform_crucible_contracts (
  match_id UUID PRIMARY KEY,
  contract_id UUID NOT NULL UNIQUE,
  contract_hash CHAR(64) NOT NULL CHECK (contract_hash ~ '^[0-9a-f]{64}$'),
  epoch_id TEXT NOT NULL REFERENCES platform_economy_epochs(epoch_id) ON DELETE RESTRICT,
  player_a_id UUID NOT NULL REFERENCES rank_players(id) ON DELETE RESTRICT,
  player_b_id UUID NOT NULL REFERENCES rank_players(id) ON DELETE RESTRICT,
  escrow_account_id TEXT NOT NULL REFERENCES platform_economy_accounts(account_id) ON DELETE RESTRICT,
  status TEXT NOT NULL CHECK (status IN ('PENDING', 'RESERVED', 'SETTLED', 'REFUNDED', 'EXPIRED')),
  result_id UUID UNIQUE,
  winner_player_id UUID REFERENCES rank_players(id) ON DELETE RESTRICT,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (player_a_id <> player_b_id)
);

CREATE TABLE IF NOT EXISTS platform_crucible_reservations (
  match_id UUID NOT NULL REFERENCES platform_crucible_contracts(match_id) ON DELETE RESTRICT,
  player_id UUID NOT NULL REFERENCES rank_players(id) ON DELETE RESTRICT,
  amount_millis BIGINT NOT NULL CHECK (amount_millis = 1000),
  producer_service TEXT NOT NULL,
  producer_event_id TEXT NOT NULL,
  reservation_transaction_id UUID NOT NULL REFERENCES platform_journal_transactions(transaction_id) ON DELETE RESTRICT,
  status TEXT NOT NULL CHECK (status IN ('RESERVED', 'SETTLED', 'REFUNDED', 'EXPIRED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (match_id, player_id),
  UNIQUE (producer_service, producer_event_id),
  FOREIGN KEY (producer_service, producer_event_id)
    REFERENCES platform_event_receipts(producer_service, producer_event_id) ON DELETE RESTRICT
);
