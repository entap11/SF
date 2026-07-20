import {
  deepClone,
  DurableCoreError,
  sha256Canonical,
  uuidV7,
  type DurableCoreRepository,
  type JsonRecord,
  type TerminalResult
} from "./durableCore.js";
import {
  clientReportHash,
  terminalInputFromVerified,
  validateClientReport,
  verificationInputHash,
  verifySignedSyncResult,
  type ClientTerminalReport,
  type ClientTerminalReportInput,
  type CompleteVerificationInput,
  type SignedSyncResult,
  type VerificationBundle,
  type VerificationJobStatus,
  type VerificationRepository,
  type VerificationStatusView,
  type VerifierVerificationConfig
} from "./verificationAuthority.js";

type MemoryJob = {
  jobId: string;
  resultId: string;
  matchId: string;
  contractId: string;
  matchEpoch: number;
  inputHash: string;
  status: VerificationJobStatus;
  attemptCount: number;
  maxAttempts: number;
  leaseOwner: string | null;
  leaseToken: string | null;
  leaseExpiresAt: string | null;
  availableAt: string;
  receiptIssuedAt: string;
  completionHash: string | null;
};

export class MemoryVerificationRepository implements VerificationRepository {
  private readonly reports = new Map<string, ClientTerminalReport>();
  private readonly jobs = new Map<string, MemoryJob>();
  private readonly receipts = new Map<string, SignedSyncResult>();

  constructor(private readonly core: DurableCoreRepository) {}

  async submitClientReport(input: ClientTerminalReportInput): Promise<{ report: ClientTerminalReport; status: VerificationStatusView }> {
    validateClientReport(input);
    const contract = await this.core.getContractByMatchId(input.matchId);
    if (!contract || !contract.roster.some((entry) => entry.playerId === input.playerId)) {
      throw new DurableCoreError("player_not_in_match");
    }
    if (!["STANDARD_1V1", "CTF_1V1", "HCTF_1V1", "CRUCIBLE_1V1", "STANDARD_3P_FFA",
      "STANDARD_2V2", "STANDARD_4P_FFA"].includes(contract.modeId) || ![2, 3, 4].includes(contract.requiredPlayers)) {
      throw new DurableCoreError("verification_contract_unsupported");
    }
    if (contract.authorityTier !== "AUTHORITY_VERIFIED") throw new DurableCoreError("authority_tier_not_verifiable");
    const key = reportKey(input.matchId, contract.matchEpoch, input.playerId);
    const requestHash = clientReportHash(input);
    const existing = this.reports.get(key);
    if (existing) {
      if (existing.requestId !== input.requestId || existing.requestHash !== requestHash) {
        throw new DurableCoreError("idempotency_conflict");
      }
      return { report: { ...deepClone(existing), duplicate: true }, status: await this.status(contract.matchId, contract.matchEpoch) };
    }
    const report: ClientTerminalReport = {
      ...deepClone(input),
      reportId: uuidV7(),
      contractId: contract.contractId,
      matchEpoch: contract.matchEpoch,
      requestHash,
      duplicate: false
    };
    this.reports.set(key, report);
    const reports = this.reportsFor(input.matchId, contract.matchEpoch);
    if (reports.length === contract.requiredPlayers && !this.jobs.has(jobKey(input.matchId, contract.matchEpoch))) {
      const commands = (await this.core.readCommands(input.matchId, contract.matchEpoch, 0)).events;
      const nowIso = input.submittedAt;
      this.jobs.set(jobKey(input.matchId, contract.matchEpoch), {
        jobId: uuidV7(), resultId: uuidV7(), matchId: input.matchId, contractId: contract.contractId,
        matchEpoch: contract.matchEpoch, inputHash: verificationInputHash(contract, commands, []), status: "PENDING",
        attemptCount: 0, maxAttempts: 5, leaseOwner: null, leaseToken: null, leaseExpiresAt: null,
        availableAt: nowIso, receiptIssuedAt: nowIso, completionHash: null
      });
      await this.core.updateContractStatus(contract.contractId, "VERIFYING", nowIso);
    }
    return { report: deepClone(report), status: await this.status(contract.matchId, contract.matchEpoch) };
  }

  async getPlayerStatus(matchId: string, playerId: string): Promise<VerificationStatusView> {
    const contract = await this.core.getContractByMatchId(matchId);
    if (!contract || !contract.roster.some((entry) => entry.playerId === playerId)) {
      throw new DurableCoreError("player_not_in_match");
    }
    return this.status(matchId, contract.matchEpoch);
  }

  async leaseNext(workerId: string, nowIso: string, leaseSec: number): Promise<VerificationBundle | null> {
    const now = new Date(nowIso).getTime();
    const job = [...this.jobs.values()].filter((candidate) =>
      (["PENDING", "RETRY"].includes(candidate.status) && new Date(candidate.availableAt).getTime() <= now)
      || (candidate.status === "LEASED" && candidate.leaseExpiresAt != null
        && new Date(candidate.leaseExpiresAt).getTime() <= now))
      .sort((a, b) => a.availableAt.localeCompare(b.availableAt) || a.jobId.localeCompare(b.jobId))[0];
    if (!job) return null;
    job.status = "LEASED";
    job.attemptCount += 1;
    job.leaseOwner = workerId;
    job.leaseToken = uuidV7();
    job.leaseExpiresAt = new Date(now + leaseSec * 1_000).toISOString();
    return this.bundle(job);
  }

  async complete(input: CompleteVerificationInput, config: VerifierVerificationConfig): Promise<VerificationStatusView> {
    const found = [...this.jobs.values()].find((candidate) => candidate.jobId === input.jobId);
    if (!found) throw new DurableCoreError("verification_job_not_found");
    const completionHash = sha256Canonical(input.signedResult);
    if (["COMPLETED", "QUARANTINED"].includes(found.status)) {
      if (found.completionHash !== completionHash) throw new DurableCoreError("idempotency_conflict");
      return this.status(found.matchId, found.matchEpoch);
    }
    this.requireLease(found, input.workerId, input.leaseToken);
    const bundle = await this.bundle(found);
    const payload = verifySignedSyncResult(input.signedResult, bundle, config);
    const terminal = await this.core.saveTerminalResult(terminalInputFromVerified(payload));
    found.status = String(payload.terminal_reason) === "NO_CONTEST" ? "QUARANTINED" : "COMPLETED";
    found.completionHash = completionHash;
    found.leaseOwner = null;
    found.leaseToken = null;
    found.leaseExpiresAt = null;
    this.receipts.set(found.resultId, deepClone(input.signedResult));
    return this.status(found.matchId, found.matchEpoch, terminal);
  }

  async fail(input: {
    workerId: string; leaseToken: string; jobId: string; startedAt: string; finishedAt: string;
    retryable: boolean; errorCode: string; diagnostics: JsonRecord; retryDelaySec: number;
  }): Promise<void> {
    const job = [...this.jobs.values()].find((candidate) => candidate.jobId === input.jobId);
    if (!job) throw new DurableCoreError("verification_job_not_found");
    this.requireLease(job, input.workerId, input.leaseToken);
    job.status = input.retryable && job.attemptCount < job.maxAttempts ? "RETRY" : "FAILED";
    job.availableAt = new Date(new Date(input.finishedAt).getTime() + input.retryDelaySec * 1_000).toISOString();
    job.leaseOwner = null;
    job.leaseToken = null;
    job.leaseExpiresAt = null;
  }

  async expireReconnectGrace(_nowIso: string, _limit: number): Promise<number> { return 0; }

  private async bundle(job: MemoryJob): Promise<VerificationBundle> {
    const contract = await this.core.getContractById(job.contractId);
    if (!contract) throw new DurableCoreError("contract_missing");
    const commandPage = await this.core.readCommands(job.matchId, job.matchEpoch, 0);
    return {
      jobId: job.jobId, resultId: job.resultId, leaseToken: job.leaseToken ?? "", attempt: job.attemptCount,
      receiptIssuedAt: job.receiptIssuedAt, inputHash: job.inputHash, authorityMethod: "SIM_REPLAY",
      contract, commands: commandPage.events, lifecycleEvents: [],
      clientReports: this.reportsFor(job.matchId, job.matchEpoch),
      finalCommandSeq: commandPage.highWaterSeq,
      commandLogHash: sha256Canonical(commandPage.events.map((entry) => entry.command))
    };
  }

  private reportsFor(matchId: string, epoch: number): ClientTerminalReport[] {
    return [...this.reports.values()].filter((report) => report.matchId === matchId && report.matchEpoch === epoch)
      .map(deepClone);
  }

  private async status(matchId: string, epoch: number, knownResult?: TerminalResult): Promise<VerificationStatusView> {
    const job = this.jobs.get(jobKey(matchId, epoch));
    const result = knownResult ?? await this.core.getTerminalResult(matchId, epoch);
    const contract = await this.core.getContractByMatchId(matchId);
    return {
      matchId, matchEpoch: epoch, status: job?.status ?? "AWAITING_REPORTS",
      reportCount: this.reportsFor(matchId, epoch).length, requiredReportCount: contract?.requiredPlayers ?? 0,
      result, signedReceipt: result ? deepClone(this.receipts.get(result.resultId) ?? null) : null
    };
  }

  private requireLease(job: MemoryJob, workerId: string, leaseToken: string): void {
    if (job.status !== "LEASED" || job.leaseOwner !== workerId || job.leaseToken !== leaseToken) {
      throw new DurableCoreError("verification_lease_invalid");
    }
  }
}

function reportKey(matchId: string, epoch: number, playerId: string): string {
  return `${matchId}|${epoch}|${playerId}`;
}

function jobKey(matchId: string, epoch: number): string {
  return `${matchId}|${epoch}`;
}
