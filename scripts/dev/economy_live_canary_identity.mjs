import crypto from "node:crypto";
import { chmod, readFile, writeFile } from "node:fs/promises";

const action = String(process.argv[2] ?? "").trim().toLowerCase();
const stateFile = String(process.env.ECONOMY_CANARY_STATE_FILE ?? "").trim();
const configuredBase = String(process.env.ECONOMY_CANARY_RANK_URL ?? "").trim().replace(/\/+$/, "");

if (!stateFile) throw new Error("ECONOMY_CANARY_STATE_FILE is required");

async function main() {
  if (action === "register") return register();
  const state = JSON.parse(await readFile(stateFile, "utf8"));
  assertSafeBase(state.base_url);
  if (!Array.isArray(state.players) || state.players.length !== 2) throw new Error("invalid canary state");
  if (action === "ids") return print({ ok: true, player_ids: state.players.map((player) => player.id) });
  if (action === "snapshot") return snapshot(state);
  if (action === "spend") return spend(state);
  throw new Error("action must be register, ids, snapshot, or spend");
}

async function register() {
  assertSafeBase(configuredBase);
  const players = [];
  for (let index = 0; index < 2; index += 1) {
    const keyPair = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
    const registered = await post(configuredBase, "/v1/identity/register", {
      request_id: `economy-canary-${Date.now()}-${index}`,
      call_sign: `EcoCanary${index + 1}`,
      region: "CANARY",
      device: {
        public_key_jwk: keyPair.publicKey.export({ format: "jwk" }),
        platform: "canary",
        label: "Economy Live Canary"
      }
    });
    expect([200, 201].includes(registered.status) && registered.body.ok === true,
      "registration failed", safeResponse(registered));
    const challenge = registered.body.challenge;
    const signature = crypto.sign("sha256", Buffer.from(String(challenge.challenge), "utf8"), {
      key: keyPair.privateKey,
      dsaEncoding: "ieee-p1363"
    }).toString("base64url");
    const session = await post(configuredBase, "/v1/identity/session", {
      challenge_id: challenge.id,
      signature
    });
    expect(session.status === 201 && session.body.ok === true, "session failed", safeResponse(session));
    const accessToken = String(session.body.access_token ?? "");
    expect(accessToken.split(".").length === 3, "session token missing");
    players.push({
      id: String(registered.body.player.id),
      device_id: String(registered.body.device.id),
      access_token: accessToken,
      private_key_pem: keyPair.privateKey.export({ type: "pkcs8", format: "pem" })
    });
  }
  const state = {
    schema_version: 1,
    base_url: configuredBase,
    created_at: new Date().toISOString(),
    spend_request_id: `honey-spend-${crypto.randomUUID()}`,
    players
  };
  await writeFile(stateFile, `${JSON.stringify(state)}\n`, { encoding: "utf8", flag: "wx", mode: 0o600 });
  await chmod(stateFile, 0o600);
  print({ ok: true, player_ids: players.map((player) => player.id), state_file_mode: "0600" });
}

async function snapshot(state) {
  const players = [];
  for (const player of state.players) {
    const response = await get(state.base_url, "/v1/platform/economy/me", player.access_token);
    expect(response.status === 200 && response.body.ok === true, "economy snapshot failed", safeResponse(response));
    players.push(response.body);
  }
  print({ ok: true, players });
}

async function spend(state) {
  const player = state.players[0];
  const request = {
    request_id: state.spend_request_id,
    catalog_action_id: "beta.canary_entitlement"
  };
  const first = await post(state.base_url, "/v1/platform/economy/honey/spend", request, player.access_token);
  expect(first.status === 200 && first.body.ok === true && first.body.duplicate === false,
    "first Honey spend failed", safeResponse(first));
  const duplicate = await post(state.base_url, "/v1/platform/economy/honey/spend", request, player.access_token);
  expect(duplicate.status === 200 && duplicate.body.ok === true && duplicate.body.duplicate === true,
    "Honey spend retry was not idempotent", safeResponse(duplicate));
  const altered = await post(state.base_url, "/v1/platform/economy/honey/spend", {
    ...request,
    catalog_action_id: "beta.test"
  }, player.access_token);
  expect(altered.status === 409, "altered Honey retry was not rejected", safeResponse(altered));
  const current = await get(state.base_url, "/v1/platform/economy/me", player.access_token);
  expect(current.status === 200 && Array.isArray(current.body.entitlements)
    && current.body.entitlements.includes("beta_economy_canary"),
  "Honey entitlement was not committed atomically", safeResponse(current));
  print({
    ok: true,
    player_id: player.id,
    honey_spend_centi: 100,
    duplicate_retry: true,
    altered_retry_rejected: true,
    entitlement: "beta_economy_canary",
    balance: current.body
  });
}

async function get(base, path, token) {
  const response = await fetch(`${base}${path}`, {
    headers: { Accept: "application/json", Authorization: `Bearer ${token}` }
  });
  return { status: response.status, body: await response.json() };
}

async function post(base, path, body, token = "") {
  const response = await fetch(`${base}${path}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {})
    },
    body: JSON.stringify(body)
  });
  return { status: response.status, body: await response.json() };
}

function assertSafeBase(value) {
  const url = new URL(value);
  const safe = url.protocol === "https:" && url.hostname === "swarmfront-cert-rank.onrender.com"
    || ["localhost", "127.0.0.1"].includes(url.hostname);
  if (!safe) throw new Error("economy canary is restricted to the certification Rank service or localhost");
}

function safeResponse(response) {
  return { status: response.status, body: response.body };
}

function expect(condition, message, details) {
  if (!condition) throw new Error(`${message}${details == null ? "" : `: ${JSON.stringify(details)}`}`);
}

function print(value) { console.log(JSON.stringify(value)); }

void main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
