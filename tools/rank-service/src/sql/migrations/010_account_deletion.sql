-- Requests remain pending until every data owner has supplied a fulfillment receipt.
-- No recoverable archive is created by permanent deletion.
ALTER TABLE rank_players ADD COLUMN IF NOT EXISTS account_status TEXT NOT NULL DEFAULT 'active'
  CHECK (account_status IN ('active', 'deletion_pending'));

CREATE TABLE IF NOT EXISTS entap_account_deletion_requests (
  request_id TEXT PRIMARY KEY,
  player_id UUID UNIQUE,
  subject_hash TEXT NOT NULL UNIQUE,
  receipt_hash TEXT NOT NULL,
  verification_evidence_ref TEXT NOT NULL DEFAULT 'device:deletion-specific-signature',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed')),
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  target_at TIMESTAMPTZ NOT NULL DEFAULT now() + interval '7 days',
  completed_at TIMESTAMPTZ,
  CHECK ((status = 'pending' AND player_id IS NOT NULL AND completed_at IS NULL)
    OR (status = 'completed' AND player_id IS NULL AND completed_at IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS entap_account_deletion_challenges (
  request_id TEXT PRIMARY KEY,
  player_id UUID NOT NULL REFERENCES rank_players(id) ON DELETE CASCADE,
  device_id UUID NOT NULL REFERENCES entap_player_devices(id) ON DELETE CASCADE,
  receipt_hash TEXT NOT NULL,
  challenge TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT now() + interval '5 minutes'
);

CREATE TABLE IF NOT EXISTS entap_account_deletion_tasks (
  request_id TEXT NOT NULL REFERENCES entap_account_deletion_requests(request_id) ON DELETE CASCADE,
  domain TEXT NOT NULL CHECK (domain IN ('identity', 'multiplayer', 'analytics', 'community', 'support', 'backups')),
  completed_at TIMESTAMPTZ,
  evidence_ref TEXT,
  retention JSONB NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(retention) = 'array'),
  PRIMARY KEY (request_id, domain)
);

-- Minimal suppression evidence prevents a delayed result/import recreating a deleted ID.
-- This is not a progress archive. Access and retention are covered by the runbook.
CREATE OR REPLACE FUNCTION entap_guard_deleted_identity() RETURNS trigger AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM entap_account_deletion_requests
    WHERE subject_hash = encode(digest(NEW.id::text, 'sha256'), 'hex')) THEN
    IF TG_OP = 'INSERT' OR NEW.account_status <> 'deletion_pending' THEN
      RAISE EXCEPTION 'account_deletion_pending';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER entap_guard_deleted_identity BEFORE INSERT OR UPDATE ON rank_players
  FOR EACH ROW EXECUTE FUNCTION entap_guard_deleted_identity();
