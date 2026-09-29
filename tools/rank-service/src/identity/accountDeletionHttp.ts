import crypto from "node:crypto";
import type { Express, NextFunction, Request, Response } from "express";
import { AccountDeletionStore, type Retention } from "./accountDeletion.js";
import { bearerTokenFromHeader, PlayerTokenError, verifyPlayerAccessToken, type PlayerTokenKeyConfig } from "./playerToken.js";
import { IdentitySessionError } from "./sessionStore.js";

export function installAccountDeletionRoutes(app: Express, store: AccountDeletionStore,
  tokenConfig: PlayerTokenKeyConfig): void {
  const route = (fn: (req: Request, res: Response) => Promise<void>) =>
    (req: Request, res: Response, next: NextFunction): void => {
      res.setHeader("Cache-Control", "no-store");
      void fn(req, res).catch(error => {
        if (error instanceof IdentitySessionError) res.status(error.status).json({ ok: false, err: error.code });
        else if (error instanceof PlayerTokenError) res.status(401).json({ ok: false, err: error.code });
        else {
          console.error(JSON.stringify({ event: "account_deletion_failed", code: String((error as { code?: unknown })?.code || "internal") }));
          res.status(500).json({ ok: false, err: "deletion_service_unavailable" });
        }
      });
    };
  const value = (input: unknown): string => typeof input === "string" ? input.trim() : "";
  const operator = (req: Request): void => {
    const expected = process.env.ENTAP_DELETION_OPERATOR_TOKEN?.trim() || "";
    const provided = bearerTokenFromHeader(req.header("authorization"));
    if (expected.length < 32) throw new IdentitySessionError("deletion_operator_not_configured", 503);
    if (provided.length !== expected.length || !crypto.timingSafeEqual(Buffer.from(provided), Buffer.from(expected))) {
      throw new IdentitySessionError("unauthorized", 401);
    }
  };

  app.post("/v1/identity/session/status", route(async (req, res) => {
    const claims = verifyPlayerAccessToken(bearerTokenFromHeader(req.header("authorization")), tokenConfig);
    await store.assertActiveSession(claims);
    res.json({ ok: true, active: true });
  }));
  app.post("/v1/account/deletion/challenge", route(async (req, res) => {
    const claims = verifyPlayerAccessToken(bearerTokenFromHeader(req.header("authorization")), tokenConfig);
    res.json({ ok: true, ...await store.challenge(claims, value(req.body?.request_id), value(req.body?.receipt_token)) });
  }));
  app.post("/v1/account/deletion/confirm", route(async (req, res) => {
    if (req.body?.confirmation !== "DELETE") throw new IdentitySessionError("deletion_confirmation_required");
    const receipt = await store.confirm(value(req.body?.request_id), value(req.body?.receipt_token), value(req.body?.signature));
    res.status(receipt.status === "completed" ? 200 : 202).json({ ok: true, ...receipt });
  }));
  app.post("/v1/account/deletion/status", route(async (req, res) => {
    res.json({ ok: true, ...await store.status(value(req.body?.request_id), value(req.body?.receipt_token)) });
  }));
  app.get("/v1/admin/account-deletions", route(async (req, res) => {
    operator(req);
    res.json({ ok: true, requests: await store.pending() });
  }));
  app.post("/v1/admin/account-deletions/verified-request", route(async (req, res) => {
    operator(req);
    if (req.body?.owner_confirmed !== true) throw new IdentitySessionError("deletion_confirmation_required");
    res.status(202).json({ ok: true, ...await store.acceptVerifiedSupportRequest({
      requestId: value(req.body?.request_id), receiptToken: value(req.body?.receipt_token),
      playerId: value(req.body?.player_id), verificationEvidenceRef: value(req.body?.verification_evidence_ref)
    }) });
  }));
  app.post("/v1/admin/account-deletions/:requestId/fulfillment", route(async (req, res) => {
    operator(req);
    await store.recordFulfillment(value(req.params.requestId), value(req.body?.domain),
      value(req.body?.evidence_ref), req.body?.retention as Retention[]);
    res.json({ ok: true });
  }));
  app.post("/v1/admin/account-deletions/:requestId/complete", route(async (req, res) => {
    operator(req);
    res.json({ ok: true, ...await store.complete(value(req.params.requestId)) });
  }));
}
