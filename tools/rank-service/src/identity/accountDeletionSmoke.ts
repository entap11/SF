import assert from "node:assert/strict";
import crypto from "node:crypto";
import type { Pool } from "pg";
import express from "express";
import { PGlite } from "@electric-sql/pglite";
import { pgcrypto } from "@electric-sql/pglite/contrib/pgcrypto";
import { PGlitePoolAdapter } from "./embeddedPool.js";
import { runMigrations } from "../db/migrate.js";
import { AccountDeletionStore, DELETION_DOMAINS } from "./accountDeletion.js";
import { installAccountDeletionRoutes } from "./accountDeletionHttp.js";
import { IdentitySessionStore } from "./sessionStore.js";
import { signPlayerAccessToken, verifyPlayerAccessToken, type PlayerTokenKeyConfig } from "./playerToken.js";
import { RankStore } from "../store.js";

async function main(): Promise<void> {
  const db = new PGlite({ extensions: { pgcrypto } });
  await db.waitReady;
  const pool = new PGlitePoolAdapter(db) as unknown as Pool;
  await runMigrations(pool);
  const issuer = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const tokenConfig: PlayerTokenKeyConfig = {
    issuer: "deletion-smoke", audience: "swarmfront-smoke", keyId: "test-key", accessTokenTtlSec: 600,
    privateKeyPem: issuer.privateKey.export({ format: "pem", type: "pkcs8" }).toString(),
    publicKeyPem: issuer.publicKey.export({ format: "pem", type: "spki" }).toString()
  };
  const identity = new IdentitySessionStore(pool, tokenConfig, 300);
  const deletion = new AccountDeletionStore(pool, true);
  const device = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const sign = (message: unknown): string => crypto.sign("sha256", Buffer.from(String(message)), {
    key: device.privateKey, dsaEncoding: "ieee-p1363"
  }).toString("base64url");
  const registered = await identity.registerIdentityAndDevice({ requestId: "register-deletion-smoke",
    callSign: "DeleteSmoke", region: "TEST", publicKeyJwk: device.publicKey.export({ format: "jwk" }),
    platform: "smoke", deviceLabel: "test", installMetadata: {} });
  const session = await identity.createSession(String(registered.challenge.id), sign(registered.challenge.challenge));
  const token = String(session.access_token);
  const claims = verifyPlayerAccessToken(token, tokenConfig);
  await deletion.assertActiveSession(claims);

  // Same ENTaP principal, independent application credentials and permissions.
  const entapKey = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const entapDevice = (await pool.query(`INSERT INTO entap_player_devices
    (player_id, public_key_jwk, public_key_sha256, registration_request_id, application_id)
    VALUES ($1, $2::jsonb, $3, 'entap-device-test', 'entap') RETURNING id::text`,
  [registered.player.id, JSON.stringify(entapKey.publicKey.export({ format: "jwk" })), "entap-key-test"])).rows[0].id;
  const entapSession = (await pool.query(`INSERT INTO entap_player_sessions
    (player_id, device_id, scopes, expires_at, application_id)
    VALUES ($1, $2, ARRAY['entap:profile'], now() + interval '1 hour', 'entap') RETURNING id::text`,
  [registered.player.id, entapDevice])).rows[0].id;
  const entapChallenge = (await pool.query(`INSERT INTO entap_device_challenges
    (device_id, nonce, request_key, expires_at, application_id)
    VALUES ($1, 'entap-nonce', 'entap-proof-test', now() + interval '5 minutes', 'entap') RETURNING id::text`,
  [entapDevice])).rows[0].id;
  await pool.query(`INSERT INTO rank_audit_events (event_type, player_id, payload, application_id)
    VALUES ('entap_login', $1, $2::jsonb, 'entap')`, [registered.player.id, JSON.stringify({ player_id: registered.player.id })]);
  const otherAppSnapshot = async () => (await pool.query(`SELECT jsonb_build_object(
    'identity', (SELECT to_jsonb(p) FROM entap_player_identities p WHERE id = $1),
    'devices', (SELECT jsonb_agg(to_jsonb(d)) FROM entap_player_devices d WHERE application_id = 'entap'),
    'sessions', (SELECT jsonb_agg(to_jsonb(s)) FROM entap_player_sessions s WHERE application_id = 'entap'),
    'challenges', (SELECT jsonb_agg(to_jsonb(c)) FROM entap_device_challenges c WHERE application_id = 'entap'),
    'audit', (SELECT jsonb_agg(to_jsonb(a)) FROM rank_audit_events a WHERE application_id = 'entap')
  ) AS snapshot`, [registered.player.id])).rows[0].snapshot;
  const entapBefore = await otherAppSnapshot();
  const wrongApplication = signPlayerAccessToken({ playerId: registered.player.id, sessionId: entapSession,
    deviceId: entapDevice, scopes: ["match:queue"] }, tokenConfig);
  await assert.rejects(deletion.assertActiveSession(wrongApplication.claims), /account_or_session_inactive/);
  await assert.rejects(identity.issueChallenge(entapDevice, "wrong-app-issue"), /device_not_found/);
  await assert.rejects(identity.createSession(entapChallenge, "irrelevant"), /challenge_not_found/);
  assert.equal(await identity.revokeSession(entapSession, registered.player.id, "wrong-app"), false);
  await assert.rejects(pool.query(`INSERT INTO entap_player_sessions
    (player_id, device_id, scopes, expires_at, application_id)
    VALUES ($1, $2, ARRAY['match:queue'], now() + interval '1 hour', 'swarmfront')`,
  [registered.player.id, entapDevice]), /entap_session_device_application_fkey/);

  const app = express();
  app.use(express.json());
  installAccountDeletionRoutes(app, deletion, tokenConfig);
  const server = app.listen(0, "127.0.0.1");
  await new Promise<void>(resolve => server.once("listening", resolve));
  const address = server.address() as { port: number };
  const post = async (path: string, body: unknown, auth = "") => {
    const response = await fetch(`http://127.0.0.1:${address.port}/v1/${path}`, { method: "POST",
      headers: { "Content-Type": "application/json", ...(auth ? { Authorization: `Bearer ${auth}` } : {}) },
      body: JSON.stringify(body) });
    return { status: response.status, body: await response.json() as Record<string, unknown> };
  };
  try {
    const requestId = "delete-smoke-0001";
    const receiptToken = crypto.randomBytes(32).toString("base64url");
    const receipt = { request_id: requestId, receipt_token: receiptToken };
    await assert.rejects(new AccountDeletionStore(pool).challenge(claims, requestId, receiptToken), /deletion_requests_not_enabled/);
    assert.equal((await post("account/deletion/challenge", receipt)).status, 401);
    assert.equal((await post("account/deletion/challenge", receipt, wrongApplication.token)).status, 403);
    const challenge = await post("account/deletion/challenge", receipt, token);
    assert.equal(challenge.status, 200);
    assert.equal((await post("account/deletion/confirm", { ...receipt, confirmation: "DELETE", signature: "bad" })).status, 401);
    assert.equal((await post("account/deletion/confirm", { ...receipt, signature: sign(challenge.body.challenge) })).status, 400);
    const confirmed = await post("account/deletion/confirm", {
      ...receipt, confirmation: "DELETE", signature: sign(challenge.body.challenge)
    });
    assert.equal(confirmed.status, 202);
    assert.equal(confirmed.body.status, "pending");
    assert.equal(confirmed.body.application_id, "swarmfront");
    assert.deepEqual(await otherAppSnapshot(), entapBefore, "request must not revoke ENTaP access");
    assert.equal((await post("identity/session/status", {}, token)).status, 403);
    await assert.rejects(identity.issueChallenge(registered.device.id, "after-delete-0001"), /account_deletion_pending/);
    const rank = new RankStore(pool, "/nonexistent-deletion-test.json");
    assert.deepEqual(await rank.read(state => Object.keys(state.players_by_id)), []);
    // A lost confirmation response can be retried after Swarmfront revocation and service restart.
    const restarted = new AccountDeletionStore(pool);
    assert.equal((await restarted.confirm(requestId, receiptToken, "")).status, "pending");
    assert.equal((await post("account/deletion/status", {
      ...receipt, receipt_token: crypto.randomBytes(32).toString("base64url")
    })).status, 404);
    await assert.rejects(deletion.complete(requestId), /deletion_fulfillment_incomplete/);
    assert.equal((await post(`admin/account-deletions/${requestId}/complete`, {}, token)).status, 503);
    for (const domain of DELETION_DOMAINS.filter(item => item !== "identity")) {
      await deletion.recordFulfillment(requestId, domain, `smoke:${domain}:purged`, []);
    }
    // Residual ledger ownership must prevent a false "complete", even with operator receipts.
    await pool.query(`INSERT INTO platform_economy_accounts
      (account_id, epoch_id, asset, account_type, owner_id) VALUES ('smoke-owned-account',
      'legacy-pre-platform', 'HONEY_CENTI', 'PLAYER', $1)`, [registered.player.id]);
    await assert.rejects(deletion.complete(requestId), /retained_records_require_review/);
    assert.equal((await deletion.status(requestId, receiptToken)).status, "pending");
    // Roll back only the test fixture, without weakening any production ledger trigger.
    await pool.query("BEGIN");
    await pool.query("ALTER TABLE platform_economy_accounts DISABLE TRIGGER platform_economy_accounts_no_delete");
    await pool.query("DELETE FROM platform_economy_accounts WHERE account_id = 'smoke-owned-account'");
    await pool.query("ALTER TABLE platform_economy_accounts ENABLE TRIGGER platform_economy_accounts_no_delete");
    await pool.query("COMMIT");
    const completed = await deletion.complete(requestId);
    assert.equal(completed.status, "completed");
    assert.equal((await deletion.complete(requestId)).status, "completed");
    assert.equal((await pool.query("SELECT count(*)::int AS count FROM rank_players")).rows[0].count, 0);
    for (const table of ["entap_player_devices", "entap_player_sessions", "entap_device_challenges"]) {
      assert.equal((await pool.query(`SELECT count(*)::int AS count FROM ${table} WHERE application_id = 'swarmfront'`)).rows[0].count, 0, table);
    }
    assert.deepEqual(await otherAppSnapshot(), entapBefore, "completion must preserve ENTaP identity, keys, sessions, permissions and evidence");
    assert.equal((await pool.query(`SELECT count(*)::int AS count FROM rank_audit_events
      WHERE application_id = 'swarmfront' AND (player_id = $1 OR related_player_id = $1 OR strpos(payload::text, $1) > 0)`,
    [registered.player.id])).rows[0].count, 0);
    assert.equal((await deletion.status(requestId, receiptToken)).status, "completed");
    assert.equal((await pool.query("SELECT player_id FROM entap_account_deletion_requests")).rows[0].player_id, null);
    await assert.rejects(pool.query(`INSERT INTO rank_players
      (id, entap_id, call_sign, region, wax_score, last_active_unix, tier_id, color_id)
      VALUES ($1, 'ZZZ 999', 'Resurrection', 'TEST', 0, 0, 'DRONE', 'GREEN')`, [registered.player.id]), /account_deletion_pending/);
    const second = await identity.registerIdentityAndDevice({ requestId: "support-register-smoke",
      callSign: "SupportSmoke", region: "TEST", publicKeyJwk: device.publicKey.export({ format: "jwk" }),
      platform: "smoke", deviceLabel: "test", installMetadata: {} });
    process.env.ENTAP_DELETION_OPERATOR_TOKEN = crypto.randomBytes(32).toString("base64url");
    const operator = process.env.ENTAP_DELETION_OPERATOR_TOKEN;
    const supportRequest = { request_id: "support-delete-smoke", receipt_token: crypto.randomBytes(32).toString("base64url"),
      player_id: second.player.id, verification_evidence_ref: "test-case:verified-owner", owner_confirmed: false };
    assert.equal((await post("admin/account-deletions/verified-request", supportRequest, token)).status, 401);
    assert.equal((await post("admin/account-deletions/verified-request", supportRequest, operator)).status, 400);
    assert.equal((await post("admin/account-deletions/verified-request", { ...supportRequest, owner_confirmed: true }, operator)).status, 202);
    assert.equal((await deletion.status(supportRequest.request_id, supportRequest.receipt_token)).status, "pending");
    await assert.rejects(deletion.recordFulfillment(supportRequest.request_id, "backups", "test-case:backups", [
      { category: "backup", reason: "Normal backup expiration", expires_at: "2020-01-01T00:00:00Z" }
    ]), /invalid_fulfillment_evidence/);
    delete process.env.ENTAP_DELETION_OPERATOR_TOKEN;
    console.log(JSON.stringify({ ok: true, smoke: "account_deletion", checks: [
      "device-proof", "http-authorization", "explicit-confirmation", "revocation", "public-rank-removal",
      "private-status", "lost-response-retry", "fulfillment-gate", "financial-review-gate", "purge", "anti-resurrection", "verified-support-intake",
      "entap-preserved", "cross-app-authorization-denied", "credential-application-foreign-keys"
    ] }));
  } finally {
    await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
    await db.close();
  }
}
void main().catch(error => { console.error(error); process.exitCode = 1; });
