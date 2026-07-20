import crypto from "node:crypto";
import type { Pool, QueryResult } from "pg";
import { PGlite, type PGliteInterface } from "@electric-sql/pglite";
import { pgcrypto } from "@electric-sql/pglite/contrib/pgcrypto";
import { IdentitySessionStore } from "./identity/sessionStore.js";
import { generateUuidV7, buildLeaderboardView } from "./logic.js";
import { RankStore } from "./store.js";
import { ServiceTrustError, verifyServiceJwt } from "./serviceTrust.js";
import { applyVerifiedStandard1v1Settlement } from "./verifiedSettlement.js";
import { canonicalJson, sha256Canonical, VerifiedReceiptError, verifyStandard1v1Receipt, type JsonRecord } from "./verifiedReceipt.js";

type DbResult<T> = { rows: T[]; affectedRows?: number };
class Adapter {
  constructor(private readonly db: PGliteInterface) {}
  async query<T extends Record<string, unknown> = Record<string, unknown>>(sql: string, params: unknown[] = []): Promise<QueryResult<T>> {
    if (sql.includes("pg_advisory_xact_lock")) return this.normalize({ rows: [{} as T], affectedRows: 1 });
    if (params.length === 0 && sql.split(";").filter((part) => part.trim()).length > 1) {
      const results = await this.db.exec(sql); return this.normalize((results.at(-1) ?? { rows: [] }) as DbResult<T>);
    }
    return this.normalize(await this.db.query<T>(sql, params) as DbResult<T>);
  }
  async connect(): Promise<Adapter & { release: () => void }> { return Object.assign(this, { release: () => undefined }); }
  private normalize<T extends Record<string, unknown>>(result: DbResult<T>): QueryResult<T> {
    return { command: "", rowCount: result.rows.length || result.affectedRows || 0, oid: 0, fields: [], rows: result.rows };
  }
}
function expect(value: unknown, message: string, details?: unknown): void {
  if (!value) throw new Error(`${message}${details == null ? "" : `: ${JSON.stringify(details)}`}`);
}
function expectCode(run: () => unknown, code: string): void {
  try { run(); } catch (error) {
    expect((error instanceof ServiceTrustError || error instanceof VerifiedReceiptError) && error.code === code,
      `expected ${code}`, error instanceof Error ? error.message : error);
    return;
  }
  throw new Error(`expected ${code}`);
}
function serviceToken(privateKey: string, now: number, claimOverrides: JsonRecord = {}): string {
  const encode = (value: unknown) => Buffer.from(JSON.stringify(value)).toString("base64url");
  const head = encode({ alg: "ES256", typ: "JWT", kid: "service-key" });
  const body = encode({ iss: "vs-smoke", aud: "rank-smoke", sub: "settlement-smoke", scp: ["rank:settle"],
    iat: now, nbf: now - 1, exp: now + 60, jti: generateUuidV7(), ...claimOverrides });
  const input = `${head}.${body}`;
  return `${input}.${crypto.sign("sha256", Buffer.from(input), { key: privateKey, dsaEncoding: "ieee-p1363" }).toString("base64url")}`;
}

async function main(): Promise<void> {
  const db = new PGlite({ extensions: { pgcrypto } });
  await db.waitReady;
  const pool = new Adapter(db) as unknown as Pool;
  const store = new RankStore(pool, "/nonexistent-rank-smoke.json");
  await store.init();
  const issuer = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const sessions = new IdentitySessionStore(pool, {
    issuer: "identity-smoke", audience: "vs-smoke", keyId: "identity-key",
    privateKeyPem: issuer.privateKey.export({ format: "pem", type: "pkcs8" }).toString(),
    publicKeyPem: issuer.publicKey.export({ format: "pem", type: "spki" }).toString(), accessTokenTtlSec: 600
  }, 300);
  const register = async (requestId: string, callSign: string) => sessions.registerIdentityAndDevice({
    requestId, callSign, region: "GLOBAL",
    publicKeyJwk: crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" }).publicKey.export({ format: "jwk" }),
    platform: "smoke", deviceLabel: "smoke", installMetadata: {}
  });
  const playerA = (await register("verified-rank-a", "RankSmokeA")).player.id;
  const playerB = (await register("verified-rank-b", "RankSmokeB")).player.id;

  const servicePair = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const now = Math.floor(Date.now() / 1000);
  const claims = verifyServiceJwt(serviceToken(servicePair.privateKey.export({ format: "pem", type: "pkcs8" }).toString(), now), {
    issuer: "vs-smoke", audience: "rank-smoke", subject: "settlement-smoke", keyId: "service-key",
    publicKeyPem: servicePair.publicKey.export({ format: "pem", type: "spki" }).toString()
  }, "rank:settle", now);
  expect(claims.sub === "settlement-smoke", "service JWT boundary failed", claims);
  expectCode(() => verifyServiceJwt(serviceToken(
    servicePair.privateKey.export({ format: "pem", type: "pkcs8" }).toString(), now
  ), {
    issuer: "vs-smoke", audience: "wrong-audience", subject: "settlement-smoke", keyId: "service-key",
    publicKeyPem: servicePair.publicKey.export({ format: "pem", type: "spki" }).toString()
  }, "rank:settle", now), "service_token_invalid");
  for (const claimOverrides of [{ iss: "wrong-issuer" }, { aud: "wrong-audience" }, { sub: "wrong-subject" }]) {
    expectCode(() => verifyServiceJwt(serviceToken(
      servicePair.privateKey.export({ format: "pem", type: "pkcs8" }).toString(), now, claimOverrides
    ), {
      issuer: "vs-smoke", audience: "rank-smoke", subject: "settlement-smoke", keyId: "service-key",
      publicKeyPem: servicePair.publicKey.export({ format: "pem", type: "spki" }).toString()
    }, "rank:settle", now), "service_token_invalid");
  }
  expectCode(() => verifyServiceJwt(serviceToken(
    servicePair.privateKey.export({ format: "pem", type: "pkcs8" }).toString(), now
  ), {
    issuer: "vs-smoke", audience: "rank-smoke", subject: "settlement-smoke", keyId: "wrong-key",
    publicKeyPem: servicePair.publicKey.export({ format: "pem", type: "spki" }).toString()
  }, "rank:settle", now), "service_token_invalid");

  const verifier = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const payload: JsonRecord = {
    result_id: generateUuidV7(), result_schema_version: 1, match_id: generateUuidV7(), contract_id: generateUuidV7(),
    match_epoch: 1, contract_hash: "1".repeat(64), authority_method: "SIM_REPLAY",
    terminal_reason: "OBJECTIVE_COMPLETE",
    placements: [{ place: 1, player_ids: [playerA] }, { place: 2, player_ids: [playerB] }],
    winning_team_id: null, elapsed_sim_ticks: 18, final_state_hash: "2".repeat(64), final_command_seq: 1,
    command_log_hash: "3".repeat(64), sim_build_id: "sim-smoke", worker_build_id: "worker-smoke",
    verified_at: new Date().toISOString(), verifier_key_id: "verifier-smoke"
  };
  const signed = {
    payload, payloadHash: sha256Canonical(payload), keyId: "verifier-smoke", algorithm: "ES256" as const,
    signature: crypto.sign("sha256", Buffer.from(canonicalJson(payload)), {
      key: verifier.privateKey, dsaEncoding: "ieee-p1363"
    }).toString("base64url")
  };
  const verified = verifyStandard1v1Receipt(signed, {
    keyId: "verifier-smoke", publicKeyPem: verifier.publicKey.export({ format: "pem", type: "spki" }).toString(),
    workerBuildId: "worker-smoke", receiptMaxAgeSec: 3_600
  });
  expectCode(() => verifyStandard1v1Receipt({ ...signed, signature: Buffer.alloc(64).toString("base64url") }, {
    keyId: "verifier-smoke", publicKeyPem: verifier.publicKey.export({ format: "pem", type: "spki" }).toString(),
    workerBuildId: "worker-smoke", receiptMaxAgeSec: 3_600
  }), "verifier_receipt_signature_invalid");
  expectCode(() => verifyStandard1v1Receipt(signed, {
    keyId: "verifier-smoke", publicKeyPem: verifier.publicKey.export({ format: "pem", type: "spki" }).toString(),
    workerBuildId: "wrong-worker", receiptMaxAgeSec: 3_600
  }), "verifier_receipt_binding_invalid");
  expectCode(() => verifyStandard1v1Receipt(signed, {
    keyId: "wrong-verifier", publicKeyPem: verifier.publicKey.export({ format: "pem", type: "spki" }).toString(),
    workerBuildId: "worker-smoke", receiptMaxAgeSec: 3_600
  }), "verifier_receipt_signature_invalid");
  const stalePayload = { ...payload, verified_at: new Date(Date.now() - 3_601_000).toISOString() };
  const staleSigned = {
    ...signed, payload: stalePayload, payloadHash: sha256Canonical(stalePayload),
    signature: crypto.sign("sha256", Buffer.from(canonicalJson(stalePayload)), {
      key: verifier.privateKey, dsaEncoding: "ieee-p1363"
    }).toString("base64url")
  };
  expectCode(() => verifyStandard1v1Receipt(staleSigned, {
    keyId: "verifier-smoke", publicKeyPem: verifier.publicKey.export({ format: "pem", type: "spki" }).toString(),
    workerBuildId: "worker-smoke", receiptMaxAgeSec: 3_600
  }), "verifier_receipt_stale");
  const first = await applyVerifiedStandard1v1Settlement(store, verified, String(claims.sub));
  const restartedStore = new RankStore(pool, "/nonexistent-rank-smoke.json");
  await restartedStore.init();
  const duplicate = await applyVerifiedStandard1v1Settlement(restartedStore, verified, String(claims.sub));
  expect(first.ok === true && first.status === "SETTLED" && first.duplicate === false, "first settlement failed", first);
  expect(duplicate.ok === true && duplicate.duplicate === true, "settlement was not idempotent", duplicate);
  const state = await store.read((value) => value);
  const board = buildLeaderboardView(state, "", "GLOBAL", 25);
  const counts = await pool.query<{ processed: string; audits: string }>(
    `SELECT (SELECT count(*)::text FROM rank_processed_events WHERE dedupe_key = $1) AS processed,
      (SELECT count(*)::text FROM rank_audit_events WHERE event_type = 'verified_standard_1v1_settled') AS audits`,
    [`verified-standard-1v1:${payload.result_id}`]
  );
  expect(counts.rows[0]?.processed === "1" && counts.rows[0]?.audits === "1", "durable dedupe/audit mismatch", counts.rows[0]);
  expect((board.rows as unknown[]).length === 2, "public global board missing settled players", board);
  console.log(JSON.stringify({ ok: true, smoke: "verified_rank_settlement", idempotent: true, restart_retry: true,
    service_jwt: "ES256", wrong_issuer_rejected: true, wrong_audience_rejected: true,
    wrong_subject_rejected: true, wrong_service_key_rejected: true, verifier_receipt: "ES256",
    forged_receipt_rejected: true, wrong_verifier_key_rejected: true,
    wrong_worker_build_rejected: true, stale_receipt_rejected: true,
    processed_events: 1, audit_events: 1 }));
  await db.close();
}

void main().catch((error) => { console.error(error); process.exitCode = 1; });
