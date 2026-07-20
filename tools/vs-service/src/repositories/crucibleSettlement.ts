import type { Pool, PoolClient } from "pg";
import { deepClone, DurableCoreError, sha256Canonical, uuidV7, type JsonRecord } from "./durableCore.js";

type Executor = Pick<Pool, "query"> | Pick<PoolClient, "query">;
type Row = Record<string, unknown>;
const STAKE_EACH = 1_000;
const POT = 2_000;
const WINNER_PAYOUT = 1_800;
const RESERVE_CONTRIBUTION = 200;
const RESERVE_ACCOUNT = "reserve:award";
const SYSTEM_ACCOUNT = "system:issuance";

export type CrucibleEscrowView = {
  escrowId: string; matchId: string; playerAId: string; playerBId: string;
  stakeEachMillis: 1000; potMillis: 2000; winnerPayoutMillis: 1800;
  awardReserveMillis: 200; status: "ESCROWED" | "SETTLED" | "REFUNDED" | "REVERSED";
};

export class PostgresCrucibleSettlementRepository {
  constructor(private readonly pool: Pool) {}

  async setPlayerBalance(playerId: string, balanceMillis: number, requestId: string, nowIso: string): Promise<JsonRecord> {
    const target = Math.max(0, Math.trunc(balanceMillis));
    const requestHash = sha256Canonical({ player_id: playerId, balance_millis: target });
    return this.transaction(async (client) => {
      const duplicate = await claimReceipt(client, "crucible.balance.v1", playerId, requestId, requestHash, nowIso);
      if (duplicate) return { ...duplicate, duplicate: true };
      await ensureAccount(client, playerAccount(playerId), "PLAYER", playerId, nowIso);
      const locked = await client.query<Row>("SELECT balance_millis FROM vs_crucible_accounts WHERE account_key = $1 FOR UPDATE", [playerAccount(playerId)]);
      const current = Number(locked.rows[0]?.balance_millis ?? 0);
      const delta = target - current;
      let transactionId: string | null = null;
      if (delta !== 0) {
        transactionId = await postTransaction(client, null, "BALANCE_ADJUSTMENT", requestId, requestHash, null,
          [{ account: playerAccount(playerId), amount: delta }, { account: SYSTEM_ACCOUNT, amount: -delta }],
          { actor: "ops", player_id: playerId }, nowIso);
      }
      const response = { ok: true, player_id: playerId, balance_millis: target, transaction_id: transactionId };
      await completeReceipt(client, "crucible.balance.v1", playerId, requestId, response, transactionId ?? playerId, nowIso);
      return response;
    });
  }

  async openEscrow(matchId: string, requestId: string, nowIso: string): Promise<JsonRecord> {
    const requestHash = sha256Canonical({ match_id: matchId });
    return this.transaction(async (client) => {
      const duplicate = await claimReceipt(client, "crucible.escrow.v1", matchId, requestId, requestHash, nowIso);
      if (duplicate) return { ...duplicate, duplicate: true };
      const contract = await crucibleContract(client, matchId, true);
      const roster = await humanRoster(client, String(contract.contract_id));
      if (roster.length !== 2) throw new DurableCoreError("crucible_roster_invalid");
      const [a, b] = roster.map((row) => String(row.player_id));
      await ensureAccount(client, playerAccount(a), "PLAYER", a, nowIso);
      await ensureAccount(client, playerAccount(b), "PLAYER", b, nowIso);
      await ensureAccount(client, escrowAccount(matchId), "ESCROW", null, nowIso);
      const balances = await client.query<Row>(
        "SELECT account_key, balance_millis FROM vs_crucible_accounts WHERE account_key IN ($1, $2) ORDER BY account_key FOR UPDATE",
        [playerAccount(a), playerAccount(b)]
      );
      if (balances.rows.length !== 2 || balances.rows.some((row) => Number(row.balance_millis) < STAKE_EACH)) {
        throw new DurableCoreError("insufficient_wax");
      }
      const existing = await client.query<Row>("SELECT * FROM vs_crucible_escrows WHERE match_id = $1", [matchId]);
      if (existing.rows[0]) throw new DurableCoreError("crucible_escrow_already_exists");
      const transactionId = await postTransaction(client, matchId, "ESCROW_OPEN", requestId, requestHash, null,
        [{ account: playerAccount(a), amount: -STAKE_EACH }, { account: escrowAccount(matchId), amount: STAKE_EACH },
          { account: playerAccount(b), amount: -STAKE_EACH }, { account: escrowAccount(matchId), amount: STAKE_EACH }],
        { contract_id: contract.contract_id }, nowIso);
      const escrowId = uuidV7();
      await client.query(
        `INSERT INTO vs_crucible_escrows
          (escrow_id, match_id, contract_id, player_a_id, player_b_id, stake_each_millis, pot_millis,
           winner_payout_millis, award_reserve_millis, status, open_transaction_id, opened_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, 1000, 2000, 1800, 200, 'ESCROWED', $6, $7, $7)`,
        [escrowId, matchId, contract.contract_id, a, b, transactionId, nowIso]
      );
      const response = { ok: true, escrow: escrowView({ escrow_id: escrowId, match_id: matchId,
        player_a_id: a, player_b_id: b, status: "ESCROWED" }) };
      await completeReceipt(client, "crucible.escrow.v1", matchId, requestId, response, escrowId, nowIso);
      return response;
    });
  }

  async settleVerified(matchId: string, resultId: string, requestId: string, nowIso: string): Promise<JsonRecord> {
    const requestHash = sha256Canonical({ match_id: matchId, result_id: resultId });
    return this.transaction(async (client) => {
      const duplicate = await claimReceipt(client, "crucible.settlement.v1", matchId, requestId, requestHash, nowIso);
      if (duplicate) return { ...duplicate, duplicate: true };
      const escrowResult = await client.query<Row>("SELECT * FROM vs_crucible_escrows WHERE match_id = $1 FOR UPDATE", [matchId]);
      const escrow = escrowResult.rows[0];
      if (!escrow) throw new DurableCoreError("crucible_escrow_not_found");
      if (String(escrow.status) !== "ESCROWED") throw new DurableCoreError("crucible_escrow_not_open");
      const evidence = await client.query<Row>(
        `SELECT r.result_json, r.terminal_reason FROM vs_terminal_results r
         JOIN vs_verifier_signed_receipts s ON s.result_id = r.result_id
         JOIN vs_match_contracts c ON c.contract_id = r.contract_id
         WHERE r.result_id = $1 AND r.match_id = $2 AND c.mode_id = 'CRUCIBLE_1V1'
           AND c.authority_tier = 'AUTHORITY_VERIFIED'`, [resultId, matchId]
      );
      const result = evidence.rows[0];
      if (!result) throw new DurableCoreError("crucible_verified_result_required");
      if (String(result.terminal_reason) === "NO_CONTEST") throw new DurableCoreError("crucible_no_contest_requires_refund");
      const payload = json(result.result_json);
      const placements = Array.isArray(payload.placements) ? payload.placements as JsonRecord[] : [];
      const winner = String((Array.isArray(placements[0]?.player_ids) ? placements[0].player_ids as unknown[] : [])[0] ?? "");
      const players = [String(escrow.player_a_id), String(escrow.player_b_id)];
      if (!players.includes(winner)) throw new DurableCoreError("crucible_verified_winner_invalid");
      const loser = players.find((id) => id !== winner) ?? "";
      const transactionId = await postTransaction(client, matchId, "WINNER_SETTLEMENT", requestId, requestHash, null,
        [{ account: escrowAccount(matchId), amount: -WINNER_PAYOUT }, { account: playerAccount(winner), amount: WINNER_PAYOUT },
          { account: escrowAccount(matchId), amount: -RESERVE_CONTRIBUTION }, { account: RESERVE_ACCOUNT, amount: RESERVE_CONTRIBUTION }],
        { result_id: resultId }, nowIso);
      const settlementId = uuidV7();
      await client.query(
        `INSERT INTO vs_crucible_settlements
          (settlement_id, escrow_id, match_id, result_id, winner_player_id, loser_player_id,
           payout_millis, reserve_millis, transaction_id, settled_at)
         VALUES ($1, $2, $3, $4, $5, $6, 1800, 200, $7, $8)`,
        [settlementId, escrow.escrow_id, matchId, resultId, winner, loser, transactionId, nowIso]
      );
      await client.query("UPDATE vs_crucible_escrows SET status = 'SETTLED', updated_at = $2 WHERE escrow_id = $1",
        [escrow.escrow_id, nowIso]);
      const response = { ok: true, settlement: { settlement_id: settlementId, match_id: matchId, result_id: resultId,
        winner_id: winner, loser_id: loser, stake_each: STAKE_EACH, pot: POT, winner_payout: WINNER_PAYOUT,
        award_reserve: RESERVE_CONTRIBUTION, status: "SETTLED", transaction_id: transactionId } };
      await completeReceipt(client, "crucible.settlement.v1", matchId, requestId, response, settlementId, nowIso);
      return response;
    });
  }

  async refund(matchId: string, reason: string, requestId: string, nowIso: string): Promise<JsonRecord> {
    const requestHash = sha256Canonical({ match_id: matchId, reason });
    return this.transaction(async (client) => {
      const duplicate = await claimReceipt(client, "crucible.refund.v1", matchId, requestId, requestHash, nowIso);
      if (duplicate) return { ...duplicate, duplicate: true };
      const found = await client.query<Row>("SELECT * FROM vs_crucible_escrows WHERE match_id = $1 FOR UPDATE", [matchId]);
      const escrow = found.rows[0];
      if (!escrow) throw new DurableCoreError("crucible_escrow_not_found");
      if (String(escrow.status) !== "ESCROWED") throw new DurableCoreError("crucible_escrow_not_open");
      const transactionId = await postTransaction(client, matchId, "REFUND", requestId, requestHash, null,
        [{ account: escrowAccount(matchId), amount: -STAKE_EACH }, { account: playerAccount(String(escrow.player_a_id)), amount: STAKE_EACH },
          { account: escrowAccount(matchId), amount: -STAKE_EACH }, { account: playerAccount(String(escrow.player_b_id)), amount: STAKE_EACH }],
        { reason }, nowIso);
      const refundId = uuidV7();
      await client.query(
        `INSERT INTO vs_crucible_refunds
          (refund_id, escrow_id, match_id, reason, player_a_refund_millis, player_b_refund_millis, transaction_id, refunded_at)
         VALUES ($1, $2, $3, $4, 1000, 1000, $5, $6)`,
        [refundId, escrow.escrow_id, matchId, reason, transactionId, nowIso]
      );
      await client.query("UPDATE vs_crucible_escrows SET status = 'REFUNDED', updated_at = $2 WHERE escrow_id = $1",
        [escrow.escrow_id, nowIso]);
      const response = { ok: true, refund: { refund_id: refundId, match_id: matchId, reason,
        player_a_refund: STAKE_EACH, player_b_refund: STAKE_EACH, status: "REFUNDED", transaction_id: transactionId } };
      await completeReceipt(client, "crucible.refund.v1", matchId, requestId, response, refundId, nowIso);
      return response;
    });
  }

  async reverseSettlement(matchId: string, reason: string, requestId: string, nowIso: string): Promise<JsonRecord> {
    const requestHash = sha256Canonical({ match_id: matchId, reason });
    return this.transaction(async (client) => {
      const duplicate = await claimReceipt(client, "crucible.reversal.v1", matchId, requestId, requestHash, nowIso);
      if (duplicate) return { ...duplicate, duplicate: true };
      const found = await client.query<Row>(
        `SELECT e.*, s.settlement_id, s.transaction_id AS settlement_transaction_id,
          s.winner_player_id, s.loser_player_id
         FROM vs_crucible_escrows e JOIN vs_crucible_settlements s ON s.escrow_id = e.escrow_id
         WHERE e.match_id = $1 FOR UPDATE`, [matchId]
      );
      const row = found.rows[0];
      if (!row) throw new DurableCoreError("crucible_settlement_not_found");
      if (String(row.status) !== "SETTLED") throw new DurableCoreError("crucible_settlement_not_reversible");
      const winner = String(row.winner_player_id); const loser = String(row.loser_player_id);
      const transactionId = await postTransaction(client, matchId, "REVERSAL", requestId, requestHash,
        String(row.settlement_transaction_id),
        [{ account: playerAccount(winner), amount: -WINNER_PAYOUT }, { account: RESERVE_ACCOUNT, amount: -RESERVE_CONTRIBUTION },
          { account: escrowAccount(matchId), amount: POT }, { account: escrowAccount(matchId), amount: -STAKE_EACH },
          { account: playerAccount(winner), amount: STAKE_EACH }, { account: escrowAccount(matchId), amount: -STAKE_EACH },
          { account: playerAccount(loser), amount: STAKE_EACH }], { reason }, nowIso);
      const reversalId = uuidV7();
      await client.query(
        `INSERT INTO vs_crucible_reversals
          (reversal_id, match_id, settlement_id, settlement_transaction_id, reversal_transaction_id, reason, reversed_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [reversalId, matchId, row.settlement_id, row.settlement_transaction_id, transactionId, reason, nowIso]
      );
      await client.query("UPDATE vs_crucible_escrows SET status = 'REVERSED', updated_at = $2 WHERE escrow_id = $1",
        [row.escrow_id, nowIso]);
      const response = { ok: true, reversal: { reversal_id: reversalId, match_id: matchId,
        reversal_of_transaction_id: row.settlement_transaction_id, transaction_id: transactionId,
        player_a_refund: STAKE_EACH, player_b_refund: STAKE_EACH, status: "REVERSED", reason } };
      await completeReceipt(client, "crucible.reversal.v1", matchId, requestId, response, reversalId, nowIso);
      return response;
    });
  }

  async reconcile(): Promise<JsonRecord> {
    const transactions = await this.pool.query<Row>(
      `SELECT count(*)::int AS invalid_transaction_count FROM (
        SELECT transaction_id FROM vs_crucible_journal_entries GROUP BY transaction_id HAVING sum(amount_millis) <> 0
       ) invalid`
    );
    const accounts = await this.pool.query<Row>(
      `SELECT count(*)::int AS divergent_account_count FROM vs_crucible_accounts a
       LEFT JOIN (SELECT account_key, sum(amount_millis) AS journal_balance FROM vs_crucible_journal_entries GROUP BY account_key) j
         ON j.account_key = a.account_key
       WHERE a.balance_millis <> COALESCE(j.journal_balance, 0)`
    );
    const invalidTransactions = Number(transactions.rows[0]?.invalid_transaction_count ?? 0);
    const divergentAccounts = Number(accounts.rows[0]?.divergent_account_count ?? 0);
    return { ok: invalidTransactions === 0 && divergentAccounts === 0,
      invalid_transaction_count: invalidTransactions, divergent_account_count: divergentAccounts };
  }

  async metrics(): Promise<JsonRecord> {
    const accounts = await this.pool.query<Row>(
      `SELECT COALESCE(sum(balance_millis) FILTER (WHERE account_type = 'AWARD_RESERVE'), 0) AS reserve,
        COALESCE(sum(balance_millis) FILTER (WHERE account_type = 'ESCROW'), 0) AS escrow
       FROM vs_crucible_accounts`
    );
    const journal = await this.pool.query<Row>(
      `SELECT COALESCE(sum(amount_millis), 0) AS imbalance,
        count(DISTINCT transaction_id)::int AS transaction_count FROM vs_crucible_journal_entries`
    );
    const counts = await this.pool.query<Row>(
      `SELECT count(*) FILTER (WHERE status = 'ESCROWED')::int AS open_escrows,
        count(*) FILTER (WHERE status = 'SETTLED')::int AS settled,
        count(*) FILTER (WHERE status = 'REFUNDED')::int AS refunded FROM vs_crucible_escrows`
    );
    const reconciliation = await this.reconcile();
    return { ok: true, award_reserve_balance_millis: Number(accounts.rows[0]?.reserve ?? 0),
      escrow_balance_millis: Number(accounts.rows[0]?.escrow ?? 0), ledger_imbalance_millis: Number(journal.rows[0]?.imbalance ?? 0),
      transaction_count: Number(journal.rows[0]?.transaction_count ?? 0), reconciliation, ...counts.rows[0] };
  }

  async balance(playerId: string): Promise<number> {
    const result = await this.pool.query<Row>("SELECT balance_millis FROM vs_crucible_accounts WHERE account_key = $1", [playerAccount(playerId)]);
    return Number(result.rows[0]?.balance_millis ?? 0);
  }

  private async transaction<T>(body: (client: PoolClient) => Promise<T>): Promise<T> {
    const client = await this.pool.connect();
    try { await client.query("BEGIN"); const result = await body(client); await client.query("COMMIT"); return result; }
    catch (error) { try { await client.query("ROLLBACK"); } catch {} throw normalize(error); }
    finally { client.release(); }
  }
}

async function crucibleContract(client: Executor, matchId: string, lock: boolean): Promise<Row> {
  const result = await client.query<Row>(
    `SELECT * FROM vs_match_contracts WHERE match_id = $1 AND mode_id = 'CRUCIBLE_1V1'
      AND authority_tier = 'AUTHORITY_VERIFIED'${lock ? " FOR UPDATE" : ""}`, [matchId]
  );
  if (!result.rows[0]) throw new DurableCoreError("crucible_contract_not_found");
  return result.rows[0];
}
async function humanRoster(client: Executor, contractId: string): Promise<Row[]> {
  const result = await client.query<Row>(
    "SELECT * FROM vs_match_roster WHERE contract_id = $1 AND participant_type = 'HUMAN' ORDER BY seat_id", [contractId]
  );
  return result.rows;
}
async function ensureAccount(client: Executor, key: string, type: string, playerId: string | null, nowIso: string): Promise<void> {
  await client.query(
    `INSERT INTO vs_crucible_accounts (account_key, account_type, player_id, balance_millis, created_at, updated_at)
     VALUES ($1, $2, $3, 0, $4, $4) ON CONFLICT (account_key) DO NOTHING`, [key, type, playerId, nowIso]
  );
}
async function postTransaction(client: Executor, matchId: string | null, operation: string, requestId: string,
  requestHash: string, reversalOf: string | null, lines: Array<{ account: string; amount: number }>, metadata: JsonRecord,
  nowIso: string): Promise<string> {
  if (lines.reduce((sum, line) => sum + line.amount, 0) !== 0) throw new DurableCoreError("crucible_ledger_unbalanced");
  const transactionId = uuidV7();
  await client.query(
    `INSERT INTO vs_crucible_transactions
      (transaction_id, match_id, operation_type, request_id, request_hash, reversal_of_transaction_id, metadata, created_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, $8)`,
    [transactionId, matchId, operation, requestId, requestHash, reversalOf, JSON.stringify(metadata), nowIso]
  );
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    await client.query(
      "UPDATE vs_crucible_accounts SET balance_millis = balance_millis + $2, updated_at = $3 WHERE account_key = $1",
      [line.account, line.amount, nowIso]
    );
    await client.query(
      `INSERT INTO vs_crucible_journal_entries (transaction_id, line_number, account_key, amount_millis, created_at)
       VALUES ($1, $2, $3, $4, $5)`, [transactionId, index + 1, line.account, line.amount, nowIso]
    );
  }
  return transactionId;
}
async function claimReceipt(client: Executor, namespace: string, subject: string, key: string, requestHash: string,
  nowIso: string): Promise<JsonRecord | null> {
  const found = await client.query<Row>(
    `SELECT request_hash, status, response_json FROM vs_idempotency_receipts
     WHERE namespace = $1 AND authoritative_subject = $2 AND idempotency_key = $3 FOR UPDATE`,
    [namespace, subject, key]
  );
  if (found.rows[0]) {
    if (String(found.rows[0].request_hash) !== requestHash) throw new DurableCoreError("idempotency_conflict");
    if (String(found.rows[0].status) !== "COMPLETED") throw new DurableCoreError("idempotency_in_progress");
    return json(found.rows[0].response_json);
  }
  await client.query(
    `INSERT INTO vs_idempotency_receipts
      (namespace, authoritative_subject, idempotency_key, request_hash, status, created_at, updated_at)
     VALUES ($1, $2, $3, $4, 'PENDING', $5, $5)`, [namespace, subject, key, requestHash, nowIso]
  );
  return null;
}
async function completeReceipt(client: Executor, namespace: string, subject: string, key: string, response: JsonRecord,
  sideEffect: string, nowIso: string): Promise<void> {
  await client.query(
    `UPDATE vs_idempotency_receipts SET status = 'COMPLETED', response_json = $4::jsonb,
      side_effect_ref = $5, updated_at = $6
     WHERE namespace = $1 AND authoritative_subject = $2 AND idempotency_key = $3`,
    [namespace, subject, key, JSON.stringify(response), sideEffect, nowIso]
  );
}
function escrowView(row: Row): CrucibleEscrowView {
  return { escrowId: String(row.escrow_id), matchId: String(row.match_id), playerAId: String(row.player_a_id),
    playerBId: String(row.player_b_id), stakeEachMillis: 1000, potMillis: 2000, winnerPayoutMillis: 1800,
    awardReserveMillis: 200, status: String(row.status) as CrucibleEscrowView["status"] };
}
function playerAccount(playerId: string): string { return `player:${playerId}`; }
function escrowAccount(matchId: string): string { return `escrow:${matchId}`; }
function json(value: unknown): JsonRecord {
  if (typeof value === "string") value = JSON.parse(value);
  if (typeof value !== "object" || value == null || Array.isArray(value)) throw new DurableCoreError("stored_json_invalid");
  return deepClone(value as JsonRecord);
}
function normalize(error: unknown): unknown {
  if (error instanceof DurableCoreError) return error;
  const pg = error as { code?: string; constraint?: string; message?: string };
  if (pg.code === "23514" && pg.constraint?.includes("balance_millis")) return new DurableCoreError("insufficient_wax");
  return error;
}
