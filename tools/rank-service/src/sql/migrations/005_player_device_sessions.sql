CREATE TABLE IF NOT EXISTS entap_player_devices (
  id UUID PRIMARY KEY DEFAULT rank_uuid_v7(),
  player_id UUID NOT NULL REFERENCES rank_players(id) ON DELETE CASCADE,
  public_key_jwk JSONB NOT NULL,
  public_key_sha256 TEXT NOT NULL UNIQUE,
  platform TEXT NOT NULL DEFAULT 'unknown',
  device_label TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked')),
  registration_request_id TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_authenticated_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_entap_player_devices_player
  ON entap_player_devices (player_id, created_at ASC);

CREATE TABLE IF NOT EXISTS entap_device_challenges (
  id UUID PRIMARY KEY DEFAULT rank_uuid_v7(),
  device_id UUID NOT NULL REFERENCES entap_player_devices(id) ON DELETE CASCADE,
  nonce TEXT NOT NULL,
  request_key TEXT NOT NULL UNIQUE,
  purpose TEXT NOT NULL DEFAULT 'session',
  issued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_entap_device_challenges_device
  ON entap_device_challenges (device_id, issued_at DESC);

CREATE TABLE IF NOT EXISTS entap_player_sessions (
  id UUID PRIMARY KEY DEFAULT rank_uuid_v7(),
  player_id UUID NOT NULL REFERENCES rank_players(id) ON DELETE CASCADE,
  device_id UUID NOT NULL REFERENCES entap_player_devices(id) ON DELETE CASCADE,
  scopes TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  issued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  revoke_reason TEXT NOT NULL DEFAULT ''
);

CREATE INDEX IF NOT EXISTS idx_entap_player_sessions_player
  ON entap_player_sessions (player_id, issued_at DESC);
CREATE INDEX IF NOT EXISTS idx_entap_player_sessions_device
  ON entap_player_sessions (device_id, issued_at DESC);
