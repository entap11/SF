import { durablePool } from "./pool.js";
import { runMigrations } from "./migrate.js";

async function main(): Promise<void> {
  await runMigrations(durablePool);
  await durablePool.end();
}

void main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
