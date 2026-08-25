import type { Request, Response as ExpressResponse } from "express";
import { config } from "./config.js";
import { bearerPlayerToken, PlayerAuthError, verifyPlayerToken } from "./playerAuth.js";
import type { JsonRecord } from "./repositories/durableCore.js";

const ACTIONS = new Set(["get_honey_balance", "debit_honey"]);

export async function handlePlatformEconomyPlayerAction(action: string, req: Request, res: ExpressResponse): Promise<boolean> {
  if (!ACTIONS.has(action)) return false;
  try {
    const token = bearerPlayerToken(req.header("authorization"));
    if (!token) throw new PlayerAuthError("player_token_required", 401);
    const requiredScope = action === "get_honey_balance" ? "economy:read" : "economy:spend";
    const player = verifyPlayerToken(token, {
      issuer: config.playerTokenIssuer, audience: config.playerTokenAudience,
      keyId: config.playerTokenKeyId, publicKeyPem: config.playerTokenPublicKeyPem
    }, requiredScope);
    if (!config.enablePlatformEconomyDelivery || !config.rankServiceUrl) {
      fail(res, "platform_economy_delivery_disabled", 503); return true;
    }
    const suppliedPlayerId = text(req.body?.player_id);
    if (suppliedPlayerId && suppliedPlayerId !== player.playerId) {
      throw new PlayerAuthError("identity_mismatch", 403);
    }
    if (action === "get_honey_balance") {
      const response = await fetch(`${config.rankServiceUrl}/v1/platform/economy/me`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      const body = await safeJson(response);
      if (!response.ok || body.ok !== true) { proxyFailure(res, response.status, body); return true; }
      res.json({ ...body, balance_centi: Number(body.honey_centi ?? 0) });
      return true;
    }
    const actionId = text(req.body?.source).toLowerCase();
    if (!actionId.startsWith("store_sku:") && !actionId.startsWith("analysis_")) {
      fail(res, "catalog_action_required", 400); return true;
    }
    const response = await fetch(`${config.rankServiceUrl}/v1/platform/economy/honey/spend`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
      body: JSON.stringify({ request_id: text(req.body?.idempotency_key), catalog_action_id: actionId })
    });
    const body = await safeJson(response);
    if (!response.ok || body.ok !== true) { proxyFailure(res, response.status, body); return true; }
    res.json(body);
    return true;
  } catch (error) {
    if (error instanceof PlayerAuthError) fail(res, error.code, error.status);
    else fail(res, "platform_economy_proxy_failure", 502);
    return true;
  }
}

function proxyFailure(res: ExpressResponse, status: number, body: JsonRecord): void {
  res.status(status).json({ ok: false, err: text(body.err) || `PLATFORM_HTTP_${status}` });
}
function fail(res: ExpressResponse, err: string, status: number): void { res.status(status).json({ ok: false, err }); }
function text(value: unknown): string { return String(value ?? "").trim(); }
async function safeJson(response: globalThis.Response): Promise<JsonRecord> {
  try {
    const value = await response.json();
    return typeof value === "object" && value != null && !Array.isArray(value) ? value as JsonRecord : {};
  } catch { return {}; }
}
