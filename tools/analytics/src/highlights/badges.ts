import { defaultHighlightConfig } from "./config.js";
import type {
  DerivedBadges,
  HighlightAnalytics,
  HighlightBadge,
  HighlightConfig,
  HighlightContentFlags,
  HighlightMatch,
  HighlightPlayer
} from "./types.js";

function priorityFor(key: string, config: HighlightConfig): number {
  return config.badgePriorities[key] ?? 1;
}

function matchBadge(key: string, name: string, tier: string, config: HighlightConfig): HighlightBadge {
  return {
    badge_key: key,
    badge_name: name,
    badge_type: "match_badge",
    badge_tier: tier,
    display_priority: priorityFor(key, config)
  };
}

function milestoneBadge(base: HighlightBadge, playerId: string, config: HighlightConfig): HighlightBadge {
  return {
    ...base,
    badge_type: "player_milestone_badge",
    display_priority: priorityFor(base.badge_key, config) || base.display_priority,
    player_id: playerId
  };
}

export function deriveCandidateBadges(
  match: HighlightMatch,
  players: HighlightPlayer[],
  analytics: HighlightAnalytics,
  contentFlags: HighlightContentFlags,
  config: HighlightConfig = defaultHighlightConfig
): HighlightBadge[] {
  const badges: HighlightBadge[] = [];

  if (contentFlags.game_of_the_day_candidate) {
    badges.push(matchBadge("game_of_the_day_candidate", "Game of the Day", "featured", config));
  }
  if (contentFlags.top_10_candidate) {
    badges.push(matchBadge("top_10_candidate", "Top 10 Candidate", "featured", config));
  }
  if (analytics.comeback_factor.score_raw >= config.badgeCriteria.majorComebackMinRaw) {
    badges.push(matchBadge("major_comeback", "Major Comeback", "epic", config));
  }
  if (match.is_money_game && match.stake_amount_usd >= config.badgeCriteria.highStakesMinUsd) {
    badges.push(matchBadge("high_stakes", "High Stakes", "premium", config));
  }
  if (
    match.player_count >= config.badgeCriteria.fullChaosMinPlayers &&
    match.buffs_used_total >= config.badgeCriteria.fullChaosMinBuffs &&
    analytics.swarm_density_factor.label === "goldilocks"
  ) {
    badges.push(matchBadge("full_chaos_match", "Full Chaos", "epic", config));
  }
  if (contentFlags.highlight_game) {
    badges.push(matchBadge("highlight_game", "Highlight Game", "highlight", config));
  }
  if (contentFlags.featured_replay) {
    badges.push(matchBadge("featured_replay", "Featured Replay", "featured", config));
  }

  for (const player of players) {
    for (const earnedBadge of player.badges_earned_in_match) {
      if (earnedBadge.badge_type === "player_milestone_badge") {
        badges.push(milestoneBadge(earnedBadge, player.player_id, config));
      }
    }
    if (player.won && match.is_money_game && match.stake_amount_usd > 0 && player.wins_total_after_match === 1) {
      badges.push(
        milestoneBadge(
          {
            badge_key: "first_money_win",
            badge_name: "First Money Win",
            badge_type: "player_milestone_badge",
            badge_tier: "milestone",
            display_priority: priorityFor("first_money_win", config)
          },
          player.player_id,
          config
        )
      );
    }
  }

  const seen = new Set<string>();
  return badges.filter((badge) => {
    const key = `${badge.badge_key}:${badge.player_id ?? ""}`;
    if (seen.has(key)) {
      return false;
    }
    seen.add(key);
    return true;
  });
}

export function selectBadges(
  candidateBadges: HighlightBadge[],
  config: HighlightConfig = defaultHighlightConfig
): HighlightBadge[] {
  const selected = [...candidateBadges]
    .sort((a, b) => b.display_priority - a.display_priority || a.badge_key.localeCompare(b.badge_key))
    .slice(0, config.systemRules.badge_rules.max_badges_rendered)
    .map((badge, index) => ({
      ...badge,
      render_slot: (index + 1) as 1 | 2,
      headline_selected: index === 0
    }));
  return selected;
}

export function selectHeadlineBadge(selectedBadges: HighlightBadge[]): HighlightBadge | null {
  return selectedBadges.length > 0 ? selectedBadges[0] : null;
}

export function buildDerivedBadges(
  candidateBadges: HighlightBadge[],
  config: HighlightConfig = defaultHighlightConfig
): DerivedBadges {
  return {
    candidate_badges: candidateBadges.map((badge) => ({ ...badge })),
    selected_badges: selectBadges(candidateBadges, config),
    selection_rules_applied: {
      max_badges_rendered: config.systemRules.badge_rules.max_badges_rendered,
      selected_by_highest_priority: true,
      headline_selected_from_highest_priority_badge: true
    }
  };
}
