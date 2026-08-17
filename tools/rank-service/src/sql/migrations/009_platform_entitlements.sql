CREATE TABLE IF NOT EXISTS platform_player_entitlements (
  epoch_id TEXT NOT NULL REFERENCES platform_economy_epochs(epoch_id) ON DELETE RESTRICT,
  player_id UUID NOT NULL REFERENCES rank_players(id) ON DELETE RESTRICT,
  entitlement_id TEXT NOT NULL,
  catalog_action_id TEXT NOT NULL,
  source_transaction_id UUID NOT NULL REFERENCES platform_journal_transactions(transaction_id) ON DELETE RESTRICT,
  granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (epoch_id, player_id, entitlement_id),
  CHECK (length(entitlement_id) BETWEEN 1 AND 128),
  CHECK (length(catalog_action_id) BETWEEN 1 AND 128)
);

CREATE INDEX IF NOT EXISTS platform_player_entitlements_player_idx
  ON platform_player_entitlements (epoch_id, player_id, granted_at, entitlement_id);

DROP TRIGGER IF EXISTS platform_player_entitlements_immutable ON platform_player_entitlements;
CREATE TRIGGER platform_player_entitlements_immutable
  BEFORE UPDATE OR DELETE ON platform_player_entitlements
  FOR EACH ROW EXECUTE FUNCTION platform_reject_immutable_change();
