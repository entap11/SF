import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { Pool } from "pg";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const MIGRATIONS_DIR_CANDIDATES = [
  path.resolve(__dirname, "../sql/migrations"),
  path.resolve(__dirname, "../../src/sql/migrations")
];

async function ensureMigrationsTable(pool: Pool): Promise<void> {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id BIGSERIAL PRIMARY KEY,
      filename TEXT NOT NULL UNIQUE,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
}

export async function runMigrations(pool: Pool): Promise<void> {
  await ensureMigrationsTable(pool);

  const migrationsDir = await resolveMigrationsDir();
  const migrationFiles = (await readdir(migrationsDir))
    .filter((name) => name.endsWith(".sql"))
    .sort((a, b) => a.localeCompare(b));

  for (const filename of migrationFiles) {
    const existing = await pool.query<{ filename: string }>(
      "SELECT filename FROM schema_migrations WHERE filename = $1",
      [filename]
    );
    if ((existing.rowCount ?? 0) > 0) {
      continue;
    }

    const fullPath = path.join(migrationsDir, filename);
    const sql = await readFile(fullPath, "utf8");
    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      await client.query(sql);
      await client.query("INSERT INTO schema_migrations (filename) VALUES ($1)", [filename]);
      await client.query("COMMIT");
      // eslint-disable-next-line no-console
      console.log(`applied migration: ${filename}`);
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  }
}

async function resolveMigrationsDir(): Promise<string> {
  for (const candidate of MIGRATIONS_DIR_CANDIDATES) {
    try {
      const entries = await readdir(candidate);
      if (entries.length >= 0) {
        return candidate;
      }
    } catch {
      continue;
    }
  }
  throw new Error("rank-service migrations directory not found");
}
