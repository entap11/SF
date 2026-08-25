import type { Request, Response } from "express";
import { config } from "./config.js";
import { DurableCoreError, type JsonRecord } from "./repositories/durableCore.js";
import { getCrucibleSettlementRepository } from "./repositories/durableCoreRuntime.js";
import { requirePublicRollout } from "./publicModesOpsHttp.js";

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
    // The VS ledger is retained for historical reconciliation only. Platform is the
    // sole Wax writer; no deployment flag or admin token may reactivate this path.
    throw new DurableCoreError("platform_wax_authority_required");
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
  if (code === "platform_wax_authority_required") return 410;
  if (code.includes("not_found")) return 404;
  if (code.includes("already") || code.includes("not_open") || code.startsWith("idempotency_")) return 409;
  if (code === "insufficient_wax") return 402;
  return 400;
}
function ok(res: Response, body: JsonRecord): void { res.json({ ok: true, server_unix_ms: Date.now(), ...body }); }
function fail(res: Response, err: string, code: number): void { res.status(code).json({ ok: false, err }); }
