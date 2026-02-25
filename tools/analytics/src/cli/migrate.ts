import { pool } from "../db/pool.js";
import { runMigrations } from "../db/migrate.js";

async function main(): Promise<void> {
  try {
    await runMigrations(pool);
  } finally {
    await pool.end();
  }
}

main().catch((error: unknown) => {
  // eslint-disable-next-line no-console
  console.error(error);
  process.exit(1);
});
