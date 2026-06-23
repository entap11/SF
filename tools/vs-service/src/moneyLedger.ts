export type JsonRecord = Record<string, unknown>;

type Direction = "credit" | "debit";
type LedgerName = "sync_money_game" | "async_money_game";

type PlayerFunding = {
  player_id: string;
  balance_cents?: number;
};

type SyncMatch = {
  session_id: string;
  status: "escrowed" | "settled" | "refunded";
  player_ids: string[];
  wager_cents: number;
  pot_cents: number;
  escrow_cents: number;
  winner_id: string;
  winner_payout_cents: number;
  house_rake_cents: number;
  open_idempotency_key: string;
  settle_idempotency_key?: string;
  refund_idempotency_key?: string;
  refund_reason?: string;
};

type AsyncEntry = {
  entry_id: string;
  contest_id: string;
  player_id: string;
  status: "escrowed" | "settled" | "refunded";
  wager_cents: number;
  escrow_cents: number;
  open_idempotency_key: string;
  refund_idempotency_key?: string;
  refund_reason?: string;
};

type AsyncContest = {
  contest_id: string;
  status: "escrowed" | "settled" | "refunded";
  entry_ids: string[];
  player_ids: string[];
  wager_cents: number;
  pot_cents: number;
  escrow_cents: number;
  winner_id: string;
  winner_payout_cents: number;
  payout_total_cents: number;
  payout_count: number;
  payouts: SettlementPayout[];
  house_rake_cents: number;
  settle_idempotency_key?: string;
};

type SettlementPayout = {
  placement: number;
  player_id: string;
  amount_cents: number;
  payout_bps: number;
  approval_id?: string;
  approved_by?: string;
};

const DEFAULT_BALANCE_CENTS = 100_000;
const DEFAULT_HOUSE_RAKE_BPS = 1000;
const BASIS_POINTS_DENOMINATOR = 10_000;
const HOUSE_ACCOUNT_ID = "house";

function cleanString(value: unknown): string {
  return String(value ?? "").trim();
}

function clone<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

function cents(value: unknown, fallback = 0): number {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? Math.trunc(numeric) : fallback;
}

function utcStamp(unix: number): string {
  return new Date(unix * 1000).toISOString().replace(/\.\d{3}Z$/, "Z");
}

export class MoneyLedger {
  private houseRakeBps = DEFAULT_HOUSE_RAKE_BPS;
  private balances = new Map<string, number>();
  private syncMatches = new Map<string, SyncMatch>();
  private asyncEntries = new Map<string, AsyncEntry>();
  private asyncContests = new Map<string, AsyncContest>();
  private asyncPayoutApprovalReports = new Map<string, JsonRecord>();
  private operationResults = new Map<string, JsonRecord>();
  private transactions: JsonRecord[] = [];
  private nextTransactionSeq = 1;

  constructor() {
    this.balances.set(HOUSE_ACCOUNT_ID, 0);
  }

  configureHouseRakeBps(rakeBps: number): void {
    this.houseRakeBps = Math.max(0, Math.min(BASIS_POINTS_DENOMINATOR, Math.trunc(rakeBps)));
  }

  setBalanceCents(accountId: string, balanceCents: number): JsonRecord {
    const cleanAccountId = cleanString(accountId);
    if (!cleanAccountId) {
      return this.error("missing_account_id", "Account id is required.");
    }
    this.balances.set(cleanAccountId, Math.max(0, Math.trunc(balanceCents)));
    return { ok: true, account_id: cleanAccountId, balance_cents: this.getBalanceCents(cleanAccountId) };
  }

  getBalanceCents(accountId: string): number {
    return this.balances.get(cleanString(accountId)) ?? 0;
  }

  openMoneyEscrow(sessionId: string, players: PlayerFunding[], wagerCents: number, idempotencyKey: string): JsonRecord {
    const cleanKey = cleanString(idempotencyKey);
    if (!cleanKey) {
      return this.error("missing_idempotency_key", "Idempotency key is required.");
    }
    const cached = this.cached(cleanKey);
    if (cached) {
      return cached;
    }
    const cleanSessionId = cleanString(sessionId);
    const cleanWagerCents = Math.trunc(wagerCents);
    const playerIds = players.map((player) => cleanString(player.player_id)).filter(Boolean);
    if (!cleanSessionId) {
      return this.store(cleanKey, this.error("missing_session_id", "Session id is required."));
    }
    if (cleanWagerCents <= 0) {
      return this.store(cleanKey, this.error("invalid_wager", "Wager must be positive integer cents."));
    }
    if (playerIds.length < 2) {
      return this.store(cleanKey, this.error("not_enough_players", "At least two players are required."));
    }
    if (new Set(playerIds).size !== playerIds.length) {
      return this.store(cleanKey, this.error("duplicate_player", "Players must be unique."));
    }
    if (this.syncMatches.has(cleanSessionId)) {
      return this.store(cleanKey, this.error("match_already_exists", "Money match already exists."));
    }
    for (const player of players) {
      this.ensureAccount(cleanString(player.player_id), player.balance_cents);
    }
    const shortPlayer = playerIds.find((playerId) => this.getBalanceCents(playerId) < cleanWagerCents);
    if (shortPlayer) {
      return this.store(cleanKey, this.error("insufficient_funds", "Player cannot cover wager.", {
        player_id: shortPlayer,
        balance_cents: this.getBalanceCents(shortPlayer),
        wager_cents: cleanWagerCents
      }));
    }
    const transactionIds: string[] = [];
    for (const playerId of playerIds) {
      const balanceAfter = this.getBalanceCents(playerId) - cleanWagerCents;
      this.balances.set(playerId, balanceAfter);
      const transaction = this.appendTransaction("sync_money_game", "escrow_debit", playerId, "debit", cleanWagerCents, balanceAfter, {
        session_id: cleanSessionId,
        player_id: playerId,
        idempotency_key: cleanKey,
        memo: "Money game escrow debit"
      });
      transactionIds.push(String(transaction.transaction_id ?? ""));
    }
    const potCents = cleanWagerCents * playerIds.length;
    const match: SyncMatch = {
      session_id: cleanSessionId,
      status: "escrowed",
      player_ids: [...playerIds],
      wager_cents: cleanWagerCents,
      pot_cents: potCents,
      escrow_cents: potCents,
      winner_id: "",
      winner_payout_cents: 0,
      house_rake_cents: 0,
      open_idempotency_key: cleanKey
    };
    this.syncMatches.set(cleanSessionId, match);
    return this.store(cleanKey, {
      ok: true,
      type: "escrow_opened",
      session_id: cleanSessionId,
      status: match.status,
      player_ids: [...playerIds],
      wager_cents: cleanWagerCents,
      pot_cents: potCents,
      escrow_cents: potCents,
      transaction_ids: transactionIds
    });
  }

  settleMoneyMatch(sessionId: string, winnerId: string, idempotencyKey: string): JsonRecord {
    const cleanKey = cleanString(idempotencyKey);
    if (!cleanKey) {
      return this.error("missing_idempotency_key", "Idempotency key is required.");
    }
    const cached = this.cached(cleanKey);
    if (cached) {
      return cached;
    }
    const cleanSessionId = cleanString(sessionId);
    const cleanWinnerId = cleanString(winnerId);
    if (!cleanSessionId) {
      return this.store(cleanKey, this.error("missing_session_id", "Session id is required."));
    }
    if (!cleanWinnerId) {
      return this.store(cleanKey, this.error("missing_winner_id", "Winner id is required."));
    }
    const match = this.syncMatches.get(cleanSessionId);
    if (!match) {
      return this.store(cleanKey, this.error("match_not_found", "Money match was not found."));
    }
    if (match.status !== "escrowed") {
      return this.store(cleanKey, this.error("match_already_closed", "Only escrowed matches can be settled."));
    }
    if (!match.player_ids.includes(cleanWinnerId)) {
      return this.store(cleanKey, this.error("winner_not_in_match", "Winner must be in match."));
    }
    if (match.escrow_cents <= 0) {
      return this.store(cleanKey, this.error("empty_escrow", "Escrow is empty."));
    }
    const houseRakeCents = Math.floor((match.escrow_cents * this.houseRakeBps) / BASIS_POINTS_DENOMINATOR);
    const winnerPayoutCents = match.escrow_cents - houseRakeCents;
    const winnerBalance = this.getBalanceCents(cleanWinnerId) + winnerPayoutCents;
    const houseBalance = this.getBalanceCents(HOUSE_ACCOUNT_ID) + houseRakeCents;
    this.balances.set(cleanWinnerId, winnerBalance);
    this.balances.set(HOUSE_ACCOUNT_ID, houseBalance);
    const payoutTransaction = this.appendTransaction("sync_money_game", "winner_payout", cleanWinnerId, "credit", winnerPayoutCents, winnerBalance, {
      session_id: cleanSessionId,
      player_id: cleanWinnerId,
      winner_id: cleanWinnerId,
      idempotency_key: cleanKey,
      memo: "Money game winner payout"
    });
    const rakeTransaction = this.appendTransaction("sync_money_game", "house_rake", HOUSE_ACCOUNT_ID, "credit", houseRakeCents, houseBalance, {
      session_id: cleanSessionId,
      winner_id: cleanWinnerId,
      house_account_id: HOUSE_ACCOUNT_ID,
      idempotency_key: cleanKey,
      memo: "Money game house rake"
    });
    match.status = "settled";
    match.winner_id = cleanWinnerId;
    match.winner_payout_cents = winnerPayoutCents;
    match.house_rake_cents = houseRakeCents;
    match.escrow_cents = 0;
    match.settle_idempotency_key = cleanKey;
    return this.store(cleanKey, {
      ok: true,
      type: "match_settled",
      session_id: cleanSessionId,
      status: match.status,
      winner_id: cleanWinnerId,
      winner_payout_cents: winnerPayoutCents,
      house_rake_cents: houseRakeCents,
      pot_cents: match.pot_cents,
      transaction_ids: [payoutTransaction.transaction_id, rakeTransaction.transaction_id]
    });
  }

  refundMoneyMatch(sessionId: string, reason: string, idempotencyKey: string): JsonRecord {
    const cleanKey = cleanString(idempotencyKey);
    if (!cleanKey) {
      return this.error("missing_idempotency_key", "Idempotency key is required.");
    }
    const cached = this.cached(cleanKey);
    if (cached) {
      return cached;
    }
    const cleanSessionId = cleanString(sessionId);
    if (!cleanSessionId) {
      return this.store(cleanKey, this.error("missing_session_id", "Session id is required."));
    }
    const match = this.syncMatches.get(cleanSessionId);
    if (!match) {
      return this.store(cleanKey, this.error("match_not_found", "Money match was not found."));
    }
    if (match.status !== "escrowed") {
      return this.store(cleanKey, this.error("match_already_closed", "Only escrowed matches can be refunded."));
    }
    const transactionIds: string[] = [];
    const refundPerPlayer = match.wager_cents;
    for (const playerId of match.player_ids) {
      const balanceAfter = this.getBalanceCents(playerId) + refundPerPlayer;
      this.balances.set(playerId, balanceAfter);
      const transaction = this.appendTransaction("sync_money_game", "refund_credit", playerId, "credit", refundPerPlayer, balanceAfter, {
        session_id: cleanSessionId,
        player_id: playerId,
        idempotency_key: cleanKey,
        memo: "Money game escrow refund"
      });
      transactionIds.push(String(transaction.transaction_id ?? ""));
    }
    match.status = "refunded";
    match.escrow_cents = 0;
    match.refund_reason = cleanString(reason);
    match.refund_idempotency_key = cleanKey;
    return this.store(cleanKey, {
      ok: true,
      type: "match_refunded",
      session_id: cleanSessionId,
      status: match.status,
      refund_reason: match.refund_reason,
      refunded_cents_per_player: refundPerPlayer,
      transaction_ids: transactionIds
    });
  }

  openAsyncEntryEscrow(entryId: string, contestId: string, player: PlayerFunding, wagerCents: number, idempotencyKey: string): JsonRecord {
    const cleanKey = cleanString(idempotencyKey);
    if (!cleanKey) {
      return this.error("missing_idempotency_key", "Idempotency key is required.");
    }
    const cached = this.cached(cleanKey);
    if (cached) {
      return cached;
    }
    const cleanEntryId = cleanString(entryId);
    const cleanContestId = cleanString(contestId);
    const cleanPlayerId = cleanString(player.player_id);
    const cleanWagerCents = Math.trunc(wagerCents);
    if (!cleanEntryId) {
      return this.store(cleanKey, this.error("missing_entry_id", "Entry id is required."));
    }
    if (!cleanContestId) {
      return this.store(cleanKey, this.error("missing_contest_id", "Contest id is required."));
    }
    if (!cleanPlayerId) {
      return this.store(cleanKey, this.error("missing_player_id", "Player id is required."));
    }
    if (cleanWagerCents <= 0) {
      return this.store(cleanKey, this.error("invalid_wager", "Wager must be positive integer cents."));
    }
    if (this.asyncEntries.has(cleanEntryId)) {
      return this.store(cleanKey, this.error("entry_already_exists", "Async money entry already has escrow."));
    }
    this.ensureAccount(cleanPlayerId, player.balance_cents);
    if (this.getBalanceCents(cleanPlayerId) < cleanWagerCents) {
      return this.store(cleanKey, this.error("insufficient_funds", "Player cannot cover wager.", {
        player_id: cleanPlayerId,
        balance_cents: this.getBalanceCents(cleanPlayerId),
        wager_cents: cleanWagerCents
      }));
    }
    const balanceAfter = this.getBalanceCents(cleanPlayerId) - cleanWagerCents;
    this.balances.set(cleanPlayerId, balanceAfter);
    const escrowTransaction = this.appendTransaction("async_money_game", "async_entry_escrow_debit", cleanPlayerId, "debit", cleanWagerCents, balanceAfter, {
      entry_id: cleanEntryId,
      contest_id: cleanContestId,
      player_id: cleanPlayerId,
      idempotency_key: cleanKey,
      memo: "Async money entry escrow debit"
    });
    const entry: AsyncEntry = {
      entry_id: cleanEntryId,
      contest_id: cleanContestId,
      player_id: cleanPlayerId,
      status: "escrowed",
      wager_cents: cleanWagerCents,
      escrow_cents: cleanWagerCents,
      open_idempotency_key: cleanKey
    };
    this.asyncEntries.set(cleanEntryId, entry);
    const pot = this.asyncContests.get(cleanContestId) ?? {
      contest_id: cleanContestId,
      status: "escrowed",
      entry_ids: [],
      player_ids: [],
      wager_cents: cleanWagerCents,
      pot_cents: 0,
      escrow_cents: 0,
      winner_id: "",
      winner_payout_cents: 0,
      payout_total_cents: 0,
      payout_count: 0,
      payouts: [],
      house_rake_cents: 0
    };
    pot.entry_ids.push(cleanEntryId);
    if (!pot.player_ids.includes(cleanPlayerId)) {
      pot.player_ids.push(cleanPlayerId);
    }
    pot.wager_cents = cleanWagerCents;
    pot.pot_cents += cleanWagerCents;
    pot.escrow_cents += cleanWagerCents;
    this.asyncContests.set(cleanContestId, pot);
    return this.store(cleanKey, {
      ok: true,
      type: "async_entry_escrowed",
      entry_id: cleanEntryId,
      contest_id: cleanContestId,
      player_id: cleanPlayerId,
      status: entry.status,
      wager_cents: cleanWagerCents,
      pot_cents: pot.pot_cents,
      escrow_cents: pot.escrow_cents,
      transaction_ids: [escrowTransaction.transaction_id]
    });
  }

  buildAsyncContestPayoutApprovalReport(contestId: string, payouts: unknown[], houseRakeBps: number): JsonRecord {
    const cleanContestId = cleanString(contestId);
    if (!cleanContestId) {
      return this.error("missing_contest_id", "Contest id is required.");
    }
    const pot = this.asyncContests.get(cleanContestId);
    if (!pot) {
      return this.error("contest_not_found", "Contest escrow was not found.");
    }
    if (pot.status !== "escrowed") {
      return this.error("contest_already_closed", "Only escrowed contests can be reported.");
    }
    if (pot.escrow_cents <= 0) {
      return this.error("empty_escrow", "Escrow is empty.");
    }
    const normalizedPayouts = this.normalizeSettlementPayouts(payouts);
    if (normalizedPayouts.length <= 0) {
      return this.error("missing_payouts", "At least one payout is required.");
    }
    const cleanHouseRakeBps = Math.max(0, Math.min(BASIS_POINTS_DENOMINATOR, Math.trunc(houseRakeBps)));
    let payoutTotalBps = 0;
    const seenPlayers = new Set<string>();
    const seenPlacements = new Set<number>();
    for (const payout of normalizedPayouts) {
      if (!payout.player_id) {
        return this.error("missing_payout_player", "Each payout requires a player id.");
      }
      if (!pot.player_ids.includes(payout.player_id)) {
        return this.error("payout_player_not_in_contest", "Payout player must be entered in contest.");
      }
      if (seenPlayers.has(payout.player_id)) {
        return this.error("duplicate_payout_player", "Each player can receive one settlement payout.");
      }
      if (seenPlacements.has(payout.placement)) {
        return this.error("duplicate_payout_placement", "Each placement can receive one settlement payout.");
      }
      if (payout.payout_bps <= 0) {
        return this.error("invalid_payout_percentage", "Payout percentages must be positive basis points.");
      }
      seenPlayers.add(payout.player_id);
      seenPlacements.add(payout.placement);
      payoutTotalBps += payout.payout_bps;
    }
    if (payoutTotalBps + cleanHouseRakeBps !== BASIS_POINTS_DENOMINATOR) {
      return this.error("settlement_percentages_not_balanced", "Payout percentages plus house rake must equal 100 percent.");
    }
    const houseRakeCents = Math.floor((pot.escrow_cents * cleanHouseRakeBps) / BASIS_POINTS_DENOMINATOR);
    const playerPoolCents = Math.max(0, pot.escrow_cents - houseRakeCents);
    let payoutTotalCents = 0;
    const plannedPayouts = normalizedPayouts.map((payout) => {
      const amountCents = Math.floor((pot.escrow_cents * payout.payout_bps) / BASIS_POINTS_DENOMINATOR);
      payoutTotalCents += amountCents;
      return { ...payout, amount_cents: amountCents };
    });
    const roundingRemainderCents = playerPoolCents - payoutTotalCents;
    if (roundingRemainderCents > 0 && plannedPayouts.length > 0) {
      plannedPayouts[0].amount_cents += roundingRemainderCents;
      payoutTotalCents += roundingRemainderCents;
    }
    const entryCounts = this.asyncContestEntryCounts(pot);
    const reportId = this.approvalReportId(cleanContestId, pot.escrow_cents, cleanHouseRakeBps, plannedPayouts);
    return {
      ok: true,
      type: "async_contest_payout_approval_report",
      approval_status: "pending_approval",
      approval_required: true,
      report_id: reportId,
      contest_id: cleanContestId,
      players_count: pot.player_ids.length,
      entries_count: entryCounts.entries_count,
      paid_entries_count: entryCounts.paid_entries_count,
      refunded_entries_count: entryCounts.refunded_entries_count,
      total_take_cents: pot.escrow_cents,
      pot_cents: pot.pot_cents,
      escrow_cents: pot.escrow_cents,
      house_rake_bps: cleanHouseRakeBps,
      house_rake_cents: houseRakeCents,
      player_pool_cents: playerPoolCents,
      payout_total_bps: payoutTotalBps,
      payout_total_cents: payoutTotalCents,
      planned_payouts: clone(plannedPayouts),
      payout_count: plannedPayouts.length,
      rounding_remainder_cents: roundingRemainderCents
    };
  }

  previewAsyncContestPayoutApprovalReport(contestId: string, payouts: unknown[], houseRakeBps: number): JsonRecord {
    const report = this.buildAsyncContestPayoutApprovalReport(contestId, payouts, houseRakeBps);
    if (report.ok === true) {
      const now = Math.floor(Date.now() / 1000);
      report.generated_unix = now;
      report.generated_utc = utcStamp(now);
      report.updated_unix = now;
      report.updated_utc = utcStamp(now);
      this.asyncPayoutApprovalReports.set(cleanString(report.report_id), clone(report));
    }
    return report;
  }

  listAsyncContestPayoutApprovalReports(filters: JsonRecord = {}): JsonRecord[] {
    let reports = [...this.asyncPayoutApprovalReports.values()]
      .filter((report) => this.approvalReportMatches(report, filters))
      .map((report) => clone(report));
    if (Boolean(filters.sort_desc)) {
      reports = reports.reverse();
    }
    const limit = Math.max(0, cents(filters.limit));
    if (limit > 0 && reports.length > limit) {
      reports = reports.slice(0, limit);
    }
    return reports;
  }

  settleAsyncContest(contestId: string, winnerId: string, idempotencyKey: string): JsonRecord {
    const cleanKey = cleanString(idempotencyKey);
    if (!cleanKey) {
      return this.error("missing_idempotency_key", "Idempotency key is required.");
    }
    const cached = this.cached(cleanKey);
    if (cached) {
      return cached;
    }
    const cleanContestId = cleanString(contestId);
    const cleanWinnerId = cleanString(winnerId);
    if (!cleanContestId) {
      return this.store(cleanKey, this.error("missing_contest_id", "Contest id is required."));
    }
    if (!cleanWinnerId) {
      return this.store(cleanKey, this.error("missing_winner_id", "Winner id is required."));
    }
    const pot = this.asyncContests.get(cleanContestId);
    if (pot && !pot.player_ids.includes(cleanWinnerId)) {
      return this.store(cleanKey, this.error("winner_not_in_contest", "Winner must be entered in contest."));
    }
    const escrowCents = pot?.escrow_cents ?? 0;
    const houseRakeCents = Math.floor((escrowCents * this.houseRakeBps) / BASIS_POINTS_DENOMINATOR);
    const winnerPayoutCents = escrowCents - houseRakeCents;
    return this.settleAsyncContestPayouts(cleanContestId, [{ placement: 1, player_id: cleanWinnerId, amount_cents: winnerPayoutCents }], houseRakeCents, idempotencyKey);
  }

  settleAsyncContestPayouts(contestId: string, payouts: unknown[], houseRakeCents: number, idempotencyKey: string): JsonRecord {
    const cleanKey = cleanString(idempotencyKey);
    if (!cleanKey) {
      return this.error("missing_idempotency_key", "Idempotency key is required.");
    }
    const cached = this.cached(cleanKey);
    if (cached) {
      return cached;
    }
    const cleanContestId = cleanString(contestId);
    if (!cleanContestId) {
      return this.store(cleanKey, this.error("missing_contest_id", "Contest id is required."));
    }
    const pot = this.asyncContests.get(cleanContestId);
    if (!pot) {
      return this.store(cleanKey, this.error("contest_not_found", "Contest escrow was not found."));
    }
    if (pot.status !== "escrowed") {
      return this.store(cleanKey, this.error("contest_already_closed", "Only escrowed contests can be settled."));
    }
    if (pot.escrow_cents <= 0) {
      return this.store(cleanKey, this.error("empty_escrow", "Escrow is empty."));
    }
    const normalizedPayouts = this.normalizeSettlementPayouts(payouts);
    if (normalizedPayouts.length <= 0) {
      return this.store(cleanKey, this.error("missing_payouts", "At least one payout is required."));
    }
    let payoutTotalCents = 0;
    const seenPlayers = new Set<string>();
    const seenPlacements = new Set<number>();
    for (const payout of normalizedPayouts) {
      if (!payout.player_id) {
        return this.store(cleanKey, this.error("missing_payout_player", "Each payout requires a player id."));
      }
      if (!pot.player_ids.includes(payout.player_id)) {
        return this.store(cleanKey, this.error("payout_player_not_in_contest", "Payout player must be entered in contest."));
      }
      if (seenPlayers.has(payout.player_id)) {
        return this.store(cleanKey, this.error("duplicate_payout_player", "Each player can receive one settlement payout."));
      }
      if (seenPlacements.has(payout.placement)) {
        return this.store(cleanKey, this.error("duplicate_payout_placement", "Each placement can receive one settlement payout."));
      }
      if (payout.amount_cents <= 0) {
        return this.store(cleanKey, this.error("invalid_payout_amount", "Payout amounts must be positive integer cents."));
      }
      seenPlayers.add(payout.player_id);
      seenPlacements.add(payout.placement);
      payoutTotalCents += payout.amount_cents;
    }
    const cleanHouseRakeCents = Math.max(0, Math.trunc(houseRakeCents));
    if (payoutTotalCents + cleanHouseRakeCents !== pot.escrow_cents) {
      return this.store(cleanKey, this.error("settlement_not_balanced", "Payouts plus house rake must equal escrow."));
    }
    const transactionIds: unknown[] = [];
    const winnerId = normalizedPayouts[0]?.player_id ?? "";
    for (const payout of normalizedPayouts) {
      const balanceAfter = this.getBalanceCents(payout.player_id) + payout.amount_cents;
      this.balances.set(payout.player_id, balanceAfter);
      const payoutTransaction = this.appendTransaction("async_money_game", "async_winner_payout", payout.player_id, "credit", payout.amount_cents, balanceAfter, {
        contest_id: cleanContestId,
        player_id: payout.player_id,
        winner_id: winnerId,
        placement: payout.placement,
        payout_bps: payout.payout_bps,
        payout_count: normalizedPayouts.length,
        approval_id: payout.approval_id ?? "",
        approved_by: payout.approved_by ?? "",
        idempotency_key: cleanKey,
        memo: "Async money contest winner payout"
      });
      transactionIds.push(payoutTransaction.transaction_id);
    }
    const houseBalance = this.getBalanceCents(HOUSE_ACCOUNT_ID) + cleanHouseRakeCents;
    this.balances.set(HOUSE_ACCOUNT_ID, houseBalance);
    const rakeTransaction = this.appendTransaction("async_money_game", "async_house_rake", HOUSE_ACCOUNT_ID, "credit", cleanHouseRakeCents, houseBalance, {
      contest_id: cleanContestId,
      winner_id: winnerId,
      house_account_id: HOUSE_ACCOUNT_ID,
      approval_id: normalizedPayouts[0]?.approval_id ?? "",
      approved_by: normalizedPayouts[0]?.approved_by ?? "",
      idempotency_key: cleanKey,
      memo: "Async money contest house rake"
    });
    transactionIds.push(rakeTransaction.transaction_id);
    pot.status = "settled";
    pot.winner_id = winnerId;
    pot.winner_payout_cents = normalizedPayouts[0]?.amount_cents ?? 0;
    pot.payout_total_cents = payoutTotalCents;
    pot.payout_count = normalizedPayouts.length;
    pot.payouts = clone(normalizedPayouts);
    pot.house_rake_cents = cleanHouseRakeCents;
    pot.escrow_cents = 0;
    pot.settle_idempotency_key = cleanKey;
    for (const entryId of pot.entry_ids) {
      const entry = this.asyncEntries.get(entryId);
      if (entry) {
        entry.status = "settled";
        entry.escrow_cents = 0;
      }
    }
    return this.store(cleanKey, {
      ok: true,
      type: "async_contest_settled",
      contest_id: cleanContestId,
      status: pot.status,
      winner_id: pot.winner_id,
      winner_payout_cents: pot.winner_payout_cents,
      payout_total_cents: payoutTotalCents,
      payout_count: normalizedPayouts.length,
      payouts: clone(normalizedPayouts),
      house_rake_cents: cleanHouseRakeCents,
      pot_cents: pot.pot_cents,
      transaction_ids: transactionIds
    });
  }

  settleAsyncContestPayoutPercentages(contestId: string, payouts: unknown[], houseRakeBps: number, idempotencyKey: string): JsonRecord {
    const cleanKey = cleanString(idempotencyKey);
    if (!cleanKey) {
      return this.error("missing_idempotency_key", "Idempotency key is required.");
    }
    const cached = this.cached(cleanKey);
    if (cached) {
      return cached;
    }
    const report = this.buildAsyncContestPayoutApprovalReport(contestId, payouts, houseRakeBps);
    if (report.ok !== true) {
      return this.store(cleanKey, report);
    }
    return this.settleAsyncContestPayouts(
      cleanString(report.contest_id),
      Array.isArray(report.planned_payouts) ? report.planned_payouts : [],
      cents(report.house_rake_cents),
      cleanKey
    );
  }

  approveAsyncContestPayoutReport(report: JsonRecord, approverId: string, idempotencyKey: string): JsonRecord {
    const cleanKey = cleanString(idempotencyKey);
    if (!cleanKey) {
      return this.error("missing_idempotency_key", "Idempotency key is required.");
    }
    const cached = this.cached(cleanKey);
    if (cached) {
      return cached;
    }
    if (report == null || report.ok !== true) {
      return this.store(cleanKey, this.error("invalid_approval_report", "A valid payout approval report is required."));
    }
    const cleanApproverId = cleanString(approverId);
    if (!cleanApproverId) {
      return this.store(cleanKey, this.error("missing_approver_id", "Approver id is required."));
    }
    const approvedPayouts = (Array.isArray(report.planned_payouts) ? report.planned_payouts : [])
      .filter((payout): payout is JsonRecord => payout != null && typeof payout === "object" && !Array.isArray(payout))
      .map((payout) => ({
        ...payout,
        approval_id: cleanString(report.report_id),
        approved_by: cleanApproverId
      }));
    const approvalId = cleanString(report.report_id);
    const settle = this.settleAsyncContestPayouts(cleanString(report.contest_id), approvedPayouts, cents(report.house_rake_cents), cleanKey);
    if (settle.ok === true) {
      const storedReport = this.asyncPayoutApprovalReports.get(approvalId) ?? clone(report);
      const now = Math.floor(Date.now() / 1000);
      const approvedReport = {
        ...storedReport,
        approval_status: "approved",
        approval_id: approvalId,
        approved_by: cleanApproverId,
        approved_unix: now,
        approved_utc: utcStamp(now),
        updated_unix: now,
        updated_utc: utcStamp(now),
        settlement_transaction_ids: Array.isArray(settle.transaction_ids) ? clone(settle.transaction_ids) : []
      };
      if (approvalId) {
        this.asyncPayoutApprovalReports.set(approvalId, approvedReport);
      }
      return {
        ...settle,
        approval_status: "approved",
        approval_id: approvalId,
        approved_by: cleanApproverId,
        approval_report: clone(approvedReport)
      };
    }
    return settle;
  }

  refundAsyncEntry(entryId: string, reason: string, idempotencyKey: string): JsonRecord {
    const cleanKey = cleanString(idempotencyKey);
    if (!cleanKey) {
      return this.error("missing_idempotency_key", "Idempotency key is required.");
    }
    const cached = this.cached(cleanKey);
    if (cached) {
      return cached;
    }
    const cleanEntryId = cleanString(entryId);
    if (!cleanEntryId) {
      return this.store(cleanKey, this.error("missing_entry_id", "Entry id is required."));
    }
    const entry = this.asyncEntries.get(cleanEntryId);
    if (!entry) {
      return this.store(cleanKey, this.error("entry_not_found", "Async money entry was not found."));
    }
    if (entry.status !== "escrowed") {
      return this.store(cleanKey, this.error("entry_already_closed", "Only escrowed entries can be refunded."));
    }
    const refundCents = entry.escrow_cents;
    const balanceAfter = this.getBalanceCents(entry.player_id) + refundCents;
    this.balances.set(entry.player_id, balanceAfter);
    const refundTransaction = this.appendTransaction("async_money_game", "async_entry_refund_credit", entry.player_id, "credit", refundCents, balanceAfter, {
      entry_id: entry.entry_id,
      contest_id: entry.contest_id,
      player_id: entry.player_id,
      idempotency_key: cleanKey,
      memo: "Async money entry escrow refund"
    });
    entry.status = "refunded";
    entry.escrow_cents = 0;
    entry.refund_reason = cleanString(reason);
    entry.refund_idempotency_key = cleanKey;
    const pot = this.asyncContests.get(entry.contest_id);
    if (pot) {
      pot.escrow_cents = Math.max(0, pot.escrow_cents - refundCents);
    }
    return this.store(cleanKey, {
      ok: true,
      type: "async_entry_refunded",
      entry_id: entry.entry_id,
      contest_id: entry.contest_id,
      status: entry.status,
      refunded_cents: refundCents,
      refund_reason: entry.refund_reason,
      transaction_ids: [refundTransaction.transaction_id]
    });
  }

  getTransactionLedger(filters: JsonRecord = {}): JsonRecord[] {
    let rows = this.transactions.filter((transaction) => this.transactionMatches(transaction, filters)).map((transaction) => clone(transaction));
    if (Boolean(filters.sort_desc)) {
      rows = rows.reverse();
    }
    const limit = Math.max(0, cents(filters.limit));
    if (limit > 0 && rows.length > limit) {
      rows = rows.slice(0, limit);
    }
    return rows;
  }

  getPayoutSummary(filters: JsonRecord = {}): JsonRecord {
    const aggregationFilters = { ...filters };
    delete aggregationFilters.limit;
    const rows = this.getTransactionLedger(aggregationFilters);
    const byContest = new Map<string, JsonRecord>();
    let paidOutCents = 0;
    let houseRakeCents = 0;
    let payoutTransactionCount = 0;
    let rakeTransactionCount = 0;
    let syncPaidOutCents = 0;
    let asyncPaidOutCents = 0;
    for (const row of rows) {
      const transactionType = cleanString(row.transaction_type);
      const amountCents = Math.max(0, cents(row.amount_cents));
      const contestId = cleanString(row.contest_id);
      if (transactionType === "winner_payout" || transactionType === "async_winner_payout") {
        paidOutCents += amountCents;
        payoutTransactionCount += 1;
        if (transactionType === "winner_payout") {
          syncPaidOutCents += amountCents;
        } else {
          asyncPaidOutCents += amountCents;
        }
      } else if (transactionType === "house_rake" || transactionType === "async_house_rake") {
        houseRakeCents += amountCents;
        rakeTransactionCount += 1;
      } else {
        continue;
      }
      if (contestId) {
        const summary = byContest.get(contestId) ?? {
          contest_id: contestId,
          paid_out_cents: 0,
          house_rake_cents: 0,
          payout_count: 0,
          transaction_count: 0,
          last_paid_unix: 0,
          last_paid_utc: "",
          transaction_ids: []
        };
        summary.transaction_count = cents(summary.transaction_count) + 1;
        const ids = Array.isArray(summary.transaction_ids) ? summary.transaction_ids : [];
        ids.push(cleanString(row.transaction_id));
        summary.transaction_ids = ids.filter(Boolean);
        const createdUnix = cents(row.created_unix);
        if (createdUnix >= cents(summary.last_paid_unix)) {
          summary.last_paid_unix = createdUnix;
          summary.last_paid_utc = cleanString(row.created_utc);
        }
        if (transactionType === "async_winner_payout") {
          summary.paid_out_cents = cents(summary.paid_out_cents) + amountCents;
          summary.payout_count = cents(summary.payout_count) + 1;
        } else if (transactionType === "async_house_rake") {
          summary.house_rake_cents = cents(summary.house_rake_cents) + amountCents;
        }
        byContest.set(contestId, summary);
      }
    }
    let contestSummaries: JsonRecord[] = [...byContest.values()].map((summary) => {
      const paid = cents(summary.paid_out_cents);
      const rake = cents(summary.house_rake_cents);
      return {
        ...summary,
        total_take_cents: paid + rake
      };
    });
    contestSummaries.sort((a, b) => {
      const bLast = cents(b.last_paid_unix);
      const aLast = cents(a.last_paid_unix);
      if (aLast !== bLast) {
        return bLast - aLast;
      }
      return cleanString(a.contest_id).localeCompare(cleanString(b.contest_id));
    });
    const limit = Math.max(0, cents(filters.limit));
    if (limit > 0 && contestSummaries.length > limit) {
      contestSummaries = contestSummaries.slice(0, limit);
    }
    return {
      ok: true,
      type: "money_payout_summary",
      paid_out_cents: paidOutCents,
      house_rake_cents: houseRakeCents,
      gross_closed_cents: paidOutCents + houseRakeCents,
      payout_transaction_count: payoutTransactionCount,
      rake_transaction_count: rakeTransactionCount,
      sync_paid_out_cents: syncPaidOutCents,
      async_paid_out_cents: asyncPaidOutCents,
      contest_count: byContest.size,
      contests: contestSummaries,
      pending_approval_reports: this.listAsyncContestPayoutApprovalReports({ status: "pending_approval" }).length
    };
  }

  getSnapshot(): JsonRecord {
    return {
      house_rake_bps: this.houseRakeBps,
      balances: Object.fromEntries(this.balances.entries()),
      sync_matches: Object.fromEntries([...this.syncMatches.entries()].map(([key, value]) => [key, clone(value)])),
      async_entries: Object.fromEntries([...this.asyncEntries.entries()].map(([key, value]) => [key, clone(value)])),
      async_contests: Object.fromEntries([...this.asyncContests.entries()].map(([key, value]) => [key, clone(value)])),
      async_payout_approval_reports: Object.fromEntries([...this.asyncPayoutApprovalReports.entries()].map(([key, value]) => [key, clone(value)])),
      transactions: this.getTransactionLedger()
    };
  }

  private ensureAccount(accountId: string, initialBalanceCents?: number): void {
    if (!accountId || this.balances.has(accountId)) {
      return;
    }
    this.balances.set(accountId, initialBalanceCents == null ? DEFAULT_BALANCE_CENTS : Math.max(0, Math.trunc(initialBalanceCents)));
  }

  private normalizeSettlementPayouts(payouts: unknown[]): SettlementPayout[] {
    return payouts
      .filter((payout): payout is JsonRecord => payout != null && typeof payout === "object" && !Array.isArray(payout))
      .map((payout, index) => ({
        placement: Math.max(1, cents(payout.placement, index + 1)),
        player_id: cleanString(payout.player_id),
        amount_cents: Math.max(0, cents(payout.amount_cents ?? payout.amount)),
        payout_bps: Math.max(0, Math.min(BASIS_POINTS_DENOMINATOR, cents(payout.payout_bps))),
        approval_id: cleanString(payout.approval_id),
        approved_by: cleanString(payout.approved_by)
      }))
      .sort((a, b) => a.placement - b.placement);
  }

  private asyncContestEntryCounts(pot: AsyncContest): JsonRecord {
    let entriesCount = 0;
    let paidEntriesCount = 0;
    let refundedEntriesCount = 0;
    for (const entryId of pot.entry_ids) {
      entriesCount += 1;
      const entry = this.asyncEntries.get(entryId);
      if (entry?.status === "escrowed") {
        paidEntriesCount += 1;
      } else if (entry?.status === "refunded") {
        refundedEntriesCount += 1;
      }
    }
    return {
      entries_count: entriesCount,
      paid_entries_count: paidEntriesCount,
      refunded_entries_count: refundedEntriesCount
    };
  }

  private approvalReportId(contestId: string, escrowCents: number, houseRakeBps: number, plannedPayouts: SettlementPayout[]): string {
    const payload = JSON.stringify({ contest_id: contestId, escrow_cents: escrowCents, house_rake_bps: houseRakeBps, planned_payouts: plannedPayouts });
    let hash = 0;
    for (let i = 0; i < payload.length; i += 1) {
      hash = ((hash << 5) - hash + payload.charCodeAt(i)) | 0;
    }
    return `APR-${contestId}-${Math.abs(hash).toString(16).padStart(8, "0")}`;
  }

  private approvalReportMatches(report: JsonRecord, filters: JsonRecord): boolean {
    const exactKeys = ["report_id", "contest_id", "approval_status", "approval_id", "approved_by"];
    for (const key of exactKeys) {
      const expected = cleanString(filters[key]);
      if (expected && cleanString(report[key]) !== expected) {
        return false;
      }
    }
    const status = cleanString(filters.status);
    if (status && cleanString(report.approval_status) !== status) {
      return false;
    }
    const fromUnix = cents(filters.from_unix, -1);
    if (fromUnix >= 0 && cents(report.generated_unix) < fromUnix) {
      return false;
    }
    const toUnix = cents(filters.to_unix, -1);
    if (toUnix >= 0 && cents(report.generated_unix) > toUnix) {
      return false;
    }
    return true;
  }

  private cached(idempotencyKey: string): JsonRecord | null {
    const cached = this.operationResults.get(idempotencyKey);
    return cached == null ? null : clone(cached);
  }

  private store(idempotencyKey: string, result: JsonRecord): JsonRecord {
    const stored = clone(result);
    this.operationResults.set(idempotencyKey, stored);
    return clone(stored);
  }

  private error(code: string, message: string, extra: JsonRecord = {}): JsonRecord {
    return { ok: false, err: code, code, message, ...extra };
  }

  private appendTransaction(
    ledger: LedgerName,
    transactionType: string,
    accountId: string,
    direction: Direction,
    amountCents: number,
    balanceAfterCents: number,
    extra: JsonRecord
  ): JsonRecord {
    const seq = this.nextTransactionSeq;
    this.nextTransactionSeq += 1;
    const now = Math.floor(Date.now() / 1000);
    const prefix = ledger === "sync_money_game" ? "SYNC" : "ASYNC";
    const transaction: JsonRecord = {
      transaction_id: `${prefix}-${seq.toString().padStart(9, "0")}`,
      transaction_seq: seq,
      created_unix: now,
      created_utc: utcStamp(now),
      ledger,
      transaction_type: transactionType,
      status: "posted",
      account_id: accountId,
      direction,
      amount_cents: Math.max(0, Math.trunc(amountCents)),
      balance_after_cents: Math.trunc(balanceAfterCents),
      ...extra
    };
    this.transactions.push(transaction);
    return clone(transaction);
  }

  private transactionMatches(transaction: JsonRecord, filters: JsonRecord): boolean {
    const exactKeys = [
      "account_id",
      "session_id",
      "contest_id",
      "entry_id",
      "transaction_type",
      "direction",
      "status",
      "idempotency_key"
    ];
    for (const key of exactKeys) {
      const expected = cleanString(filters[key]);
      if (expected && cleanString(transaction[key]) !== expected) {
        return false;
      }
    }
    const fromUnix = cents(filters.from_unix, -1);
    if (fromUnix >= 0 && cents(transaction.created_unix) < fromUnix) {
      return false;
    }
    const toUnix = cents(filters.to_unix, -1);
    if (toUnix >= 0 && cents(transaction.created_unix) > toUnix) {
      return false;
    }
    return true;
  }
}

export const moneyLedger = new MoneyLedger();
