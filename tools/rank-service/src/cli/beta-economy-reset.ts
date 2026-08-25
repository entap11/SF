import { config } from "../config.js";
import { pool } from "../db/pool.js";
import { runMigrations } from "../db/migrate.js";
import { PlatformEconomyError, PlatformEconomyRepository } from "../platformEconomy.js";

const EPOCH = process.env.PLATFORM_BETA_EPOCH?.trim() || "beta_launch_0001";
const SEASON = process.env.PLATFORM_BETA_SEASON?.trim() || "BETA_S1";

function enabled(name: string): boolean {
  return ["1", "true", "yes", "on"].includes(String(process.env[name] ?? "").trim().toLowerCase());
}

async function main(): Promise<void> {
  if (!config.economyResetEnabled) throw new Error("RANK_ECONOMY_RESET_ENABLED must be true for this operator process");
  if (config.economyMutationsEnabled) throw new Error("RANK_ECONOMY_MUTATIONS_ENABLED must remain false during reset");
  if (process.env.PLATFORM_BETA_RESET_CONFIRM?.trim() !== EPOCH) {
    throw new Error(`PLATFORM_BETA_RESET_CONFIRM must equal ${EPOCH}`);
  }
  const artifactDigest = String(process.env.PLATFORM_ARTIFACT_DIGEST ?? "").trim().toLowerCase();
  if (!/^[0-9a-f]{64}$/.test(artifactDigest)) throw new Error("PLATFORM_ARTIFACT_DIGEST must be a SHA-256 digest");
  const requiredEvidence = [
    "PLATFORM_PREFLIGHT_NO_ACTIVE_ECONOMIC_MATCHES",
    "PLATFORM_PREFLIGHT_NO_UNRESOLVED_ESCROW",
    "PLATFORM_PREFLIGHT_OUTBOXES_DRAINED",
    "PLATFORM_PREFLIGHT_RECONCILIATION_GREEN",
    "PLATFORM_PREFLIGHT_BACKUP_RESTORABLE",
    "PLATFORM_PREFLIGHT_ARTIFACTS_PINNED"
  ];
  const missing = requiredEvidence.filter((name) => !enabled(name));
  if (missing.length > 0) throw new Error(`reset preflight evidence missing: ${missing.join(",")}`);
  await runMigrations(pool);
  const economy = new PlatformEconomyRepository(pool);
  for (const capability of ["NECTAR", "HONEY_EARN", "HONEY_SPEND", "WAX_STANDARD", "WAX_CRUCIBLE"] as const) {
    await economy.setCapability(capability, false);
  }
  const existing = await pool.query<{ state: string }>(
    "SELECT state FROM platform_economy_epochs WHERE epoch_id = $1", [EPOCH]
  );
  let state = existing.rows[0]?.state ?? "";
  if (!state) {
    await economy.createEpochDraft({ epochId: EPOCH, seasonId: SEASON, artifactDigest,
      openingHoneyCenti: 0, openingWaxMillis: 0, openingNectarMilli: 0 });
    state = "DRAFT";
  }
  if (state === "ABORTED") throw new PlatformEconomyError("epoch_aborted", 409);
  if (state === "DRAFT") {
    await economy.prepareEpoch(EPOCH, {
      mutations_off: true,
      no_active_economic_matches: true,
      no_unresolved_escrow: true,
      outboxes_drained: true,
      reconciliation_green: true,
      backup_restorable: true,
      artifacts_pinned: true
    });
    state = "PREPARED";
  }
  if (state === "PREPARED") {
    await economy.markEpochReconciled(EPOCH);
    state = "RECONCILED";
  }
  if (state === "RECONCILED") {
    await economy.activateEpoch(EPOCH);
    state = "ACTIVE";
  }
  const report = await economy.reconcile(EPOCH);
  if (state !== "ACTIVE" || report.ok !== true) throw new Error(`reset did not finish cleanly: ${JSON.stringify({ state, report })}`);
  console.log(JSON.stringify({ ok: true, epoch_id: EPOCH, season_id: SEASON,
    state, opening_honey_centi: 0, opening_wax_millis: 0, opening_nectar_milli: 0,
    capabilities_enabled: false, reconciliation: report }));
}

void main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
}).finally(async () => pool.end());
