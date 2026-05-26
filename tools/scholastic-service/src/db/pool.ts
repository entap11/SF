import { Pool } from "pg";
import { config } from "../config.js";

export const pool = new Pool({
  connectionString: config.databaseUrl,
  max: 12,
  idleTimeoutMillis: 30_000
});
