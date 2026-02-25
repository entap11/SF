import { pool } from "../db/pool.js";
import { runMigrations } from "../db/migrate.js";
import { computeRollupsForDate, computeRollupsForRange } from "../rollups/compute.js";
import { parseDateStrict } from "../util/date.js";

function arg(name: string): string | null {
  const prefix = `--${name}=`;
  const hit = process.argv.find((item) => item.startsWith(prefix));
  return hit ? hit.slice(prefix.length) : null;
}

async function main(): Promise<void> {
  await runMigrations(pool);

  const date = arg("date");
  const start = arg("start");
  const end = arg("end");

  if (date) {
    parseDateStrict(date);
    await computeRollupsForDate(pool, date);
    // eslint-disable-next-line no-console
    console.log(`rollup complete for ${date}`);
    return;
  }

  if (start && end) {
    parseDateStrict(start);
    parseDateStrict(end);
    if (start > end) {
      throw new Error("start must be <= end");
    }
    await computeRollupsForRange(pool, start, end);
    // eslint-disable-next-line no-console
    console.log(`rollup complete for range ${start}..${end}`);
    return;
  }

  throw new Error("Provide --date=YYYY-MM-DD or --start=YYYY-MM-DD --end=YYYY-MM-DD");
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
