import crypto from "node:crypto";
import { isUuidV7 } from "./logic.js";

export type JsonRecord = Record<string, unknown>;
export type SignedVerifierReceipt = {
  payload: JsonRecord; payloadHash: string; keyId: string; algorithm: "ES256"; signature: string;
};

export class VerifiedReceiptError extends Error {
  constructor(readonly code: string, readonly status = 400) { super(code); }
}

export function parseSignedVerifierReceipt(value: unknown): SignedVerifierReceipt {
  const source = record(value);
  const payload = record(source.payload);
  const algorithm = String(source.algorithm ?? "");
  if (algorithm !== "ES256") throw new VerifiedReceiptError("verifier_receipt_invalid");
  return {
    payload,
    payloadHash: String(source.payload_hash ?? source.payloadHash ?? ""),
    keyId: String(source.key_id ?? source.keyId ?? ""),
    algorithm: "ES256",
    signature: String(source.signature ?? "")
  };
}

export function verifyStandard1v1Receipt(receipt: SignedVerifierReceipt, config: {
  keyId: string; publicKeyPem: string; workerBuildId: string;
}): JsonRecord {
  if (!config.keyId || !config.publicKeyPem || !config.workerBuildId) {
    throw new VerifiedReceiptError("verifier_receipt_auth_not_configured", 503);
  }
  if (receipt.keyId !== config.keyId || receipt.payloadHash !== sha256Canonical(receipt.payload)) {
    throw new VerifiedReceiptError("verifier_receipt_signature_invalid");
  }
  const signature = Buffer.from(receipt.signature, "base64url");
  if (signature.length !== 64 || !crypto.verify("sha256", Buffer.from(canonicalJson(receipt.payload), "utf8"), {
    key: config.publicKeyPem, dsaEncoding: "ieee-p1363"
  }, signature)) throw new VerifiedReceiptError("verifier_receipt_signature_invalid");
  const payload = receipt.payload;
  const placements = Array.isArray(payload.placements) ? payload.placements.map(record) : [];
  const playerIds = placements.flatMap((group) => Array.isArray(group.player_ids) ? group.player_ids.map(String) : []);
  if (payload.result_schema_version !== 1 || !isUuidV7(String(payload.result_id ?? ""))
    || !isUuidV7(String(payload.match_id ?? "")) || !isUuidV7(String(payload.contract_id ?? ""))
    || !Number.isSafeInteger(payload.match_epoch) || Number(payload.match_epoch) < 1
    || !/^[0-9a-f]{64}$/.test(String(payload.contract_hash ?? ""))
    || !["SIM_REPLAY", "SERVER_LIFECYCLE"].includes(String(payload.authority_method ?? ""))
    || !["OBJECTIVE_COMPLETE", "TIME_LIMIT_PLACEMENT", "FORFEIT_DISCONNECT", "FORFEIT_VOLUNTARY", "NO_CONTEST"]
      .includes(String(payload.terminal_reason ?? ""))
    || !Number.isSafeInteger(payload.final_command_seq) || Number(payload.final_command_seq) < 0
    || !/^[0-9a-f]{64}$/.test(String(payload.command_log_hash ?? ""))
    || !Number.isSafeInteger(payload.elapsed_sim_ticks) || Number(payload.elapsed_sim_ticks) < 0
    || !String(payload.sim_build_id ?? "") || !String(payload.worker_build_id ?? "")
    || !validIso(String(payload.verified_at ?? ""))
    || payload.worker_build_id !== config.workerBuildId || payload.verifier_key_id !== config.keyId) {
    throw new VerifiedReceiptError("verifier_receipt_binding_invalid");
  }
  const authorityMethod = String(payload.authority_method);
  const terminalReason = String(payload.terminal_reason);
  if ((terminalReason !== "NO_CONTEST" && authorityMethod === "SIM_REPLAY"
      && !/^[0-9a-f]{64}$/.test(String(payload.final_state_hash ?? "")))
    || (terminalReason !== "NO_CONTEST" && authorityMethod === "SERVER_LIFECYCLE" && payload.final_state_hash != null)
    || (["OBJECTIVE_COMPLETE", "TIME_LIMIT_PLACEMENT"].includes(terminalReason) && authorityMethod !== "SIM_REPLAY")
    || (["FORFEIT_DISCONNECT", "FORFEIT_VOLUNTARY"].includes(terminalReason) && authorityMethod !== "SERVER_LIFECYCLE")) {
    throw new VerifiedReceiptError("verifier_receipt_result_invalid");
  }
  if (payload.terminal_reason === "NO_CONTEST") {
    if (placements.length !== 0 || !String(payload.no_contest_reason ?? "")) {
      throw new VerifiedReceiptError("verifier_receipt_result_invalid");
    }
    return payload;
  }
  if (placements.length !== 2 || placements.some((group, index) => Number(group.place) !== index + 1)
    || playerIds.length !== 2 || new Set(playerIds).size !== 2 || playerIds.some((id) => !isUuidV7(id))) {
    throw new VerifiedReceiptError("verifier_receipt_result_invalid");
  }
  return payload;
}

export function canonicalJson(value: unknown): string { return JSON.stringify(canonicalValue(value)); }
export function sha256Canonical(value: unknown): string {
  return crypto.createHash("sha256").update(canonicalJson(value), "utf8").digest("hex");
}
function canonicalValue(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonicalValue);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value as JsonRecord).sort(([a], [b]) => a.localeCompare(b))
      .map(([key, item]) => [key, canonicalValue(item)]));
  }
  return value;
}
function record(value: unknown): JsonRecord {
  return typeof value === "object" && value != null && !Array.isArray(value) ? value as JsonRecord : {};
}
function validIso(value: string): boolean {
  const parsed = new Date(value);
  return Number.isFinite(parsed.getTime()) && parsed.toISOString() === value;
}
