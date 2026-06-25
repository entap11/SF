ALTER TABLE rank_players DROP CONSTRAINT IF EXISTS chk_rank_players_entap_id_format;
ALTER TABLE rank_players
  ADD CONSTRAINT chk_rank_players_entap_id_format
  CHECK (entap_id ~ '^[A-Z]{3} [0-9]{3}$');

CREATE UNIQUE INDEX IF NOT EXISTS uq_rank_players_call_sign_lower
  ON rank_players (lower(call_sign));
