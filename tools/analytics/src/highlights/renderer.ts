import { defaultHighlightConfig } from "./config.js";
import type { HighlightConfig, HighlightPayload, RenderedHighlightCard, RenderSurface } from "./types.js";

export function generateShareAssetPaths(
  matchId: string,
  replayId: string,
  surface: RenderSurface,
  config: HighlightConfig = defaultHighlightConfig
): { image_url: string; og_image_url: string } {
  const safeMatchId = encodeURIComponent(matchId);
  const safeReplayId = encodeURIComponent(replayId);
  return {
    image_url: `${config.render.assetBaseUrl}/${safeMatchId}/${surface}.png`,
    og_image_url: `${config.render.assetBaseUrl}/${safeReplayId}/og.png`
  };
}

export function buildOgImageMetadata(payload: HighlightPayload): RenderedHighlightCard["metadata"] {
  return {
    title: payload.share_card.title,
    description: payload.share_card.subtitle,
    canonical_url: payload.replay_link.canonical_url,
    template_key: payload.share_card.template_key
  };
}

export function renderHighlightCard(
  payload: HighlightPayload,
  surface: RenderSurface,
  config: HighlightConfig = defaultHighlightConfig
): RenderedHighlightCard {
  const cappedBadges = payload.share_card.badges_to_render.slice(0, config.systemRules.badge_rules.max_badges_rendered);
  const paths = generateShareAssetPaths(payload.match.match_id, payload.match.replay_id, surface, config);

  return {
    surface,
    image_url: paths.image_url,
    og_image_url: paths.og_image_url,
    width: config.render.outputWidth,
    height: config.render.outputHeight,
    format: "png",
    metadata: {
      ...buildOgImageMetadata(payload),
      description: `${payload.share_card.subtitle} • ${cappedBadges.map((badge) => badge.badge_name).join(" + ")}`
    }
  };
}
