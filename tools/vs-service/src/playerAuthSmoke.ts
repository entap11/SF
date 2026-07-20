import crypto from "node:crypto";
import http from "node:http";
import { mkdtempSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

type JsonRecord = Record<string, unknown>;
type ListenableApp = { listen: (port: number, hostname: string, callback: () => void) => http.Server };

function expect(condition: unknown, message: string, details?: unknown): void {
  if (!condition) throw new Error(`${message}${details == null ? "" : ` :: ${JSON.stringify(details)}`}`);
}

function listen(app: ListenableApp): Promise<http.Server> {
  return new Promise((resolve) => {
    const server = app.listen(0, "127.0.0.1", () => resolve(server));
  });
}

function close(server: http.Server): Promise<void> {
  return new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
}

function encode(value: unknown): string {
  return Buffer.from(JSON.stringify(value), "utf8").toString("base64url");
}

function token(privateKeyPem: string, claims: JsonRecord, kid = "auth-smoke-key"): string {
  const input = `${encode({ alg: "ES256", typ: "JWT", kid })}.${encode(claims)}`;
  const signature = crypto.sign("sha256", Buffer.from(input, "ascii"), {
    key: privateKeyPem,
    dsaEncoding: "ieee-p1363"
  });
  return `${input}.${signature.toString("base64url")}`;
}

async function post(base: string, action: string, body: JsonRecord, accessToken = ""): Promise<JsonRecord> {
  const response = await fetch(`${base}/${action}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {})
    },
    body: JSON.stringify(body)
  });
  return { ...await response.json() as JsonRecord, http_status: response.status };
}

async function main(): Promise<void> {
  const tempDir = mkdtempSync(join(tmpdir(), "sf-player-auth-"));
  const pair = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const privatePem = pair.privateKey.export({ format: "pem", type: "pkcs8" }).toString();
  const publicPem = pair.publicKey.export({ format: "pem", type: "spki" }).toString();
  process.env.CRUCIBLE_LEDGER_PATH = join(tempDir, "crucible.json");
  process.env.HONEY_LEDGER_PATH = join(tempDir, "honey.json");
  process.env.VS_AUTHENTICATED_1V1_SLICE_ENABLED = "true";
  process.env.VS_PLAYER_TOKEN_ISSUER = "auth-smoke-issuer";
  process.env.VS_PLAYER_TOKEN_AUDIENCE = "auth-smoke-audience";
  process.env.VS_PLAYER_TOKEN_KEY_ID = "auth-smoke-key";
  process.env.VS_PLAYER_TOKEN_PUBLIC_KEY_PEM = publicPem;
  process.env.VS_ADMIN_TOKEN = "admin-only";
  process.env.VS_MATCH_AUTHORITY_TOKEN = "authority-only";
  process.env.VS_ECONOMY_MUTATIONS_ENABLED = "true";
  const { createApp } = await import("./server.js");
  const server = await listen(createApp());
  const address = server.address();
  if (address == null || typeof address === "string") throw new Error("missing listen address");
  const base = `http://127.0.0.1:${address.port}/v1`;
  const now = Math.floor(Date.now() / 1000);
  const playerA = "0190f47a-1234-7abc-8def-123456789abc";
  const playerB = "0190f47a-2234-7abc-8def-123456789abc";
  const common = { iss: "auth-smoke-issuer", aud: "auth-smoke-audience",
    sid: "0190f47a-3234-7abc-8def-123456789abc", did: "0190f47a-4234-7abc-8def-123456789abc",
    scp: ["match:queue"], iat: now, nbf: now - 1, exp: now + 600, jti: "jti-a", ver: 1 };
  const tokenA = token(privatePem, { ...common, sub: playerA, name: "VerifiedA", entap_id: "AAA 001" });
  const tokenB = token(privatePem, { ...common, sub: playerB,
    sid: "0190f47a-5234-7abc-8def-123456789abc", did: "0190f47a-6234-7abc-8def-123456789abc",
    jti: "jti-b", name: "VerifiedB" });
  const context = { mode: "1V1", map_count: 1, price_usd: 0, free_roll: true, stage_map_paths: ["res://maps/json/MAP_TEST_8x12.json"] };
  try {
    const health = await fetch(`http://127.0.0.1:${address.port}/health`).then((response) => response.json() as Promise<JsonRecord>);
    expect(health.player_auth_configured === true && health.authenticated_1v1_slice_enabled === true,
      "health does not expose auth slice", health);
    expect(health.public_1v1_enabled === false, "auth slice accidentally enabled public 1v1", health);

    const missing = await post(base, "enqueue_public_1v1", { profile: { uid: playerA }, context });
    expect(missing.http_status === 401 && missing.err === "player_token_required", "missing token accepted", missing);
    const mismatch = await post(base, "enqueue_public_1v1", { profile: { uid: playerB }, context }, tokenA);
    expect(mismatch.http_status === 403 && mismatch.err === "identity_mismatch", "body identity overrode token", mismatch);
    const noScope = token(privatePem, { ...common, sub: playerA, scp: [], jti: "no-scope" });
    const scopeDenied = await post(base, "enqueue_public_1v1", { profile: { uid: playerA }, context }, noScope);
    expect(scopeDenied.http_status === 403 && scopeDenied.err === "player_scope_required", "missing scope accepted", scopeDenied);
    const wrongAudience = token(privatePem, { ...common, sub: playerA, aud: "wrong", jti: "wrong-aud" });
    const audienceDenied = await post(base, "enqueue_public_1v1", { profile: { uid: playerA }, context }, wrongAudience);
    expect(audienceDenied.http_status === 401, "wrong audience accepted", audienceDenied);

    const queued = await post(base, "enqueue_public_1v1", { profile: { uid: playerA, display_name: "ForgedName" }, context }, tokenA);
    expect(queued.ok === true && queued.matched === false, "authenticated player did not queue", queued);
    const matched = await post(base, "enqueue_public_1v1", { profile: { uid: playerB, display_name: "AlsoForged" }, context }, tokenB);
    expect(matched.ok === true && matched.matched === true, "authenticated players did not match", matched);
    const session = matched.session as JsonRecord;
    const host = session.host as JsonRecord;
    const guest = session.guest as JsonRecord;
    expect(host.uid === playerA && guest.uid === playerB, "token subjects did not own seats", session);
    expect(host.display_name === "VerifiedA" && guest.display_name === "VerifiedB", "client display hints were trusted", session);
    expect((session.context as JsonRecord).authority_tier === "RELAY_ATTESTED"
      && (session.context as JsonRecord).ranked === false, "slice implied trusted/ranked authority", session.context);

    const adminDenied = await post(base, "debug_fill_session", {}, tokenA);
    expect(adminDenied.http_status === 401 && adminDenied.err === "admin_auth_required",
      "player token invoked admin action", adminDenied);
    const authorityDenied = await post(base, "settle_money_match", {}, tokenA);
    expect(authorityDenied.http_status === 401 && authorityDenied.err === "match_authority_required",
      "player token invoked match-authority action", authorityDenied);
  } finally {
    await close(server);
    rmSync(tempDir, { recursive: true, force: true });
  }
  console.log(JSON.stringify({ ok: true, smoke: "player_auth_vertical_slice", public_1v1_enabled: false }));
}

void main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
