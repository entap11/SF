CREATE TABLE IF NOT EXISTS vs_crucible_accounts (
  account_key TEXT PRIMARY KEY,
  account_type TEXT NOT NULL CHECK (account_type IN ('PLAYER', 'ESCROW', 'AWARD_RESERVE', 'SYSTEM_ISSUANCE')),
  player_id UUID,
  balance_millis BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  CHECK ((account_type = 'PLAYER' AND player_id IS NOT NULL)
    OR (account_type <> 'PLAYER' AND player_id IS NULL)),
  CHECK ((account_type IN ('PLAYER', 'ESCROW', 'AWARD_RESERVE') AND balance_millis >= 0)
    OR account_type = 'SYSTEM_ISSUANCE')
);

CREATE UNIQUE INDEX IF NOT EXISTS vs_crucible_accounts_player_idx
  ON vs_crucible_accounts (player_id) WHERE player_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS vs_crucible_escrows (
  escrow_id UUID PRIMARY KEY,
  match_id UUID NOT NULL UNIQUE REFERENCES vs_match_contracts(match_id) ON DELETE RESTRICT,
  contract_id UUID NOT NULL REFERENCES vs_match_contracts(contract_id) ON DELETE RESTRICT,
  player_a_id UUID NOT NULL,
  player_b_id UUID NOT NULL,
  stake_each_millis BIGINT NOT NULL CHECK (stake_each_millis = 1000),
  pot_millis BIGINT NOT NULL CHECK (pot_millis = 2000),
  winner_payout_millis BIGINT NOT NULL CHECK (winner_payout_millis = 1800),
  award_reserve_millis BIGINT NOT NULL CHECK (award_reserve_millis = 200),
  status TEXT NOT NULL CHECK (status IN ('ESCROWED', 'SETTLED', 'REFUNDED', 'REVERSED')),
  open_transaction_id UUID NOT NULL UNIQUE,
  opened_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  CHECK (player_a_id <> player_b_id),
  FOREIGN KEY (contract_id, match_id) REFERENCES vs_match_contracts(contract_id, match_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS vs_crucible_transactions (
  transaction_id UUID PRIMARY KEY,
  match_id UUID REFERENCES vs_match_contracts(match_id) ON DELETE RESTRICT,
  operation_type TEXT NOT NULL CHECK (operation_type IN ('BALANCE_ADJUSTMENT', 'ESCROW_OPEN', 'WINNER_SETTLEMENT', 'REFUND', 'REVERSAL')),
  request_id TEXT NOT NULL,
  request_hash CHAR(64) NOT NULL CHECK (request_hash ~ '^[0-9a-f]{64}$'),
  reversal_of_transaction_id UUID REFERENCES vs_crucible_transactions(transaction_id) ON DELETE RESTRICT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL,
  UNIQUE (operation_type, request_id)
);

CREATE TABLE IF NOT EXISTS vs_crucible_journal_entries (
  transaction_id UUID NOT NULL REFERENCES vs_crucible_transactions(transaction_id) ON DELETE RESTRICT,
  line_number SMALLINT NOT NULL CHECK (line_number >= 1),
  account_key TEXT NOT NULL REFERENCES vs_crucible_accounts(account_key) ON DELETE RESTRICT,
  amount_millis BIGINT NOT NULL CHECK (amount_millis <> 0),
  created_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (transaction_id, line_number)
);

CREATE INDEX IF NOT EXISTS vs_crucible_journal_match_idx
  ON vs_crucible_transactions (match_id, created_at);
CREATE INDEX IF NOT EXISTS vs_crucible_journal_account_idx
  ON vs_crucible_journal_entries (account_key, created_at);

CREATE TABLE IF NOT EXISTS vs_crucible_settlements (
  settlement_id UUID PRIMARY KEY,
  escrow_id UUID NOT NULL UNIQUE REFERENCES vs_crucible_escrows(escrow_id) ON DELETE RESTRICT,
  match_id UUID NOT NULL UNIQUE REFERENCES vs_match_contracts(match_id) ON DELETE RESTRICT,
  result_id UUID NOT NULL UNIQUE REFERENCES vs_terminal_results(result_id) ON DELETE RESTRICT,
  winner_player_id UUID NOT NULL,
  loser_player_id UUID NOT NULL,
  payout_millis BIGINT NOT NULL CHECK (payout_millis = 1800),
  reserve_millis BIGINT NOT NULL CHECK (reserve_millis = 200),
  transaction_id UUID NOT NULL UNIQUE REFERENCES vs_crucible_transactions(transaction_id) ON DELETE RESTRICT,
  settled_at TIMESTAMPTZ NOT NULL,
  CHECK (winner_player_id <> loser_player_id)
);

CREATE TABLE IF NOT EXISTS vs_crucible_refunds (
  refund_id UUID PRIMARY KEY,
  escrow_id UUID NOT NULL UNIQUE REFERENCES vs_crucible_escrows(escrow_id) ON DELETE RESTRICT,
  match_id UUID NOT NULL UNIQUE REFERENCES vs_match_contracts(match_id) ON DELETE RESTRICT,
  reason TEXT NOT NULL,
  player_a_refund_millis BIGINT NOT NULL CHECK (player_a_refund_millis = 1000),
  player_b_refund_millis BIGINT NOT NULL CHECK (player_b_refund_millis = 1000),
  transaction_id UUID NOT NULL UNIQUE REFERENCES vs_crucible_transactions(transaction_id) ON DELETE RESTRICT,
  refunded_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS vs_crucible_reversals (
  reversal_id UUID PRIMARY KEY,
  match_id UUID NOT NULL UNIQUE REFERENCES vs_match_contracts(match_id) ON DELETE RESTRICT,
  settlement_id UUID NOT NULL UNIQUE REFERENCES vs_crucible_settlements(settlement_id) ON DELETE RESTRICT,
  settlement_transaction_id UUID NOT NULL REFERENCES vs_crucible_transactions(transaction_id) ON DELETE RESTRICT,
  reversal_transaction_id UUID NOT NULL UNIQUE REFERENCES vs_crucible_transactions(transaction_id) ON DELETE RESTRICT,
  reason TEXT NOT NULL,
  reversed_at TIMESTAMPTZ NOT NULL
);

INSERT INTO vs_crucible_accounts
  (account_key, account_type, player_id, balance_millis, created_at, updated_at)
VALUES
  ('reserve:award', 'AWARD_RESERVE', NULL, 0, now(), now()),
  ('system:issuance', 'SYSTEM_ISSUANCE', NULL, 0, now(), now())
ON CONFLICT (account_key) DO NOTHING;
