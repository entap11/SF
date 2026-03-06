import { Pool } from "pg";
import { config } from "../config.js";

export const pool = new Pool({
  connectionString: config.databaseUrl,
  max: 16,
  idleTimeoutMillis: 30_000
});
