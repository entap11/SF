import { Pool } from "pg";
import { config } from "../config.js";

export const durablePool = new Pool({
  connectionString: config.databaseUrl,
  max: config.databasePoolMax,
  idleTimeoutMillis: 30_000
});
