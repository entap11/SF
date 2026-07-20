import type { Request, Response } from "express";
import { config } from "./config.js";
import { DurableCoreError, type JsonRecord } from "./repositories/durableCore.js";
import { getCrucibleSettlementRepository } from "./repositories/durableCoreRuntime.js";

const ACTIONS = new Set([
  "open_public_crucible_escrow", "settle_public_crucible_verified", "refund_public_crucible",
  "reverse_public_crucible_settlement", "set_public_crucible_balance", "get_public_crucible_metrics"
]);

export async function handleCrucibleSettlementAction(action: string, req: Request, res: Response): Promise<boolean> {
  if (!ACTIONS.has(action)) return false;
  try {
    if (!config.durableCoreEnabled || config.durableStore !== "postgres") throw new DurableCoreError("durable_crucible_disabled");
    const repository = getCrucibleSettlementRepository();
    const nowIso = new Date().toISOString();
    if (action === "get_public_crucible_metrics") {
      requireToken(req, config.adminToken, "admin_auth_required");
      ok(res, { metrics: await repository.metrics() }); return true;
    }
    if (action === "set_public_crucible_balance") {
      requireToken(req, config.adminToken, "admin_auth_required");
      ok(res, await repository.setPlayerBalance(text(req.body?.player_id), integer(req.body?.balance_millis),
        requestKey(req), nowIso)); return true;
    }
    if (!config.enableCrucibleWaxSettlement) throw new DurableCoreError("crucible_wax_settlement_disabled");
    if (action === "refund_public_crucible" || action === "reverse_public_crucible_settlement") {
      requireToken(req, config.adminToken, "admin_auth_required");
      const matchId = text(req.body?.match_id); const reason = text(req.body?.reason) || "ops_correction";
      ok(res, action === "refund_public_crucible"
        ? await repository.refund(matchId, reason, requestKey(req), nowIso)
        : await repository.reverseSettlement(matchId, reason, requestKey(req), nowIso));
      return true;
    }
    requireToken(req, config.matchAuthorityToken, "match_authority_required");
    if (!config.enablePublicCrucible) throw new DurableCoreError("public_crucible_disabled");
    if (action === "open_public_crucible_escrow") {
      ok(res, await repository.openEscrow(text(req.body?.match_id), requestKey(req), nowIso)); return true;
    }
    ok(res, await repository.settleVerified(text(req.body?.match_id), text(req.body?.result_id), requestKey(req), nowIso));
    return true;
  } catch (error) {
    if (error instanceof DurableCoreError) fail(res, error.code, status(error.code));
    else throw error;
    return true;
  }
}

function requireToken(req: Request, expected: string, code: string): void {
  const supplied = text(req.header("authorization")).replace(/^Bearer\s+/i, "") || text(req.header("x-admin-token"))
    || text(req.header("x-match-authority-token"));
  if (!expected || supplied !== expected) throw new DurableCoreError(code);
}
function requestKey(req: Request): string {
  const value = text(req.body?.request_id ?? req.body?.idempotency_key);
  if (!value || value.length > 256) throw new DurableCoreError("idempotency_key_required");
  return value;
}
function text(value: unknown): string { return String(value ?? "").trim(); }
function integer(value: unknown): number {
  const parsed = Number(value); if (!Number.isSafeInteger(parsed)) throw new DurableCoreError("integer_required"); return parsed;
}
function status(code: string): number {
  if (code.endsWith("_required")) return 401;
  if (code.includes("disabled")) return 503;
  if (code.includes("not_found")) return 404;
  if (code.includes("already") || code.includes("not_open") || code.startsWith("idempotency_")) return 409;
  if (code === "insufficient_wax") return 402;
  return 400;
}
function ok(res: Response, body: JsonRecord): void { res.json({ ok: true, server_unix_ms: Date.now(), ...body }); }
function fail(res: Response, err: string, code: number): void { res.status(code).json({ ok: false, err }); }
