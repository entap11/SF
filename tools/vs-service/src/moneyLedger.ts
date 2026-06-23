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
  house_rake_cents: number;
  settle_idempotency_key?: string;
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
    if (!pot) {
      return this.store(cleanKey, this.error("contest_not_found", "Contest escrow was not found."));
    }
    if (pot.status !== "escrowed") {
      return this.store(cleanKey, this.error("contest_already_closed", "Only escrowed contests can be settled."));
    }
    if (!pot.player_ids.includes(cleanWinnerId)) {
      return this.store(cleanKey, this.error("winner_not_in_contest", "Winner must be entered in contest."));
    }
    if (pot.escrow_cents <= 0) {
      return this.store(cleanKey, this.error("empty_escrow", "Escrow is empty."));
    }
    const houseRakeCents = Math.floor((pot.escrow_cents * this.houseRakeBps) / BASIS_POINTS_DENOMINATOR);
    const winnerPayoutCents = pot.escrow_cents - houseRakeCents;
    const winnerBalance = this.getBalanceCents(cleanWinnerId) + winnerPayoutCents;
    const houseBalance = this.getBalanceCents(HOUSE_ACCOUNT_ID) + houseRakeCents;
    this.balances.set(cleanWinnerId, winnerBalance);
    this.balances.set(HOUSE_ACCOUNT_ID, houseBalance);
    const payoutTransaction = this.appendTransaction("async_money_game", "async_winner_payout", cleanWinnerId, "credit", winnerPayoutCents, winnerBalance, {
      contest_id: cleanContestId,
      player_id: cleanWinnerId,
      winner_id: cleanWinnerId,
      idempotency_key: cleanKey,
      memo: "Async money contest winner payout"
    });
    const rakeTransaction = this.appendTransaction("async_money_game", "async_house_rake", HOUSE_ACCOUNT_ID, "credit", houseRakeCents, houseBalance, {
      contest_id: cleanContestId,
      winner_id: cleanWinnerId,
      house_account_id: HOUSE_ACCOUNT_ID,
      idempotency_key: cleanKey,
      memo: "Async money contest house rake"
    });
    pot.status = "settled";
    pot.winner_id = cleanWinnerId;
    pot.winner_payout_cents = winnerPayoutCents;
    pot.house_rake_cents = houseRakeCents;
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
      winner_id: cleanWinnerId,
      winner_payout_cents: winnerPayoutCents,
      house_rake_cents: houseRakeCents,
      pot_cents: pot.pot_cents,
      transaction_ids: [payoutTransaction.transaction_id, rakeTransaction.transaction_id]
    });
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

  getSnapshot(): JsonRecord {
    return {
      house_rake_bps: this.houseRakeBps,
      balances: Object.fromEntries(this.balances.entries()),
      sync_matches: Object.fromEntries([...this.syncMatches.entries()].map(([key, value]) => [key, clone(value)])),
      async_entries: Object.fromEntries([...this.asyncEntries.entries()].map(([key, value]) => [key, clone(value)])),
      async_contests: Object.fromEntries([...this.asyncContests.entries()].map(([key, value]) => [key, clone(value)])),
      transactions: this.getTransactionLedger()
    };
  }

  private ensureAccount(accountId: string, initialBalanceCents?: number): void {
    if (!accountId || this.balances.has(accountId)) {
      return;
    }
    this.balances.set(accountId, initialBalanceCents == null ? DEFAULT_BALANCE_CENTS : Math.max(0, Math.trunc(initialBalanceCents)));
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
