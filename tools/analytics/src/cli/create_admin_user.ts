import bcrypt from "bcryptjs";
import { pool } from "../db/pool.js";
import { runMigrations } from "../db/migrate.js";
import { config } from "../config.js";

function arg(name: string): string | null {
  const prefix = `--${name}=`;
  const hit = process.argv.find((item) => item.startsWith(prefix));
  return hit ? hit.slice(prefix.length) : null;
}

async function main(): Promise<void> {
  const username = arg("username") ?? config.adminBootstrapUsername;
  const password = arg("password") ?? config.adminBootstrapPassword;

  if (!username || !password) {
    throw new Error("username/password required. Use --username=... --password=... or ADMIN_BOOTSTRAP_* env vars.");
  }

  await runMigrations(pool);
  const hash = await bcrypt.hash(password, 12);
  await pool.query(
    `
      INSERT INTO admin_users (username, password_hash)
      VALUES ($1, $2)
      ON CONFLICT (username)
      DO UPDATE SET password_hash = EXCLUDED.password_hash, updated_at = now()
    `,
    [username, hash]
  );

  // eslint-disable-next-line no-console
  console.log(`admin user upserted: ${username}`);
}

main()
  .catch((error: unknown) => {
    // eslint-disable-next-line no-console
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await pool.end();
  });
