import { config } from "./config.js";
import {
  applyDecayAll,
  computeGain,
  computeLoss,
  normalizePlayerRecord,
  nowUnix,
  playerSnapshot,
  pruneProcessedEvents,
  recomputeRankings
} from "./logic.js";
import type { RankStore } from "./store.js";
import type { JsonRecord } from "./verifiedReceipt.js";

export async function applyVerifiedStandard1v1Settlement(
  store: RankStore,
  payload: JsonRecord,
  callerService: string
): Promise<Record<string, unknown>> {
  const resultId = String(payload.result_id);
  if (String(payload.terminal_reason) === "NO_CONTEST") {
    return { ok: true, applied: false, duplicate: false, status: "NOT_APPLICABLE", rank_event_id: resultId };
  }
  const placements = payload.placements as JsonRecord[];
  const winnerId = String((placements[0]!.player_ids as unknown[])[0]);
  const loserId = String((placements[1]!.player_ids as unknown[])[0]);
  const dedupeKey = `verified-standard-1v1:${resultId}`;
  return store.writeEconomy((state, context) => {
    if (state.processed_events[dedupeKey]) {
      return {
        ok: true, applied: true, duplicate: true, status: "SETTLED", rank_event_id: resultId,
        winner: playerSnapshot(state.players_by_id[winnerId]), loser: playerSnapshot(state.players_by_id[loserId])
      };
    }
    const missingPlayerIds = [winnerId, loserId].filter((playerId) => !state.players_by_id[playerId]);
    if (missingPlayerIds.length > 0) {
      return { ok: false, err: "rank_players_missing", retryable: true, missing_player_ids: missingPlayerIds };
    }
    const unixNow = nowUnix();
    applyDecayAll(state, unixNow);
    const winner = state.players_by_id[winnerId]!;
    const loser = state.players_by_id[loserId]!;
    const winnerBefore = winner.wax_score;
    const loserBefore = loser.wax_score;
    winner.wax_score = winnerBefore + computeGain(winnerBefore, loserBefore, "STANDARD", 0);
    loser.wax_score = Math.max(config.rank.waxFloor,
      loserBefore - computeLoss(loserBefore, winnerBefore, "STANDARD", 0));
    const decayDay = Math.floor(unixNow / 86_400);
    winner.last_active_unix = unixNow;
    loser.last_active_unix = unixNow;
    winner.last_decay_day = decayDay;
    loser.last_decay_day = decayDay;
    state.players_by_id[winnerId] = normalizePlayerRecord(winnerId, winner, unixNow);
    state.players_by_id[loserId] = normalizePlayerRecord(loserId, loser, unixNow);
    recomputeRankings(state);
    state.processed_events[dedupeKey] = unixNow;
    pruneProcessedEvents(state);
    context.recordAuditEvent({
      event_type: "verified_standard_1v1_settled",
      player_id: winnerId,
      related_player_id: loserId,
      payload: {
        result_id: resultId,
        match_id: payload.match_id,
        contract_id: payload.contract_id,
        contract_hash: payload.contract_hash,
        terminal_reason: payload.terminal_reason,
        authority_method: payload.authority_method,
        caller_service: callerService,
        winner_wax_before: winnerBefore,
        winner_wax_after: state.players_by_id[winnerId]!.wax_score,
        loser_wax_before: loserBefore,
        loser_wax_after: state.players_by_id[loserId]!.wax_score
      }
    });
    return {
      ok: true, applied: true, duplicate: false, status: "SETTLED", rank_event_id: resultId,
      winner: playerSnapshot(state.players_by_id[winnerId]), loser: playerSnapshot(state.players_by_id[loserId])
    };
  });
}
