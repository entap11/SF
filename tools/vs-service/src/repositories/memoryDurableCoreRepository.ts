import {
  canonicalCommand,
  commandRequestHash,
  contractRequestHash,
  deepClone,
  DurableCoreError,
  materializeContract,
  outboxRequestHash,
  sha256Canonical,
  uuidV7,
  validateTerminalResultInput,
  type AppendCommandInput,
  type CommandPage,
  type CommandReceipt,
  type CreateContractInput,
  type DurableContract,
  type DurableCoreRepository,
  type OutboxEvent,
  type OutboxEventInput,
  type ReconnectState,
  type TerminalResult,
  type TerminalResultInput
} from "./durableCore.js";

type CommandStream = { nextSeq: number; lastExecuteTick: number; events: CommandReceipt[] };

export class MemoryDurableCoreRepository implements DurableCoreRepository {
  private readonly contractsById = new Map<string, DurableContract>();
  private readonly contractIdByMatchId = new Map<string, string>();
  private readonly contractReceipts = new Map<string, { requestHash: string; contractId: string }>();
  private readonly reconnectStates = new Map<string, ReconnectState>();
  private readonly streams = new Map<string, CommandStream>();
  private readonly terminalResults = new Map<string, TerminalResult>();
  private readonly outboxById = new Map<string, OutboxEvent>();
  private readonly outboxIdByDedupe = new Map<string, string>();

  async createContract(input: CreateContractInput): Promise<{ contract: DurableContract; duplicate: boolean }> {
    const receiptKey = `${input.idempotencySubject}|${input.requestId}`;
    const requestHash = contractRequestHash(input);
    const existingReceipt = this.contractReceipts.get(receiptKey);
    if (existingReceipt) {
      if (existingReceipt.requestHash !== requestHash) throw new DurableCoreError("idempotency_conflict");
      const contract = this.contractsById.get(existingReceipt.contractId);
      if (!contract) throw new DurableCoreError("idempotency_receipt_corrupt");
      return { contract: deepClone(contract), duplicate: true };
    }
    const contract = materializeContract(input);
    this.contractsById.set(contract.contractId, deepClone(contract));
    this.contractIdByMatchId.set(contract.matchId, contract.contractId);
    this.contractReceipts.set(receiptKey, { requestHash, contractId: contract.contractId });
    this.streams.set(streamKey(contract.matchId, contract.matchEpoch), { nextSeq: 1, lastExecuteTick: -1, events: [] });
    return { contract: deepClone(contract), duplicate: false };
  }

  async getContractById(contractId: string): Promise<DurableContract | null> {
    const contract = this.contractsById.get(contractId);
    return contract ? deepClone(contract) : null;
  }

  async getContractByMatchId(matchId: string): Promise<DurableContract | null> {
    const contractId = this.contractIdByMatchId.get(matchId);
    return contractId ? this.getContractById(contractId) : null;
  }

  async listRecoverableContracts(nowIso: string): Promise<DurableContract[]> {
    const now = new Date(nowIso).getTime();
    return [...this.contractsById.values()]
      .filter((contract) => ["FROZEN", "RUNNING", "RECONNECTING", "VERIFYING"].includes(contract.status)
        && new Date(contract.expiresAt).getTime() >= now)
      .map(deepClone);
  }

  async updateContractStatus(contractId: string, status: DurableContract["status"], _updatedAt: string): Promise<DurableContract> {
    const contract = this.contractsById.get(contractId);
    if (!contract) throw new DurableCoreError("contract_missing");
    contract.status = status;
    return deepClone(contract);
  }

  async setReconnectState(input: ReconnectState): Promise<ReconnectState> {
    const contract = await this.getContractByMatchId(input.matchId);
    if (!contract || contract.matchEpoch !== input.matchEpoch
      || !contract.roster.some((entry) => entry.playerId === input.playerId)) {
      throw new DurableCoreError("reconnect_player_not_in_match");
    }
    if (input.connectionState === "GRACE" && !input.graceDeadlineAt) {
      throw new DurableCoreError("reconnect_grace_deadline_required");
    }
    const copy = deepClone(input);
    this.reconnectStates.set(reconnectKey(input.matchId, input.playerId), copy);
    return deepClone(copy);
  }

  async getReconnectStates(matchId: string): Promise<ReconnectState[]> {
    return [...this.reconnectStates.values()].filter((state) => state.matchId === matchId).map(deepClone);
  }

  async appendCommand(input: AppendCommandInput): Promise<CommandReceipt> {
    const contract = await this.getContractByMatchId(input.matchId);
    const stream = this.streams.get(streamKey(input.matchId, input.matchEpoch));
    if (!stream) throw new DurableCoreError("command_stream_missing");
    const requestHash = commandRequestHash(input);
    const existing = stream.events.find((event) => event.clientCommandId === input.clientCommandId);
    if (existing) {
      if (existing.requestHash !== requestHash) throw new DurableCoreError("idempotency_conflict");
      return { ...deepClone(existing), duplicate: true };
    }
    validateCommandAgainstContract(input, contract);
    const commandSeq = stream.nextSeq;
    const executeTick = Math.max(input.requestedExecuteTick, input.issuedTick + 3, stream.lastExecuteTick + 1);
    const command = canonicalCommand(input, commandSeq, executeTick);
    const receipt: CommandReceipt = {
      matchId: input.matchId,
      matchEpoch: input.matchEpoch,
      commandSeq,
      contractId: contract!.contractId,
      playerId: input.playerId,
      seatId: input.seatId,
      clientCommandId: input.clientCommandId,
      issuedTick: input.issuedTick,
      requestedExecuteTick: input.requestedExecuteTick,
      executeTick,
      requestHash,
      commandHash: sha256Canonical(command),
      command,
      receivedAt: input.receivedAt,
      committedAt: new Date().toISOString(),
      duplicate: false
    };
    stream.events.push(deepClone(receipt));
    stream.nextSeq += 1;
    stream.lastExecuteTick = executeTick;
    return deepClone(receipt);
  }

  async readCommands(matchId: string, matchEpoch: number, afterSeq: number): Promise<CommandPage> {
    const stream = this.streams.get(streamKey(matchId, matchEpoch));
    if (!stream) throw new DurableCoreError("command_stream_missing");
    const highWaterSeq = stream.nextSeq - 1;
    for (let index = 0; index < stream.events.length; index += 1) {
      if (stream.events[index].commandSeq !== index + 1) throw new DurableCoreError("command_stream_gap");
    }
    return {
      afterSeq,
      highWaterSeq,
      events: stream.events.filter((event) => event.commandSeq > afterSeq).map(deepClone)
    };
  }

  async saveTerminalResult(input: TerminalResultInput): Promise<TerminalResult> {
    validateTerminalResultInput(input);
    const contract = await this.getContractByMatchId(input.matchId);
    if (!contract || contract.contractId !== input.contractId || contract.matchEpoch !== input.matchEpoch
      || contract.contractHash !== input.contractHash) {
      throw new DurableCoreError("result_contract_mismatch");
    }
    const stream = this.streams.get(streamKey(input.matchId, input.matchEpoch));
    if (!stream || input.finalCommandSeq !== stream.nextSeq - 1) {
      throw new DurableCoreError("result_command_high_water_mismatch");
    }
    if (input.commandLogHash !== sha256Canonical(stream.events.map((event) => event.command))) {
      throw new DurableCoreError("result_command_log_hash_mismatch");
    }
    const payloadHash = sha256Canonical(input.result);
    const key = streamKey(input.matchId, input.matchEpoch);
    const existing = this.terminalResults.get(key);
    if (existing) {
      if (existing.resultId !== input.resultId || existing.payloadHash !== payloadHash) {
        throw new DurableCoreError("idempotency_conflict");
      }
      return { ...deepClone(existing), duplicate: true };
    }
    const result: TerminalResult = { ...deepClone(input), payloadHash, duplicate: false };
    this.terminalResults.set(key, deepClone(result));
    const stored = this.contractsById.get(contract.contractId)!;
    stored.status = "TERMINAL";
    return deepClone(result);
  }

  async getTerminalResult(matchId: string, matchEpoch: number): Promise<TerminalResult | null> {
    const result = this.terminalResults.get(streamKey(matchId, matchEpoch));
    return result ? deepClone(result) : null;
  }

  async enqueueOutbox(input: OutboxEventInput): Promise<OutboxEvent> {
    const dedupe = `${input.dedupeNamespace}|${input.dedupeKey}`;
    const existingId = this.outboxIdByDedupe.get(dedupe);
    if (existingId) {
      const existing = this.outboxById.get(existingId)!;
      if (outboxRequestHash(existing) !== outboxRequestHash(input)) {
        throw new DurableCoreError("idempotency_conflict");
      }
      return { ...deepClone(existing), duplicate: true };
    }
    const event: OutboxEvent = {
      ...deepClone(input),
      recipientPlayerId: input.recipientPlayerId ?? null,
      eventId: uuidV7(),
      status: "PENDING",
      deliveryAttempts: 0,
      deliveredAt: null,
      createdAt: new Date().toISOString(),
      duplicate: false
    };
    this.outboxById.set(event.eventId, deepClone(event));
    this.outboxIdByDedupe.set(dedupe, event.eventId);
    return deepClone(event);
  }

  async listPendingOutbox(recipientPlayerId: string, limit: number): Promise<OutboxEvent[]> {
    const now = Date.now();
    return [...this.outboxById.values()]
      .filter((event) => event.recipientPlayerId === recipientPlayerId && event.status === "PENDING"
        && new Date(event.availableAt).getTime() <= now)
      .sort((a, b) => a.createdAt.localeCompare(b.createdAt) || a.eventId.localeCompare(b.eventId))
      .slice(0, Math.max(1, Math.min(100, limit)))
      .map(deepClone);
  }

  async acknowledgeOutbox(eventId: string, recipientPlayerId: string, deliveredAt: string): Promise<OutboxEvent> {
    const event = this.outboxById.get(eventId);
    if (!event || event.recipientPlayerId !== recipientPlayerId) throw new DurableCoreError("outbox_event_not_found");
    if (event.status === "PENDING") {
      event.status = "DELIVERED";
      event.deliveredAt = deliveredAt;
      event.deliveryAttempts += 1;
    }
    return deepClone(event);
  }
}

function validateCommandAgainstContract(input: AppendCommandInput, contract: DurableContract | null): void {
  if (!contract || contract.matchEpoch !== input.matchEpoch) {
    throw new DurableCoreError("command_contract_unavailable");
  }
  if (!["RUNNING", "RECONNECTING"].includes(contract.status)) throw new DurableCoreError("match_not_running");
  if (!input.clientCommandId.trim() || !Number.isSafeInteger(input.issuedTick) || input.issuedTick < 0
    || !Number.isSafeInteger(input.requestedExecuteTick) || input.requestedExecuteTick < 0) {
    throw new DurableCoreError("invalid_command");
  }
  const entry = contract.roster.find((candidate) => candidate.playerId === input.playerId);
  if (!entry || entry.seatId !== input.seatId) throw new DurableCoreError("command_sender_mismatch");
}

function streamKey(matchId: string, matchEpoch: number): string {
  return `${matchId}|${matchEpoch}`;
}

function reconnectKey(matchId: string, playerId: string): string {
  return `${matchId}|${playerId}`;
}
