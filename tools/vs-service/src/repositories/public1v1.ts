import {
  deepClone,
  DurableCoreError,
  sha256Canonical,
  type AppendCommandInput,
  type CommandPage,
  type CommandReceipt,
  type DurableContract,
  type JsonRecord,
  type RosterEntry
} from "./durableCore.js";

export type Public1v1Player = {
  playerId: string;
  displayName: string;
  publicEntapId?: string;
};

export type PublicDuelQueueMode = "STANDARD_1V1" | "CTF_1V1" | "HCTF_1V1";
export type PublicDuelContractMode = PublicDuelQueueMode | "CTF_BOT" | "HCTF_BOT";

export type Public1v1Policy = {
  modeId: PublicDuelQueueMode;
  clientMode: "1V1" | "CAPTURE_FLAG" | "HIDDEN_CAPTURE_FLAG";
  vsRuleset: "STANDARD" | "CAPTURE_FLAG" | "HIDDEN_CAPTURE_FLAG";
  minimumClientBuild: string;
  simBuildId: string;
  rulesetId: string;
  rulesetHash: string;
  mapId: string;
  mapHash: string;
  queueTtlSec: number;
  sessionTtlSec: number;
  reconnectGraceSec: number;
  authorityTier: "RELAY_ATTESTED" | "AUTHORITY_VERIFIED";
  ranked: boolean;
};

export type PublicBotFallbackInput = {
  ticketId: string;
  playerId: string;
  requestId: string;
  nowIso: string;
  thresholdSec: number;
  botProfileId: string;
  botDisplayName: string;
};

export type PublicBotFallbackOffer = {
  eligible: boolean;
  modeId: PublicDuelQueueMode;
  selectedMode: "CAPTURE_FLAG" | "HIDDEN_CAPTURE_FLAG";
  waitedSec: number;
  remainingSec: number;
};

export type EnqueuePublic1v1Input = {
  requestId: string;
  player: Public1v1Player;
  protocolVersion: number;
  clientBuild: string;
  nowIso: string;
  policy: Public1v1Policy;
};

export type Public1v1Ticket = {
  ticketId: string;
  playerId: string;
  status: "WAITING" | "MATCHED" | "CANCELLED" | "EXPIRED";
  contractId: string | null;
  matchId: string | null;
  createdAt: string;
  expiresAt: string;
};

export type Public1v1QueueResult = {
  ticket: Public1v1Ticket;
  session: JsonRecord | null;
  duplicate: boolean;
};

export type LifecycleInput = {
  matchId: string;
  playerId: string;
  requestId: string;
  nowIso: string;
};

export interface Public1v1Repository {
  enqueue(input: EnqueuePublic1v1Input): Promise<Public1v1QueueResult>;
  poll(ticketId: string, playerId: string, nowIso: string): Promise<Public1v1QueueResult>;
  cancel(ticketId: string, playerId: string, requestId: string, nowIso: string): Promise<Public1v1QueueResult>;
  getBotFallbackOffer(ticketId: string, playerId: string, nowIso: string, thresholdSec: number): Promise<PublicBotFallbackOffer>;
  acceptBotFallback(input: PublicBotFallbackInput): Promise<JsonRecord>;
  getSession(matchId: string, playerId: string): Promise<JsonRecord>;
  setReady(input: LifecycleInput & { ready: boolean }): Promise<JsonRecord>;
  start(input: LifecycleInput): Promise<JsonRecord>;
  leave(input: LifecycleInput, reconnectGraceSec: number): Promise<JsonRecord>;
  resume(playerId: string, requestId: string, nowIso: string): Promise<JsonRecord>;
  appendCommand(input: AppendCommandInput): Promise<CommandReceipt>;
  readCommands(matchId: string, matchEpoch: number, playerId: string, afterSeq: number): Promise<CommandPage>;
}

export function publicQueueRequestHash(input: EnqueuePublic1v1Input): string {
  return sha256Canonical({
    player_id: input.player.playerId,
    display_name: input.player.displayName,
    public_entap_id: input.player.publicEntapId ?? null,
    protocol_version: input.protocolVersion,
    client_build: input.clientBuild,
    policy: input.policy
  });
}

export function publicQueueCompatibilityHash(input: EnqueuePublic1v1Input): string {
  return sha256Canonical({
    mode_id: input.policy.modeId,
    protocol_version: input.protocolVersion,
    minimum_client_build: input.policy.minimumClientBuild,
    sim_build_id: input.policy.simBuildId,
    ruleset_id: input.policy.rulesetId,
    ruleset_hash: input.policy.rulesetHash,
    map_id: input.policy.mapId,
    map_hash: input.policy.mapHash,
    authority_tier: input.policy.authorityTier,
    ranked: input.policy.ranked
  });
}

export function validatePublic1v1Enqueue(input: EnqueuePublic1v1Input): void {
  if (input.protocolVersion !== 2) throw new DurableCoreError("protocol_incompatible");
  if (!input.requestId.trim() || !input.clientBuild.trim() || !input.player.displayName.trim()
    || !/^[0-9a-f]{64}$/.test(input.policy.rulesetHash) || !/^[0-9a-f]{64}$/.test(input.policy.mapHash)
    || !input.policy.minimumClientBuild.trim() || !input.policy.simBuildId.trim()
    || !input.policy.rulesetId.trim() || !input.policy.mapId.trim()
    || !["STANDARD_1V1", "CTF_1V1", "HCTF_1V1"].includes(input.policy.modeId)) {
    throw new DurableCoreError("durable_1v1_contract_not_configured");
  }
  if (input.clientBuild.localeCompare(input.policy.minimumClientBuild) < 0) {
    throw new DurableCoreError("client_build_too_old");
  }
}

export function publicSessionView(contract: DurableContract, rosterOverride?: RosterEntry[]): JsonRecord {
  const roster = deepClone(rosterOverride ?? contract.roster).map((entry) => ({
    uid: entry.playerId ?? `bot_${entry.botProfileId ?? "unknown"}`,
    player_id: entry.playerId,
    public_entap_id: entry.publicEntapId ?? null,
    display_name: entry.displayName,
    participant_type: entry.participantType,
    seat: entry.seatId,
    seat_id: entry.seatId,
    role: entry.seatId === 1 ? "host" : "player",
    team_id: entry.teamId ?? entry.seatId,
    color_id: entry.colorId,
    ready: entry.readyState === "READY" || entry.readyState === "LOCKED",
    ready_state: entry.readyState,
    connection_state: entry.connectionState
  }));
  const compatibilityEmpty = { uid: "", player_id: null, display_name: "", ready: false };
  const rankPolicy = recordValue(contract.contractJson.rank_policy);
  const economyPolicy = recordValue(contract.contractJson.economy_policy);
  const practicePolicy = recordValue(contract.contractJson.practice_policy);
  const presentation = presentationForMode(contract.modeId);
  const practice = practicePolicy.practice === true;
  const economic = String(economyPolicy.policy_id ?? "NONE") !== "NONE";
  return {
    id: contract.matchId,
    session_id: contract.matchId,
    contract_id: contract.contractId,
    match_id: contract.matchId,
    legacy_session_id: contract.legacySessionId,
    contract_version: contract.protocolVersion,
    protocol_version: contract.protocolVersion,
    command_schema_version: contract.commandSchemaVersion,
    result_schema_version: contract.resultSchemaVersion,
    match_epoch: contract.matchEpoch,
    contract_hash: contract.contractHash,
    authority_tier: contract.authorityTier,
    status: compatibilityStatus(contract.status, roster),
    lifecycle_status: contract.status,
    required_players: contract.requiredPlayers,
    roster,
    host: roster[0] ?? compatibilityEmpty,
    guest: roster[1] ?? compatibilityEmpty,
    context: {
      mode: presentation.clientMode,
      vs_mode: presentation.clientMode,
      mode_id: contract.modeId,
      vs_ruleset: presentation.vsRuleset,
      ruleset_id: contract.rulesetId,
      ruleset_hash: contract.rulesetHash,
      map_id: contract.mapId,
      map_hash: contract.mapHash,
      sim_build_id: contract.simBuildId,
      match_seed: presentation.clientMode === "HIDDEN_CAPTURE_FLAG" ? null : contract.seed,
      ctf_flag_selection_mode: presentation.clientMode === "CAPTURE_FLAG" ? "auto_random" : null,
      ctf_player_select_pct: presentation.clientMode === "CAPTURE_FLAG" ? 0 : null,
      ctf_randomize_flag_hive: presentation.clientMode === "CAPTURE_FLAG",
      ctf_flag_move_count_max: 0,
      ctf_flag_move_reveals: true,
      human_pvp: !practice,
      free_roll: true,
      paid_entry: false,
      ranked: rankPolicy.enabled === true,
      economic,
      practice,
      bot_fill: practicePolicy.bot_fill === true,
      authority_tier: contract.authorityTier,
      authenticated_slice: true,
      durable_contract: true
    },
    created_at: contract.createdAt,
    expires_at: contract.expiresAt
  };
}

function presentationForMode(modeId: string): {
  clientMode: "1V1" | "CAPTURE_FLAG" | "HIDDEN_CAPTURE_FLAG";
  vsRuleset: "STANDARD" | "CAPTURE_FLAG" | "HIDDEN_CAPTURE_FLAG";
} {
  if (["CTF_1V1", "CTF_BOT"].includes(modeId)) {
    return { clientMode: "CAPTURE_FLAG", vsRuleset: "CAPTURE_FLAG" };
  }
  if (["HCTF_1V1", "HCTF_BOT"].includes(modeId)) {
    return { clientMode: "HIDDEN_CAPTURE_FLAG", vsRuleset: "HIDDEN_CAPTURE_FLAG" };
  }
  return { clientMode: "1V1", vsRuleset: "STANDARD" };
}

function recordValue(value: unknown): JsonRecord {
  return typeof value === "object" && value != null && !Array.isArray(value) ? value as JsonRecord : {};
}

function compatibilityStatus(status: DurableContract["status"], roster: JsonRecord[]): string {
  if (status === "RUNNING") return "started";
  if (status === "TERMINAL" || status === "CANCELLED") return "closed";
  if (status === "RECONNECTING") return "reconnecting";
  return roster.length === 2 && roster.every((entry) => Boolean(entry.ready)) ? "ready" : "matched";
}
