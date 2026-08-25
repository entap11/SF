import type { Pool, PoolClient } from "pg";
import { computeGain, computeLoss } from "./logic.js";
import { evaluateHoneyFact, evaluateNectarMatchFact, honeyCatalogItem, opponentKey, passLevelForNectarMilli } from "./platformPolicies.js";
import { sha256Canonical } from "./verifiedReceipt.js";

export type PlatformAsset = "HONEY_CENTI" | "WAX_MILLIS" | "NECTAR_MILLI";
export type PlatformCapability = "NECTAR" | "HONEY_EARN" | "HONEY_SPEND" | "WAX_STANDARD" | "WAX_CRUCIBLE";
export type PlatformEpochState = "DRAFT" | "PREPARED" | "RECONCILED" | "ACTIVE" | "ABORTED";
export type JsonRecord = Record<string, unknown>;

export type ProducerEnvelope = {
  producerService: string;
  producerEventId: string;
  eventType: string;
  epochId: string;
  sourceAuthority: string;
  occurredAt: string;
  schemaVersion: number;
  payload: JsonRecord;
};

type Posting = {
  accountId: string;
  asset: PlatformAsset;
  deltaUnits: number;
};

type AccountSpec = {
  accountId: string;
  asset: PlatformAsset;
  accountType: "PLAYER" | "ESCROW" | "AWARD_RESERVE" | "ISSUANCE" | "SINK";
  ownerId: string;
};

type EventWorkResult = {
  response: JsonRecord;
  transactionId?: string;
};

export class PlatformEconomyError extends Error {
  constructor(readonly code: string, readonly status = 400) {
    super(code);
    this.name = "PlatformEconomyError";
  }
}

export class PlatformEconomyRepository {
  constructor(private readonly pool: Pool) {}

  async getCurrentEpoch(): Promise<JsonRecord | null> {
    const result = await this.pool.query<JsonRecord>(
      `SELECT epoch_id, state, is_current, season_id, opening_honey_centi::text,
              opening_wax_millis::text, opening_nectar_milli::text, artifact_digest,
              prepared_at, reconciled_at, activated_at
       FROM platform_economy_epochs WHERE is_current = TRUE LIMIT 1`
    );
    return result.rows[0] ? normalizeRow(result.rows[0]) : null;
  }

  async setCapability(capability: PlatformCapability, enabled: boolean): Promise<JsonRecord> {
    const result = await this.pool.query<JsonRecord>(
      `UPDATE platform_economy_capabilities
       SET enabled = $2, updated_at = now()
       WHERE capability = $1
       RETURNING capability, enabled, updated_at`,
      [capability, enabled]
    );
    if (!result.rows[0]) throw new PlatformEconomyError("unknown_capability");
    return normalizeRow(result.rows[0]);
  }

  async capabilitySnapshot(): Promise<JsonRecord> {
    const result = await this.pool.query<{ capability: string; enabled: boolean }>(
      "SELECT capability, enabled FROM platform_economy_capabilities ORDER BY capability"
    );
    return Object.fromEntries(result.rows.map((row) => [row.capability, row.enabled]));
  }

  async getPlayerBalances(playerId: string, epochId?: string): Promise<JsonRecord> {
    const epoch = epochId || await this.currentEpochId();
    const rows = await this.pool.query<{ asset: PlatformAsset; balance_units: string }>(
      `SELECT asset, balance_units::text FROM platform_economy_accounts
       WHERE epoch_id = $1 AND account_type = 'PLAYER' AND owner_id = $2`,
      [epoch, playerId]
    );
    const balances: JsonRecord = { honey_centi: 0, wax_millis: 0, nectar_milli: 0 };
    for (const row of rows.rows) balances[assetField(row.asset)] = safeInteger(row.balance_units);
    const progression = await this.pool.query<JsonRecord>(
      `SELECT p.season_id, p.fractional_milli, p.entitlement_tier, p.pass_level, p.revision::text
       FROM platform_nectar_progression p
       WHERE p.epoch_id = $1 AND p.player_id = $2
       ORDER BY p.updated_at DESC LIMIT 1`, [epoch, playerId]
    );
    const entitlements = await this.pool.query<{ entitlement_id: string }>(
      `SELECT entitlement_id FROM platform_player_entitlements
       WHERE epoch_id = $1 AND player_id = $2 ORDER BY entitlement_id`,
      [epoch, playerId]
    );
    return { ok: true, epoch_id: epoch, player_id: playerId, ...balances,
      entitlements: entitlements.rows.map((row) => row.entitlement_id),
      ...(progression.rows[0] ? normalizeRow(progression.rows[0]) : {
        season_id: "", fractional_milli: 0, entitlement_tier: "FREE", pass_level: 1, revision: 0
      }) };
  }

  async issuePlayerAsset(input: {
    envelope: ProducerEnvelope;
    playerId: string;
    asset: PlatformAsset;
    amountUnits: number;
    capability: PlatformCapability;
    metadata?: JsonRecord;
  }): Promise<JsonRecord> {
    const amount = positiveInteger(input.amountUnits, "amount_invalid");
    return this.runEvent(input.envelope, async (client, platformEventId) => {
      await this.requireCapability(client, input.capability);
      await this.requirePlayer(client, input.playerId);
      const player = await this.ensurePlayerAccount(client, input.envelope.epochId, input.playerId, input.asset);
      const issuance = await this.ensureSystemAccount(client, input.envelope.epochId, input.asset, "ISSUANCE");
      const tx = await this.postTransaction(client, platformEventId, input.envelope, [
        { accountId: issuance.accountId, asset: input.asset, deltaUnits: -amount },
        { accountId: player.accountId, asset: input.asset, deltaUnits: amount }
      ], input.metadata ?? {});
      const balance = await this.accountBalance(client, player.accountId);
      return { transactionId: tx, response: {
        ok: true, applied: true, duplicate: false, epoch_id: input.envelope.epochId,
        player_id: input.playerId, asset: input.asset, amount_units: amount,
        balance_units: balance, transaction_id: tx, platform_event_id: platformEventId
      } };
    });
  }

  async spendHoney(input: {
    envelope: ProducerEnvelope;
    playerId: string;
    catalogActionId: string;
  }): Promise<JsonRecord> {
    const action = clean(input.catalogActionId);
    if (!action) throw new PlatformEconomyError("catalog_action_missing");
    const item = honeyCatalogItem(action);
    if (!item || item.costCenti <= 0) throw new PlatformEconomyError("catalog_action_unknown");
    const cost = item.costCenti;
    return this.runEvent(input.envelope, async (client, platformEventId) => {
      await this.requireCapability(client, "HONEY_SPEND");
      await this.requirePlayer(client, input.playerId);
      const player = await this.ensurePlayerAccount(client, input.envelope.epochId, input.playerId, "HONEY_CENTI");
      await client.query(
        "SELECT account_id FROM platform_economy_accounts WHERE account_id = $1 FOR UPDATE",
        [player.accountId]
      );
      if (item.entitlements.length > 0) {
        const owned = await client.query(
          `SELECT 1 FROM platform_player_entitlements
           WHERE epoch_id = $1 AND player_id = $2 AND entitlement_id = ANY($3::text[]) LIMIT 1`,
          [input.envelope.epochId, input.playerId, [...item.entitlements]]
        );
        if ((owned.rowCount ?? 0) > 0) throw new PlatformEconomyError("catalog_item_already_owned", 409);
      }
      const sink = await this.ensureSystemAccount(client, input.envelope.epochId, "HONEY_CENTI", "SINK");
      const tx = await this.postTransaction(client, platformEventId, input.envelope, [
        { accountId: player.accountId, asset: "HONEY_CENTI", deltaUnits: -cost },
        { accountId: sink.accountId, asset: "HONEY_CENTI", deltaUnits: cost }
      ], { catalog_action_id: action });
      for (const entitlement of item.entitlements) {
        await client.query(
          `INSERT INTO platform_player_entitlements
            (epoch_id, player_id, entitlement_id, catalog_action_id, source_transaction_id)
           VALUES ($1, $2, $3, $4, $5)`,
          [input.envelope.epochId, input.playerId, entitlement, action, tx]
        );
      }
      const balance = await this.accountBalance(client, player.accountId);
      const entitlements = await client.query<{ entitlement_id: string }>(
        `SELECT entitlement_id FROM platform_player_entitlements
         WHERE epoch_id = $1 AND player_id = $2 ORDER BY entitlement_id`,
        [input.envelope.epochId, input.playerId]
      );
      return { transactionId: tx, response: {
        ok: true, applied: true, duplicate: false, epoch_id: input.envelope.epochId,
        player_id: input.playerId, catalog_action_id: action, cost_centi: cost,
        balance_centi: balance, granted_entitlements: [...item.entitlements],
        entitlements: entitlements.rows.map((row) => row.entitlement_id),
        transaction_id: tx, platform_event_id: platformEventId
      } };
    }, { stablePlayerIntent: true });
  }

  async awardHoneyActivity(envelopeInput: ProducerEnvelope): Promise<JsonRecord> {
    const playerId = uuid(envelopeInput.payload.player_id, "player_id_invalid");
    return this.runEvent(envelopeInput, async (client, platformEventId) => {
      await this.requireCapability(client, "HONEY_EARN");
      await this.requirePlayer(client, playerId);
      const key = opponentKey(envelopeInput.payload.opponent_ids);
      const repeats = await client.query<{ count: string }>(
        `SELECT count(*)::text AS count FROM platform_honey_activity_history
         WHERE epoch_id = $1 AND player_id = $2 AND activity_key = $3 AND opponent_key = $4
           AND occurred_at >= $5::timestamptz - interval '24 hours'`,
        [envelopeInput.epochId, playerId, clean(envelopeInput.payload.activity_key), key, envelopeInput.occurredAt]
      );
      const policy = evaluateHoneyFact(envelopeInput.payload, safeInteger(repeats.rows[0]?.count ?? 0));
      const amount = nonnegativeInteger(policy.amount_centi, "honey_policy_amount_invalid");
      let tx: string | undefined;
      let balance = (await this.getPlayerBalanceInTransaction(client, envelopeInput.epochId, playerId, "HONEY_CENTI"));
      if (amount > 0) {
        const player = await this.ensurePlayerAccount(client, envelopeInput.epochId, playerId, "HONEY_CENTI");
        const issuance = await this.ensureSystemAccount(client, envelopeInput.epochId, "HONEY_CENTI", "ISSUANCE");
        tx = await this.postTransaction(client, platformEventId, envelopeInput, [
          { accountId: issuance.accountId, asset: "HONEY_CENTI", deltaUnits: -amount },
          { accountId: player.accountId, asset: "HONEY_CENTI", deltaUnits: amount }
        ], policy);
        balance = await this.accountBalance(client, player.accountId);
      }
      await client.query(
        `INSERT INTO platform_honey_activity_history
          (producer_service, producer_event_id, epoch_id, player_id, activity_key,
           opponent_key, occurred_at, awarded_centi)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [envelopeInput.producerService, envelopeInput.producerEventId, envelopeInput.epochId,
          playerId, clean(policy.activity_key), key, envelopeInput.occurredAt, amount]
      );
      return { transactionId: tx, response: {
        ok: true, applied: amount > 0, awarded: amount > 0, duplicate: false,
        epoch_id: envelopeInput.epochId, player_id: playerId, amount_centi: amount,
        balance_centi: balance, policy, transaction_id: tx ?? null, platform_event_id: platformEventId
      } };
    });
  }

  async awardNectarMatch(envelopeInput: ProducerEnvelope): Promise<JsonRecord> {
    const playerId = uuid(envelopeInput.payload.player_id, "player_id_invalid");
    return this.runEvent(envelopeInput, async (client, platformEventId) => {
      await this.requireCapability(client, "NECTAR");
      await this.requirePlayer(client, playerId);
      const epoch = await this.lockEpoch(client, envelopeInput.epochId);
      const seasonId = String(epoch.season_id);
      const key = opponentKey(envelopeInput.payload.opponent_ids);
      const history = await client.query<{ repeat_count: string; daily_milli: string }>(
        `SELECT
           count(*) FILTER (WHERE opponent_key <> '' AND opponent_key = $4)::text AS repeat_count,
           COALESCE(sum(awarded_nectar_milli), 0)::text AS daily_milli
         FROM platform_nectar_award_history
         WHERE epoch_id = $1 AND season_id = $2 AND player_id = $3
           AND occurred_at >= date_trunc('day', $5::timestamptz)`,
        [envelopeInput.epochId, seasonId, playerId, key, envelopeInput.occurredAt]
      );
      const policy = evaluateNectarMatchFact(envelopeInput.payload,
        safeInteger(history.rows[0]?.repeat_count ?? 0), safeInteger(history.rows[0]?.daily_milli ?? 0));
      const baseMilli = nonnegativeInteger(policy.base_nectar_milli, "nectar_policy_amount_invalid");
      await client.query(
        `INSERT INTO platform_nectar_progression (epoch_id, season_id, player_id)
         VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`,
        [envelopeInput.epochId, seasonId, playerId]
      );
      const progression = await client.query<JsonRecord>(
        `SELECT nectar_milli::text, fractional_milli, entitlement_tier, pass_level, revision::text
         FROM platform_nectar_progression
         WHERE epoch_id = $1 AND season_id = $2 AND player_id = $3 FOR UPDATE`,
        [envelopeInput.epochId, seasonId, playerId]
      );
      const current = progression.rows[0]!;
      const tier = String(current.entitlement_tier);
      const multiplierMilli = tier === "ELITE" ? 1600 : tier === "PREMIUM" ? 1300 : 1000;
      const diminished = nonnegativeInteger(policy.diminished_nectar_milli ?? 0, "nectar_policy_amount_invalid");
      const scaled = diminished * multiplierMilli + safeInteger(current.fractional_milli);
      const awardMilli = policy.ok === true ? Math.floor(scaled / 1000) : 0;
      const fractionalMilli = policy.ok === true ? scaled % 1000 : safeInteger(current.fractional_milli);
      let tx: string | undefined;
      let balance = safeInteger(current.nectar_milli);
      if (awardMilli > 0) {
        const player = await this.ensurePlayerAccount(client, envelopeInput.epochId, playerId, "NECTAR_MILLI");
        const issuance = await this.ensureSystemAccount(client, envelopeInput.epochId, "NECTAR_MILLI", "ISSUANCE");
        tx = await this.postTransaction(client, platformEventId, envelopeInput, [
          { accountId: issuance.accountId, asset: "NECTAR_MILLI", deltaUnits: -awardMilli },
          { accountId: player.accountId, asset: "NECTAR_MILLI", deltaUnits: awardMilli }
        ], { ...policy, entitlement_tier: tier, entitlement_multiplier_milli: multiplierMilli });
        balance = await this.accountBalance(client, player.accountId);
      }
      const level = passLevelForNectarMilli(balance);
      await client.query(
        `UPDATE platform_nectar_progression
         SET nectar_milli = $4, fractional_milli = $5, pass_level = $6,
             revision = revision + 1, updated_at = now()
         WHERE epoch_id = $1 AND season_id = $2 AND player_id = $3`,
        [envelopeInput.epochId, seasonId, playerId, balance, fractionalMilli, level]
      );
      await client.query(
        `INSERT INTO platform_nectar_award_history
          (producer_service, producer_event_id, epoch_id, season_id, player_id,
           mode_id, opponent_key, occurred_at, base_nectar_milli, awarded_nectar_milli)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
        [envelopeInput.producerService, envelopeInput.producerEventId, envelopeInput.epochId,
          seasonId, playerId, clean(policy.mode_id), key, envelopeInput.occurredAt, baseMilli, awardMilli]
      );
      return { transactionId: tx, response: {
        ok: true, applied: awardMilli > 0, awarded: awardMilli > 0, duplicate: false,
        epoch_id: envelopeInput.epochId, season_id: seasonId, player_id: playerId,
        nectar_milli_awarded: awardMilli, nectar_milli: balance, fractional_milli: fractionalMilli,
        pass_level: level, entitlement_tier: tier, policy,
        transaction_id: tx ?? null, platform_event_id: platformEventId
      } };
    });
  }

  async settleStandardWax(input: {
    envelope: ProducerEnvelope;
    winnerPlayerId: string;
    loserPlayerId: string;
    modeName?: string;
    moneyTier?: number;
    noContest?: boolean;
  }): Promise<JsonRecord> {
    const winnerId = uuid(input.winnerPlayerId, "winner_player_id_invalid");
    const loserId = uuid(input.loserPlayerId, "loser_player_id_invalid");
    if (winnerId === loserId) throw new PlatformEconomyError("same_player_ids");
    return this.runEvent(input.envelope, async (client, platformEventId) => {
      await this.requireCapability(client, "WAX_STANDARD");
      await this.requirePlayer(client, winnerId);
      await this.requirePlayer(client, loserId);
      if (input.noContest === true) {
        return { response: {
          ok: true, applied: false, status: "NOT_APPLICABLE", duplicate: false,
          epoch_id: input.envelope.epochId, winner_player_id: winnerId,
          loser_player_id: loserId, platform_event_id: platformEventId
        } };
      }
      const winner = await this.ensurePlayerAccount(client, input.envelope.epochId, winnerId, "WAX_MILLIS");
      const loser = await this.ensurePlayerAccount(client, input.envelope.epochId, loserId, "WAX_MILLIS");
      const issuance = await this.ensureSystemAccount(client, input.envelope.epochId, "WAX_MILLIS", "ISSUANCE");
      const sink = await this.ensureSystemAccount(client, input.envelope.epochId, "WAX_MILLIS", "SINK");
      const winnerBefore = await this.accountBalance(client, winner.accountId);
      const loserBefore = await this.accountBalance(client, loser.accountId);
      const mode = clean(input.modeName).toUpperCase() || "STANDARD";
      const moneyTier = Math.max(0, Math.trunc(Number(input.moneyTier ?? 0)));
      const gainMillis = Math.max(0, Math.round(computeGain(winnerBefore / 1000, loserBefore / 1000, mode, moneyTier) * 1000));
      const configuredLossMillis = Math.max(0, Math.round(computeLoss(loserBefore / 1000, winnerBefore / 1000, mode, moneyTier) * 1000));
      const lossMillis = Math.min(loserBefore, configuredLossMillis);
      const postings: Posting[] = [];
      if (gainMillis > 0) postings.push(
        { accountId: issuance.accountId, asset: "WAX_MILLIS", deltaUnits: -gainMillis },
        { accountId: winner.accountId, asset: "WAX_MILLIS", deltaUnits: gainMillis }
      );
      if (lossMillis > 0) postings.push(
        { accountId: loser.accountId, asset: "WAX_MILLIS", deltaUnits: -lossMillis },
        { accountId: sink.accountId, asset: "WAX_MILLIS", deltaUnits: lossMillis }
      );
      if (postings.length === 0) throw new PlatformEconomyError("wax_policy_zero_mutation", 409);
      const tx = await this.postTransaction(client, platformEventId, input.envelope, postings, {
        mode_name: mode, money_tier: moneyTier, winner_gain_millis: gainMillis,
        loser_loss_millis: lossMillis, configured_loser_loss_millis: configuredLossMillis
      });
      const winnerAfter = await this.accountBalance(client, winner.accountId);
      const loserAfter = await this.accountBalance(client, loser.accountId);
      await client.query(
        `UPDATE rank_players SET wax_score = CASE id
           WHEN $1::uuid THEN $3::double precision / 1000.0
           WHEN $2::uuid THEN $4::double precision / 1000.0 END,
           last_active_unix = floor(extract(epoch from now()))::bigint,
           last_decay_day = floor(extract(epoch from now()) / 86400)::int,
           updated_at = now()
         WHERE id IN ($1::uuid, $2::uuid)`,
        [winnerId, loserId, winnerAfter, loserAfter]
      );
      await this.refreshRankOrder(client);
      return { transactionId: tx, response: {
        ok: true, applied: true, status: "SETTLED", duplicate: false,
        epoch_id: input.envelope.epochId, rank_event_id: input.envelope.producerEventId,
        winner: { player_id: winnerId, wax_millis: winnerAfter, wax_score: winnerAfter / 1000 },
        loser: { player_id: loserId, wax_millis: loserAfter, wax_score: loserAfter / 1000 },
        winner_gain_millis: gainMillis, loser_loss_millis: lossMillis,
        transaction_id: tx, platform_event_id: platformEventId
      } };
    });
  }

  async reserveCrucibleParticipant(input: {
    envelope: ProducerEnvelope;
    matchId: string;
    contractId: string;
    contractHash: string;
    playerId: string;
    playerAId: string;
    playerBId: string;
    expiresAt: string;
  }): Promise<JsonRecord> {
    const matchId = uuid(input.matchId, "match_id_invalid");
    const contractId = uuid(input.contractId, "contract_id_invalid");
    const contractHash = hash(input.contractHash, "contract_hash_invalid");
    const playerId = uuid(input.playerId, "player_id_invalid");
    const playerA = uuid(input.playerAId, "player_a_id_invalid");
    const playerB = uuid(input.playerBId, "player_b_id_invalid");
    if (playerA === playerB || ![playerA, playerB].includes(playerId)) {
      throw new PlatformEconomyError("crucible_roster_invalid");
    }
    if (!Number.isFinite(Date.parse(input.expiresAt))) throw new PlatformEconomyError("expires_at_invalid");
    return this.runEvent(input.envelope, async (client, platformEventId) => {
      await this.requireCapability(client, "WAX_CRUCIBLE");
      await this.requirePlayer(client, playerA);
      await this.requirePlayer(client, playerB);
      const escrow = await this.ensureAccount(client, input.envelope.epochId, {
        accountId: `escrow:crucible:${matchId}`,
        asset: "WAX_MILLIS", accountType: "ESCROW", ownerId: matchId
      });
      await client.query(
        `INSERT INTO platform_crucible_contracts
          (match_id, contract_id, contract_hash, epoch_id, player_a_id, player_b_id,
           escrow_account_id, status, expires_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, 'PENDING', $8)
         ON CONFLICT (match_id) DO NOTHING`,
        [matchId, contractId, contractHash, input.envelope.epochId, playerA, playerB, escrow.accountId, input.expiresAt]
      );
      const contract = await client.query<JsonRecord>(
        "SELECT * FROM platform_crucible_contracts WHERE match_id = $1 FOR UPDATE", [matchId]
      );
      const row = contract.rows[0];
      if (!row || String(row.contract_id) !== contractId || String(row.contract_hash) !== contractHash
        || String(row.epoch_id) !== input.envelope.epochId
        || String(row.player_a_id) !== playerA || String(row.player_b_id) !== playerB) {
        throw new PlatformEconomyError("crucible_contract_conflict", 409);
      }
      if (!['PENDING', 'RESERVED'].includes(String(row.status))) {
        throw new PlatformEconomyError("crucible_contract_terminal", 409);
      }
      const player = await this.ensurePlayerAccount(client, input.envelope.epochId, playerId, "WAX_MILLIS");
      const tx = await this.postTransaction(client, platformEventId, input.envelope, [
        { accountId: player.accountId, asset: "WAX_MILLIS", deltaUnits: -1000 },
        { accountId: escrow.accountId, asset: "WAX_MILLIS", deltaUnits: 1000 }
      ], { match_id: matchId, contract_id: contractId, player_id: playerId });
      await client.query(
        `INSERT INTO platform_crucible_reservations
          (match_id, player_id, amount_millis, producer_service, producer_event_id,
           reservation_transaction_id, status)
         VALUES ($1, $2, 1000, $3, $4, $5, 'RESERVED')`,
        [matchId, playerId, input.envelope.producerService, input.envelope.producerEventId, tx]
      );
      const count = await client.query<{ count: string }>(
        "SELECT count(*)::text AS count FROM platform_crucible_reservations WHERE match_id = $1 AND status = 'RESERVED'",
        [matchId]
      );
      const reservationCount = safeInteger(count.rows[0]?.count ?? 0);
      if (reservationCount === 2) {
        await client.query("UPDATE platform_crucible_contracts SET status = 'RESERVED', updated_at = now() WHERE match_id = $1", [matchId]);
      }
      return { transactionId: tx, response: {
        ok: true, applied: true, duplicate: false, epoch_id: input.envelope.epochId,
        match_id: matchId, contract_id: contractId, player_id: playerId,
        reserved_millis: 1000, reservation_count: reservationCount,
        startable: reservationCount === 2, transaction_id: tx, platform_event_id: platformEventId
      } };
    });
  }

  async settleCrucible(input: {
    envelope: ProducerEnvelope;
    matchId: string;
    resultId: string;
    winnerPlayerId: string;
  }): Promise<JsonRecord> {
    const matchId = uuid(input.matchId, "match_id_invalid");
    const resultId = uuid(input.resultId, "result_id_invalid");
    const winner = uuid(input.winnerPlayerId, "winner_player_id_invalid");
    return this.runEvent(input.envelope, async (client, platformEventId) => {
      await this.requireCapability(client, "WAX_CRUCIBLE");
      const contract = await this.lockCrucible(client, matchId, input.envelope.epochId, "RESERVED");
      const players = [String(contract.player_a_id), String(contract.player_b_id)];
      if (!players.includes(winner)) throw new PlatformEconomyError("winner_not_in_contract");
      const winnerAccount = await this.ensurePlayerAccount(client, input.envelope.epochId, winner, "WAX_MILLIS");
      const reserve = await this.ensureAccount(client, input.envelope.epochId, {
        accountId: `reserve:award:${input.envelope.epochId}`, asset: "WAX_MILLIS",
        accountType: "AWARD_RESERVE", ownerId: "reserve:award"
      });
      const tx = await this.postTransaction(client, platformEventId, input.envelope, [
        { accountId: String(contract.escrow_account_id), asset: "WAX_MILLIS", deltaUnits: -2000 },
        { accountId: winnerAccount.accountId, asset: "WAX_MILLIS", deltaUnits: 1800 },
        { accountId: reserve.accountId, asset: "WAX_MILLIS", deltaUnits: 200 }
      ], { match_id: matchId, result_id: resultId, winner_player_id: winner });
      await client.query(
        `UPDATE platform_crucible_contracts
         SET status = 'SETTLED', result_id = $2, winner_player_id = $3, updated_at = now()
         WHERE match_id = $1`, [matchId, resultId, winner]
      );
      await client.query(
        "UPDATE platform_crucible_reservations SET status = 'SETTLED', updated_at = now() WHERE match_id = $1",
        [matchId]
      );
      return { transactionId: tx, response: {
        ok: true, applied: true, duplicate: false, epoch_id: input.envelope.epochId,
        match_id: matchId, result_id: resultId, winner_player_id: winner,
        winner_payout_millis: 1800, award_reserve_millis: 200,
        transaction_id: tx, platform_event_id: platformEventId
      } };
    });
  }

  async refundCrucible(input: {
    envelope: ProducerEnvelope;
    matchId: string;
    resultId: string;
    reason: string;
  }): Promise<JsonRecord> {
    const matchId = uuid(input.matchId, "match_id_invalid");
    const resultId = uuid(input.resultId, "result_id_invalid");
    const reason = clean(input.reason) || "no_contest";
    return this.runEvent(input.envelope, async (client, platformEventId) => {
      await this.requireCapability(client, "WAX_CRUCIBLE");
      const contract = await this.lockCrucible(client, matchId, input.envelope.epochId, ["PENDING", "RESERVED"]);
      const reservations = await client.query<{ player_id: string; amount_millis: string }>(
        `SELECT player_id::text, amount_millis::text FROM platform_crucible_reservations
         WHERE match_id = $1 AND status = 'RESERVED' ORDER BY player_id FOR UPDATE`, [matchId]
      );
      const postings: Posting[] = [];
      let totalRefund = 0;
      for (const reservation of reservations.rows) {
        const amount = safeInteger(reservation.amount_millis);
        const player = await this.ensurePlayerAccount(client, input.envelope.epochId,
          reservation.player_id, "WAX_MILLIS");
        postings.push({ accountId: player.accountId, asset: "WAX_MILLIS", deltaUnits: amount });
        totalRefund += amount;
      }
      if (totalRefund > 0) postings.unshift({
        accountId: String(contract.escrow_account_id), asset: "WAX_MILLIS", deltaUnits: -totalRefund
      });
      const tx = postings.length > 0 ? await this.postTransaction(client, platformEventId, input.envelope,
        postings, { match_id: matchId, result_id: resultId, reason }) : undefined;
      await client.query(
        `UPDATE platform_crucible_contracts
         SET status = 'REFUNDED', result_id = $2, updated_at = now() WHERE match_id = $1`,
        [matchId, resultId]
      );
      await client.query(
        "UPDATE platform_crucible_reservations SET status = 'REFUNDED', updated_at = now() WHERE match_id = $1",
        [matchId]
      );
      return { transactionId: tx, response: {
        ok: true, applied: totalRefund > 0, duplicate: false, epoch_id: input.envelope.epochId,
        match_id: matchId, result_id: resultId, reason,
        refunded_millis: totalRefund, reservation_count: reservations.rows.length,
        transaction_id: tx ?? null, platform_event_id: platformEventId
      } };
    });
  }

  async createEpochDraft(input: {
    epochId: string;
    seasonId: string;
    artifactDigest: string;
    openingHoneyCenti?: number;
    openingWaxMillis?: number;
    openingNectarMilli?: number;
  }): Promise<JsonRecord> {
    const epoch = clean(input.epochId);
    const season = clean(input.seasonId);
    if (!epoch || !season) throw new PlatformEconomyError("epoch_identity_invalid");
    const digest = hash(input.artifactDigest, "artifact_digest_invalid");
    const openings = [input.openingHoneyCenti ?? 0, input.openingWaxMillis ?? 0, input.openingNectarMilli ?? 0]
      .map((value) => nonnegativeInteger(value, "opening_value_invalid"));
    const result = await this.pool.query<JsonRecord>(
      `INSERT INTO platform_economy_epochs
        (epoch_id, state, is_current, season_id, opening_honey_centi, opening_wax_millis,
         opening_nectar_milli, artifact_digest)
       VALUES ($1, 'DRAFT', FALSE, $2, $3, $4, $5, $6)
       ON CONFLICT (epoch_id) DO NOTHING
       RETURNING *`,
      [epoch, season, ...openings, digest]
    );
    if (!result.rows[0]) throw new PlatformEconomyError("epoch_already_exists", 409);
    return normalizeRow(result.rows[0]);
  }

  async prepareEpoch(epochId: string, preconditions: JsonRecord): Promise<JsonRecord> {
    const required = ["mutations_off", "no_active_economic_matches", "no_unresolved_escrow",
      "outboxes_drained", "reconciliation_green", "backup_restorable", "artifacts_pinned"];
    const missing = required.filter((key) => preconditions[key] !== true);
    if (missing.length > 0) throw new PlatformEconomyError(`epoch_precondition_failed:${missing.join(",")}`, 409);
    return this.withTransaction(async (client) => {
      const epoch = await this.lockEpoch(client, epochId);
      if (String(epoch.state) !== "DRAFT") throw new PlatformEconomyError("epoch_not_draft", 409);
      const enabled = await client.query<{ count: string }>(
        "SELECT count(*)::text AS count FROM platform_economy_capabilities WHERE enabled = TRUE"
      );
      if (safeInteger(enabled.rows[0]?.count ?? 0) !== 0) throw new PlatformEconomyError("epoch_mutations_enabled", 409);
      await this.ensureSystemAccount(client, epochId, "HONEY_CENTI", "ISSUANCE");
      await this.ensureSystemAccount(client, epochId, "HONEY_CENTI", "SINK");
      await this.ensureSystemAccount(client, epochId, "WAX_MILLIS", "ISSUANCE");
      await this.ensureSystemAccount(client, epochId, "WAX_MILLIS", "SINK");
      await this.ensureSystemAccount(client, epochId, "NECTAR_MILLI", "ISSUANCE");
      await this.ensureSystemAccount(client, epochId, "NECTAR_MILLI", "SINK");
      await this.ensureAccount(client, epochId, {
        accountId: `reserve:award:${epochId}`, asset: "WAX_MILLIS",
        accountType: "AWARD_RESERVE", ownerId: "reserve:award"
      });
      const players = await client.query<{ id: string }>("SELECT id::text AS id FROM rank_players ORDER BY id");
      for (const player of players.rows) {
        await this.ensurePlayerAccount(client, epochId, player.id, "HONEY_CENTI");
        await this.ensurePlayerAccount(client, epochId, player.id, "WAX_MILLIS");
        await this.ensurePlayerAccount(client, epochId, player.id, "NECTAR_MILLI");
        await client.query(
          `INSERT INTO platform_nectar_progression (epoch_id, season_id, player_id)
           VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`,
          [epochId, String(epoch.season_id), player.id]
        );
      }
      const updated = await client.query<JsonRecord>(
        `UPDATE platform_economy_epochs SET state = 'PREPARED', prepared_at = now(), updated_at = now()
         WHERE epoch_id = $1 RETURNING *`, [epochId]
      );
      return normalizeRow(updated.rows[0]!);
    });
  }

  async reconcile(epochId?: string): Promise<JsonRecord> {
    const epoch = epochId || await this.currentEpochId();
    const result = await this.pool.query<JsonRecord>(
      `WITH entry_totals AS (
         SELECT a.asset, COALESCE(sum(e.delta_units), 0)::bigint AS entry_total
         FROM platform_economy_accounts a
         LEFT JOIN platform_journal_entries e ON e.account_id = a.account_id
         WHERE a.epoch_id = $1 GROUP BY a.asset
       ), balance_totals AS (
         SELECT asset, COALESCE(sum(balance_units), 0)::bigint AS balance_total
         FROM platform_economy_accounts WHERE epoch_id = $1 GROUP BY asset
       ), tx_balance AS (
         SELECT t.transaction_id, e.asset, COALESCE(sum(e.delta_units), 0)::bigint AS delta
         FROM platform_journal_transactions t
         JOIN platform_journal_entries e ON e.transaction_id = t.transaction_id
         WHERE t.epoch_id = $1 GROUP BY t.transaction_id, e.asset
       )
       SELECT
         (SELECT count(*)::text FROM tx_balance WHERE delta <> 0) AS unbalanced_transactions,
         (SELECT count(*)::text FROM platform_event_receipts r
           WHERE r.epoch_id = $1 AND r.status <> 'COMPLETED') AS incomplete_receipts,
         (SELECT count(*)::text FROM platform_crucible_contracts c
           WHERE c.epoch_id = $1 AND c.status IN ('PENDING', 'RESERVED')) AS open_crucible_contracts,
         (SELECT count(*)::text FROM platform_economy_accounts a
           LEFT JOIN (SELECT account_id, sum(delta_units)::bigint AS delta FROM platform_journal_entries GROUP BY account_id) e
             ON e.account_id = a.account_id
           WHERE a.epoch_id = $1 AND a.balance_units <> COALESCE(e.delta, 0)) AS account_drift,
         (SELECT COALESCE(jsonb_object_agg(asset, balance_total::text), '{}'::jsonb) FROM balance_totals) AS conservation_totals,
         (SELECT COALESCE(jsonb_object_agg(asset, entry_total::text), '{}'::jsonb) FROM entry_totals) AS journal_totals`,
      [epoch]
    );
    const row = normalizeRow(result.rows[0] ?? {});
    const ok = [row.unbalanced_transactions, row.incomplete_receipts, row.account_drift]
      .every((value) => safeInteger(value) === 0);
    return { ok, epoch_id: epoch, ...row };
  }

  async markEpochReconciled(epochId: string): Promise<JsonRecord> {
    const report = await this.reconcile(epochId);
    if (report.ok !== true || safeInteger(report.open_crucible_contracts) !== 0) {
      throw new PlatformEconomyError("epoch_reconciliation_failed", 409);
    }
    const result = await this.pool.query<JsonRecord>(
      `UPDATE platform_economy_epochs
       SET state = 'RECONCILED', reconciled_at = now(), updated_at = now()
       WHERE epoch_id = $1 AND state = 'PREPARED' RETURNING *`, [epochId]
    );
    if (!result.rows[0]) throw new PlatformEconomyError("epoch_not_prepared", 409);
    return { ...normalizeRow(result.rows[0]), reconciliation: report };
  }

  async activateEpoch(epochId: string): Promise<JsonRecord> {
    return this.withTransaction(async (client) => {
      const epoch = await this.lockEpoch(client, epochId);
      if (String(epoch.state) !== "RECONCILED") throw new PlatformEconomyError("epoch_not_reconciled", 409);
      const capabilities = await client.query<{ count: string }>(
        "SELECT count(*)::text AS count FROM platform_economy_capabilities WHERE enabled = TRUE"
      );
      if (safeInteger(capabilities.rows[0]?.count ?? 0) !== 0) throw new PlatformEconomyError("epoch_mutations_enabled", 409);
      await client.query("UPDATE platform_economy_epochs SET is_current = FALSE WHERE is_current = TRUE");
      const activated = await client.query<JsonRecord>(
        `UPDATE platform_economy_epochs
         SET state = 'ACTIVE', is_current = TRUE, activated_at = now(), updated_at = now()
         WHERE epoch_id = $1 RETURNING *`, [epochId]
      );
      await client.query(
        `UPDATE rank_players SET wax_score = 0, last_decay_day = floor(extract(epoch from now()) / 86400)::int,
          tier_id = 'DRONE', color_id = 'GREEN', rank_position = 0, percentile = 0,
          promotion_history = '{}'::jsonb, apex_active = FALSE, updated_at = now()`
      );
      await client.query(
        `INSERT INTO rank_audit_events (event_type, payload)
         VALUES ('platform_beta_epoch_activated', jsonb_build_object(
           'epoch_id', $1::text, 'season_id', $2::text, 'opening_honey_centi', 0,
           'opening_wax_millis', 0, 'opening_nectar_milli', 0,
           'identities_preserved', TRUE, 'capabilities_enabled', FALSE))`,
        [epochId, String(epoch.season_id)]
      );
      return normalizeRow(activated.rows[0]!);
    });
  }

  async abortEpoch(epochId: string): Promise<JsonRecord> {
    const result = await this.pool.query<JsonRecord>(
      `UPDATE platform_economy_epochs
       SET state = 'ABORTED', is_current = FALSE, aborted_at = now(), updated_at = now()
       WHERE epoch_id = $1 AND state IN ('DRAFT', 'PREPARED', 'RECONCILED') RETURNING *`, [epochId]
    );
    if (!result.rows[0]) throw new PlatformEconomyError("epoch_not_abortable", 409);
    return normalizeRow(result.rows[0]);
  }

  private async runEvent(
    envelopeInput: ProducerEnvelope,
    work: (client: PoolClient, platformEventId: string) => Promise<EventWorkResult>,
    options: { stablePlayerIntent?: boolean } = {}
  ): Promise<JsonRecord> {
    const envelope = validateEnvelope(envelopeInput);
    const requestHash = sha256Canonical({
      producer_service: envelope.producerService,
      producer_event_id: envelope.producerEventId,
      event_type: envelope.eventType,
      epoch_id: envelope.epochId,
      source_authority: envelope.sourceAuthority,
      ...(options.stablePlayerIntent ? {} : { occurred_at: envelope.occurredAt }),
      schema_version: envelope.schemaVersion,
      payload: envelope.payload
    });
    return this.withTransaction(async (client) => {
      await this.requireCurrentActiveEpoch(client, envelope.epochId);
      const claimed = await client.query<{ platform_event_id: string }>(
        `INSERT INTO platform_event_receipts
          (producer_service, producer_event_id, epoch_id, event_type, request_hash, status)
         VALUES ($1, $2, $3, $4, $5, 'PENDING')
         ON CONFLICT DO NOTHING RETURNING platform_event_id::text`,
        [envelope.producerService, envelope.producerEventId, envelope.epochId, envelope.eventType, requestHash]
      );
      if (!claimed.rows[0]) {
        const existing = await client.query<JsonRecord>(
          `SELECT request_hash, status, response_json FROM platform_event_receipts
           WHERE producer_service = $1 AND producer_event_id = $2 FOR UPDATE`,
          [envelope.producerService, envelope.producerEventId]
        );
        const receipt = existing.rows[0];
        const legacyStableRetry = options.stablePlayerIntent === true
          && String(receipt?.status) === "COMPLETED"
          && isRecord(receipt?.response_json)
          && String((receipt!.response_json as JsonRecord).player_id) === String(envelope.payload.player_id)
          && String((receipt!.response_json as JsonRecord).catalog_action_id) === String(envelope.payload.catalog_action_id);
        if (!receipt || (String(receipt.request_hash) !== requestHash && !legacyStableRetry)) {
          throw new PlatformEconomyError("idempotency_conflict", 409);
        }
        if (String(receipt.status) !== "COMPLETED" || !isRecord(receipt.response_json)) {
          throw new PlatformEconomyError("idempotency_in_progress", 409);
        }
        return { ...(receipt.response_json as JsonRecord), duplicate: true };
      }
      const platformEventId = claimed.rows[0].platform_event_id;
      const result = await work(client, platformEventId);
      const response = { ...result.response, duplicate: false };
      const completed = await client.query(
        `UPDATE platform_event_receipts
         SET status = 'COMPLETED', response_json = $4::jsonb, transaction_id = $5, updated_at = now()
         WHERE producer_service = $1 AND producer_event_id = $2 AND request_hash = $3`,
        [envelope.producerService, envelope.producerEventId, requestHash, JSON.stringify(response), result.transactionId ?? null]
      );
      if ((completed.rowCount ?? 0) !== 1) throw new PlatformEconomyError("receipt_completion_failed", 500);
      return response;
    });
  }

  private async postTransaction(
    client: PoolClient,
    platformEventId: string,
    envelope: ProducerEnvelope,
    postings: Posting[],
    metadata: JsonRecord
  ): Promise<string> {
    if (postings.length < 2) throw new PlatformEconomyError("journal_postings_missing");
    const totals = new Map<PlatformAsset, number>();
    for (const posting of postings) {
      if (!Number.isSafeInteger(posting.deltaUnits) || posting.deltaUnits === 0) {
        throw new PlatformEconomyError("journal_delta_invalid");
      }
      totals.set(posting.asset, (totals.get(posting.asset) ?? 0) + posting.deltaUnits);
    }
    if ([...totals.values()].some((total) => total !== 0)) throw new PlatformEconomyError("journal_unbalanced");
    const accountIds = [...new Set(postings.map((posting) => posting.accountId))].sort();
    const accounts = await client.query<JsonRecord>(
      `SELECT account_id, epoch_id, asset, account_type, owner_id, balance_units::text
       FROM platform_economy_accounts WHERE account_id = ANY($1::text[]) ORDER BY account_id FOR UPDATE`,
      [accountIds]
    );
    if (accounts.rows.length !== accountIds.length) throw new PlatformEconomyError("journal_account_missing");
    const byId = new Map(accounts.rows.map((row) => [String(row.account_id), row]));
    const next = new Map<string, number>();
    for (const posting of postings) {
      const account = byId.get(posting.accountId)!;
      if (String(account.epoch_id) !== envelope.epochId || String(account.asset) !== posting.asset) {
        throw new PlatformEconomyError("journal_account_binding_invalid");
      }
      if (String(account.account_type) === "AWARD_RESERVE" && posting.deltaUnits < 0) {
        throw new PlatformEconomyError("award_reserve_debit_forbidden", 403);
      }
      const value = (next.get(posting.accountId) ?? safeInteger(account.balance_units)) + posting.deltaUnits;
      next.set(posting.accountId, value);
    }
    for (const [accountId, balance] of next) {
      const type = String(byId.get(accountId)!.account_type);
      if (!["ISSUANCE", "SINK"].includes(type) && balance < 0) {
        throw new PlatformEconomyError("insufficient_funds", 409);
      }
    }
    const tx = await client.query<{ transaction_id: string }>(
      `INSERT INTO platform_journal_transactions
        (platform_event_id, epoch_id, event_type, external_ref, metadata)
       VALUES ($1, $2, $3, $4, $5::jsonb) RETURNING transaction_id::text`,
      [platformEventId, envelope.epochId, envelope.eventType,
        String(envelope.payload.source_result_id ?? envelope.payload.match_id ?? ""), JSON.stringify(metadata)]
    );
    const transactionId = tx.rows[0]!.transaction_id;
    for (const posting of postings) {
      await client.query(
        `INSERT INTO platform_journal_entries (transaction_id, account_id, asset, delta_units)
         VALUES ($1, $2, $3, $4)`,
        [transactionId, posting.accountId, posting.asset, posting.deltaUnits]
      );
    }
    await client.query("SELECT set_config('platform.journal_write', 'on', TRUE)");
    for (const [accountId, balance] of next) {
      await client.query(
        "UPDATE platform_economy_accounts SET balance_units = $2, updated_at = now() WHERE account_id = $1",
        [accountId, balance]
      );
    }
    return transactionId;
  }

  private async ensurePlayerAccount(client: PoolClient, epochId: string, playerId: string, asset: PlatformAsset): Promise<AccountSpec> {
    return this.ensureAccount(client, epochId, {
      accountId: `player:${asset.toLowerCase()}:${playerId}:${epochId}`,
      asset, accountType: "PLAYER", ownerId: playerId
    });
  }

  private async ensureSystemAccount(
    client: PoolClient,
    epochId: string,
    asset: PlatformAsset,
    accountType: "ISSUANCE" | "SINK"
  ): Promise<AccountSpec> {
    return this.ensureAccount(client, epochId, {
      accountId: `${accountType.toLowerCase()}:${asset.toLowerCase()}:${epochId}`,
      asset, accountType, ownerId: `${accountType.toLowerCase()}:${asset.toLowerCase()}`
    });
  }

  private async ensureAccount(client: PoolClient, epochId: string, spec: AccountSpec): Promise<AccountSpec> {
    await client.query(
      `INSERT INTO platform_economy_accounts
        (account_id, epoch_id, asset, account_type, owner_id, balance_units)
       VALUES ($1, $2, $3, $4, $5, 0) ON CONFLICT (account_id) DO NOTHING`,
      [spec.accountId, epochId, spec.asset, spec.accountType, spec.ownerId]
    );
    const found = await client.query<JsonRecord>(
      "SELECT epoch_id, asset, account_type, owner_id FROM platform_economy_accounts WHERE account_id = $1",
      [spec.accountId]
    );
    const row = found.rows[0];
    if (!row || String(row.epoch_id) !== epochId || String(row.asset) !== spec.asset
      || String(row.account_type) !== spec.accountType || String(row.owner_id) !== spec.ownerId) {
      throw new PlatformEconomyError("account_identity_conflict", 409);
    }
    return spec;
  }

  private async accountBalance(client: PoolClient, accountId: string): Promise<number> {
    const result = await client.query<{ balance_units: string }>(
      "SELECT balance_units::text FROM platform_economy_accounts WHERE account_id = $1", [accountId]
    );
    if (!result.rows[0]) throw new PlatformEconomyError("account_not_found", 404);
    return safeInteger(result.rows[0].balance_units);
  }

  private async getPlayerBalanceInTransaction(
    client: PoolClient,
    epochId: string,
    playerId: string,
    asset: PlatformAsset
  ): Promise<number> {
    const result = await client.query<{ balance_units: string }>(
      `SELECT balance_units::text FROM platform_economy_accounts
       WHERE epoch_id = $1 AND account_type = 'PLAYER' AND owner_id = $2 AND asset = $3`,
      [epochId, playerId, asset]
    );
    return result.rows[0] ? safeInteger(result.rows[0].balance_units) : 0;
  }

  private async requireCapability(client: PoolClient, capability: PlatformCapability): Promise<void> {
    const result = await client.query<{ enabled: boolean }>(
      "SELECT enabled FROM platform_economy_capabilities WHERE capability = $1", [capability]
    );
    if (result.rows[0]?.enabled !== true) throw new PlatformEconomyError("economy_capability_disabled", 503);
  }

  private async requirePlayer(client: PoolClient, playerId: string): Promise<void> {
    const result = await client.query("SELECT 1 FROM rank_players WHERE id = $1::uuid", [playerId]);
    if ((result.rowCount ?? 0) !== 1) throw new PlatformEconomyError("player_not_found", 404);
  }

  private async currentEpochId(): Promise<string> {
    const current = await this.getCurrentEpoch();
    if (!current) throw new PlatformEconomyError("active_epoch_missing", 503);
    return String(current.epoch_id);
  }

  private async requireCurrentActiveEpoch(client: PoolClient, epochId: string): Promise<void> {
    const result = await client.query(
      "SELECT 1 FROM platform_economy_epochs WHERE epoch_id = $1 AND state = 'ACTIVE' AND is_current = TRUE",
      [epochId]
    );
    if ((result.rowCount ?? 0) !== 1) throw new PlatformEconomyError("old_or_inactive_epoch", 409);
  }

  private async lockEpoch(client: PoolClient, epochId: string): Promise<JsonRecord> {
    const result = await client.query<JsonRecord>(
      "SELECT * FROM platform_economy_epochs WHERE epoch_id = $1 FOR UPDATE", [clean(epochId)]
    );
    if (!result.rows[0]) throw new PlatformEconomyError("epoch_not_found", 404);
    return result.rows[0];
  }

  private async lockCrucible(client: PoolClient, matchId: string, epochId: string,
    requiredStatus: string | string[]): Promise<JsonRecord> {
    const result = await client.query<JsonRecord>(
      "SELECT * FROM platform_crucible_contracts WHERE match_id = $1 FOR UPDATE", [matchId]
    );
    const row = result.rows[0];
    if (!row) throw new PlatformEconomyError("crucible_contract_not_found", 404);
    if (String(row.epoch_id) !== epochId) throw new PlatformEconomyError("crucible_epoch_mismatch", 409);
    const allowed = Array.isArray(requiredStatus) ? requiredStatus : [requiredStatus];
    if (!allowed.includes(String(row.status))) throw new PlatformEconomyError("crucible_contract_not_settleable", 409);
    return row;
  }

  private async refreshRankOrder(client: PoolClient): Promise<void> {
    await client.query(
      `WITH ordered AS (
         SELECT id, row_number() OVER (ORDER BY wax_score DESC, id ASC)::int AS position,
           count(*) OVER ()::int AS total
         FROM rank_players
       ), projected AS (
         SELECT id, position,
           CASE WHEN total <= 1 THEN 1.0
                ELSE greatest(0.0, least(1.0, (total - position)::double precision / (total - 1)::double precision))
           END AS pct
         FROM ordered
       )
       UPDATE rank_players p SET rank_position = x.position, percentile = x.pct, updated_at = now()
       FROM projected x WHERE p.id = x.id`
    );
  }

  private async withTransaction<T>(fn: (client: PoolClient) => Promise<T>): Promise<T> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const result = await fn(client);
      await client.query("COMMIT");
      return result;
    } catch (error) {
      try { await client.query("ROLLBACK"); } catch { /* preserve original error */ }
      throw error;
    } finally {
      client.release();
    }
  }
}

function validateEnvelope(input: ProducerEnvelope): ProducerEnvelope {
  const envelope: ProducerEnvelope = {
    producerService: clean(input.producerService),
    producerEventId: clean(input.producerEventId),
    eventType: clean(input.eventType),
    epochId: clean(input.epochId),
    sourceAuthority: clean(input.sourceAuthority),
    occurredAt: clean(input.occurredAt),
    schemaVersion: Number(input.schemaVersion),
    payload: isRecord(input.payload) ? input.payload : {}
  };
  if (!envelope.producerService || !envelope.producerEventId || !envelope.eventType
    || !envelope.epochId || !envelope.sourceAuthority) {
    throw new PlatformEconomyError("event_envelope_incomplete");
  }
  if (!Number.isSafeInteger(envelope.schemaVersion) || envelope.schemaVersion < 1) {
    throw new PlatformEconomyError("schema_version_invalid");
  }
  if (!Number.isFinite(Date.parse(envelope.occurredAt))) throw new PlatformEconomyError("occurred_at_invalid");
  return envelope;
}

function assetField(asset: PlatformAsset): string {
  if (asset === "HONEY_CENTI") return "honey_centi";
  if (asset === "WAX_MILLIS") return "wax_millis";
  return "nectar_milli";
}

function normalizeRow(row: JsonRecord): JsonRecord {
  return Object.fromEntries(Object.entries(row).map(([key, value]) => {
    if (typeof value === "bigint") return [key, Number(value)];
    if (value instanceof Date) return [key, value.toISOString()];
    return [key, value];
  }));
}

function safeInteger(value: unknown): number {
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed)) throw new PlatformEconomyError("integer_out_of_range", 500);
  return parsed;
}

function positiveInteger(value: unknown, code: string): number {
  const parsed = safeInteger(value);
  if (parsed <= 0) throw new PlatformEconomyError(code);
  return parsed;
}

function nonnegativeInteger(value: unknown, code: string): number {
  const parsed = safeInteger(value);
  if (parsed < 0) throw new PlatformEconomyError(code);
  return parsed;
}

function clean(value: unknown): string { return String(value ?? "").trim(); }
function hash(value: unknown, code: string): string {
  const cleanValue = clean(value).toLowerCase();
  if (!/^[0-9a-f]{64}$/.test(cleanValue)) throw new PlatformEconomyError(code);
  return cleanValue;
}
function uuid(value: unknown, code: string): string {
  const cleanValue = clean(value).toLowerCase();
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(cleanValue)) {
    throw new PlatformEconomyError(code);
  }
  return cleanValue;
}
function isRecord(value: unknown): value is JsonRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
