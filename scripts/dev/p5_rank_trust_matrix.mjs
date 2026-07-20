import crypto from "node:crypto";
import { verifyServiceJwt } from "file:///opt/render/project/src/tools/rank-service/dist/serviceTrust.js";
import { canonicalJson, sha256Canonical, verifyStandard1v1Receipt } from "file:///opt/render/project/src/tools/rank-service/dist/verifiedReceipt.js";

function expectCode(run, code) {
  try { run(); } catch (error) {
    if (error?.code === code) return;
    throw error;
  }
  throw new Error(`expected ${code}`);
}

const pair = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
const workerBuildId = process.env.RANK_VERIFIER_WORKER_BUILD_ID?.trim() ?? "";
if (!workerBuildId) throw new Error("RANK_VERIFIER_WORKER_BUILD_ID is required");
const privateKey = pair.privateKey.export({ format: "pem", type: "pkcs8" }).toString();
const publicKey = pair.publicKey.export({ format: "pem", type: "spki" }).toString();
const nowSec = Math.floor(Date.now() / 1000);
const encode = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
function serviceToken(overrides = {}, kid = "p5-service-key") {
  const header = encode({ alg: "ES256", typ: "JWT", kid });
  const claims = encode({ iss: "p5-vs", aud: "p5-rank", sub: "p5-settlement", scp: ["rank:settle"],
    iat: nowSec, nbf: nowSec - 1, exp: nowSec + 60, jti: crypto.randomUUID(), ...overrides });
  const input = `${header}.${claims}`;
  const signature = crypto.sign("sha256", Buffer.from(input), { key: privateKey, dsaEncoding: "ieee-p1363" }).toString("base64url");
  return `${input}.${signature}`;
}
const serviceConfig = { issuer: "p5-vs", audience: "p5-rank", subject: "p5-settlement",
  keyId: "p5-service-key", publicKeyPem: publicKey };
verifyServiceJwt(serviceToken(), serviceConfig, "rank:settle", nowSec);
for (const override of [{ iss: "wrong" }, { aud: "wrong" }, { sub: "wrong" }]) {
  expectCode(() => verifyServiceJwt(serviceToken(override), serviceConfig, "rank:settle", nowSec), "service_token_invalid");
}
expectCode(() => verifyServiceJwt(serviceToken({}, "wrong-key"), serviceConfig, "rank:settle", nowSec), "service_token_invalid");

const verifier = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
const verifierPublic = verifier.publicKey.export({ format: "pem", type: "spki" }).toString();
const payload = {
  result_id: "019f8120-0001-7000-8000-000000000001",
  result_schema_version: 1,
  match_id: "019f8120-0002-7000-8000-000000000002",
  contract_id: "019f8120-0003-7000-8000-000000000003",
  match_epoch: 1,
  contract_hash: "1".repeat(64),
  authority_method: "SIM_REPLAY",
  terminal_reason: "OBJECTIVE_COMPLETE",
  placements: [
    { place: 1, player_ids: ["019f8120-0004-7000-8000-000000000004"] },
    { place: 2, player_ids: ["019f8120-0005-7000-8000-000000000005"] }
  ],
  winning_team_id: null,
  elapsed_sim_ticks: 1400,
  final_state_hash: "2".repeat(64),
  final_command_seq: 53,
  command_log_hash: "3".repeat(64),
  sim_build_id: "sf-sim-8abb766",
  worker_build_id: workerBuildId,
  verified_at: new Date().toISOString(),
  verifier_key_id: "p5-verifier-key"
};
function signed(value = payload, keyId = "p5-verifier-key") {
  return { payload: value, payloadHash: sha256Canonical(value), keyId, algorithm: "ES256",
    signature: crypto.sign("sha256", Buffer.from(canonicalJson(value)), {
      key: verifier.privateKey, dsaEncoding: "ieee-p1363"
    }).toString("base64url") };
}
const verifierConfig = { keyId: "p5-verifier-key", publicKeyPem: verifierPublic,
  workerBuildId, receiptMaxAgeSec: 3600 };
verifyStandard1v1Receipt(signed(), verifierConfig);
expectCode(() => verifyStandard1v1Receipt({ ...signed(), signature: Buffer.alloc(64).toString("base64url") }, verifierConfig),
  "verifier_receipt_signature_invalid");
expectCode(() => verifyStandard1v1Receipt(signed(), { ...verifierConfig, keyId: "wrong-key" }),
  "verifier_receipt_signature_invalid");
expectCode(() => verifyStandard1v1Receipt(signed(), { ...verifierConfig, workerBuildId: "wrong-worker" }),
  "verifier_receipt_binding_invalid");
const stale = { ...payload, verified_at: new Date(Date.now() - 3_601_000).toISOString() };
expectCode(() => verifyStandard1v1Receipt(signed(stale), verifierConfig), "verifier_receipt_stale");
const future = { ...payload, verified_at: new Date(Date.now() + 6_000).toISOString() };
expectCode(() => verifyStandard1v1Receipt(signed(future), verifierConfig), "verifier_receipt_stale");

console.log(JSON.stringify({ ok: true, matrix: "p5_rank_trust", service_jwt: "ES256",
  wrong_issuer_rejected: true, wrong_audience_rejected: true, wrong_subject_rejected: true,
  wrong_service_key_rejected: true, verifier_receipt: "ES256", forged_receipt_rejected: true,
  wrong_verifier_key_rejected: true, wrong_worker_build_rejected: true,
  stale_receipt_rejected: true, future_receipt_rejected: true }));
