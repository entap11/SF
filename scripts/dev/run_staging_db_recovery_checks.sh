#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: CERT_DATABASE_URL=<secret> $0 <before|migrated|restored|recovered>"
}

stage="${1:-}"
case "${stage}" in
  before|migrated|restored|recovered) ;;
  *) usage; exit 2 ;;
esac

if [[ -z "${CERT_DATABASE_URL:-}" ]]; then
  echo "STAGING_DB_CHECK_FAIL reason=CERT_DATABASE_URL_missing"
  exit 2
fi

psql_bin="${PSQL_BIN:-$(command -v psql || true)}"
if [[ -z "${psql_bin}" && -x /usr/local/opt/libpq/bin/psql ]]; then
  psql_bin=/usr/local/opt/libpq/bin/psql
elif [[ -z "${psql_bin}" && -x /opt/homebrew/opt/libpq/bin/psql ]]; then
  psql_bin=/opt/homebrew/opt/libpq/bin/psql
fi
if [[ -z "${psql_bin}" ]]; then
  echo "STAGING_DB_CHECK_FAIL reason=psql_missing"
  exit 2
fi

psql_cmd=("${psql_bin}" --no-psqlrc --set ON_ERROR_STOP=1 --dbname "${CERT_DATABASE_URL}")
server_version="$("${psql_cmd[@]}" --tuples-only --no-align --command "SHOW server_version;")"
schema_material="$("${psql_cmd[@]}" --tuples-only --no-align --field-separator '|' <<'SQL'
WITH material AS (
  SELECT 'column' AS kind,
         table_schema AS object_schema,
         table_name AS object_name,
         ordinal_position::text || ':' || column_name || ':' || data_type || ':' ||
           is_nullable || ':' || COALESCE(column_default, '') AS definition
  FROM information_schema.columns
  WHERE table_schema = 'public'
  UNION ALL
  SELECT 'constraint', n.nspname, c.relname, con.conname || ':' || pg_get_constraintdef(con.oid, true)
  FROM pg_constraint con
  JOIN pg_class c ON c.oid = con.conrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
  UNION ALL
  SELECT 'index', schemaname, tablename, indexname || ':' || indexdef
  FROM pg_indexes
  WHERE schemaname = 'public'
)
SELECT kind, object_schema, object_name, definition
FROM material
ORDER BY kind, object_schema, object_name, definition;
SQL
)"
schema_sha256="$(printf '%s\n' "${schema_material}" | shasum -a 256 | awk '{print $1}')"

echo "STAGING_DB_CHECK stage=${stage} server_version=${server_version//[[:space:]]/}"
echo "STAGING_DB_SCHEMA stage=${stage} sha256=${schema_sha256}"
echo "STAGING_DB_MIGRATIONS_BEGIN stage=${stage}"
"${psql_cmd[@]}" --tuples-only --no-align <<'SQL'
SELECT 'SELECT filename FROM schema_migrations ORDER BY filename;'
WHERE to_regclass('public.schema_migrations') IS NOT NULL
\gexec
SQL
echo "STAGING_DB_MIGRATIONS_END stage=${stage}"

echo "STAGING_DB_COUNTS_BEGIN stage=${stage}"
"${psql_cmd[@]}" --tuples-only --no-align --field-separator '|' <<'SQL'
SELECT format(
  'SELECT %L, count(*) FROM %I.%I;',
  table_name,
  table_schema,
  table_name
)
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
ORDER BY table_name
\gexec
SQL
echo "STAGING_DB_COUNTS_END stage=${stage}"
echo "STAGING_DB_CHECK_PASS stage=${stage}"
