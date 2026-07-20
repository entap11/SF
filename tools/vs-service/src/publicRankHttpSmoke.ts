import http from "node:http";
import { mkdtempSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

type JsonRecord = Record<string, unknown>;
type ListenableApp = { listen: (port: number, hostname: string, callback: () => void) => http.Server };

function expect(condition: unknown, message: string, details?: unknown): void {
  if (!condition) throw new Error(`${message}${details == null ? "" : `: ${JSON.stringify(details)}`}`);
}
function listen(app: ListenableApp): Promise<http.Server> {
  return new Promise((resolve) => { const server = app.listen(0, "127.0.0.1", () => resolve(server)); });
}
function close(server: http.Server): Promise<void> {
  server.closeAllConnections();
  return new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
}
async function post(base: string): Promise<JsonRecord> {
  const response = await fetch(`${base}/v1/get_public_global_rank`, {
    method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ limit: 10 })
  });
  return { ...await response.json() as JsonRecord, http_status: response.status };
}

async function main(): Promise<void> {
  const tempDir = mkdtempSync(join(tmpdir(), "sf-public-rank-"));
  const generatedAt = new Date().toISOString();
  const rankServer = http.createServer((req, res) => {
    if (req.url?.startsWith("/v1/public/leaderboard/global")) {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ ok: true, board: { region: "GLOBAL", generated_at: generatedAt,
        rows: [{ rank: 1, player_id: "player-a", display_name: "Rank A", wax: 120 }] } }));
      return;
    }
    res.writeHead(404).end();
  });
  await new Promise<void>((resolve) => rankServer.listen(0, "127.0.0.1", resolve));
  const rankAddress = rankServer.address();
  if (rankAddress == null || typeof rankAddress === "string") throw new Error("rank mock address missing");
  process.env.VS_ENABLE_PUBLIC_LEADERBOARDS = "true";
  process.env.VS_RANK_SERVICE_URL = `http://127.0.0.1:${rankAddress.port}`;
  process.env.VS_RANK_LEADERBOARD_MAX_STALE_SEC = "300";
  process.env.CRUCIBLE_LEDGER_PATH = join(tempDir, "crucible.json");
  process.env.HONEY_LEDGER_PATH = join(tempDir, "honey.json");
  const [{ createApp }, rankProxy] = await Promise.all([import("./server.js"), import("./publicRankHttp.js")]);
  const vsServer = await listen(createApp());
  const vsAddress = vsServer.address();
  if (vsAddress == null || typeof vsAddress === "string") throw new Error("VS address missing");
  const base = `http://127.0.0.1:${vsAddress.port}`;
  try {
    const live = await post(base);
    const liveBoard = live.board as JsonRecord;
    expect(live.http_status === 200 && liveBoard.source === "rank_primary"
      && liveBoard.stale === false && liveBoard.cache_age_seconds === 0,
    "live public rank labels are wrong", live);
    await close(rankServer);
    const cached = await post(base);
    const cachedBoard = cached.board as JsonRecord;
    expect(cached.http_status === 200 && cachedBoard.source === "vs_cache" && cachedBoard.stale === true
      && Number(cachedBoard.cache_age_seconds) >= 0,
    "bounded cached rank fallback failed", cached);
    rankProxy.clearPublicRankCacheForTests();
    const unavailable = await post(base);
    expect(unavailable.http_status === 503 && unavailable.err === "public_leaderboard_unavailable"
      && unavailable.cache_age_seconds == null,
    "leaderboard did not fail closed without cache", unavailable);
  } finally {
    if (rankServer.listening) await close(rankServer);
    await close(vsServer);
    rmSync(tempDir, { recursive: true, force: true });
  }
  console.log(JSON.stringify({ ok: true, smoke: "public_rank_proxy", live_primary: true,
    cache_age_labeled: true, bounded_stale_fallback: true, no_local_data_fallback: true }));
}

void main().catch((error) => { console.error(error); process.exitCode = 1; });
