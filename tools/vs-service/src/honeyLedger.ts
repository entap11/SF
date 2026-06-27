import { createHoneyLedgerStore, type HoneyLedgerStore } from "./honeyLedgerStore.js";
import {
  evaluateHoneyActivity,
  honeyActivitySpecsSnapshot,
  normalizeOpponentKey,
  type HoneyActivityHistoryEntry,
  type HoneyActivityInput
} from "./honeyEconomyPolicy.js";

export type JsonRecord = Record<string, unknown>;

type HoneyTransaction = JsonRecord & {
  transaction_id: string;
  transaction_seq: number;
  type: string;
  player_id: string;
  amount_centi: number;
  balance_after_centi: number;
  source: string;
  idempotency_key: string;
  created_unix: number;
  metadata: JsonRecord;
};

const SNAPSHOT_SCHEMA_VERSION = 1;
const SNAPSHOT_TYPE = "honey_ledger";
const CENTI_PER_HONEY = 100;

function cleanString(value: unknown): string {
  return String(value ?? "").trim();
}

function intValue(value: unknown, fallback = 0): number {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? Math.trunc(numeric) : fallback;
}

function clone<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

function nowUnix(): number {
  return Math.floor(Date.now() / 1000);
}

function error(code: string, message: string, extra: JsonRecord = {}): JsonRecord {
  return { ok: false, code, err: code, message, ...extra };
}

function recordValue(value: unknown): JsonRecord {
  return value != null && typeof value === "object" && !Array.isArray(value) ? value as JsonRecord : {};
}

function arrayValue(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

export class HoneyLedger {
  private storeAdapter: HoneyLedgerStore;
  private balances = new Map<string, number>();
  private transactions: HoneyTransaction[] = [];
  private activityRecords: JsonRecord[] = [];
  private operationResults = new Map<string, JsonRecord>();
  private nextTransactionSeq = 1;

  constructor(storeOrPath?: HoneyLedgerStore | string) {
    this.storeAdapter = createHoneyLedgerStore(storeOrPath);
    this.loadFromStore();
  }

  getStorageSnapshot(): JsonRecord {
    return { kind: this.storeAdapter.kind };
  }

  getBalanceCenti(playerId: string): number {
    const cleanPlayer = cleanString(playerId);
    if (!cleanPlayer) {
      return 0;
    }
    return Math.max(0, this.balances.get(cleanPlayer) ?? 0);
  }

  getBalanceSnapshot(playerId: string): JsonRecord {
    const cleanPlayer = cleanString(playerId);
    if (!cleanPlayer) {
      return error("missing_player_id", "Player id is required.");
    }
    const balance = this.getBalanceCenti(cleanPlayer);
    return {
      ok: true,
      player_id: cleanPlayer,
      balance_centi: balance,
      balance_honey_whole: Math.floor(balance / CENTI_PER_HONEY),
      pending_centi: balance % CENTI_PER_HONEY
    };
  }

  setBalanceCenti(playerId: string, balanceCenti: number, source = "ops", metadata: JsonRecord = {}, idempotencyKey = ""): JsonRecord {
    const cleanPlayer = cleanString(playerId);
    if (!cleanPlayer) {
      return error("missing_player_id", "Player id is required.");
    }
    const key = this.operationKey(idempotencyKey, "set_balance", cleanPlayer);
    const existing = this.operationResults.get(key);
    if (existing != null) {
      return clone(existing);
    }
    const before = this.getBalanceCenti(cleanPlayer);
    const next = Math.max(0, intValue(balanceCenti));
    const delta = next - before;
    this.balances.set(cleanPlayer, next);
    const transaction = this.appendTransaction("set_balance", cleanPlayer, delta, source, key, metadata);
    const result = {
      ok: true,
      player_id: cleanPlayer,
      balance_centi: next,
      delta_centi: delta,
      transaction
    };
    this.storeOperation(key, result);
    return result;
  }

  grant(playerId: string, amountCenti: number, source: string, metadata: JsonRecord = {}, idempotencyKey = ""): JsonRecord {
    const cleanPlayer = cleanString(playerId);
    const amount = Math.max(0, intValue(amountCenti));
    if (!cleanPlayer) {
      return error("missing_player_id", "Player id is required.");
    }
    if (amount <= 0) {
      return error("invalid_amount", "Honey amount must be positive.", { amount_centi: amountCenti });
    }
    const cleanSource = cleanString(source) || "unknown";
    const key = this.operationKey(idempotencyKey, "grant", cleanPlayer, cleanSource, amount);
    const existing = this.operationResults.get(key);
    if (existing != null) {
      return clone(existing);
    }
    this.balances.set(cleanPlayer, this.getBalanceCenti(cleanPlayer) + amount);
    const transaction = this.appendTransaction("grant", cleanPlayer, amount, cleanSource, key, metadata);
    const result = {
      ok: true,
      player_id: cleanPlayer,
      amount_centi: amount,
      balance_centi: this.getBalanceCenti(cleanPlayer),
      transaction
    };
    this.storeOperation(key, result);
    return result;
  }

  recordActivity(input: HoneyActivityInput, idempotencyKey = ""): JsonRecord {
    const cleanPlayer = cleanString(input.player_id);
    const activityKey = cleanString(input.activity_key);
    if (!cleanPlayer) {
      return error("missing_player_id", "Player id is required.");
    }
    if (!activityKey) {
      return error("missing_activity_key", "Honey activity key is required.");
    }
    const key = this.operationKey(idempotencyKey, "activity", cleanPlayer, activityKey, cleanString(recordValue(input.metadata).event_id));
    const existing = this.operationResults.get(key);
    if (existing != null) {
      return clone(existing);
    }
    const occurredUnix = Math.max(0, intValue(input.occurred_unix, nowUnix())) || nowUnix();
    const policy = evaluateHoneyActivity(
      { ...input, player_id: cleanPlayer, activity_key: activityKey, occurred_unix: occurredUnix },
      this.activityHistory(),
      occurredUnix
    );
    const activityRecord = {
      activity_id: `hact_${this.activityRecords.length + 1}`,
      player_id: cleanPlayer,
      activity_key: activityKey,
      entap_title: policy.entap_title,
      occurred_unix: occurredUnix,
      amount_centi: policy.amount_centi,
      policy,
      metadata: clone(recordValue(input.metadata))
    };
    this.activityRecords.push(activityRecord);
    if (policy.amount_centi <= 0) {
      const denied = {
        ok: true,
        awarded: false,
        player_id: cleanPlayer,
        activity_key: activityKey,
        amount_centi: 0,
        policy,
        activity: activityRecord,
        balance_centi: this.getBalanceCenti(cleanPlayer)
      };
      this.storeOperation(key, denied);
      return denied;
    }
    this.balances.set(cleanPlayer, this.getBalanceCenti(cleanPlayer) + policy.amount_centi);
    const transaction = this.appendTransaction("activity_grant", cleanPlayer, policy.amount_centi, activityKey, key, {
      ...recordValue(input.metadata),
      entap_title: policy.entap_title,
      policy
    });
    const result = {
      ok: true,
      awarded: true,
      player_id: cleanPlayer,
      activity_key: activityKey,
      amount_centi: policy.amount_centi,
      balance_centi: this.getBalanceCenti(cleanPlayer),
      policy,
      activity: activityRecord,
      transaction
    };
    this.storeOperation(key, result);
    return result;
  }

  debit(playerId: string, amountCenti: number, source: string, metadata: JsonRecord = {}, idempotencyKey = ""): JsonRecord {
    const cleanPlayer = cleanString(playerId);
    const amount = Math.max(0, intValue(amountCenti));
    if (!cleanPlayer) {
      return error("missing_player_id", "Player id is required.");
    }
    if (amount <= 0) {
      return error("invalid_amount", "Honey amount must be positive.", { amount_centi: amountCenti });
    }
    if (this.getBalanceCenti(cleanPlayer) < amount) {
      return error("insufficient_honey", "Player does not have enough Honey.", {
        player_id: cleanPlayer,
        balance_centi: this.getBalanceCenti(cleanPlayer),
        required_centi: amount
      });
    }
    const cleanSource = cleanString(source) || "unknown";
    const key = this.operationKey(idempotencyKey, "debit", cleanPlayer, cleanSource, amount);
    const existing = this.operationResults.get(key);
    if (existing != null) {
      return clone(existing);
    }
    this.balances.set(cleanPlayer, this.getBalanceCenti(cleanPlayer) - amount);
    const transaction = this.appendTransaction("debit", cleanPlayer, -amount, cleanSource, key, metadata);
    const result = {
      ok: true,
      player_id: cleanPlayer,
      amount_centi: amount,
      balance_centi: this.getBalanceCenti(cleanPlayer),
      transaction
    };
    this.storeOperation(key, result);
    return result;
  }

  previewHivePurchase(hiveId: string, memberIds: string[], costCenti: number): JsonRecord {
    const cleanHive = cleanString(hiveId);
    const cost = Math.max(0, intValue(costCenti));
    if (!cleanHive) {
      return error("missing_hive_id", "Hive id is required.");
    }
    if (cost <= 0) {
      return error("invalid_amount", "Hive purchase amount must be positive.", { cost_centi: costCenti });
    }
    const cleanMembers = [...new Set(memberIds.map(cleanString).filter(Boolean))].sort();
    if (cleanMembers.length <= 0) {
      return error("missing_members", "At least one Hive member is required.");
    }
    const balances = cleanMembers.map((playerId) => ({ player_id: playerId, balance_centi: this.getBalanceCenti(playerId) }));
    const positiveBalances = balances.filter((entry) => entry.balance_centi > 0);
    const total = positiveBalances.reduce((sum, entry) => sum + entry.balance_centi, 0);
    if (total < cost) {
      return error("insufficient_hive_honey", "Hive members do not have enough Honey.", {
        hive_id: cleanHive,
        available_centi: total,
        required_centi: cost
      });
    }
    let remaining = cost;
    const deductions: JsonRecord[] = [];
    for (let i = 0; i < positiveBalances.length; i += 1) {
      const entry = positiveBalances[i];
      const deduction = i === positiveBalances.length - 1
        ? remaining
        : Math.min(entry.balance_centi, Math.floor((cost * entry.balance_centi) / total));
      remaining -= deduction;
      deductions.push({
        player_id: entry.player_id,
        balance_before_centi: entry.balance_centi,
        deduction_centi: deduction,
        balance_after_centi: Math.max(0, entry.balance_centi - deduction),
        share_bps: Math.round((10_000 * entry.balance_centi) / Math.max(1, total))
      });
    }
    return {
      ok: true,
      hive_id: cleanHive,
      cost_centi: cost,
      available_centi: total,
      deductions,
      deduction_model: "member_owned_proportional"
    };
  }

  debitHivePurchase(hiveId: string, memberIds: string[], costCenti: number, source: string, metadata: JsonRecord = {}, idempotencyKey = ""): JsonRecord {
    const preview = this.previewHivePurchase(hiveId, memberIds, costCenti);
    if (preview.ok !== true) {
      return preview;
    }
    const cleanHive = cleanString(hiveId);
    const cleanSource = cleanString(source) || "hive_purchase";
    const cost = intValue(preview.cost_centi);
    const membersKey = (preview.deductions as JsonRecord[]).map((entry) => cleanString(entry.player_id)).join(",");
    const key = this.operationKey(idempotencyKey, "hive_debit", cleanHive, cleanSource, cost, membersKey);
    const existing = this.operationResults.get(key);
    if (existing != null) {
      return clone(existing);
    }
    const transactions: HoneyTransaction[] = [];
    const deductions = (preview.deductions as JsonRecord[]).map((entry) => clone(entry));
    for (const deduction of deductions) {
      const playerId = cleanString(deduction.player_id);
      const amount = Math.max(0, intValue(deduction.deduction_centi));
      if (!playerId || amount <= 0) {
        continue;
      }
      this.balances.set(playerId, this.getBalanceCenti(playerId) - amount);
      transactions.push(this.appendTransaction("hive_debit", playerId, -amount, cleanSource, `${key}:${playerId}`, {
        ...metadata,
        hive_id: cleanHive,
        hive_purchase_idempotency_key: key
      }));
      deduction.balance_after_centi = this.getBalanceCenti(playerId);
    }
    const result = {
      ok: true,
      hive_id: cleanHive,
      cost_centi: cost,
      deductions,
      transactions,
      deduction_model: "member_owned_proportional"
    };
    this.storeOperation(key, result);
    return result;
  }

  getTransactionLedger(filters: JsonRecord = {}): JsonRecord[] {
    const playerId = cleanString(filters.player_id);
    const type = cleanString(filters.type ?? filters.transaction_type);
    const source = cleanString(filters.source);
    const limit = Math.max(0, Math.min(1000, intValue(filters.limit, 250)));
    const sortDesc = filters.sort_desc !== false;
    let rows = this.transactions.filter((transaction) => {
      if (playerId && transaction.player_id !== playerId) {
        return false;
      }
      if (type && transaction.type !== type) {
        return false;
      }
      if (source && transaction.source !== source) {
        return false;
      }
      return true;
    });
    rows = rows.sort((a, b) => sortDesc ? b.transaction_seq - a.transaction_seq : a.transaction_seq - b.transaction_seq);
    return rows.slice(0, limit).map((row) => clone(row));
  }

  getSnapshot(): JsonRecord {
    return {
      schema_version: SNAPSHOT_SCHEMA_VERSION,
      type: SNAPSHOT_TYPE,
      precision: "centi_honey",
      storage: this.getStorageSnapshot(),
      balances_by_player: Object.fromEntries(this.balances.entries()),
      transactions: this.transactions.map((entry) => clone(entry)),
      activity_records: this.activityRecords.map((entry) => clone(entry)),
      policy: honeyActivitySpecsSnapshot(),
      operation_results: Object.fromEntries(this.operationResults.entries()),
      next_transaction_seq: this.nextTransactionSeq
    };
  }

  private appendTransaction(type: string, playerId: string, amountCenti: number, source: string, idempotencyKey: string, metadata: JsonRecord): HoneyTransaction {
    const cleanPlayer = cleanString(playerId);
    const transaction: HoneyTransaction = {
      transaction_id: `htx_${this.nextTransactionSeq.toString().padStart(8, "0")}`,
      transaction_seq: this.nextTransactionSeq,
      type,
      player_id: cleanPlayer,
      amount_centi: intValue(amountCenti),
      balance_after_centi: this.getBalanceCenti(cleanPlayer),
      source: cleanString(source) || "unknown",
      idempotency_key: cleanString(idempotencyKey),
      created_unix: nowUnix(),
      metadata: clone(metadata)
    };
    this.nextTransactionSeq += 1;
    this.transactions.push(transaction);
    this.persistToStore();
    return clone(transaction);
  }

  private operationKey(idempotencyKey: string, ...fallbackParts: unknown[]): string {
    const explicit = cleanString(idempotencyKey);
    if (explicit) {
      return explicit;
    }
    return fallbackParts.map((part) => cleanString(part)).join(":");
  }

  private storeOperation(key: string, result: JsonRecord): void {
    this.operationResults.set(key, clone(result));
    this.persistToStore();
  }

  private loadFromStore(): void {
    const snapshot = this.storeAdapter.load();
    if (snapshot == null) {
      return;
    }
    const balances = recordValue(snapshot.balances_by_player);
    for (const [playerId, value] of Object.entries(balances)) {
      const cleanPlayer = cleanString(playerId);
      if (cleanPlayer) {
        this.balances.set(cleanPlayer, Math.max(0, intValue(value)));
      }
    }
    this.transactions = arrayValue(snapshot.transactions)
      .map((entry) => recordValue(entry) as HoneyTransaction)
      .filter((entry) => cleanString(entry.transaction_id) && cleanString(entry.player_id));
    this.activityRecords = arrayValue(snapshot.activity_records).map((entry) => clone(recordValue(entry)));
    const operations = recordValue(snapshot.operation_results);
    for (const [key, value] of Object.entries(operations)) {
      this.operationResults.set(key, clone(recordValue(value)));
    }
    this.nextTransactionSeq = Math.max(intValue(snapshot.next_transaction_seq, 0), this.inferNextTransactionSeq());
  }

  private persistToStore(): void {
    this.storeAdapter.save(this.getSnapshot());
  }

  private inferNextTransactionSeq(): number {
    let maxSeq = 0;
    for (const entry of this.transactions) {
      maxSeq = Math.max(maxSeq, intValue(entry.transaction_seq, 0));
    }
    return maxSeq + 1;
  }

  private activityHistory(): HoneyActivityHistoryEntry[] {
    return this.activityRecords.map((entry) => ({
      player_id: cleanString(entry.player_id),
      activity_key: cleanString(entry.activity_key),
      opponent_key: cleanString(recordValue(entry.policy).opponent_key) || normalizeOpponentKey(recordValue(entry.metadata).opponent_ids),
      occurred_unix: Math.max(0, intValue(entry.occurred_unix, 0)),
      awarded_centi: Math.max(0, intValue(entry.amount_centi, 0))
    }));
  }
}

export const honeyLedger = new HoneyLedger();
