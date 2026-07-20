import type { Request, Response } from "express";
import { config } from "./config.js";
import { DurableCoreError, type JsonRecord } from "./repositories/durableCore.js";
import { requirePublicRollout } from "./publicModesOpsHttp.js";

let cache: { board: JsonRecord; fetchedAtMs: number; baseAgeSeconds: number } | null = null;

export async function handlePublicRankAction(action: string, req: Request, res: Response): Promise<boolean> {
  if (action !== "get_public_global_rank") return false;
  try { await requirePublicRollout("enable_public_leaderboards", String(req.body?.client_build ?? "").trim()); }
  catch (error) {
    const minimum = error instanceof DurableCoreError && error.code === "minimum_client_build_required";
    res.status(minimum ? 426 : 503).json({ ok: false,
      err: minimum ? "minimum_client_build_required" : "public_leaderboards_disabled" }); return true;
  }
  if (!config.rankServiceUrl) {
    res.status(503).json({ ok: false, err: "public_leaderboard_not_configured" });
    return true;
  }
  const limit = Math.max(1, Math.min(100, integer(req.body?.limit, 25)));
  try {
    const response = await fetch(`${config.rankServiceUrl}/v1/public/leaderboard/global?limit=${limit}`);
    const payload = await response.json() as JsonRecord;
    if (!response.ok || payload.ok !== true || !Array.isArray(record(payload.board).rows)) {
      throw new Error("rank_primary_unavailable");
    }
    const nowMs = Date.now();
    const primary = record(payload.board);
    const primaryAge = Math.max(0, integer(primary.cache_age_seconds, 0));
    if (primaryAge > config.rankLeaderboardMaxStaleSec) throw new Error("rank_primary_snapshot_too_old");
    const normalized = { ...primary, cache_age_seconds: primaryAge,
      stale: primaryAge > 0 || primary.stale === true, source: String(primary.source ?? "rank_primary") };
    cache = { board: normalized, fetchedAtMs: nowMs, baseAgeSeconds: primaryAge };
    res.json({ ok: true, board: normalized });
    return true;
  } catch {
    const ageSeconds = cache
      ? cache.baseAgeSeconds + Math.max(0, Math.floor((Date.now() - cache.fetchedAtMs) / 1_000))
      : Number.MAX_SAFE_INTEGER;
    if (cache && ageSeconds <= config.rankLeaderboardMaxStaleSec) {
      res.json({ ok: true, board: { ...cache.board, cache_age_seconds: ageSeconds, stale: true, source: "vs_cache" } });
      return true;
    }
    res.status(503).json({ ok: false, err: "public_leaderboard_unavailable", cache_age_seconds: cache ? ageSeconds : null });
    return true;
  }
}

export function clearPublicRankCacheForTests(): void { cache = null; }
function record(value: unknown): JsonRecord {
  return typeof value === "object" && value != null && !Array.isArray(value) ? value as JsonRecord : {};
}
function integer(value: unknown, fallback: number): number {
  const parsed = Number(value); return Number.isSafeInteger(parsed) ? parsed : fallback;
}
