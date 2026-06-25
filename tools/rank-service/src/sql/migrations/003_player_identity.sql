CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION rank_uuid_v7() RETURNS uuid AS $$
DECLARE
  unix_ms bigint;
  rand bytea;
  bytes bytea;
BEGIN
  unix_ms := floor(extract(epoch from clock_timestamp()) * 1000)::bigint;
  rand := gen_random_bytes(10);
  bytes := decode(lpad(to_hex(unix_ms), 12, '0'), 'hex') || rand;
  bytes := set_byte(bytes, 6, (get_byte(bytes, 6) & 15) | 112);
  bytes := set_byte(bytes, 8, (get_byte(bytes, 8) & 63) | 128);
  RETURN encode(bytes, 'hex')::uuid;
END;
$$ LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE FUNCTION rank_entap_id_from_sequence(seq bigint) RETURNS text AS $$
DECLARE
  safe_seq bigint;
  letters bigint;
  digits bigint;
  a int;
  b int;
  c int;
BEGIN
  safe_seq := greatest(0, least(seq, (26 * 26 * 26 * 1000) - 1));
  letters := safe_seq / 1000;
  digits := safe_seq % 1000;
  a := letters / (26 * 26);
  b := (letters / 26) % 26;
  c := letters % 26;
  RETURN chr(65 + a) || chr(65 + b) || chr(65 + c) || ' ' || lpad(digits::text, 3, '0');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE SEQUENCE IF NOT EXISTS rank_entap_id_seq START WITH 0 MINVALUE 0;

ALTER TABLE rank_players ADD COLUMN IF NOT EXISTS player_id text;
ALTER TABLE rank_players ADD COLUMN IF NOT EXISTS display_name text;
ALTER TABLE rank_players ADD COLUMN IF NOT EXISTS id uuid;
ALTER TABLE rank_players ADD COLUMN IF NOT EXISTS entap_id text;
ALTER TABLE rank_players ADD COLUMN IF NOT EXISTS call_sign text;

UPDATE rank_players
SET id = rank_uuid_v7()
WHERE id IS NULL;

WITH numbered AS (
  SELECT ctid, row_number() OVER (ORDER BY created_at ASC, COALESCE(player_id, id::text) ASC) - 1 AS seq
  FROM rank_players
  WHERE entap_id IS NULL OR entap_id !~ '^[A-Z]{3} [0-9]{3}$'
)
UPDATE rank_players p
SET entap_id = rank_entap_id_from_sequence(numbered.seq)
FROM numbered
WHERE p.ctid = numbered.ctid;

UPDATE rank_players
SET call_sign = regexp_replace(COALESCE(NULLIF(display_name, ''), 'Player_' || replace(entap_id, ' ', '_')), '[^A-Za-z0-9_]', '_', 'g')
WHERE call_sign IS NULL OR call_sign = '';

WITH normalized AS (
  SELECT
    ctid,
    CASE
      WHEN length(call_sign) < 3 THEN call_sign || repeat('_', 3 - length(call_sign))
      WHEN length(call_sign) > 16 THEN left(call_sign, 16)
      ELSE call_sign
    END AS base_call_sign
  FROM rank_players
),
deduped AS (
  SELECT ctid, base_call_sign,
    row_number() OVER (PARTITION BY lower(base_call_sign) ORDER BY ctid) AS dup_index
  FROM normalized
)
UPDATE rank_players p
SET call_sign = CASE
  WHEN deduped.dup_index = 1 THEN deduped.base_call_sign
  ELSE left(deduped.base_call_sign, greatest(3, 16 - length(deduped.dup_index::text) - 1)) || '_' || deduped.dup_index::text
END
FROM deduped
WHERE p.ctid = deduped.ctid;

ALTER TABLE rank_players ALTER COLUMN id SET NOT NULL;
ALTER TABLE rank_players ALTER COLUMN entap_id SET NOT NULL;
ALTER TABLE rank_players ALTER COLUMN call_sign SET NOT NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE table_name = 'rank_players'
      AND constraint_type = 'PRIMARY KEY'
      AND constraint_name <> 'rank_players_pkey'
  ) THEN
    NULL;
  END IF;
END $$;

ALTER TABLE rank_players DROP CONSTRAINT IF EXISTS rank_players_pkey;
ALTER TABLE rank_players ADD CONSTRAINT rank_players_pkey PRIMARY KEY (id);
ALTER TABLE rank_players DROP CONSTRAINT IF EXISTS uq_rank_players_entap_id;
ALTER TABLE rank_players ADD CONSTRAINT uq_rank_players_entap_id UNIQUE (entap_id);
ALTER TABLE rank_players DROP CONSTRAINT IF EXISTS uq_rank_players_call_sign;
ALTER TABLE rank_players ADD CONSTRAINT uq_rank_players_call_sign UNIQUE (call_sign);
ALTER TABLE rank_players DROP CONSTRAINT IF EXISTS chk_rank_players_entap_id_format;
ALTER TABLE rank_players ADD CONSTRAINT chk_rank_players_entap_id_format CHECK (entap_id ~ '^[A-Z]{3} [0-9]{3}$');
ALTER TABLE rank_players DROP CONSTRAINT IF EXISTS chk_rank_players_call_sign_format;
ALTER TABLE rank_players ADD CONSTRAINT chk_rank_players_call_sign_format CHECK (call_sign ~ '^[A-Za-z0-9_]{3,16}$');

DROP INDEX IF EXISTS idx_rank_players_wax_desc;
CREATE INDEX IF NOT EXISTS idx_rank_players_wax_desc ON rank_players (wax_score DESC, id ASC);
CREATE INDEX IF NOT EXISTS idx_rank_players_rank_position ON rank_players (rank_position ASC);
CREATE INDEX IF NOT EXISTS idx_rank_players_region_rank ON rank_players (region, rank_position ASC);
CREATE INDEX IF NOT EXISTS idx_rank_players_entap_id ON rank_players (entap_id ASC);
CREATE INDEX IF NOT EXISTS idx_rank_players_call_sign ON rank_players (call_sign ASC);

SELECT setval(
  'rank_entap_id_seq',
  greatest(
    0,
    (
      SELECT COALESCE(MAX(
        (((ascii(substr(entap_id, 1, 1)) - 65) * 26 * 26)
        + ((ascii(substr(entap_id, 2, 1)) - 65) * 26)
        + (ascii(substr(entap_id, 3, 1)) - 65)) * 1000
        + substr(entap_id, 5, 3)::int
      ), -1) + 1
      FROM rank_players
    )
  ),
  false
);
