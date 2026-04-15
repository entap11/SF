import { defaultHighlightConfig } from "./config.js";
import { generateShareAssetPaths } from "./renderer.js";
import type { HighlightConfig, HighlightPayload, HighlightShareCard } from "./types.js";

function formatDuration(seconds: number): string {
  const minutes = Math.floor(seconds / 60);
  const remainder = Math.max(0, seconds % 60);
  return `${minutes}:${remainder.toString().padStart(2, "0")}`;
}

function matchDescriptor(payload: HighlightPayload): string {
  if (payload.match.is_money_game) {
    return `$${payload.match.stake_amount_usd} Money Match`;
  }
  if (payload.match.mode === "pvp_4p") {
    return "4-Player Match";
  }
  if (payload.match.mode === "pvp_3p") {
    return "3-Player Match";
  }
  if (payload.match.mode === "pvp_1v1") {
    return "1v1 Match";
  }
  return "Async Match";
}

function headlineTitle(badgeKey: string, fallback: string): string {
  switch (badgeKey) {
    case "game_of_the_day_candidate":
      return "Game of the Day";
    case "wins_500":
      return "500 Wins";
    case "top_10_candidate":
      return "Top 10 Replay";
    case "major_comeback":
      return "Major Comeback";
    case "high_stakes":
      return "High Stakes";
    case "full_chaos_match":
      return "Full Chaos";
    default:
      return fallback;
  }
}

export function buildShareStory(
  payload: HighlightPayload,
  config: HighlightConfig = defaultHighlightConfig
): HighlightShareCard {
  const selectedBadges = payload.derived_badges.selected_badges.slice(0, config.systemRules.badge_rules.max_badges_rendered);
  const primaryBadge = selectedBadges[0] ?? null;
  const secondaryBadge = selectedBadges[1] ?? null;
  const winner = payload.players.find((player) => player.won) ?? payload.players[0];
  const paths = generateShareAssetPaths(payload.match.match_id, payload.match.replay_id, "discord_og_card", config);
  const comebackLabel = payload.analytics.comeback_factor.label.replaceAll("_", " ");
  const storyStat =
    payload.analytics.comeback_factor.score_raw >= 0.82
      ? { label: "Story", value: "Major Comeback" }
      : { label: "Swarms", value: String(payload.match.swarms_sent_total) };

  return {
    template_key: config.render.templateKey,
    headline_source: "highest_priority_badge",
    title: primaryBadge == null ? "Swarmfront Highlight" : headlineTitle(primaryBadge.badge_key, primaryBadge.badge_name),
    subtitle: `${matchDescriptor(payload)} • ${formatDuration(payload.match.duration_seconds)} • ${comebackLabel}`,
    story_focus: {
      primary_story: primaryBadge?.badge_type ?? "highlight",
      primary_badge_key: primaryBadge?.badge_key ?? "",
      secondary_story: secondaryBadge?.badge_type ?? "",
      secondary_badge_key: secondaryBadge?.badge_key ?? ""
    },
    hero_players:
      winner == null
        ? []
        : [
            {
              player_id: winner.player_id,
              username: winner.username,
              placement: winner.placement,
              won: winner.won
            }
          ],
    badges_to_render: selectedBadges,
    stats_to_render: [
      { label: "Duration", value: formatDuration(payload.match.duration_seconds) },
      { label: "Stakes", value: payload.match.is_money_game ? `$${payload.match.stake_amount_usd}` : "Ranked" },
      storyStat
    ],
    render_assets: {
      background_key: config.render.backgroundKey,
      frame_key: config.render.frameKey,
      badge_style_key: config.render.badgeStyleKey
    },
    render_constraints: {
      max_badges_rendered: config.systemRules.badge_rules.max_badges_rendered,
      do_not_overcrowd: true,
      secondary_badge_must_support_primary_story: true
    },
    output: {
      image_url: paths.image_url,
      og_image_url: paths.og_image_url,
      width: config.render.outputWidth,
      height: config.render.outputHeight,
      format: "png"
    }
  };
}
