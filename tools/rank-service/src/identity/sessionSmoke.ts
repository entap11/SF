import crypto from "node:crypto";
import { assertSafeTestBackend } from "../testBackendGuard.js";

type JsonRecord = Record<string, unknown>;

const configuredBase = (process.env.RANK_SMOKE_BASE_URL || process.env.SF_RANK_BACKEND_URL || "").replace(/\/+$/, "");
const serviceToken = (process.env.RANK_SMOKE_TOKEN || process.env.SF_RANK_BACKEND_TOKEN || "").trim();

function expect(condition: unknown, message: string, details?: unknown): void {
  if (!condition) throw new Error(`${message}${details == null ? "" : `: ${JSON.stringify(details)}`}`);
}

function serviceRootUrl(): string {
  const parsed = new URL(configuredBase);
  if (parsed.pathname.endsWith("/v1/rank")) parsed.pathname = parsed.pathname.slice(0, -"/v1/rank".length) || "/";
  parsed.pathname = parsed.pathname.replace(/\/+$/, "");
  parsed.search = "";
  parsed.hash = "";
  return parsed.toString().replace(/\/+$/, "");
}

async function post(path: string, body: JsonRecord, token = ""): Promise<{ status: number; body: JsonRecord }> {
  const response = await fetch(`${serviceRootUrl()}${path}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {})
    },
    body: JSON.stringify(body)
  });
  return { status: response.status, body: await response.json() as JsonRecord };
}

function uniqueCallSign(): string {
  return `Sess_${Date.now().toString(36)}`.slice(0, 16);
}

async function main(): Promise<void> {
  expect(configuredBase, "RANK_SMOKE_BASE_URL or SF_RANK_BACKEND_URL is required");
  assertSafeTestBackend(configuredBase);
  const keyPair = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const publicJwk = keyPair.publicKey.export({ format: "jwk" });
  const jwksResponse = await fetch(`${serviceRootUrl()}/.well-known/jwks.json`);
  const jwks = await jwksResponse.json() as JsonRecord;
  const publishedKeys = jwks.keys as JsonRecord[];
  expect(jwksResponse.ok && Array.isArray(publishedKeys) && publishedKeys.length === 1
    && publishedKeys[0].alg === "ES256" && publishedKeys[0].d == null, "public JWKS invalid", jwks);
  const requestId = `session-smoke-${Date.now()}`;
  const registered = await post("/v1/identity/register", {
    request_id: requestId,
    call_sign: uniqueCallSign(),
    region: "SMOKE",
    device: { public_key_jwk: publicJwk, platform: "smoke", label: "Session Smoke" }
  });
  expect([200, 201].includes(registered.status) && registered.body.ok === true, "registration failed", registered);
  const player = registered.body.player as JsonRecord;
  const device = registered.body.device as JsonRecord;
  const challenge = registered.body.challenge as JsonRecord;
  expect(/^[0-9a-f-]+$/i.test(String(player.id)), "missing player id", player);
  expect(String(device.id), "missing device id", device);
  const signature = crypto.sign("sha256", Buffer.from(String(challenge.challenge), "utf8"), {
    key: keyPair.privateKey,
    dsaEncoding: "ieee-p1363"
  }).toString("base64url");
  const session = await post("/v1/identity/session", {
    challenge_id: challenge.id,
    signature
  });
  expect(session.status === 201 && session.body.ok === true, "session issuance failed", session);
  const accessToken = String(session.body.access_token ?? "");
  expect(accessToken.split(".").length === 3, "access token missing", session.body);
  const payload = JSON.parse(Buffer.from(accessToken.split(".")[1], "base64url").toString("utf8")) as JsonRecord;
  expect(payload.sub === player.id && Array.isArray(payload.scp) && payload.scp.includes("match:queue")
    && payload.scp.includes("contest:play"),
    "token claims mismatch", payload);

  const replay = await post("/v1/identity/session", { challenge_id: challenge.id, signature });
  expect(replay.status === 409 && replay.body.err === "challenge_already_used", "challenge replay was accepted", replay);

  const rankPrivilege = await fetch(`${configuredBase}/get_snapshot`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${accessToken}` },
    body: "{}"
  });
  expect([401, 503].includes(rankPrivilege.status), "player token invoked service-protected rank action", {
    status: rankPrivilege.status,
    body: await rankPrivilege.text()
  });

  const revoked = await post("/v1/identity/session/revoke", { reason: "smoke_complete" }, accessToken);
  expect(revoked.status === 200 && revoked.body.revoked === true, "session revoke failed", revoked);
  const duplicateRevoke = await post("/v1/identity/session/revoke", { reason: "smoke_duplicate" }, accessToken);
  expect(duplicateRevoke.status === 200 && duplicateRevoke.body.revoked === true,
    "session revoke was not idempotent", duplicateRevoke);

  console.log(JSON.stringify({
    ok: true,
    smoke: "device_session",
    player_id: player.id,
    device_id: device.id,
    service_token_configured: Boolean(serviceToken)
  }));
}

void main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
