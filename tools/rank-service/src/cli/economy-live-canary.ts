import { pool } from "../db/pool.js";
import {
  PlatformEconomyRepository,
  type PlatformCapability
} from "../platformEconomy.js";

const EPOCH = process.env.PLATFORM_BETA_EPOCH?.trim() || "beta_launch_0001";
const ALL_CAPABILITIES: PlatformCapability[] = [
  "NECTAR", "HONEY_EARN", "HONEY_SPEND", "WAX_STANDARD", "WAX_CRUCIBLE"
];

async function main(): Promise<void> {
  const action = String(process.argv[2] ?? "snapshot").trim().toLowerCase();
  const economy = new PlatformEconomyRepository(pool);
  const playerIds = parsePlayerIds();

  if (action === "snapshot") {
    console.log(JSON.stringify(await snapshot(economy, playerIds)));
    return;
  }
  if (action === "reconcile") {
    requireConfirmation("RECONCILE");
    console.log(JSON.stringify({ ok: true, action, report: await economy.reconcile(EPOCH),
      snapshot: await snapshot(economy, playerIds) }));
    return;
  }
  if (action === "disable-all") {
    requireConfirmation("DISABLE_ALL");
    await setExactly(economy, []);
    console.log(JSON.stringify({ ok: true, action, snapshot: await snapshot(economy, playerIds) }));
    return;
  }
  if (action !== "enable") throw new Error("action must be snapshot, reconcile, enable, or disable-all");

  const requested = parseCapabilities();
  requireConfirmation(`ENABLE:${requested.slice().sort().join(",")}`);
  if (playerIds.length !== 2) throw new Error("exactly two PLATFORM_ECONOMY_CANARY_PLAYER_IDS are required");
  const epoch = await economy.getCurrentEpoch();
  if (!epoch || epoch.epoch_id !== EPOCH || epoch.state !== "ACTIVE") throw new Error("active_canary_epoch_required");
  const before = await economy.reconcile(EPOCH);
  if (before.ok !== true) throw new Error("pre_enable_reconciliation_failed");
  await setExactly(economy, requested);
  console.log(JSON.stringify({ ok: true, action, enabled: requested,
    snapshot: await snapshot(economy, playerIds) }));
}

async function setExactly(economy: PlatformEconomyRepository, enabled: PlatformCapability[]): Promise<void> {
  const allow = new Set(enabled);
  for (const capability of ALL_CAPABILITIES) await economy.setCapability(capability, allow.has(capability));
}

async function snapshot(economy: PlatformEconomyRepository, playerIds: string[]) {
  return {
    epoch: await economy.getCurrentEpoch(),
    capabilities: await economy.capabilitySnapshot(),
    reconciliation: await economy.reconcile(EPOCH),
    players: await Promise.all(playerIds.map((playerId) => economy.getPlayerBalances(playerId, EPOCH)))
  };
}

function parseCapabilities(): PlatformCapability[] {
  const raw = String(process.env.PLATFORM_ECONOMY_CANARY_CAPABILITIES ?? "");
  const values = [...new Set(raw.split(",").map((value) => value.trim()).filter(Boolean))];
  if (values.length === 0) throw new Error("PLATFORM_ECONOMY_CANARY_CAPABILITIES is required");
  for (const value of values) {
    if (!ALL_CAPABILITIES.includes(value as PlatformCapability)) throw new Error(`unsupported capability: ${value}`);
    if (value === "WAX_CRUCIBLE") throw new Error("WAX_CRUCIBLE is outside this canary");
  }
  return values as PlatformCapability[];
}

function parsePlayerIds(): string[] {
  const raw = String(process.env.PLATFORM_ECONOMY_CANARY_PLAYER_IDS ?? "");
  const ids = [...new Set(raw.split(",").map((value) => value.trim().toLowerCase()).filter(Boolean))];
  for (const id of ids) {
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(id)) {
      throw new Error("invalid canary player id");
    }
  }
  return ids;
}

function requireConfirmation(operation: string): void {
  const expected = `${EPOCH}:${operation}`;
  if (process.env.PLATFORM_ECONOMY_CANARY_CONFIRM?.trim() !== expected) {
    throw new Error(`PLATFORM_ECONOMY_CANARY_CONFIRM must equal ${expected}`);
  }
}

void main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
}).finally(async () => pool.end());
