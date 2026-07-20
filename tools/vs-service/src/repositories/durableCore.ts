import crypto from "node:crypto";

export type JsonRecord = Record<string, unknown>;

export type RosterEntry = {
  playerId: string | null;
  publicEntapId?: string | null;
  displayName: string;
  participantType: "HUMAN" | "BOT";
  botProfileId?: string | null;
  seatId: number;
  teamId?: number | null;
  colorId: string;
  partyId?: string | null;
  rankValue?: number | null;
  readyState: "NOT_READY" | "READY" | "LOCKED";
  connectionState: "CONNECTED" | "GRACE" | "DISCONNECTED";
  joinedAt: string;
};

export type CreateContractInput = {
  requestId: string;
  idempotencySubject: string;
  legacySessionId?: string | null;
  minimumClientBuild: string;
  simBuildId: string;
  modeId: string;
  rulesetId: string;
  rulesetHash: string;
  mapId: string;
  mapHash: string;
  seed: string;
  authorityTier: "RELAY_ATTESTED" | "AUTHORITY_VERIFIED";
  status: "FORMING" | "FROZEN" | "RUNNING";
  assignmentPolicyId: string;
  roster: RosterEntry[];
  rankPolicy: JsonRecord;
  economyPolicy: JsonRecord;
  practicePolicy: JsonRecord;
  createdAt: string;
  expiresAt: string;
};

export type DurableContract = {
  contractId: string;
  matchId: string;
  legacySessionId: string | null;
  protocolVersion: 2;
  commandSchemaVersion: 1;
  resultSchemaVersion: 1;
  minimumClientBuild: string;
  simBuildId: string;
  modeId: string;
  rulesetId: string;
  rulesetHash: string;
  mapId: string;
  mapHash: string;
  seed: string;
  authorityTier: "RELAY_ATTESTED" | "AUTHORITY_VERIFIED";
  matchEpoch: number;
  requiredPlayers: number;
  status: "FORMING" | "FROZEN" | "RUNNING" | "RECONNECTING" | "VERIFYING" | "TERMINAL" | "CANCELLED";
  contractHash: string;
  roster: RosterEntry[];
  contractJson: JsonRecord;
  createdAt: string;
  expiresAt: string;
};

export type ReconnectState = {
  matchId: string;
  playerId: string;
  matchEpoch: number;
  reconnectEpoch: number;
  connectionState: "CONNECTED" | "GRACE" | "DISCONNECTED";
  graceDeadlineAt: string | null;
  lastSeenAt: string;
};

export type AppendCommandInput = {
  matchId: string;
  matchEpoch: number;
  playerId: string;
  seatId: number;
  clientCommandId: string;
  issuedTick: number;
  requestedExecuteTick: number;
  command: JsonRecord;
  receivedAt: string;
};

export type CommandReceipt = {
  matchId: string;
  matchEpoch: number;
  commandSeq: number;
  contractId: string;
  playerId: string;
  seatId: number;
  clientCommandId: string;
  issuedTick: number;
  requestedExecuteTick: number;
  executeTick: number;
  requestHash: string;
  commandHash: string;
  command: JsonRecord;
  receivedAt: string;
  committedAt: string;
  duplicate: boolean;
};

export type CommandPage = {
  afterSeq: number;
  highWaterSeq: number;
  events: CommandReceipt[];
};

export type TerminalResultInput = {
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
};

export type TerminalResult = TerminalResultInput & {
  payloadHash: string;
  duplicate: boolean;
};

export type OutboxEventInput = {
  topic: string;
  recipientPlayerId?: string | null;
  aggregateType: string;
  aggregateId: string;
  dedupeNamespace: string;
  dedupeKey: string;
  payload: JsonRecord;
  availableAt: string;
};

export type OutboxEvent = OutboxEventInput & {
  eventId: string;
  status: "PENDING" | "DELIVERED" | "DEAD_LETTER";
  deliveryAttempts: number;
  deliveredAt: string | null;
  createdAt: string;
  duplicate: boolean;
};

export interface DurableCoreRepository {
  createContract(input: CreateContractInput): Promise<{ contract: DurableContract; duplicate: boolean }>;
  getContractById(contractId: string): Promise<DurableContract | null>;
  getContractByMatchId(matchId: string): Promise<DurableContract | null>;
  listRecoverableContracts(nowIso: string): Promise<DurableContract[]>;
  updateContractStatus(contractId: string, status: DurableContract["status"], updatedAt: string): Promise<DurableContract>;
  setReconnectState(input: ReconnectState): Promise<ReconnectState>;
  getReconnectStates(matchId: string): Promise<ReconnectState[]>;
  appendCommand(input: AppendCommandInput): Promise<CommandReceipt>;
  readCommands(matchId: string, matchEpoch: number, afterSeq: number): Promise<CommandPage>;
  saveTerminalResult(input: TerminalResultInput): Promise<TerminalResult>;
  getTerminalResult(matchId: string, matchEpoch: number): Promise<TerminalResult | null>;
  enqueueOutbox(input: OutboxEventInput): Promise<OutboxEvent>;
  listPendingOutbox(recipientPlayerId: string, limit: number): Promise<OutboxEvent[]>;
  acknowledgeOutbox(eventId: string, recipientPlayerId: string, deliveredAt: string): Promise<OutboxEvent>;
}

export class DurableCoreError extends Error {
  constructor(readonly code: string) {
    super(code);
    this.name = "DurableCoreError";
  }
}

export function uuidV7(nowMs = Date.now()): string {
  if (!Number.isSafeInteger(nowMs) || nowMs < 0 || nowMs > 0xffffffffffff) {
    throw new DurableCoreError("invalid_uuid_timestamp");
  }
  const bytes = crypto.randomBytes(16);
  let timestamp = BigInt(nowMs);
  for (let i = 5; i >= 0; i -= 1) {
    bytes[i] = Number(timestamp & 0xffn);
    timestamp >>= 8n;
  }
  bytes[6] = 0x70 | (bytes[6] & 0x0f);
  bytes[8] = 0x80 | (bytes[8] & 0x3f);
  const hex = bytes.toString("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

export function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

export function isUuidV7(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

export function canonicalJson(value: unknown): string {
  return JSON.stringify(canonicalValue(value));
}

export function sha256Canonical(value: unknown): string {
  return crypto.createHash("sha256").update(canonicalJson(value), "utf8").digest("hex");
}

export function deepClone<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

export function validateContractInput(input: CreateContractInput): void {
  if (!input.requestId.trim() || !input.idempotencySubject.trim() || !input.modeId.trim()
    || !input.rulesetId.trim() || !input.mapId.trim() || !input.simBuildId.trim()) {
    throw new DurableCoreError("invalid_contract_input");
  }
  if (!/^[0-9a-f]{64}$/.test(input.rulesetHash) || !/^[0-9a-f]{64}$/.test(input.mapHash)) {
    throw new DurableCoreError("invalid_content_hash");
  }
  if (!/^\d{1,20}$/.test(input.seed) || BigInt(input.seed) > 18_446_744_073_709_551_615n) {
    throw new DurableCoreError("invalid_seed");
  }
  if (input.roster.length < 2 || input.roster.length > 4) {
    throw new DurableCoreError("invalid_roster_size");
  }
  const players = new Set<string>();
  const colors = new Set<string>();
  input.roster.forEach((entry, index) => {
    if (entry.seatId !== index + 1 || !entry.displayName.trim() || !entry.colorId.trim() || colors.has(entry.colorId)) {
      throw new DurableCoreError("invalid_roster_entry");
    }
    colors.add(entry.colorId);
    if (entry.participantType === "HUMAN") {
      if (!entry.playerId || !isUuidV7(entry.playerId) || entry.botProfileId || players.has(entry.playerId)) {
        throw new DurableCoreError("invalid_roster_identity");
      }
      players.add(entry.playerId);
    } else if (entry.playerId || !entry.botProfileId) {
      throw new DurableCoreError("invalid_bot_identity");
    }
    parseIso(entry.joinedAt, "invalid_joined_at");
  });
  const created = parseIso(input.createdAt, "invalid_created_at");
  const expires = parseIso(input.expiresAt, "invalid_expires_at");
  if (expires.getTime() <= created.getTime()) throw new DurableCoreError("invalid_expires_at");
}

export function materializeContract(input: CreateContractInput, ids: {
  contractId?: string;
  matchId?: string;
} = {}): DurableContract {
  validateContractInput(input);
  const contractId = ids.contractId ?? uuidV7();
  const matchId = ids.matchId ?? uuidV7();
  const contractWithoutHash: JsonRecord = {
    contract_id: contractId,
    match_id: matchId,
    legacy_session_id: input.legacySessionId ?? null,
    protocol_version: 2,
    command_schema_version: 1,
    result_schema_version: 1,
    minimum_client_build: input.minimumClientBuild,
    sim_build_id: input.simBuildId,
    mode_id: input.modeId,
    ruleset_id: input.rulesetId,
    ruleset_hash: input.rulesetHash,
    map_id: input.mapId,
    map_hash: input.mapHash,
    seed: input.seed,
    authority_tier: input.authorityTier,
    match_epoch: 1,
    roster: {
      roster_version: 2,
      formed_at: input.createdAt,
      frozen_at: input.status === "FORMING" ? null : input.createdAt,
      assignment_policy_id: input.assignmentPolicyId,
      entries: input.roster.map(rosterJson)
    },
    required_players: input.roster.length,
    rank_policy: deepClone(input.rankPolicy),
    economy_policy: deepClone(input.economyPolicy),
    practice_policy: deepClone(input.practicePolicy),
    created_at: input.createdAt,
    expires_at: input.expiresAt,
    status: input.status
  };
  const contractHash = sha256Canonical(contractWithoutHash);
  const contractJson = { ...contractWithoutHash, contract_hash: contractHash };
  return {
    contractId,
    matchId,
    legacySessionId: input.legacySessionId ?? null,
    protocolVersion: 2,
    commandSchemaVersion: 1,
    resultSchemaVersion: 1,
    minimumClientBuild: input.minimumClientBuild,
    simBuildId: input.simBuildId,
    modeId: input.modeId,
    rulesetId: input.rulesetId,
    rulesetHash: input.rulesetHash,
    mapId: input.mapId,
    mapHash: input.mapHash,
    seed: input.seed,
    authorityTier: input.authorityTier,
    matchEpoch: 1,
    requiredPlayers: input.roster.length,
    status: input.status,
    contractHash,
    roster: deepClone(input.roster),
    contractJson,
    createdAt: input.createdAt,
    expiresAt: input.expiresAt
  };
}

export function contractRequestHash(input: CreateContractInput): string {
  const { requestId: _requestId, ...request } = input;
  return sha256Canonical(request);
}

export function commandRequestHash(input: AppendCommandInput): string {
  return sha256Canonical({
    match_id: input.matchId,
    match_epoch: input.matchEpoch,
    player_id: input.playerId,
    seat_id: input.seatId,
    client_command_id: input.clientCommandId,
    issued_tick: input.issuedTick,
    requested_execute_tick: input.requestedExecuteTick,
    command_schema_version: 1,
    command: input.command
  });
}

export function outboxRequestHash(input: OutboxEventInput): string {
  return sha256Canonical({
    topic: input.topic,
    recipient_player_id: input.recipientPlayerId ?? null,
    aggregate_type: input.aggregateType,
    aggregate_id: input.aggregateId,
    dedupe_namespace: input.dedupeNamespace,
    dedupe_key: input.dedupeKey,
    payload: input.payload,
    available_at: input.availableAt
  });
}

export function validateTerminalResultInput(input: TerminalResultInput): void {
  if (!isUuidV7(input.resultId) || !isUuidV7(input.matchId) || !isUuidV7(input.contractId)
    || !Number.isSafeInteger(input.matchEpoch) || input.matchEpoch < 1
    || !Number.isSafeInteger(input.finalCommandSeq) || input.finalCommandSeq < 0
    || !/^[0-9a-f]{64}$/.test(input.contractHash) || !/^[0-9a-f]{64}$/.test(input.commandLogHash)
    || !["OBJECTIVE_COMPLETE", "TIME_LIMIT_PLACEMENT", "FORFEIT_DISCONNECT",
      "FORFEIT_VOLUNTARY", "NO_CONTEST"].includes(input.terminalReason)) {
    throw new DurableCoreError("invalid_terminal_result");
  }
  parseIso(input.verifiedAt, "invalid_verified_at");
}

export function canonicalCommand(input: AppendCommandInput, commandSeq: number, executeTick: number): JsonRecord {
  return {
    ...deepClone(input.command),
    command_schema_version: 1,
    command_seq: commandSeq,
    command_id: `${input.matchId}:${input.matchEpoch}:${commandSeq}`,
    match_id: input.matchId,
    match_epoch: input.matchEpoch,
    player_id: input.playerId,
    seat_id: input.seatId,
    client_command_id: input.clientCommandId,
    issued_tick: input.issuedTick,
    requested_execute_tick: input.requestedExecuteTick,
    execute_tick: executeTick,
    authority_action: executeTick === input.requestedExecuteTick ? "accepted" : "rebased"
  };
}

function rosterJson(entry: RosterEntry): JsonRecord {
  return {
    player_id: entry.playerId,
    public_entap_id: entry.publicEntapId ?? null,
    display_name: entry.displayName,
    participant_type: entry.participantType,
    bot_profile_id: entry.botProfileId ?? null,
    seat_id: entry.seatId,
    team_id: entry.teamId ?? null,
    color_id: entry.colorId,
    party_id: entry.partyId ?? null,
    rank_value: entry.rankValue ?? null,
    ready_state: entry.readyState,
    connection_state: entry.connectionState,
    joined_at: entry.joinedAt
  };
}

function canonicalValue(value: unknown): unknown {
  if (value == null || typeof value === "string" || typeof value === "boolean") return value;
  if (typeof value === "number") {
    if (!Number.isSafeInteger(value)) throw new DurableCoreError("canonical_number_must_be_integer");
    return value;
  }
  if (Array.isArray(value)) return value.map(canonicalValue);
  if (typeof value === "object") {
    const record = value as JsonRecord;
    const result: JsonRecord = {};
    for (const key of Object.keys(record).sort()) {
      if (record[key] !== undefined) result[key] = canonicalValue(record[key]);
    }
    return result;
  }
  throw new DurableCoreError("canonical_value_unsupported");
}

function parseIso(value: string, code: string): Date {
  const date = new Date(value);
  if (!value || !Number.isFinite(date.getTime()) || date.toISOString() !== value) {
    throw new DurableCoreError(code);
  }
  return date;
}
