import crypto from "node:crypto";
import {
  canonicalJson,
  deepClone,
  DurableCoreError,
  isUuidV7,
  sha256Canonical,
  type CommandReceipt,
  type DurableContract,
  type JsonRecord,
  type TerminalResult
} from "./durableCore.js";

export type ClientTerminalReportInput = {
  matchId: string;
  playerId: string;
  requestId: string;
  finalStateHash: string;
  elapsedSimTicks: number;
  claimedTerminalReason: string;
  claimedWinnerPlayerId: string | null;
  diagnostics: JsonRecord;
  submittedAt: string;
};

export type ClientTerminalReport = ClientTerminalReportInput & {
  reportId: string;
  contractId: string;
  matchEpoch: number;
  requestHash: string;
  duplicate: boolean;
};

export type VerificationJobStatus = "PENDING" | "LEASED" | "RETRY" | "COMPLETED" | "QUARANTINED" | "FAILED";

export type VerificationBundle = {
  jobId: string;
  resultId: string;
  leaseToken: string;
  attempt: number;
  receiptIssuedAt: string;
  inputHash: string;
  authorityMethod: "SIM_REPLAY" | "SERVER_LIFECYCLE";
  contract: DurableContract;
  commands: CommandReceipt[];
  lifecycleEvents: JsonRecord[];
  clientReports: ClientTerminalReport[];
  finalCommandSeq: number;
  commandLogHash: string;
};

export type SignedSyncResult = {
  payload: JsonRecord;
  payloadHash: string;
  keyId: string;
  algorithm: "ES256";
  signature: string;
};

export type CompleteVerificationInput = {
  workerId: string;
  leaseToken: string;
  jobId: string;
  startedAt: string;
  finishedAt: string;
  signedResult: SignedSyncResult;
  runDiagnostics: JsonRecord;
};

export type VerificationStatusView = {
  matchId: string;
  matchEpoch: number;
  status: "AWAITING_REPORTS" | VerificationJobStatus;
  reportCount: number;
  requiredReportCount: number;
  result: TerminalResult | null;
  signedReceipt: SignedSyncResult | null;
};

export interface VerificationRepository {
  submitClientReport(input: ClientTerminalReportInput): Promise<{ report: ClientTerminalReport; status: VerificationStatusView }>;
  getPlayerStatus(matchId: string, playerId: string): Promise<VerificationStatusView>;
  leaseNext(workerId: string, nowIso: string, leaseSec: number): Promise<VerificationBundle | null>;
  complete(input: CompleteVerificationInput, verification: VerifierVerificationConfig): Promise<VerificationStatusView>;
  fail(input: {
    workerId: string;
    leaseToken: string;
    jobId: string;
    startedAt: string;
    finishedAt: string;
    retryable: boolean;
    errorCode: string;
    diagnostics: JsonRecord;
    retryDelaySec: number;
  }): Promise<void>;
  expireReconnectGrace(nowIso: string, limit: number): Promise<number>;
}

export type VerifierVerificationConfig = {
  keyId: string;
  publicKeyPem: string;
  workerBuildId: string;
};

export function clientReportHash(input: ClientTerminalReportInput): string {
  return sha256Canonical({
    match_id: input.matchId,
    player_id: input.playerId,
    final_state_hash: input.finalStateHash,
    elapsed_sim_ticks: input.elapsedSimTicks,
    claimed_terminal_reason: input.claimedTerminalReason,
    claimed_winner_player_id: input.claimedWinnerPlayerId,
    diagnostics: input.diagnostics
  });
}

export function verificationInputHash(contract: DurableContract, commands: CommandReceipt[], lifecycleEvents: JsonRecord[]): string {
  return sha256Canonical({
    contract_id: contract.contractId,
    contract_hash: contract.contractHash,
    match_epoch: contract.matchEpoch,
    commands: commands.map((entry) => entry.command),
    lifecycle_events: lifecycleEvents
  });
}

export function validateClientReport(input: ClientTerminalReportInput): void {
  if (!input.requestId.trim() || !/^[0-9a-f]{64}$/.test(input.finalStateHash)
    || !Number.isSafeInteger(input.elapsedSimTicks) || input.elapsedSimTicks < 0
    || !["OBJECTIVE_COMPLETE", "TIME_LIMIT_PLACEMENT", "FORFEIT_DISCONNECT",
      "FORFEIT_VOLUNTARY", "NO_CONTEST"].includes(input.claimedTerminalReason)
    || (input.claimedWinnerPlayerId != null && !isUuidV7(input.claimedWinnerPlayerId))) {
    throw new DurableCoreError("client_terminal_report_invalid");
  }
}

export function verifySignedSyncResult(
  signed: SignedSyncResult,
  bundle: VerificationBundle,
  config: VerifierVerificationConfig
): JsonRecord {
  if (signed.algorithm !== "ES256" || signed.keyId !== config.keyId || !config.publicKeyPem
    || signed.payloadHash !== sha256Canonical(signed.payload)) {
    throw new DurableCoreError("verifier_signature_invalid");
  }
  let signature: Buffer;
  try { signature = Buffer.from(signed.signature, "base64url"); } catch { throw new DurableCoreError("verifier_signature_invalid"); }
  if (signature.length !== 64 || !crypto.verify("sha256", Buffer.from(canonicalJson(signed.payload), "utf8"), {
    key: config.publicKeyPem,
    dsaEncoding: "ieee-p1363"
  }, signature)) throw new DurableCoreError("verifier_signature_invalid");
  const payload = deepClone(signed.payload);
  const contract = bundle.contract;
  if (payload.result_id !== bundle.resultId || payload.result_schema_version !== 1
    || payload.match_id !== contract.matchId || payload.contract_id !== contract.contractId
    || payload.match_epoch !== contract.matchEpoch || payload.contract_hash !== contract.contractHash
    || payload.authority_method !== bundle.authorityMethod || payload.final_command_seq !== bundle.finalCommandSeq
    || payload.command_log_hash !== bundle.commandLogHash || payload.sim_build_id !== contract.simBuildId
    || payload.worker_build_id !== config.workerBuildId || payload.verified_at !== bundle.receiptIssuedAt
    || payload.verifier_key_id !== config.keyId) {
    throw new DurableCoreError("verifier_result_binding_mismatch");
  }
  validateResultShape(payload, contract);
  return payload;
}

export function terminalInputFromVerified(payload: JsonRecord): {
  resultId: string;
  matchId: string;
  contractId: string;
  matchEpoch: number;
  terminalReason: string;
  contractHash: string;
  finalCommandSeq: number;
  commandLogHash: string;
  result: JsonRecord;
  verifiedAt: string;
} {
  return {
    resultId: String(payload.result_id),
    matchId: String(payload.match_id),
    contractId: String(payload.contract_id),
    matchEpoch: Number(payload.match_epoch),
    terminalReason: String(payload.terminal_reason),
    contractHash: String(payload.contract_hash),
    finalCommandSeq: Number(payload.final_command_seq),
    commandLogHash: String(payload.command_log_hash),
    result: deepClone(payload),
    verifiedAt: String(payload.verified_at)
  };
}

function validateResultShape(payload: JsonRecord, contract: DurableContract): void {
  const terminalReason = String(payload.terminal_reason ?? "");
  const placements = Array.isArray(payload.placements) ? payload.placements as JsonRecord[] : [];
  if (!["OBJECTIVE_COMPLETE", "TIME_LIMIT_PLACEMENT", "FORFEIT_DISCONNECT",
    "FORFEIT_VOLUNTARY", "NO_CONTEST"].includes(terminalReason)) throw new DurableCoreError("verifier_result_invalid");
  if (!Number.isSafeInteger(payload.elapsed_sim_ticks) || Number(payload.elapsed_sim_ticks) < 0
    || (payload.final_state_hash != null && !/^[0-9a-f]{64}$/.test(String(payload.final_state_hash)))) {
    throw new DurableCoreError("verifier_result_invalid");
  }
  if (terminalReason === "NO_CONTEST") {
    if (placements.length !== 0 || payload.winning_team_id != null || !String(payload.no_contest_reason ?? "")) {
      throw new DurableCoreError("verifier_result_invalid");
    }
    return;
  }
  const playerIds = placements.flatMap((group) => Array.isArray(group.player_ids) ? group.player_ids.map(String) : []);
  const expected = contract.roster.map((entry) => entry.playerId).filter((value): value is string => value != null).sort();
  if (placements.length !== 2 || playerIds.length !== expected.length
    || playerIds.sort().join("|") !== expected.join("|") || placements.some((group, index) => Number(group.place) !== index + 1)) {
    throw new DurableCoreError("verifier_placements_invalid");
  }
  if (payload.authority_method === "SIM_REPLAY"
    && !/^[0-9a-f]{64}$/.test(String(payload.final_state_hash ?? ""))) {
    throw new DurableCoreError("verifier_result_invalid");
  }
  if (payload.authority_method === "SERVER_LIFECYCLE" && payload.final_state_hash != null) {
    throw new DurableCoreError("verifier_result_invalid");
  }
}
