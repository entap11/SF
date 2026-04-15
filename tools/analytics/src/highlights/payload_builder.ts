import { defaultHighlightConfig } from "./config.js";
import { normalizeMatchAnalytics, type CompletedMatchInput } from "./analytics_adapter.js";
import { buildDerivedBadges, deriveCandidateBadges } from "./badges.js";
import { resolveReplayLink } from "./replay_links.js";
import { scoreMatch } from "./scorer.js";
import { buildPostingDestinations } from "./social_routing.js";
import { buildShareStory } from "./story.js";
import type { HighlightConfig, HighlightContentFlags, HighlightPayload } from "./types.js";
import { HIGHLIGHT_SCHEMA_VERSION } from "./types.js";

function contentFlagsFromScore(
  explicitFlags: Partial<HighlightContentFlags> | undefined,
  excitementScore: number,
  config: HighlightConfig
): HighlightContentFlags {
  return {
    highlight_game: explicitFlags?.highlight_game ?? excitementScore >= config.contentFlagThresholds.highlightGame,
    game_of_the_day_candidate:
      explicitFlags?.game_of_the_day_candidate ?? excitementScore >= config.contentFlagThresholds.gameOfTheDayCandidate,
    top_10_candidate: explicitFlags?.top_10_candidate ?? excitementScore >= config.contentFlagThresholds.top10Candidate,
    featured_replay: explicitFlags?.featured_replay ?? excitementScore >= config.contentFlagThresholds.featuredReplay
  };
}

function buildMessageTemplates(payload: HighlightPayload): HighlightPayload["message_templates"] {
  const link = payload.replay_link.canonical_url;
  const title = payload.share_card.title;
  const subtitle = payload.share_card.subtitle;
  return {
    discord: {
      content: `${title}: ${link}`,
      embed_title: title,
      embed_description: subtitle,
      embed_url: link
    },
    x: {
      text: `${title} in Swarmfront. Watch the replay: ${link}`
    }
  };
}

export function buildHighlightPayload(
  input: CompletedMatchInput,
  config: HighlightConfig = defaultHighlightConfig
): HighlightPayload {
  const normalized = normalizeMatchAnalytics(input);
  const scoring = scoreMatch(normalized, config);
  const contentFlags = contentFlagsFromScore(normalized.content_flags, scoring.excitement_score, config);
  const candidateBadges = deriveCandidateBadges(
    normalized.match,
    normalized.players,
    normalized.analytics,
    contentFlags,
    config
  );
  const derivedBadges = buildDerivedBadges(candidateBadges, config);
  const replayLink = resolveReplayLink(normalized.match.replay_id, config);
  const eligibleForAutoPost = scoring.watchability_pass && scoring.auto_post_tier !== "no_auto_post";

  const payload: HighlightPayload = {
    schema_version: HIGHLIGHT_SCHEMA_VERSION,
    system_rules: config.systemRules,
    match: normalized.match,
    players: normalized.players,
    analytics: normalized.analytics,
    scoring,
    content_flags: contentFlags,
    derived_badges: derivedBadges,
    posting_rules: {
      eligible_for_auto_post: eligibleForAutoPost,
      destinations: []
    },
    share_card: {
      template_key: config.render.templateKey,
      headline_source: "highest_priority_badge",
      title: "",
      subtitle: "",
      story_focus: {
        primary_story: "highlight",
        primary_badge_key: "",
        secondary_story: "",
        secondary_badge_key: ""
      },
      hero_players: [],
      badges_to_render: [],
      stats_to_render: [],
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
        image_url: "",
        og_image_url: "",
        width: config.render.outputWidth,
        height: config.render.outputHeight,
        format: "png"
      }
    },
    replay_link: replayLink,
    message_templates: {
      discord: {
        content: "",
        embed_title: "",
        embed_description: "",
        embed_url: ""
      },
      x: {
        text: ""
      }
    }
  };

  payload.share_card = buildShareStory(payload, config);
  payload.message_templates = buildMessageTemplates(payload);
  payload.posting_rules.destinations = buildPostingDestinations(payload, config);
  return payload;
}
