import { pool } from "../db/pool.js";
import { runMigrations } from "../db/migrate.js";
async function main() {
    try {
        await runMigrations(pool);
    }
    finally {
        await pool.end();
    }
}
main().catch((error) => {
    // eslint-disable-next-line no-console
    console.error(error);
    process.exit(1);
});
