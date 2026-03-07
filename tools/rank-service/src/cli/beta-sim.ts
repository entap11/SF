import {
  applyDecayAll,
  computeGain,
  computeLoss,
  newPlayerRecord,
  normalizedColorQuintiles,
  orderedTierIds,
  recomputeRankings
} from "../logic.js";
import type { RankState } from "../types.js";
import { config } from "../config.js";

function parseIntArg(name: string, fallback: number): number {
  const prefix = `--${name}=`;
  const raw = process.argv.find((arg) => arg.startsWith(prefix));
  if (!raw) {
    return fallback;
  }
  const parsed = Number.parseInt(raw.slice(prefix.length), 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function playerIdForIndex(index: number): string {
  return `u_${index.toString(16).padStart(12, "0")}`;
}

function nextRandom(state: { seed: number }): number {
  state.seed = (state.seed * 1_664_525 + 1_013_904_223) >>> 0;
  return state.seed / 4_294_967_296;
}

function summarize(state: RankState): Record<string, unknown> {
  const tiers = orderedTierIds();
  const colors = normalizedColorQuintiles();
  const tierTotals: Record<string, number> = {};
  const colorTotals: Record<string, number> = {};
  for (const tierId of tiers) {
    tierTotals[tierId] = 0;
  }
  for (const colorId of colors) {
    colorTotals[colorId] = 0;
  }
  for (const record of Object.values(state.players_by_id)) {
    tierTotals[record.tier_id] = (tierTotals[record.tier_id] ?? 0) + 1;
    colorTotals[record.color_id] = (colorTotals[record.color_id] ?? 0) + 1;
  }
  return {
    players: Object.keys(state.players_by_id).length,
    tiers: tierTotals,
    colors: colorTotals
  };
}

function main(): void {
  const playerCount = Math.max(2, parseIntArg("players", 600));
  const matchCount = Math.max(1, parseIntArg("matches", 3000));
  const seed = Math.max(1, parseIntArg("seed", 1337));
  const rng = { seed };

  const state: RankState = {
    local_player_id: playerIdForIndex(1),
    players_by_id: {},
    processed_events: {}
  };

  const unixNow = Math.floor(Date.now() / 1000);
  for (let i = 1; i <= playerCount; i += 1) {
    const playerId = playerIdForIndex(i);
    const region = i % 2 === 0 ? "NA" : "EU";
    state.players_by_id[playerId] = newPlayerRecord(playerId, `Beta ${i}`, region, unixNow, []);
  }
  recomputeRankings(state);

  for (let i = 0; i < matchCount; i += 1) {
    let aIndex = Math.floor(nextRandom(rng) * playerCount) + 1;
    let bIndex = Math.floor(nextRandom(rng) * playerCount) + 1;
    if (aIndex === bIndex) {
      bIndex = (bIndex % playerCount) + 1;
    }
    const playerId = playerIdForIndex(aIndex);
    const opponentId = playerIdForIndex(bIndex);

    applyDecayAll(state, unixNow);
    const player = state.players_by_id[playerId];
    const opponent = state.players_by_id[opponentId];
    const playerWinChance = player.wax_score / Math.max(1, player.wax_score + opponent.wax_score);
    const didPlayerWin = nextRandom(rng) <= playerWinChance;

    const playerWaxBefore = player.wax_score;
    const opponentWaxBefore = opponent.wax_score;
    const playerGain = computeGain(playerWaxBefore, opponentWaxBefore, "STANDARD");
    const opponentGain = computeGain(opponentWaxBefore, playerWaxBefore, "STANDARD");
    const playerLoss = computeLoss(playerWaxBefore, opponentWaxBefore, "STANDARD");
    const opponentLoss = computeLoss(opponentWaxBefore, playerWaxBefore, "STANDARD");

    if (didPlayerWin) {
      player.wax_score = playerWaxBefore + playerGain;
      opponent.wax_score = Math.max(config.rank.waxFloor, opponentWaxBefore - opponentLoss);
    } else {
      player.wax_score = Math.max(config.rank.waxFloor, playerWaxBefore - playerLoss);
      opponent.wax_score = opponentWaxBefore + opponentGain;
    }

    player.last_active_unix = unixNow;
    opponent.last_active_unix = unixNow;
    player.last_decay_day = Math.floor(unixNow / 86_400);
    opponent.last_decay_day = Math.floor(unixNow / 86_400);
    recomputeRankings(state);
  }

  const summary = summarize(state);
  const sorted = Object.values(state.players_by_id).sort((a, b) => {
    if (b.wax_score !== a.wax_score) {
      return b.wax_score - a.wax_score;
    }
    return a.player_id.localeCompare(b.player_id);
  });

  // eslint-disable-next-line no-console
  console.log(JSON.stringify({
    ok: true,
    seed,
    match_count: matchCount,
    summary,
    top_players: sorted.slice(0, 10).map((record) => ({
      player_id: record.player_id,
      wax_score: record.wax_score,
      tier_id: record.tier_id,
      color_id: record.color_id,
      rank_position: record.rank_position
    }))
  }, null, 2));
}

main();
