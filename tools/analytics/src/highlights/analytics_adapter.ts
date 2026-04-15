import type { HighlightAnalytics, HighlightMatch, HighlightPlayer, NormalizedMatchAnalytics } from "./types.js";

export interface CompletedMatchInput {
  match: HighlightMatch;
  players: HighlightPlayer[];
  analytics?: Partial<HighlightAnalytics>;
  content_flags?: NormalizedMatchAnalytics["content_flags"];
}

function clamp01(value: number): number {
  if (!Number.isFinite(value)) {
    return 0;
  }
  return Math.max(0, Math.min(1, value));
}

function factor(label: string, scoreRaw: number) {
  return { label, score_raw: clamp01(scoreRaw) };
}

function defaultAnalytics(match: HighlightMatch): HighlightAnalytics {
  const swarmDensity = match.duration_seconds > 0 ? match.swarms_sent_total / match.duration_seconds : 0;
  const durationScore = match.duration_seconds >= 150 && match.duration_seconds <= 420 ? 0.72 : 0.35;

  return {
    comeback_factor: factor("unknown", 0),
    closeness_factor: factor("unknown", 0.5),
    efficiency_factor: factor("unknown", 0.5),
    swarm_density_factor: factor("observed", Math.min(1, swarmDensity)),
    duration_factor: factor("observed", durationScore)
  };
}

export function normalizeMatchAnalytics(input: CompletedMatchInput): NormalizedMatchAnalytics {
  const base = defaultAnalytics(input.match);
  return {
    match: { ...input.match },
    players: input.players.map((player) => ({
      ...player,
      badges_earned_in_match: player.badges_earned_in_match.map((badge) => ({ ...badge }))
    })),
    analytics: {
      comeback_factor: input.analytics?.comeback_factor ?? base.comeback_factor,
      closeness_factor: input.analytics?.closeness_factor ?? base.closeness_factor,
      efficiency_factor: input.analytics?.efficiency_factor ?? base.efficiency_factor,
      swarm_density_factor: input.analytics?.swarm_density_factor ?? base.swarm_density_factor,
      duration_factor: input.analytics?.duration_factor ?? base.duration_factor
    },
    content_flags: input.content_flags == null ? undefined : { ...input.content_flags }
  };
}
