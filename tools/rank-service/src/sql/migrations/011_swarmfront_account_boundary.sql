-- The ENTaP principal is shared; rank_players is the Swarmfront game profile.
-- Deleting Swarmfront must not cascade through another application's credentials.
CREATE TABLE entap_player_identities (
  id UUID PRIMARY KEY,
  entap_id TEXT NOT NULL UNIQUE CHECK (entap_id ~ '^[A-Z]{3} [0-9]{3}$'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (id, entap_id)
);
INSERT INTO entap_player_identities (id, entap_id, created_at)
  SELECT id, entap_id, created_at FROM rank_players;

-- One identity authority. The game profile's public ID is constrained to it.
-- Existing registration/import writers may create a principal, never overwrite one.
CREATE FUNCTION entap_link_swarmfront_identity() RETURNS trigger AS $$
BEGIN
  INSERT INTO entap_player_identities (id, entap_id, created_at)
    VALUES (NEW.id, NEW.entap_id, NEW.created_at) ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER entap_link_swarmfront_identity BEFORE INSERT ON rank_players
  FOR EACH ROW EXECUTE FUNCTION entap_link_swarmfront_identity();
ALTER TABLE rank_players ADD CONSTRAINT rank_players_entap_identity_fkey
  FOREIGN KEY (id, entap_id) REFERENCES entap_player_identities(id, entap_id) ON DELETE RESTRICT;

ALTER TABLE entap_player_devices ADD COLUMN application_id TEXT NOT NULL DEFAULT 'swarmfront';
ALTER TABLE entap_player_sessions ADD COLUMN application_id TEXT NOT NULL DEFAULT 'swarmfront';
ALTER TABLE entap_device_challenges ADD COLUMN application_id TEXT NOT NULL DEFAULT 'swarmfront';
ALTER TABLE rank_audit_events ADD COLUMN application_id TEXT NOT NULL DEFAULT 'swarmfront';
ALTER TABLE entap_account_deletion_requests ADD COLUMN application_id TEXT NOT NULL DEFAULT 'swarmfront'
  CHECK (application_id = 'swarmfront');

ALTER TABLE entap_player_devices DROP CONSTRAINT entap_player_devices_player_id_fkey;
ALTER TABLE entap_player_devices ADD CONSTRAINT entap_player_devices_player_id_fkey
  FOREIGN KEY (player_id) REFERENCES entap_player_identities(id) ON DELETE CASCADE;
ALTER TABLE entap_player_sessions DROP CONSTRAINT entap_player_sessions_player_id_fkey;
ALTER TABLE entap_player_sessions ADD CONSTRAINT entap_player_sessions_player_id_fkey
  FOREIGN KEY (player_id) REFERENCES entap_player_identities(id) ON DELETE CASCADE;

ALTER TABLE entap_player_devices ADD CONSTRAINT entap_device_application_unique UNIQUE (id, application_id);
ALTER TABLE entap_player_devices ADD CONSTRAINT entap_device_owner_application_unique UNIQUE (id, player_id, application_id);
ALTER TABLE entap_player_sessions ADD CONSTRAINT entap_session_device_application_fkey
  FOREIGN KEY (device_id, player_id, application_id)
  REFERENCES entap_player_devices(id, player_id, application_id) ON DELETE CASCADE;
ALTER TABLE entap_device_challenges ADD CONSTRAINT entap_challenge_device_application_fkey
  FOREIGN KEY (device_id, application_id) REFERENCES entap_player_devices(id, application_id) ON DELETE CASCADE;

CREATE INDEX entap_sessions_application_player_idx ON entap_player_sessions(application_id, player_id);
CREATE INDEX entap_devices_application_player_idx ON entap_player_devices(application_id, player_id);

-- This tombstone suppresses only the game profile, never the ENTaP principal.
CREATE OR REPLACE FUNCTION entap_guard_deleted_identity() RETURNS trigger AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM entap_account_deletion_requests
    WHERE application_id = 'swarmfront'
      AND subject_hash = encode(digest(NEW.id::text, 'sha256'), 'hex')) THEN
    IF TG_OP = 'INSERT' OR NEW.account_status <> 'deletion_pending' THEN
      RAISE EXCEPTION 'account_deletion_pending';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
