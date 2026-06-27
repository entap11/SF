import { createHash } from "node:crypto";
import { createCrucibleLedgerStore, type CrucibleLedgerStore } from "./crucibleLedgerStore.js";
import { evaluateWaxMatch } from "./waxRewardPolicy.js";

export type JsonRecord = Record<string, unknown>;

type CrucibleConfig = {
  enabled: boolean;
  queue_enabled: boolean;
  wagering_enabled: boolean;
  ads_enabled: boolean;
  capacity_cap_enabled: boolean;
  settlement_enabled: boolean;
  earn_path_buttons_enabled: boolean;
  config_version: number;
  capacity_max: number;
  reserved_slots: number;
  priority_access_enabled: boolean;
  pre_ad_seconds: number;
  post_ad_seconds: number;
  banner_ads_enabled: boolean;
  ticker_ads_enabled: boolean;
  stake_bps: number;
  burn_bps: number;
  minimum_stake_millis: number;
  rounding_mode: "FLOOR" | "NEAREST" | "CEIL";
  starting_crucible_wax_millis: number;
  launch_grant_enabled: boolean;
  launch_grant_millis: number;
  standard_pvp_win_earn_millis: number;
  standard_pvp_loss_earn_millis: number;
  tournament_placement_earn_millis: number;
  challenge_earn_millis: number;
  event_earn_millis: number;
  server_authoritative_settlement_required: boolean;
  local_dev_settlement_enabled: boolean;
};

type Escrow = {
  escrow_id: string;
  match_id: string;
  ruleset: "CRUCIBLE";
  player_a_id: string;
  player_b_id: string;
  stake_each: number;
  stake_unit: "wax_millis";
  pot: number;
  burn: number;
  winner_payout: number;
  config_version: number;
  config_hash: string;
  settlement_status: "ESCROWED" | "SETTLED" | "REFUNDED" | "NO_CONTEST" | "HELD_REVIEW";
  created_at: number;
  metadata: JsonRecord;
};

const BASIS_POINTS_DENOMINATOR = 10_000;
const RULESET_CRUCIBLE = "CRUCIBLE";
const HOUSE_BURN_ACCOUNT = "crucible_burn";
const SNAPSHOT_SCHEMA_VERSION = 1;
const SNAPSHOT_TYPE = "crucible_ledger";
const REPEATED_OPPONENT_WINDOW_SEC = 24 * 60 * 60;
const DEFAULT_CONFIG: CrucibleConfig = {
  enabled: true,
  queue_enabled: true,
  wagering_enabled: true,
  ads_enabled: true,
  capacity_cap_enabled: true,
  settlement_enabled: true,
  earn_path_buttons_enabled: true,
  config_version: 1,
  capacity_max: 100,
  reserved_slots: 0,
  priority_access_enabled: false,
  pre_ad_seconds: 25,
  post_ad_seconds: 12,
  banner_ads_enabled: true,
  ticker_ads_enabled: false,
  stake_bps: 500,
  burn_bps: 1000,
  minimum_stake_millis: 1000,
  rounding_mode: "FLOOR",
  starting_crucible_wax_millis: 0,
  launch_grant_enabled: false,
  launch_grant_millis: 0,
  standard_pvp_win_earn_millis: 250,
  standard_pvp_loss_earn_millis: 100,
  tournament_placement_earn_millis: 1000,
  challenge_earn_millis: 500,
  event_earn_millis: 500,
  server_authoritative_settlement_required: true,
  local_dev_settlement_enabled: false
};

function cleanString(value: unknown): string {
  return String(value ?? "").trim();
}

function intValue(value: unknown, fallback = 0): number {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? Math.trunc(numeric) : fallback;
}

function boolValue(value: unknown, fallback = false): boolean {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "number") {
    return value !== 0;
  }
  const normalized = cleanString(value).toLowerCase();
  if (!normalized) {
    return fallback;
  }
  return ["1", "true", "yes", "on"].includes(normalized);
}

function clone<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

function nowUnix(): number {
  return Math.floor(Date.now() / 1000);
}

function pseudoHash(value: string): string {
  let hash = 2166136261;
  for (let i = 0; i < value.length; i += 1) {
    hash ^= value.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0).toString(16).padStart(8, "0");
}

function configHash(config: CrucibleConfig): string {
  return createHash("sha256").update([
    `v:${config.config_version}`,
    `stake:${config.stake_bps}`,
    `burn:${config.burn_bps}`,
    `min:${config.minimum_stake_millis}`,
    `round:${config.rounding_mode}`,
    `wager:${config.wagering_enabled}`
  ].join("|")).digest("hex");
}

function error(code: string, message: string, extra: JsonRecord = {}): JsonRecord {
  return { ok: false, code, err: code, message, ...extra };
}

export class CrucibleLedger {
  private storeAdapter: CrucibleLedgerStore;
  private config: CrucibleConfig = { ...DEFAULT_CONFIG };
  private balances = new Map<string, number>();
  private escrowsById = new Map<string, Escrow>();
  private escrowIdByMatchId = new Map<string, string>();
  private settlementsByMatchId = new Map<string, JsonRecord>();
  private transactions: JsonRecord[] = [];
  private auditRecords: JsonRecord[] = [];
  private antiCollusionObservations: JsonRecord[] = [];
  private reviewRecordsByMatchId = new Map<string, JsonRecord>();
  private competitiveWaxAwardsByEvent = new Map<string, JsonRecord>();
  private waxStatsByPlayer = new Map<string, JsonRecord>();
  private operationResults = new Map<string, JsonRecord>();
  private nextTransactionSeq = 1;

  constructor(storeOrPath?: CrucibleLedgerStore | string) {
    this.storeAdapter = createCrucibleLedgerStore(storeOrPath);
    this.loadFromStore();
  }

  getConfigSnapshot(): JsonRecord {
    return { ...this.config, config_hash: configHash(this.config) };
  }

  getStorageSnapshot(): JsonRecord {
    return { kind: this.storeAdapter.kind };
  }

  updateConfig(patch: JsonRecord, actorId = "ops"): JsonRecord {
    const next = { ...this.config };
    for (const [key, value] of Object.entries(patch)) {
      if (!(key in next)) {
        continue;
      }
      const current = (next as unknown as JsonRecord)[key];
      if (typeof current === "boolean") {
        (next as unknown as JsonRecord)[key] = boolValue(value, current);
      } else if (typeof current === "number") {
        (next as unknown as JsonRecord)[key] = Math.max(0, intValue(value, current));
      } else if (typeof current === "string") {
        (next as unknown as JsonRecord)[key] = cleanString(value).toUpperCase() || current;
      }
    }
    next.stake_bps = Math.min(BASIS_POINTS_DENOMINATOR, next.stake_bps);
    next.burn_bps = Math.min(BASIS_POINTS_DENOMINATOR, next.burn_bps);
    next.config_version = Math.max(1, next.config_version);
    this.config = next;
    const record = {
      ok: true,
      type: "crucible_config_updated",
      actor_id: actorId,
      config: this.getConfigSnapshot(),
      created_at: nowUnix()
    };
    this.auditRecords.push(clone(record));
    this.persistToStore();
    return record;
  }

  setBalanceMillis(playerId: string, balanceMillis: number): JsonRecord {
    const cleanPlayer = cleanString(playerId);
    if (!cleanPlayer) {
      return error("missing_player_id", "Player id is required.");
    }
    this.balances.set(cleanPlayer, Math.max(0, intValue(balanceMillis)));
    this.persistToStore();
    return { ok: true, player_id: cleanPlayer, balance_millis: this.getBalanceMillis(cleanPlayer) };
  }

  getBalanceMillis(playerId: string): number {
    const cleanPlayer = cleanString(playerId);
    if (!cleanPlayer) {
      return 0;
    }
    this.ensurePlayer(cleanPlayer);
    return Math.max(0, this.balances.get(cleanPlayer) ?? 0);
  }

  previewEntryStatus(playerId: string, activeCrucibleCount = 0, hasPriorityAccess = false): JsonRecord {
    const cleanPlayer = cleanString(playerId);
    if (!cleanPlayer) {
      return error("missing_player_id", "Player id is required.");
    }
    if (!this.config.enabled || !this.config.queue_enabled) {
      return error("queue_disabled", "Crucible queue is disabled.", { player_id: cleanPlayer });
    }
    if (this.config.capacity_cap_enabled && !hasPriorityAccess) {
      const usable = Math.max(0, this.config.capacity_max - Math.max(0, this.config.reserved_slots));
      if (activeCrucibleCount >= usable) {
        return error("capacity", "Crucible at capacity.", { player_id: cleanPlayer, active_crucible_count: activeCrucibleCount });
      }
    }
    this.ensurePlayer(cleanPlayer);
    const balance = this.getBalanceMillis(cleanPlayer);
    if (balance < Math.max(1, this.config.minimum_stake_millis)) {
      return error("no_wax", "Your Wax Has Melted.", { player_id: cleanPlayer, balance_millis: balance });
    }
    return { ok: true, player_id: cleanPlayer, balance_millis: balance, active_crucible_count: Math.max(0, activeCrucibleCount) };
  }

  previewMatch(playerAId: string, playerBId: string): JsonRecord {
    const a = cleanString(playerAId);
    const b = cleanString(playerBId);
    if (!a || !b) {
      return error("missing_player_ids", "Both player ids are required.");
    }
    if (a === b) {
      return error("same_player_ids", "Crucible requires two distinct players.");
    }
    return this.previewStake(this.getBalanceMillis(a), this.getBalanceMillis(b));
  }

  openEscrow(matchId: string, playerAId: string, playerBId: string, metadata: JsonRecord = {}, idempotencyKey = ""): JsonRecord {
    const cleanKey = cleanString(idempotencyKey) || `open:${matchId}`;
    const cached = this.operationResults.get(cleanKey);
    if (cached) {
      return clone(cached);
    }
    const cleanMatch = cleanString(matchId);
    const a = cleanString(playerAId);
    const b = cleanString(playerBId);
    if (!cleanMatch) {
      return this.store(cleanKey, error("missing_match_id", "Match id is required."));
    }
    if (!a || !b) {
      return this.store(cleanKey, error("missing_player_ids", "Both player ids are required."));
    }
    if (a === b) {
      return this.store(cleanKey, error("same_player_ids", "Crucible requires two distinct players."));
    }
    if (this.escrowIdByMatchId.has(cleanMatch)) {
      const existing = this.escrowForMatch(cleanMatch);
      return this.store(cleanKey, { ok: true, escrow: existing, idempotent: true });
    }
    const expectedVersion = intValue(metadata.expected_config_version, 0);
    const expectedHash = cleanString(metadata.expected_config_hash);
    if (expectedVersion > 0 && expectedVersion !== this.config.config_version) {
      return this.store(cleanKey, error("config_version_mismatch", "Crucible config version mismatch.", this.getConfigSnapshot()));
    }
    if (expectedHash && expectedHash !== configHash(this.config)) {
      return this.store(cleanKey, error("config_hash_mismatch", "Crucible config hash mismatch.", this.getConfigSnapshot()));
    }
    if (!this.config.settlement_enabled || !this.config.wagering_enabled) {
      return this.store(cleanKey, error("settlement_disabled", "Crucible settlement is disabled."));
    }
    this.applyBalanceHint(a, metadata);
    this.applyBalanceHint(b, metadata);
    const preview = this.previewMatch(a, b);
    if (preview.ok !== true) {
      return this.store(cleanKey, preview);
    }
    const stakeEach = intValue(preview.stake_each);
    if (this.getBalanceMillis(a) < stakeEach || this.getBalanceMillis(b) < stakeEach) {
      return this.store(cleanKey, error("insufficient_wax", "Player cannot cover Crucible stake."));
    }
    this.balances.set(a, this.getBalanceMillis(a) - stakeEach);
    this.balances.set(b, this.getBalanceMillis(b) - stakeEach);
    const escrow: Escrow = {
      escrow_id: cleanString(metadata.escrow_id) || `ce_${pseudoHash(cleanMatch)}_${Date.now()}`,
      match_id: cleanMatch,
      ruleset: RULESET_CRUCIBLE,
      player_a_id: a,
      player_b_id: b,
      stake_each: stakeEach,
      stake_unit: "wax_millis",
      pot: intValue(preview.pot),
      burn: intValue(preview.burn),
      winner_payout: intValue(preview.winner_payout),
      config_version: this.config.config_version,
      config_hash: configHash(this.config),
      settlement_status: "ESCROWED",
      created_at: nowUnix(),
      metadata: clone(metadata)
    };
    this.escrowsById.set(escrow.escrow_id, escrow);
    this.escrowIdByMatchId.set(cleanMatch, escrow.escrow_id);
    this.appendTransaction("ESCROW_DEBIT", cleanMatch, a, -stakeEach, escrow.escrow_id, { side: "A" });
    this.appendTransaction("ESCROW_DEBIT", cleanMatch, b, -stakeEach, escrow.escrow_id, { side: "B" });
    this.recordAntiCollusionObservation(cleanMatch, a, b, metadata.anti_collusion_signals, stakeEach);
    const result = { ok: true, escrow: clone(escrow) };
    return this.store(cleanKey, result);
  }

  settleMatch(matchId: string, winnerId: string, resultSource: string, reason = "", metadata: JsonRecord = {}, idempotencyKey = ""): JsonRecord {
    const cleanMatch = cleanString(matchId);
    const cleanKey = cleanString(idempotencyKey) || `settle:${cleanMatch}:${cleanString(winnerId) || "none"}`;
    const cached = this.operationResults.get(cleanKey);
    if (cached) {
      return clone(cached);
    }
    if (this.settlementsByMatchId.has(cleanMatch)) {
      return this.store(cleanKey, { ok: true, settlement: clone(this.settlementsByMatchId.get(cleanMatch)), idempotent: true });
    }
    const escrow = this.escrowForMatch(cleanMatch);
    if (!escrow) {
      return this.store(cleanKey, error("escrow_not_found", "Crucible escrow was not found."));
    }
    const cleanSource = cleanString(resultSource).toUpperCase();
    if (!["SERVER_MATCH_RESULT", "AUTHORITATIVE_SIM"].includes(cleanSource)) {
      return this.store(cleanKey, this.noContest(escrow, cleanSource, cleanString(reason) || "invalid_result_source", metadata));
    }
    const cleanWinner = cleanString(winnerId);
    if (!cleanWinner || ![escrow.player_a_id, escrow.player_b_id].includes(cleanWinner)) {
      return this.store(cleanKey, this.noContest(escrow, cleanSource, cleanString(reason) || "no_winner", metadata));
    }
    const loser = cleanWinner === escrow.player_a_id ? escrow.player_b_id : escrow.player_a_id;
    const risk = this.riskAssessment(escrow, metadata);
    if (risk.hold) {
      escrow.settlement_status = "HELD_REVIEW";
      const settlement = this.settlementRecord(escrow, "HELD_REVIEW", cleanWinner, loser, cleanSource, cleanString(reason) || "held_for_review", {
        ...metadata,
        risk
      });
      settlement.burn = 0;
      settlement.winner_payout = 0;
      settlement.review_status = "held";
      settlement.review_reasons = risk.reasons;
      this.settlementsByMatchId.set(cleanMatch, settlement);
      this.reviewRecordsByMatchId.set(cleanMatch, clone(settlement));
      this.auditRecords.push(clone({ ...settlement, type: "crucible_settlement_held" }));
      return this.store(cleanKey, { ok: true, settlement: clone(settlement) });
    }
    this.balances.set(cleanWinner, this.getBalanceMillis(cleanWinner) + escrow.winner_payout);
    this.balances.set(HOUSE_BURN_ACCOUNT, this.getBalanceMillis(HOUSE_BURN_ACCOUNT) + escrow.burn);
    this.appendTransaction("BURN", cleanMatch, HOUSE_BURN_ACCOUNT, escrow.burn, escrow.escrow_id, {});
    this.appendTransaction("WINNER_PAYOUT", cleanMatch, cleanWinner, escrow.winner_payout, escrow.escrow_id, {});
    const loserBurnShare = Math.floor(escrow.burn / 2);
    const winnerBurnShare = Math.max(0, escrow.burn - loserBurnShare);
    this.applyWaxStats(cleanWinner, escrow.winner_payout, winnerBurnShare);
    this.applyWaxStats(loser, -Math.max(0, escrow.stake_each), loserBurnShare);
    escrow.settlement_status = "SETTLED";
    const settlement = this.settlementRecord(escrow, "SETTLED", cleanWinner, loser, cleanSource, cleanString(reason), metadata);
    this.settlementsByMatchId.set(cleanMatch, settlement);
    this.auditRecords.push(clone(settlement));
    return this.store(cleanKey, { ok: true, settlement: clone(settlement) });
  }

  refundMatch(matchId: string, reason = "refund", resultSource = "SERVER_MATCH_RESULT", metadata: JsonRecord = {}, idempotencyKey = ""): JsonRecord {
    const cleanMatch = cleanString(matchId);
    const cleanKey = cleanString(idempotencyKey) || `refund:${cleanMatch}:${reason}`;
    const cached = this.operationResults.get(cleanKey);
    if (cached) {
      return clone(cached);
    }
    const escrow = this.escrowForMatch(cleanMatch);
    if (!escrow) {
      return this.store(cleanKey, error("escrow_not_found", "Crucible escrow was not found."));
    }
    return this.store(cleanKey, this.refundFromEscrow(escrow, cleanString(reason), "REFUNDED", cleanString(resultSource), metadata));
  }

  recordLifecycle(matchId: string, eventType: string, playerId: string, metadata: JsonRecord = {}): JsonRecord {
    const escrow = this.escrowForMatch(matchId);
    if (!escrow) {
      return error("escrow_not_found", "Crucible escrow was not found.");
    }
    const event = cleanString(eventType).toLowerCase();
    if (event === "cancel_before_first_tick" || event === "desync" || event === "no_contest" || boolValue(metadata.server_fault)) {
      return this.refundMatch(matchId, event || "no_contest", "SERVER_MATCH_RESULT", metadata, `lifecycle:${matchId}:${event}`);
    }
    if (event === "voluntary_quit" || event === "disconnect_after_start" || event === "forfeit") {
      const loser = cleanString(playerId);
      const winner = loser === escrow.player_a_id ? escrow.player_b_id : loser === escrow.player_b_id ? escrow.player_a_id : "";
      return this.settleMatch(matchId, winner, "SERVER_MATCH_RESULT", event, { ...metadata, loser_id: loser }, `lifecycle:${matchId}:${event}:${loser}`);
    }
    return error("unknown_lifecycle_event", "Unknown Crucible lifecycle event.");
  }

  awardWax(playerId: string, amountMillis: number, source: string, metadata: JsonRecord = {}): JsonRecord {
    const cleanPlayer = cleanString(playerId);
    const amount = Math.max(0, intValue(amountMillis));
    if (!cleanPlayer) {
      return error("missing_player_id", "Player id is required.");
    }
    if (amount <= 0) {
      return { ok: true, awarded: false, player_id: cleanPlayer, amount_millis: 0 };
    }
    this.balances.set(cleanPlayer, this.getBalanceMillis(cleanPlayer) + amount);
    const transaction = this.appendTransaction("EARN", cleanString(metadata.match_id), cleanPlayer, amount, "", { source: cleanString(source), ...metadata });
    this.applyWaxStats(cleanPlayer, amount, 0);
    this.persistToStore();
    return { ok: true, awarded: true, player_id: cleanPlayer, amount_millis: amount, balance_millis: this.getBalanceMillis(cleanPlayer), transaction_id: transaction.transaction_id };
  }

  recordCompetitiveWaxResult(input: JsonRecord, idempotencyKey = ""): JsonRecord {
    const cleanMatch = cleanString(input.match_id);
    const cleanPlayer = cleanString(input.player_id);
    const cleanOpponent = cleanString(input.opponent_id);
    const metadata = this.recordValue(input.metadata);
    const eventId = cleanString(input.event_id ?? metadata.event_id) || `competitive_wax:${cleanMatch}:${cleanPlayer}`;
    const cleanKey = cleanString(idempotencyKey) || eventId;
    const cached = this.operationResults.get(cleanKey);
    if (cached) {
      return clone(cached);
    }
    if (!cleanMatch || !cleanPlayer) {
      return this.store(cleanKey, error("missing_wax_award_fields", "Match id and player id are required."));
    }
    const existing = this.competitiveWaxAwardsByEvent.get(eventId);
    if (existing) {
      return this.store(cleanKey, { ok: true, awarded: false, duplicate: true, event_id: eventId, award: clone(existing) });
    }
    const occurredAt = Math.max(1, intValue(input.occurred_unix, nowUnix()));
    const repeatedCount = input.repeated_opponent_count == null
      ? this.repeatedOpponentCount(cleanPlayer, cleanOpponent, occurredAt)
      : Math.max(0, intValue(input.repeated_opponent_count));
    const payload = {
      ...metadata,
      ...input,
      match_id: cleanMatch,
      player_id: cleanPlayer,
      opponent_id: cleanOpponent,
      repeated_opponent_count: repeatedCount
    };
    const breakdown = evaluateWaxMatch(payload);
    breakdown.event_id = eventId;
    breakdown.created_at = occurredAt;
    breakdown.repeated_opponent_count = repeatedCount;
    this.competitiveWaxAwardsByEvent.set(eventId, clone(breakdown));
    const status = cleanString(breakdown.validity_status) || "eligible";
    const deltaMillis = intValue(breakdown.final_wax_delta_millis);
    if (status === "blocked" || deltaMillis === 0) {
      const heldForReview = status === "held_review";
      const result = {
        ok: true,
        awarded: false,
        subtracted: false,
        held_for_review: heldForReview,
        event_id: eventId,
        breakdown: clone(breakdown),
        balance_millis: this.getBalanceMillis(cleanPlayer)
      };
      return this.store(cleanKey, result);
    }
    this.ensurePlayer(cleanPlayer);
    let appliedDelta = deltaMillis;
    if (deltaMillis < 0) {
      appliedDelta = -Math.min(this.getBalanceMillis(cleanPlayer), Math.abs(deltaMillis));
    }
    this.balances.set(cleanPlayer, Math.max(0, this.getBalanceMillis(cleanPlayer) + appliedDelta));
    this.applyWaxStats(cleanPlayer, appliedDelta, 0);
    const transaction = this.appendTransaction(
      appliedDelta > 0 ? "COMPETITIVE_WAX_AWARD" : "COMPETITIVE_WAX_LOSS",
      cleanMatch,
      cleanPlayer,
      appliedDelta,
      "",
      { event_id: eventId, opponent_id: cleanOpponent, breakdown: clone(breakdown) }
    );
    breakdown.applied_wax_delta_millis = appliedDelta;
    breakdown.balance_millis = this.getBalanceMillis(cleanPlayer);
    breakdown.transaction_id = transaction.transaction_id;
    this.competitiveWaxAwardsByEvent.set(eventId, clone(breakdown));
    const result = {
      ok: true,
      awarded: appliedDelta > 0,
      subtracted: appliedDelta < 0,
      event_id: eventId,
      breakdown: clone(breakdown),
      balance_millis: this.getBalanceMillis(cleanPlayer),
      transaction_id: transaction.transaction_id
    };
    return this.store(cleanKey, result);
  }

  resolveReview(matchId: string, action: string, actorId = "ops", metadata: JsonRecord = {}, idempotencyKey = ""): JsonRecord {
    const cleanMatch = cleanString(matchId);
    const cleanAction = cleanString(action).toLowerCase();
    const cleanKey = cleanString(idempotencyKey) || `review:${cleanMatch}:${cleanAction}`;
    const cached = this.operationResults.get(cleanKey);
    if (cached) {
      return clone(cached);
    }
    const held = this.reviewRecordsByMatchId.get(cleanMatch);
    if (!held || cleanString(held.settlement_status) !== "HELD_REVIEW") {
      return this.store(cleanKey, error("review_not_found", "No held Crucible settlement was found for this match."));
    }
    const escrow = this.escrowForMatch(cleanMatch);
    if (!escrow) {
      return this.store(cleanKey, error("escrow_not_found", "Crucible escrow was not found."));
    }
    if (cleanAction === "refund" || cleanAction === "void") {
      const refund = this.finalizeHeldRefund(escrow, cleanAction, actorId, metadata);
      return this.store(cleanKey, { ok: true, settlement: clone(refund) });
    }
    if (cleanAction === "approve" || cleanAction === "release") {
      const winnerId = cleanString(held.winner_id);
      if (!winnerId || ![escrow.player_a_id, escrow.player_b_id].includes(winnerId)) {
        return this.store(cleanKey, error("missing_held_winner", "Held settlement does not contain a valid winner."));
      }
      const release = this.finalizeHeldPayout(escrow, winnerId, actorId, metadata);
      return this.store(cleanKey, { ok: true, settlement: clone(release) });
    }
    return this.store(cleanKey, error("unknown_review_action", "Review action must be approve or refund."));
  }

  getSnapshot(): JsonRecord {
    return {
      snapshot_type: SNAPSHOT_TYPE,
      schema_version: SNAPSHOT_SCHEMA_VERSION,
      created_at: nowUnix(),
      storage: this.getStorageSnapshot(),
      config: this.getConfigSnapshot(),
      balances_by_player: Object.fromEntries(this.balances.entries()),
      escrows_by_id: Object.fromEntries([...this.escrowsById.entries()].map(([key, value]) => [key, clone(value)])),
      settlements_by_match_id: Object.fromEntries([...this.settlementsByMatchId.entries()].map(([key, value]) => [key, clone(value)])),
      ledger_entries: clone(this.transactions),
      audit_records: clone(this.auditRecords),
      anti_collusion_observations: clone(this.antiCollusionObservations),
      review_records_by_match_id: Object.fromEntries([...this.reviewRecordsByMatchId.entries()].map(([key, value]) => [key, clone(value)])),
      competitive_wax_awards_by_event: Object.fromEntries([...this.competitiveWaxAwardsByEvent.entries()].map(([key, value]) => [key, clone(value)])),
      wax_stats_by_player: Object.fromEntries([...this.waxStatsByPlayer.entries()].map(([key, value]) => [key, clone(value)])),
      operation_results: Object.fromEntries([...this.operationResults.entries()].map(([key, value]) => [key, clone(value)])),
      next_transaction_seq: this.nextTransactionSeq
    };
  }

  getWaxAuditSnapshot(filters: JsonRecord = {}): JsonRecord {
    const playerId = cleanString(filters.player_id);
    const statusFilter = cleanString(filters.validity_status ?? filters.status);
    const limit = Math.max(1, Math.min(500, intValue(filters.limit, 100)));
    const awards: JsonRecord[] = [];
    const heldReviews: JsonRecord[] = [];
    for (const awardRaw of this.competitiveWaxAwardsByEvent.values()) {
      const award = clone(awardRaw);
      if (playerId && cleanString(award.player_id) !== playerId) {
        continue;
      }
      if (statusFilter && cleanString(award.validity_status) !== statusFilter) {
        continue;
      }
      awards.push(award);
      if (cleanString(award.validity_status) === "held_review") {
        heldReviews.push(award);
      }
      if (awards.length >= limit) {
        break;
      }
    }
    const entries: JsonRecord[] = [];
    for (let i = this.transactions.length - 1; i >= 0; i -= 1) {
      const entry = clone(this.transactions[i]);
      if (playerId && cleanString(entry.player_id) !== playerId) {
        continue;
      }
      entries.push(entry);
      if (entries.length >= limit) {
        break;
      }
    }
    return {
      ok: true,
      filters: clone(filters),
      award_count: awards.length,
      held_review_count: heldReviews.length,
      ledger_entry_count: entries.length,
      awards,
      held_reviews: heldReviews,
      ledger_entries: entries
    };
  }

  private previewStake(balanceA: number, balanceB: number): JsonRecord {
    if (!this.config.wagering_enabled) {
      return error("wagering_disabled", "Crucible wagering is disabled.");
    }
    const lowerBalance = Math.min(Math.max(0, balanceA), Math.max(0, balanceB));
    if (lowerBalance < Math.max(1, this.config.minimum_stake_millis)) {
      return error("no_wax", "Your Wax Has Melted.");
    }
    let stake = Math.floor((lowerBalance * this.config.stake_bps) / BASIS_POINTS_DENOMINATOR);
    stake = Math.max(Math.max(1, this.config.minimum_stake_millis), stake);
    stake = Math.min(stake, lowerBalance);
    const pot = stake * 2;
    const burn = Math.floor((pot * this.config.burn_bps) / BASIS_POINTS_DENOMINATOR);
    return {
      ok: true,
      stake_each: stake,
      pot,
      burn,
      winner_payout: Math.max(0, pot - burn),
      config_version: this.config.config_version,
      config_hash: configHash(this.config)
    };
  }

  private noContest(escrow: Escrow, resultSource: string, reason: string, metadata: JsonRecord): JsonRecord {
    return this.refundFromEscrow(escrow, reason || "no_contest", "NO_CONTEST", resultSource, metadata);
  }

  private refundFromEscrow(escrow: Escrow, reason: string, status: "REFUNDED" | "NO_CONTEST", resultSource: string, metadata: JsonRecord): JsonRecord {
    if (this.settlementsByMatchId.has(escrow.match_id)) {
      return { ok: true, settlement: clone(this.settlementsByMatchId.get(escrow.match_id)), idempotent: true };
    }
    this.balances.set(escrow.player_a_id, this.getBalanceMillis(escrow.player_a_id) + escrow.stake_each);
    this.balances.set(escrow.player_b_id, this.getBalanceMillis(escrow.player_b_id) + escrow.stake_each);
    this.appendTransaction("ESCROW_REFUND", escrow.match_id, escrow.player_a_id, escrow.stake_each, escrow.escrow_id, { side: "A" });
    this.appendTransaction("ESCROW_REFUND", escrow.match_id, escrow.player_b_id, escrow.stake_each, escrow.escrow_id, { side: "B" });
    escrow.settlement_status = status;
    const settlement = this.settlementRecord(escrow, status, "", "", resultSource, reason, metadata);
    settlement.burn = 0;
    settlement.winner_payout = 0;
    this.settlementsByMatchId.set(escrow.match_id, settlement);
    this.auditRecords.push(clone(settlement));
    return { ok: true, settlement: clone(settlement) };
  }

  private settlementRecord(escrow: Escrow, status: string, winnerId: string, loserId: string, resultSource: string, reason: string, metadata: JsonRecord): JsonRecord {
    return {
      settlement_id: `cs_${pseudoHash(escrow.match_id)}_${Date.now()}`,
      escrow_id: escrow.escrow_id,
      match_id: escrow.match_id,
      ruleset: RULESET_CRUCIBLE,
      player_a_id: escrow.player_a_id,
      player_b_id: escrow.player_b_id,
      stake_each: escrow.stake_each,
      stake_unit: escrow.stake_unit,
      pot: escrow.pot,
      burn: escrow.burn,
      winner_payout: escrow.winner_payout,
      winner_id: winnerId,
      loser_id: loserId,
      result_source: resultSource,
      settlement_mode: "SERVER",
      config_version: escrow.config_version,
      config_hash: escrow.config_hash,
      settlement_status: status,
      idempotency_key: `settle:${escrow.match_id}:${status}`,
      reason,
      created_at: nowUnix(),
      metadata: clone(metadata)
    };
  }

  private escrowForMatch(matchId: string): Escrow | null {
    const escrowId = this.escrowIdByMatchId.get(cleanString(matchId));
    if (!escrowId) {
      return null;
    }
    return this.escrowsById.get(escrowId) ?? null;
  }

  private ensurePlayer(playerId: string): void {
    if (this.balances.has(playerId)) {
      return;
    }
    const launchGrant = this.config.launch_grant_enabled ? Math.max(0, this.config.launch_grant_millis) : 0;
    this.balances.set(playerId, Math.max(0, this.config.starting_crucible_wax_millis) + launchGrant);
  }

  private applyBalanceHint(playerId: string, metadata: JsonRecord): void {
    const hints = metadata.player_balance_millis_by_id;
    if (hints != null && typeof hints === "object" && !Array.isArray(hints)) {
      const hint = (hints as JsonRecord)[playerId];
      if (hint != null) {
        this.balances.set(playerId, Math.max(0, intValue(hint)));
        return;
      }
    }
    this.ensurePlayer(playerId);
  }

  private appendTransaction(entryType: string, matchId: string, playerId: string, amountMillis: number, escrowId: string, metadata: JsonRecord): JsonRecord {
    const transaction = {
      transaction_id: `CRUCIBLE-${String(this.nextTransactionSeq).padStart(9, "0")}`,
      entry_type: entryType,
      match_id: cleanString(matchId),
      escrow_id: escrowId,
      player_id: cleanString(playerId),
      amount_millis: intValue(amountMillis),
      created_at: nowUnix(),
      metadata: clone(metadata)
    };
    this.nextTransactionSeq += 1;
    this.transactions.push(transaction);
    return transaction;
  }

  private store(key: string, result: JsonRecord): JsonRecord {
    const cloned = clone(result);
    this.operationResults.set(key, cloned);
    this.persistToStore();
    return clone(cloned);
  }

  private loadFromStore(): void {
    const snapshot = this.storeAdapter.load();
    if (snapshot == null) {
      return;
    }
    try {
      this.hydrate(snapshot);
    } catch (err) {
      console.warn("CRUCIBLE_LEDGER_HYDRATE_FAILED", { store: this.storeAdapter.kind, err: err instanceof Error ? err.message : String(err) });
    }
  }

  private persistToStore(): void {
    this.storeAdapter.save(this.getSnapshot());
  }

  private hydrate(snapshot: JsonRecord): void {
    const snapshotType = cleanString(snapshot.snapshot_type);
    if (snapshotType && snapshotType !== SNAPSHOT_TYPE) {
      throw new Error(`unsupported Crucible ledger snapshot type: ${snapshotType}`);
    }
    const schemaVersion = intValue(snapshot.schema_version, 1);
    if (schemaVersion > SNAPSHOT_SCHEMA_VERSION) {
      throw new Error(`unsupported Crucible ledger snapshot schema: ${schemaVersion}`);
    }
    const config = snapshot.config;
    if (config != null && typeof config === "object" && !Array.isArray(config)) {
      const merged = { ...this.config };
      for (const [key, value] of Object.entries(config as JsonRecord)) {
        if (!(key in merged)) {
          continue;
        }
        const current = (merged as unknown as JsonRecord)[key];
        if (typeof current === "boolean") {
          (merged as unknown as JsonRecord)[key] = boolValue(value, current);
        } else if (typeof current === "number") {
          (merged as unknown as JsonRecord)[key] = Math.max(0, intValue(value, current));
        } else if (typeof current === "string") {
          (merged as unknown as JsonRecord)[key] = cleanString(value).toUpperCase() || current;
        }
      }
      merged.stake_bps = Math.min(BASIS_POINTS_DENOMINATOR, merged.stake_bps);
      merged.burn_bps = Math.min(BASIS_POINTS_DENOMINATOR, merged.burn_bps);
      merged.config_version = Math.max(1, merged.config_version);
      this.config = merged;
    }
    this.balances = new Map(Object.entries(this.recordValue(snapshot.balances_by_player)).map(([key, value]) => [key, Math.max(0, intValue(value))]));
    this.escrowsById = new Map(Object.entries(this.recordValue(snapshot.escrows_by_id)).map(([key, value]) => [key, clone(value) as Escrow]));
    this.escrowIdByMatchId = new Map();
    for (const escrow of this.escrowsById.values()) {
      if (escrow?.match_id && escrow?.escrow_id) {
        this.escrowIdByMatchId.set(cleanString(escrow.match_id), cleanString(escrow.escrow_id));
      }
    }
    this.settlementsByMatchId = new Map(Object.entries(this.recordValue(snapshot.settlements_by_match_id)).map(([key, value]) => [key, clone(value) as JsonRecord]));
    this.transactions = this.arrayValue(snapshot.ledger_entries).map((entry) => clone(entry) as JsonRecord);
    this.auditRecords = this.arrayValue(snapshot.audit_records).map((entry) => clone(entry) as JsonRecord);
    this.antiCollusionObservations = this.arrayValue(snapshot.anti_collusion_observations).map((entry) => clone(entry) as JsonRecord);
    this.reviewRecordsByMatchId = new Map(Object.entries(this.recordValue(snapshot.review_records_by_match_id)).map(([key, value]) => [key, clone(value) as JsonRecord]));
    this.competitiveWaxAwardsByEvent = new Map(Object.entries(this.recordValue(snapshot.competitive_wax_awards_by_event)).map(([key, value]) => [key, clone(value) as JsonRecord]));
    this.waxStatsByPlayer = new Map(Object.entries(this.recordValue(snapshot.wax_stats_by_player)).map(([key, value]) => [key, clone(value) as JsonRecord]));
    this.operationResults = new Map(Object.entries(this.recordValue(snapshot.operation_results)).map(([key, value]) => [key, clone(value) as JsonRecord]));
    this.nextTransactionSeq = Math.max(1, intValue(snapshot.next_transaction_seq, this.inferNextTransactionSeq()));
  }

  private repeatedOpponentCount(playerId: string, opponentId: string, occurredAt: number): number {
    if (!playerId || !opponentId) {
      return 0;
    }
    const windowStart = Math.max(0, occurredAt - REPEATED_OPPONENT_WINDOW_SEC);
    let count = 0;
    for (const award of this.competitiveWaxAwardsByEvent.values()) {
      if (cleanString(award.player_id) !== playerId || cleanString(award.opponent_id) !== opponentId) {
        continue;
      }
      const createdAt = intValue(award.created_at, 0);
      if (createdAt >= windowStart && createdAt <= occurredAt) {
        count += 1;
      }
    }
    return count;
  }

  private applyWaxStats(playerId: string, deltaMillis: number, burnedMillis: number): void {
    const cleanPlayer = cleanString(playerId);
    if (!cleanPlayer) {
      return;
    }
    const existing = this.waxStatsByPlayer.get(cleanPlayer) ?? {};
    const current = {
      lifetime_wax_won: intValue(existing.lifetime_wax_won),
      lifetime_wax_lost: intValue(existing.lifetime_wax_lost),
      lifetime_wax_burned: intValue(existing.lifetime_wax_burned),
      lifetime_wax_net: intValue(existing.lifetime_wax_net),
      largest_wax_award: intValue(existing.largest_wax_award),
      largest_wax_loss: intValue(existing.largest_wax_loss)
    };
    const delta = intValue(deltaMillis);
    const burned = Math.max(0, intValue(burnedMillis));
    if (delta > 0) {
      current.lifetime_wax_won += delta;
      current.largest_wax_award = Math.max(current.largest_wax_award, delta);
    } else if (delta < 0) {
      const loss = Math.abs(delta);
      current.lifetime_wax_lost += loss;
      current.largest_wax_loss = Math.max(current.largest_wax_loss, loss);
    }
    current.lifetime_wax_burned += burned;
    current.lifetime_wax_net = current.lifetime_wax_won - current.lifetime_wax_lost - current.lifetime_wax_burned;
    this.waxStatsByPlayer.set(cleanPlayer, current);
  }

  private recordAntiCollusionObservation(matchId: string, playerAId: string, playerBId: string, signals: unknown, stakeEach: number): void {
    const cleanSignals = this.recordValue(signals);
    this.antiCollusionObservations.push({
      match_id: cleanString(matchId),
      player_a_id: cleanString(playerAId),
      player_b_id: cleanString(playerBId),
      stake_each: Math.max(0, intValue(stakeEach)),
      repeated_same_opponent: boolValue(cleanSignals.repeated_same_opponent),
      unusual_win_trading: boolValue(cleanSignals.unusual_win_trading),
      same_device_cluster: boolValue(cleanSignals.same_device_cluster),
      same_ip_pattern: boolValue(cleanSignals.same_ip_pattern),
      suspicious_forfeit: boolValue(cleanSignals.suspicious_forfeit),
      high_stakes_repeated_transfer: boolValue(cleanSignals.high_stakes_repeated_transfer),
      signals: clone(cleanSignals),
      created_at: nowUnix()
    });
  }

  private riskAssessment(escrow: Escrow, settlementMetadata: JsonRecord): { hold: boolean; reasons: string[] } {
    const reasons: string[] = [];
    const combinedSignals = {
      ...this.recordValue(escrow.metadata.anti_collusion_signals),
      ...this.recordValue(settlementMetadata.anti_collusion_signals),
      ...settlementMetadata
    };
    const riskFlags = [
      "unusual_win_trading",
      "same_device_cluster",
      "same_ip_pattern",
      "suspicious_forfeit",
      "high_stakes_repeated_transfer"
    ];
    for (const flag of riskFlags) {
      if (boolValue((combinedSignals as JsonRecord)[flag])) {
        reasons.push(flag);
      }
    }
    if (boolValue((combinedSignals as JsonRecord).repeated_same_opponent) && escrow.stake_each >= Math.max(1, this.config.minimum_stake_millis * 5)) {
      reasons.push("repeated_same_opponent_high_stake");
    }
    return { hold: reasons.length > 0, reasons };
  }

  private finalizeHeldPayout(escrow: Escrow, winnerId: string, actorId: string, metadata: JsonRecord): JsonRecord {
    const loser = winnerId === escrow.player_a_id ? escrow.player_b_id : escrow.player_a_id;
    this.balances.set(winnerId, this.getBalanceMillis(winnerId) + escrow.winner_payout);
    this.balances.set(HOUSE_BURN_ACCOUNT, this.getBalanceMillis(HOUSE_BURN_ACCOUNT) + escrow.burn);
    this.appendTransaction("BURN", escrow.match_id, HOUSE_BURN_ACCOUNT, escrow.burn, escrow.escrow_id, { review_release: true, actor_id: actorId });
    this.appendTransaction("WINNER_PAYOUT", escrow.match_id, winnerId, escrow.winner_payout, escrow.escrow_id, { review_release: true, actor_id: actorId });
    const loserBurnShare = Math.floor(escrow.burn / 2);
    const winnerBurnShare = Math.max(0, escrow.burn - loserBurnShare);
    this.applyWaxStats(winnerId, escrow.winner_payout, winnerBurnShare);
    this.applyWaxStats(loser, -Math.max(0, escrow.stake_each), loserBurnShare);
    escrow.settlement_status = "SETTLED";
    const settlement = this.settlementRecord(escrow, "SETTLED", winnerId, loser, "ADMIN_REVIEW", "review_release", {
      ...metadata,
      reviewed_by: actorId
    });
    settlement.review_status = "approved";
    this.settlementsByMatchId.set(escrow.match_id, settlement);
    this.reviewRecordsByMatchId.set(escrow.match_id, clone(settlement));
    this.auditRecords.push(clone({ ...settlement, type: "crucible_review_approved" }));
    return settlement;
  }

  private finalizeHeldRefund(escrow: Escrow, action: string, actorId: string, metadata: JsonRecord): JsonRecord {
    this.balances.set(escrow.player_a_id, this.getBalanceMillis(escrow.player_a_id) + escrow.stake_each);
    this.balances.set(escrow.player_b_id, this.getBalanceMillis(escrow.player_b_id) + escrow.stake_each);
    this.appendTransaction("ESCROW_REFUND", escrow.match_id, escrow.player_a_id, escrow.stake_each, escrow.escrow_id, { review_refund: true, actor_id: actorId, side: "A" });
    this.appendTransaction("ESCROW_REFUND", escrow.match_id, escrow.player_b_id, escrow.stake_each, escrow.escrow_id, { review_refund: true, actor_id: actorId, side: "B" });
    escrow.settlement_status = "REFUNDED";
    const settlement = this.settlementRecord(escrow, "REFUNDED", "", "", "ADMIN_REVIEW", action || "review_refund", {
      ...metadata,
      reviewed_by: actorId
    });
    settlement.burn = 0;
    settlement.winner_payout = 0;
    settlement.review_status = "refunded";
    this.settlementsByMatchId.set(escrow.match_id, settlement);
    this.reviewRecordsByMatchId.set(escrow.match_id, clone(settlement));
    this.auditRecords.push(clone({ ...settlement, type: "crucible_review_refunded" }));
    return settlement;
  }

  private recordValue(value: unknown): JsonRecord {
    return value != null && typeof value === "object" && !Array.isArray(value) ? value as JsonRecord : {};
  }

  private arrayValue(value: unknown): unknown[] {
    return Array.isArray(value) ? value : [];
  }

  private inferNextTransactionSeq(): number {
    let maxSeq = 0;
    for (const entry of this.transactions) {
      const id = cleanString(entry.transaction_id);
      const seq = Number.parseInt(id.replace(/^\D+/, ""), 10);
      if (Number.isFinite(seq)) {
        maxSeq = Math.max(maxSeq, seq);
      }
    }
    return maxSeq + 1;
  }
}

export const crucibleLedger = new CrucibleLedger();
