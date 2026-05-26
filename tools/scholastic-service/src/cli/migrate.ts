import { pool } from "../db/pool.js";
import { runMigrations } from "../db/migrate.js";

await runMigrations(pool);
await pool.end();
