export { normalizeMatchAnalytics, type CompletedMatchInput } from "./analytics_adapter.js";
export { buildDerivedBadges, deriveCandidateBadges, selectBadges, selectHeadlineBadge } from "./badges.js";
export { defaultHighlightConfig } from "./config.js";
export { buildHighlightPayload } from "./payload_builder.js";
export { resolveReplayLink } from "./replay_links.js";
export { buildOgImageMetadata, generateShareAssetPaths, renderHighlightCard } from "./renderer.js";
export {
  computeDurationBand,
  computeSwarmDensity,
  computeSwarmDensityBand,
  computeWatchabilityPass,
  scoreMatch
} from "./scorer.js";
export { buildPostingDestinations, buildSocialJobs } from "./social_routing.js";
export { buildShareStory } from "./story.js";
export * from "./types.js";
