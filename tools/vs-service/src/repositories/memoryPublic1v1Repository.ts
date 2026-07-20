import {
  deepClone,
  DurableCoreError,
  sha256Canonical,
  uuidV7,
  type AppendCommandInput,
  type CommandPage,
  type CommandReceipt,
  type DurableContract,
  type DurableCoreRepository,
  type JsonRecord,
  type ReconnectState,
  type RosterEntry
} from "./durableCore.js";
import {
  publicQueueCompatibilityHash,
  publicQueueRequestHash,
  publicSessionView,
  validatePublic1v1Enqueue,
  type EnqueuePublic1v1Input,
  type LifecycleInput,
  type Public1v1Policy,
  type PublicBotFallbackInput,
  type PublicBotFallbackOffer,
  type Public1v1QueueResult,
  type Public1v1Repository,
  type Public1v1Ticket
} from "./public1v1.js";

type StoredTicket = Public1v1Ticket & {
  displayName: string;
  publicEntapId: string | null;
  requestId: string;
  requestHash: string;
  compatibilityHash: string;
  modeId: Public1v1Policy["modeId"];
  policy: Public1v1Policy;
  lastSeenAt: string;
};

type MatchState = {
  contract: DurableContract;
  roster: RosterEntry[];
  reconnect: Map<string, ReconnectState>;
};

export class MemoryPublic1v1Repository implements Public1v1Repository {
  private readonly tickets = new Map<string, StoredTicket>();
  private readonly matches = new Map<string, MatchState>();
  private readonly lifecycleReceipts = new Map<string, { requestHash: string; response: JsonRecord }>();
  private readonly botFallbackReceipts = new Map<string, { requestHash: string; response: JsonRecord }>();

  constructor(private readonly core: DurableCoreRepository) {}

  async enqueue(input: EnqueuePublic1v1Input): Promise<Public1v1QueueResult> {
    validatePublic1v1Enqueue(input);
    this.expireTickets(input.nowIso);
    const requestHash = publicQueueRequestHash(input);
    const compatibilityHash = publicQueueCompatibilityHash(input);
    const existingByRequest = [...this.tickets.values()].find((ticket) => ticket.playerId === input.player.playerId
      && ticket.modeId === input.policy.modeId
      && ticket.requestId === input.requestId);
    if (existingByRequest) {
      if (existingByRequest.requestHash !== requestHash) throw new DurableCoreError("idempotency_conflict");
      return this.queueResult(existingByRequest, true);
    }
    const existingWaiting = [...this.tickets.values()].find((ticket) => ticket.playerId === input.player.playerId
      && ticket.modeId === input.policy.modeId
      && ticket.status === "WAITING");
    if (existingWaiting) return this.queueResult(existingWaiting, true);

    const createdAt = input.nowIso;
    const ticket: StoredTicket = {
      ticketId: uuidV7(),
      playerId: input.player.playerId,
      status: "WAITING",
      contractId: null,
      matchId: null,
      displayName: input.player.displayName,
      publicEntapId: input.player.publicEntapId ?? null,
      requestId: input.requestId,
      requestHash,
      compatibilityHash,
      modeId: input.policy.modeId,
      policy: deepClone(input.policy),
      createdAt,
      lastSeenAt: createdAt,
      expiresAt: new Date(new Date(createdAt).getTime() + input.policy.queueTtlSec * 1_000).toISOString()
    };
    const candidate = [...this.tickets.values()]
      .filter((entry) => entry.status === "WAITING" && entry.playerId !== ticket.playerId
        && entry.compatibilityHash === compatibilityHash)
      .sort((a, b) => a.createdAt.localeCompare(b.createdAt) || a.ticketId.localeCompare(b.ticketId))[0];
    this.tickets.set(ticket.ticketId, ticket);
    if (!candidate) return this.queueResult(ticket, false);

    const contractCreatedAt = input.nowIso;
    const roster = [candidate, ticket].map((entry, index): RosterEntry => ({
      playerId: entry.playerId,
      publicEntapId: entry.publicEntapId,
      displayName: entry.displayName,
      participantType: "HUMAN",
      seatId: index + 1,
      teamId: index + 1,
      colorId: index === 0 ? "GREEN" : "PURPLE",
      readyState: "NOT_READY",
      connectionState: "CONNECTED",
      joinedAt: contractCreatedAt
    }));
    const created = await this.core.createContract({
      requestId: `pair:${candidate.ticketId}:${ticket.ticketId}`,
      idempotencySubject: `${input.policy.modeId}:matchmaker`,
      minimumClientBuild: input.policy.minimumClientBuild,
      simBuildId: input.policy.simBuildId,
      modeId: input.policy.modeId,
      rulesetId: input.policy.rulesetId,
      rulesetHash: input.policy.rulesetHash,
      mapId: input.policy.mapId,
      mapHash: input.policy.mapHash,
      seed: randomSeed(),
      authorityTier: input.policy.authorityTier,
      status: "FROZEN",
      assignmentPolicyId: "SERVER_SEATS_COLORS_V1",
      roster,
      rankPolicy: input.policy.ranked
        ? { enabled: true, queue: "GLOBAL_RANK", policy_id: "STANDARD_1V1_V1" }
        : { enabled: false, queue: "NONE", policy_id: "NONE" },
      economyPolicy: { policy_id: "NONE" },
      practicePolicy: { practice: false, bot_fill: false },
      createdAt: contractCreatedAt,
      expiresAt: new Date(new Date(contractCreatedAt).getTime() + input.policy.sessionTtlSec * 1_000).toISOString()
    });
    const state: MatchState = { contract: created.contract, roster: deepClone(roster), reconnect: new Map() };
    this.matches.set(created.contract.matchId, state);
    for (const matchedTicket of [candidate, ticket]) {
      matchedTicket.status = "MATCHED";
      matchedTicket.contractId = created.contract.contractId;
      matchedTicket.matchId = created.contract.matchId;
    }
    return this.queueResult(ticket, false);
  }

  async poll(ticketId: string, playerId: string, nowIso: string): Promise<Public1v1QueueResult> {
    this.expireTickets(nowIso);
    const ticket = this.ticketForPlayer(ticketId, playerId);
    ticket.lastSeenAt = nowIso;
    return this.queueResult(ticket, false);
  }

  async cancel(ticketId: string, playerId: string, _requestId: string, nowIso: string): Promise<Public1v1QueueResult> {
    this.expireTickets(nowIso);
    const ticket = this.ticketForPlayer(ticketId, playerId);
    if (ticket.status === "WAITING") ticket.status = "CANCELLED";
    return this.queueResult(ticket, ticket.status !== "CANCELLED");
  }

  async getBotFallbackOffer(ticketId: string, playerId: string, nowIso: string, thresholdSec: number): Promise<PublicBotFallbackOffer> {
    this.expireTickets(nowIso);
    const ticket = this.ticketForPlayer(ticketId, playerId);
    if (!["CTF_1V1", "HCTF_1V1"].includes(ticket.modeId)) throw new DurableCoreError("bot_fallback_mode_unsupported");
    const waitedSec = Math.max(0, Math.floor((new Date(nowIso).getTime() - new Date(ticket.createdAt).getTime()) / 1_000));
    const remainingSec = Math.max(0, thresholdSec - waitedSec);
    return {
      eligible: ticket.status === "WAITING" && remainingSec === 0,
      modeId: ticket.modeId,
      selectedMode: ticket.modeId === "HCTF_1V1" ? "HIDDEN_CAPTURE_FLAG" : "CAPTURE_FLAG",
      waitedSec,
      remainingSec
    };
  }

  async acceptBotFallback(input: PublicBotFallbackInput): Promise<JsonRecord> {
    const ticket = this.ticketForPlayer(input.ticketId, input.playerId);
    const requestHash = sha256Canonical({
      action: "accept_bot_fallback", ticket_id: input.ticketId, player_id: input.playerId,
      bot_profile_id: input.botProfileId
    });
    const receiptKey = `${input.ticketId}|${input.playerId}|${input.requestId}`;
    const receipt = this.botFallbackReceipts.get(receiptKey);
    if (receipt) {
      if (receipt.requestHash !== requestHash) throw new DurableCoreError("idempotency_conflict");
      return { ...deepClone(receipt.response), duplicate: true };
    }
    const offer = await this.getBotFallbackOffer(input.ticketId, input.playerId, input.nowIso, input.thresholdSec);
    if (!offer.eligible) throw new DurableCoreError("bot_fallback_not_eligible");
    const policy = ticket.policy;
    const roster: RosterEntry[] = [{
      playerId: ticket.playerId,
      publicEntapId: ticket.publicEntapId,
      displayName: ticket.displayName,
      participantType: "HUMAN",
      seatId: 1,
      teamId: 1,
      colorId: "GREEN",
      readyState: "NOT_READY",
      connectionState: "CONNECTED",
      joinedAt: input.nowIso
    }, {
      playerId: null,
      displayName: input.botDisplayName,
      participantType: "BOT",
      botProfileId: input.botProfileId,
      seatId: 2,
      teamId: 2,
      colorId: "PURPLE",
      readyState: "READY",
      connectionState: "CONNECTED",
      joinedAt: input.nowIso
    }];
    const created = await this.core.createContract({
      requestId: `bot:${ticket.ticketId}:${input.requestId}`,
      idempotencySubject: `${ticket.modeId}:bot-fallback`,
      minimumClientBuild: policy.minimumClientBuild,
      simBuildId: policy.simBuildId,
      modeId: ticket.modeId === "HCTF_1V1" ? "HCTF_BOT" : "CTF_BOT",
      rulesetId: policy.rulesetId,
      rulesetHash: policy.rulesetHash,
      mapId: policy.mapId,
      mapHash: policy.mapHash,
      seed: randomSeed(),
      authorityTier: policy.authorityTier,
      status: "FROZEN",
      assignmentPolicyId: "SERVER_SEATS_CANONICAL_BOT_V1",
      roster,
      rankPolicy: { enabled: false, queue: "NONE", policy_id: "NONE" },
      economyPolicy: { policy_id: "NONE" },
      practicePolicy: { practice: true, bot_fill: true, bot_profile_id: input.botProfileId },
      createdAt: input.nowIso,
      expiresAt: new Date(new Date(input.nowIso).getTime() + policy.sessionTtlSec * 1_000).toISOString()
    });
    ticket.status = "CANCELLED";
    const state: MatchState = { contract: created.contract, roster: deepClone(roster), reconnect: new Map() };
    this.matches.set(created.contract.matchId, state);
    const response = this.view(state);
    this.botFallbackReceipts.set(receiptKey, { requestHash, response: deepClone(response) });
    return { ...response, duplicate: false };
  }

  async getSession(matchId: string, playerId: string): Promise<JsonRecord> {
    return this.sessionForPlayer(matchId, playerId);
  }

  async setReady(input: LifecycleInput & { ready: boolean }): Promise<JsonRecord> {
    return this.idempotentLifecycle("ready", input, { ready: input.ready }, () => {
      const state = this.matchForPlayer(input.matchId, input.playerId);
      if (!["FROZEN", "FORMING"].includes(state.contract.status)) throw new DurableCoreError("match_not_ready_mutable");
      const entry = state.roster.find((candidate) => candidate.playerId === input.playerId)!;
      entry.readyState = input.ready ? "READY" : "NOT_READY";
      return this.view(state);
    });
  }

  async start(input: LifecycleInput): Promise<JsonRecord> {
    const result = await this.idempotentLifecycle("start", input, {}, () => {
      const state = this.matchForPlayer(input.matchId, input.playerId);
      if (state.contract.status === "RUNNING") return this.view(state);
      if (state.contract.status !== "FROZEN" || !state.roster.every((entry) => entry.readyState === "READY")) {
        throw new DurableCoreError("roster_not_ready");
      }
      state.roster.forEach((entry) => { entry.readyState = "LOCKED"; });
      state.contract.status = "RUNNING";
      return this.view(state);
    });
    const state = this.matchForPlayer(input.matchId, input.playerId);
    await this.core.updateContractStatus(state.contract.contractId, state.contract.status, input.nowIso);
    return result;
  }

  async leave(input: LifecycleInput, reconnectGraceSec: number): Promise<JsonRecord> {
    const result = await this.idempotentLifecycle("leave", input, { reconnect_grace_sec: reconnectGraceSec }, () => {
      const state = this.matchForPlayer(input.matchId, input.playerId);
      const entry = state.roster.find((candidate) => candidate.playerId === input.playerId)!;
      if (["FROZEN", "FORMING"].includes(state.contract.status)) {
        entry.connectionState = "DISCONNECTED";
        state.contract.status = "CANCELLED";
      } else if (["RUNNING", "RECONNECTING"].includes(state.contract.status)) {
        entry.connectionState = "GRACE";
        const previous = state.reconnect.get(input.playerId);
        state.reconnect.set(input.playerId, {
          matchId: input.matchId,
          playerId: input.playerId,
          matchEpoch: state.contract.matchEpoch,
          reconnectEpoch: (previous?.reconnectEpoch ?? 0) + 1,
          connectionState: "GRACE",
          graceDeadlineAt: new Date(new Date(input.nowIso).getTime() + reconnectGraceSec * 1_000).toISOString(),
          lastSeenAt: input.nowIso
        });
        state.contract.status = "RECONNECTING";
      }
      return this.view(state);
    });
    const state = this.matchForPlayer(input.matchId, input.playerId);
    await this.core.updateContractStatus(state.contract.contractId, state.contract.status, input.nowIso);
    return result;
  }

  async resume(playerId: string, requestId: string, nowIso: string): Promise<JsonRecord> {
    const state = [...this.matches.values()]
      .filter((candidate) => candidate.roster.some((entry) => entry.playerId === playerId)
        && ["FROZEN", "RUNNING", "RECONNECTING"].includes(candidate.contract.status))
      .sort((a, b) => b.contract.createdAt.localeCompare(a.contract.createdAt))[0];
    if (!state) throw new DurableCoreError("resumable_match_not_found");
    const result = await this.idempotentLifecycle("resume", {
      matchId: state.contract.matchId, playerId, requestId, nowIso
    }, {}, () => {
      const reconnect = state.reconnect.get(playerId);
      if (reconnect?.graceDeadlineAt && new Date(reconnect.graceDeadlineAt).getTime() < new Date(nowIso).getTime()) {
        throw new DurableCoreError("reconnect_grace_expired");
      }
      const entry = state.roster.find((candidate) => candidate.playerId === playerId)!;
      entry.connectionState = "CONNECTED";
      if (reconnect) {
        reconnect.connectionState = "CONNECTED";
        reconnect.graceDeadlineAt = null;
        reconnect.lastSeenAt = nowIso;
      }
      state.contract.status = state.roster.every((candidate) => candidate.connectionState === "CONNECTED")
        && state.roster.every((candidate) => candidate.readyState === "LOCKED") ? "RUNNING" : state.contract.status;
      return this.view(state);
    });
    await this.core.updateContractStatus(state.contract.contractId, state.contract.status, nowIso);
    return result;
  }

  async appendCommand(input: AppendCommandInput): Promise<CommandReceipt> {
    const state = this.matchForPlayer(input.matchId, input.playerId);
    if (!["RUNNING", "RECONNECTING"].includes(state.contract.status)) {
      throw new DurableCoreError("match_not_running");
    }
    return this.core.appendCommand(input);
  }

  async readCommands(matchId: string, matchEpoch: number, playerId: string, afterSeq: number): Promise<CommandPage> {
    this.matchForPlayer(matchId, playerId);
    return this.core.readCommands(matchId, matchEpoch, afterSeq);
  }

  private expireTickets(nowIso: string): void {
    const now = new Date(nowIso).getTime();
    for (const ticket of this.tickets.values()) {
      if (ticket.status === "WAITING" && new Date(ticket.expiresAt).getTime() < now) ticket.status = "EXPIRED";
    }
  }

  private ticketForPlayer(ticketId: string, playerId: string): StoredTicket {
    const ticket = this.tickets.get(ticketId);
    if (!ticket || ticket.playerId !== playerId) throw new DurableCoreError("queue_ticket_not_found");
    return ticket;
  }

  private async queueResult(ticket: StoredTicket, duplicate: boolean): Promise<Public1v1QueueResult> {
    const session = ticket.matchId ? await this.getSession(ticket.matchId, ticket.playerId) : null;
    return { ticket: publicTicket(ticket), session, duplicate };
  }

  private matchForPlayer(matchId: string, playerId: string): MatchState {
    const state = this.matches.get(matchId);
    if (!state || !state.roster.some((entry) => entry.playerId === playerId)) {
      throw new DurableCoreError("player_not_in_match");
    }
    return state;
  }

  private sessionForPlayer(matchId: string, playerId: string): JsonRecord {
    return this.view(this.matchForPlayer(matchId, playerId));
  }

  private view(state: MatchState): JsonRecord {
    return publicSessionView(state.contract, state.roster);
  }

  private async idempotentLifecycle(
    action: string,
    input: LifecycleInput,
    payload: JsonRecord,
    operation: () => JsonRecord
  ): Promise<JsonRecord> {
    const key = `${action}|${input.matchId}|${input.playerId}|${input.requestId}`;
    const requestHash = sha256Canonical({ action, match_id: input.matchId, player_id: input.playerId, ...payload });
    const receipt = this.lifecycleReceipts.get(key);
    if (receipt) {
      if (receipt.requestHash !== requestHash) throw new DurableCoreError("idempotency_conflict");
      return { ...deepClone(receipt.response), duplicate: true };
    }
    const response = operation();
    this.lifecycleReceipts.set(key, { requestHash, response: deepClone(response) });
    return { ...response, duplicate: false };
  }
}

function publicTicket(ticket: StoredTicket): Public1v1Ticket {
  return {
    ticketId: ticket.ticketId,
    playerId: ticket.playerId,
    status: ticket.status,
    contractId: ticket.contractId,
    matchId: ticket.matchId,
    createdAt: ticket.createdAt,
    expiresAt: ticket.expiresAt
  };
}

function randomSeed(): string {
  return BigInt(`0x${uuidV7().replaceAll("-", "").slice(-16)}`).toString(10);
}
