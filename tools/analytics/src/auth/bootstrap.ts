import bcrypt from "bcryptjs";
import { config } from "../config.js";
import { pool } from "../db/pool.js";

export async function bootstrapAdminUserIfConfigured(): Promise<void> {
  const username = config.adminBootstrapUsername.trim();
  const password = config.adminBootstrapPassword.trim();
  if (!username || !password) {
    return;
  }

  const hash = await bcrypt.hash(password, 12);
  await pool.query(
    `
      INSERT INTO admin_users (username, password_hash)
      VALUES ($1, $2)
      ON CONFLICT (username)
      DO NOTHING
    `,
    [username, hash]
  );
}
