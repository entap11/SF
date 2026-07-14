type JsonRecord = Record<string, unknown>;

import { assertSafeTestBackend } from "./testBackendGuard.js";

const baseUrl = (process.env.RANK_SMOKE_BASE_URL || process.env.SF_RANK_BACKEND_URL || "").replace(/\/+$/, "");
const token = (process.env.RANK_SMOKE_TOKEN || process.env.SF_RANK_BACKEND_TOKEN || "").trim();

function expect(condition: boolean, message: string, details: unknown = undefined): void {
  if (!condition) {
    throw new Error(details === undefined ? message : `${message}: ${JSON.stringify(details)}`);
  }
}

function uniqueCallSign(prefix: string): string {
  const suffix = `${Date.now().toString(36)}${Math.floor(Math.random() * 36 ** 3).toString(36)}`.replace(/[^a-z0-9]/gi, "");
  return `${prefix}_${suffix}`.slice(0, 16);
}

async function getJson(path: string): Promise<JsonRecord> {
  const res = await fetch(`${baseUrl}${path}`, {
    headers: token ? { Authorization: `Bearer ${token}` } : undefined
  });
  const body = await res.json() as JsonRecord;
  expect(res.ok, `GET ${path} failed`, body);
  return body;
}

function serviceRootUrl(): string {
  const parsed = new URL(baseUrl);
  if (parsed.pathname.endsWith("/v1/rank")) {
    parsed.pathname = parsed.pathname.slice(0, -"/v1/rank".length) || "/";
  }
  parsed.pathname = parsed.pathname.replace(/\/+$/, "");
  parsed.search = "";
  parsed.hash = "";
  return parsed.toString().replace(/\/+$/, "");
}

async function getServiceHealth(): Promise<JsonRecord> {
  const res = await fetch(`${serviceRootUrl()}/health`, {
    headers: token ? { Authorization: `Bearer ${token}` } : undefined
  });
  const body = await res.json() as JsonRecord;
  expect(res.ok, "GET /health failed", body);
  return body;
}

async function postRank(action: string, payload: JsonRecord): Promise<{ status: number; body: JsonRecord }> {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    Accept: "application/json"
  };
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }
  const res = await fetch(`${baseUrl}/${action}`, {
    method: "POST",
    headers,
    body: JSON.stringify(payload)
  });
  return {
    status: res.status,
    body: await res.json() as JsonRecord
  };
}

function playerFrom(body: JsonRecord): JsonRecord {
  const player = body.player;
  expect(typeof player === "object" && player != null && !Array.isArray(player), "missing player", body);
  return player as JsonRecord;
}

async function createAccount(callSign: string): Promise<JsonRecord> {
  const result = await postRank("register_player", {
    call_sign: callSign,
    region: "SMOKE",
    install_metadata: {
      smoke: "identity",
      created_at: new Date().toISOString()
    }
  });
  expect(result.status === 200, "register_player did not return 200", result);
  expect(result.body.ok === true, "register_player body not ok", result.body);
  return playerFrom(result.body);
}

async function main(): Promise<void> {
  expect(baseUrl.length > 0, "RANK_SMOKE_BASE_URL or SF_RANK_BACKEND_URL is required");
  assertSafeTestBackend(baseUrl);

  const health = await getServiceHealth();
  expect(health.ok === true, "health failed", health);

  const callSign = uniqueCallSign("SmokeA");
  const first = await createAccount(callSign);
  expect(/^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(String(first.id)), "id is not UUIDv7", first);
  expect(/^[A-Z]{3} [0-9]{3}$/.test(String(first.entap_id)), "entap_id format invalid", first);
  expect(first.call_sign === callSign, "call_sign mismatch", first);

  const duplicate = await postRank("register_player", { call_sign: callSign, region: "SMOKE" });
  expect(duplicate.status === 409, "duplicate call_sign should return 409", duplicate);
  expect(duplicate.body.ok === false && duplicate.body.err === "call_sign_not_unique", "duplicate call_sign error mismatch", duplicate);

  const [second, third] = await Promise.all([
    createAccount(uniqueCallSign("SmokeB")),
    createAccount(uniqueCallSign("SmokeC"))
  ]);
  expect(String(second.entap_id) !== String(third.entap_id), "rapid account creations received duplicate entap_id", { second, third });

  console.log(JSON.stringify({
    ok: true,
    smoke: "identity",
    base_url: baseUrl,
    first_id: first.id,
    first_entap_id: first.entap_id,
    rapid_entap_ids: [second.entap_id, third.entap_id]
  }));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
