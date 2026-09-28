import assert from "node:assert/strict";
import crypto from "node:crypto";
import { gzipSync } from "node:zlib";
import express from "express";
import type { Pool } from "pg";
import { PGlite } from "@electric-sql/pglite";
import { pgcrypto } from "@electric-sql/pglite/contrib/pgcrypto";
import { PGlitePoolAdapter } from "./identity/embeddedPool.js";
import { runMigrations } from "./db/migrate.js";
import { IdentitySessionStore } from "./identity/sessionStore.js";
import { type PlayerTokenKeyConfig } from "./identity/playerToken.js";
import { installBetaCaptureRoutes, participantKey, decodeCapture } from "./betaCapture.js";

const db = new PGlite({ extensions: { pgcrypto } });
await db.waitReady;
const pool = new PGlitePoolAdapter(db) as unknown as Pool;
await runMigrations(pool);
const keys = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
const config: PlayerTokenKeyConfig = { issuer: "beta-smoke", audience: "swarmfront-smoke", keyId: "test", accessTokenTtlSec: 600,
  privateKeyPem: keys.privateKey.export({ format: "pem", type: "pkcs8" }).toString(),
  publicKeyPem: keys.publicKey.export({ format: "pem", type: "spki" }).toString() };
const identity = new IdentitySessionStore(pool, config, 300);
const device = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
const registration = await identity.registerIdentityAndDevice({ requestId: "register-beta-smoke", callSign: "BetaSmoke", region: "TEST",
  publicKeyJwk: device.publicKey.export({ format: "jwk" }), platform: "smoke", deviceLabel: "test", installMetadata: {} });
const signature = crypto.sign("sha256", Buffer.from(String(registration.challenge.challenge)), { key: device.privateKey, dsaEncoding: "ieee-p1363" }).toString("base64url");
const session = await identity.createSession(String(registration.challenge.id), signature);
const token = String(session.access_token);
const capture = { schema_version: 1, capture_id: "a".repeat(32), owner_key: participantKey(registration.player.id),
  build: "2026092802", source_sha256: "b".repeat(64), engine: "4.7.1", platform: "iOS", status: "completed", sim_ms: 10000,
  winner_seat: 1, metrics: {}, metadata: { map_id: "simple_syrup", mode: "1V1" }, players: [{ seat: 1, is_cpu: false }],
  profiles: [{ seat: 2, style: "balancer", tier: "medium", policy: "human_balancer_v3" }],
  events: [{ t: 500, e: 9, p: 1, src: 1, dst: 2, intent: "attack", ok: true }],
  frames: [{ t: 500, h: [[1, 1, 10]], l: [] }], dropped_events: 0, frame_stride: 1 };
let enabled = true;
const app = express();
installBetaCaptureRoutes(app, pool, config, (req, res, next) => req.header("authorization") === "Bearer test-admin" ? next() : void res.sendStatus(401), () => enabled);
const server = app.listen(0, "127.0.0.1");
await new Promise<void>(resolve => server.once("listening", resolve));
const base = `http://127.0.0.1:${(server.address() as { port: number }).port}/v1`;
const post = async (value: unknown, auth = token, digestOverride = "") => {
  const body = gzipSync(JSON.stringify(value));
  const digest = crypto.createHash("sha256").update(body).digest("hex");
  const response = await fetch(`${base}/beta-captures`, { method: "POST", body,
    headers: { "Content-Type": "application/gzip", Authorization: `Bearer ${auth}`, "X-Capture-SHA256": digestOverride || digest } });
  return { status: response.status, data: await response.json() as any, digest };
};
try {
  assert.equal((await post(capture, "")).status, 401);
  enabled = false;
  assert.equal((await post(capture)).status, 503);
  enabled = true;
  assert.equal((await post(capture, token, "bad")).status, 400);
  assert.equal((await post({ ...capture, owner_key: "c".repeat(64) })).status, 403);
  assert.equal((await post({ ...capture, metadata: { ...capture.metadata, display_name: "private" } })).status, 400);
  assert.equal((await post({ ...capture, events: [{ ...capture.events[0], access_token: "private" }] })).status, 400);
  assert.equal((await post({ ...capture, frames: [{ t: 1, h: [["private"]], l: [] }] })).status, 400);
  assert.throws(() => decodeCapture(gzipSync("x".repeat(9 * 1024 * 1024))), /invalid_capture_gzip/);
  const first = await post(capture);
  assert.equal(first.status, 200);
  assert.equal(first.data.sha256, first.digest);
  // Lost response: the same committed payload is acknowledged without another row.
  assert.equal((await post(capture)).data.duplicate, true);
  assert.equal((await post({ ...capture, sim_ms: 11000 })).status, 409);
  assert.equal((await pool.query("SELECT count(*)::int AS n FROM sf_beta_captures")).rows[0].n, 1);
  assert.equal((await fetch(`${base}/admin/beta-captures`, { headers: { Authorization: `Bearer ${token}` } })).status, 401);
  const admin = { Authorization: "Bearer test-admin" };
  let listing = await (await fetch(`${base}/admin/beta-captures`, { headers: admin })).json() as any;
  assert.equal(listing.captures[0].cohort, "unknown");
  const id = listing.captures[0].id;
  const fetched = Buffer.from(await (await fetch(`${base}/admin/beta-captures/${id}`, { headers: admin })).arrayBuffer());
  assert.deepEqual(decodeCapture(fetched), capture);
  const cohort = await fetch(`${base}/admin/beta-participants/${capture.owner_key}`, { method: "PUT",
    headers: { ...admin, "Content-Type": "application/json" }, body: JSON.stringify({ cohort: "owner" }) });
  assert.equal(cohort.status, 200);
  listing = await (await fetch(`${base}/admin/beta-captures`, { headers: admin })).json() as any;
  assert.equal(listing.captures[0].cohort, "owner");
  const next = await (await fetch(`${base}/admin/beta-captures?after=${listing.next}`, { headers: admin })).json() as any;
  assert.equal(next.captures.length, 0);
  await identity.revokeSession(String((session.session as any).id), registration.player.id, "smoke");
  assert.equal((await post(capture)).status, 403);
  await pool.query("DELETE FROM sf_beta_participants WHERE player_id=$1", [registration.player.id]);
  assert.equal((await pool.query("SELECT count(*)::int AS n FROM sf_beta_captures")).rows[0].n, 0);
  console.log("BETA_CAPTURE_HTTP_PASS: auth, bounds, privacy schema, retry/dedupe, conflict, export, cohort, revocation, purge");
} finally {
  server.closeAllConnections();
  await new Promise<void>(resolve => server.close(() => resolve()));
  await db.close();
}
