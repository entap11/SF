import { rankMutationHttpStatus } from "./economyGuard.js";
import { recomputeRankings, stateSnapshot } from "./logic.js";
import type { RankStore } from "./store.js";

export async function adminRecompute(store: RankStore): Promise<{ status: number; body: Record<string, unknown> }> {
  const result = await store.writeEconomy((state, context) => {
    recomputeRankings(state);
    context.recordAuditEvent({
      event_type: "admin_recompute",
      payload: {
        player_count: Object.keys(state.players_by_id).length
      }
    });
    return {
      ok: true,
      player_count: Object.keys(state.players_by_id).length,
      snapshot: stateSnapshot(state)
    };
  });
  return {
    status: rankMutationHttpStatus(result),
    body: result as Record<string, unknown>
  };
}
