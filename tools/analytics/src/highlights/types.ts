export const HIGHLIGHT_SCHEMA_VERSION = "swarmfront.highlight.v1.1" as const;

export type MatchMode = "async" | "pvp_1v1" | "pvp_3p" | "pvp_4p" | "money_game";
export type BadgeType = "match_badge" | "player_milestone_badge";
export type AutoPostTier = "tier_1" | "tier_2" | "no_auto_post";
export type RenderSurface =
  | "discord_og_card"
  | "x_share_card"
  | "in_app_highlight_card"
  | "web_replay_hero_card";

export interface HighlightSystemRules {
  purpose: string;
  design_principles: string[];
  badge_rules: {
    max_badges_rendered: number;
    render_only_highest_priority_badges: boolean;
    headline_uses_highest_priority_badge: boolean;
    badge_priority_source: "display_priority";
    badge_categories: BadgeType[];
  };
  render_rules: {
    single_render_system: boolean;
    render_outputs: RenderSurface[];
  };
  posting_rules: {
    auto_post_requires_watchability_pass: boolean;
    auto_post_requires_threshold: boolean;
    do_not_post_all_games: boolean;
    posting_goal: string;
  };
}

export interface HighlightMatch {
  match_id: string;
  replay_id: string;
  mode: MatchMode;
  player_count: number;
  is_money_game: boolean;
  stake_amount_usd: number;
  duration_seconds: number;
  buffs_used_total: number;
  swarms_sent_total: number;
  disconnect: boolean;
  ended_normally: boolean;
  timestamp_utc: string;
  broken_or_unusable?: boolean;
}

export interface HighlightBadge {
  badge_key: string;
  badge_name: string;
  badge_type: BadgeType;
  badge_tier: string;
  display_priority: number;
  render_slot?: 1 | 2;
  headline_selected?: boolean;
  player_id?: string;
}

export interface HighlightPlayer {
  player_id: string;
  username: string;
  team_id: string;
  placement: number;
  won: boolean;
  wins_total_after_match: number;
  badges_earned_in_match: HighlightBadge[];
}

export interface AnalyticsFactor {
  label: string;
  score_raw: number;
}

export interface HighlightAnalytics {
  comeback_factor: AnalyticsFactor;
  closeness_factor: AnalyticsFactor;
  efficiency_factor: AnalyticsFactor;
  swarm_density_factor: AnalyticsFactor;
  duration_factor: AnalyticsFactor;
}

export interface HighlightScoringResult {
  weights: Record<string, number>;
  component_scores: {
    stakes: number;
    mode_player_count: number;
    buff_usage: number;
    comeback: number;
    swarm_density: number;
    duration: number;
  };
  excitement_score: number;
  watchability_pass: boolean;
  auto_post_tier: AutoPostTier;
  scoring_visibility: {
    visible_to_players: false;
    publicly_described: false;
  };
}

export interface HighlightContentFlags {
  highlight_game: boolean;
  game_of_the_day_candidate: boolean;
  top_10_candidate: boolean;
  featured_replay: boolean;
}

export interface DerivedBadges {
  candidate_badges: HighlightBadge[];
  selected_badges: HighlightBadge[];
  selection_rules_applied: {
    max_badges_rendered: number;
    selected_by_highest_priority: true;
    headline_selected_from_highest_priority_badge: true;
  };
}

export interface HighlightShareCard {
  template_key: string;
  headline_source: "highest_priority_badge";
  title: string;
  subtitle: string;
  story_focus: {
    primary_story: BadgeType | "highlight";
    primary_badge_key: string;
    secondary_story: BadgeType | "";
    secondary_badge_key: string;
  };
  hero_players: Array<{
    player_id: string;
    username: string;
    placement: number;
    won: boolean;
  }>;
  badges_to_render: HighlightBadge[];
  stats_to_render: Array<{ label: string; value: string }>;
  render_assets: {
    background_key: string;
    frame_key: string;
    badge_style_key: string;
  };
  render_constraints: {
    max_badges_rendered: number;
    do_not_overcrowd: true;
    secondary_badge_must_support_primary_story: true;
  };
  output: {
    image_url: string;
    og_image_url: string;
    width: number;
    height: number;
    format: "png";
  };
}

export interface ReplayLinkPayload {
  canonical_url: string;
  deep_link_path: string;
  fallback_url_ios: string;
  fallback_url_android: string;
}

export interface HighlightAcquisitionLink {
  universal_url: string;
  app_deep_link: string;
  app_store_url_ios: string;
  app_store_url_android: string;
  desktop_fallback_url: string;
  campaign: string;
  cta_text: string;
}

export interface HighlightVideoCta {
  text_overlay: string;
  link_url: string;
  safe_area: "bottom";
}

export interface HighlightVideoAsset {
  source: "deterministic_replay_render";
  status: "queued" | "rendered" | "skipped";
  video_url: string;
  poster_url: string;
  duration_seconds: number;
  width: number;
  height: number;
  format: "mp4";
  retention_policy: "ephemeral_source_permanent_clip";
  cta: HighlightVideoCta;
}

export interface HighlightPayload {
  schema_version: typeof HIGHLIGHT_SCHEMA_VERSION;
  system_rules: HighlightSystemRules;
  match: HighlightMatch;
  players: HighlightPlayer[];
  analytics: HighlightAnalytics;
  scoring: HighlightScoringResult;
  content_flags: HighlightContentFlags;
  derived_badges: DerivedBadges;
  posting_rules: {
    eligible_for_auto_post: boolean;
    destinations: string[];
  };
  share_card: HighlightShareCard;
  highlight_video: HighlightVideoAsset;
  replay_link: ReplayLinkPayload;
  acquisition_link: HighlightAcquisitionLink;
  message_templates: {
    discord: {
      content: string;
      embed_title: string;
      embed_description: string;
      embed_url: string;
    };
    x: {
      text: string;
    };
  };
}

export interface NormalizedMatchAnalytics {
  match: HighlightMatch;
  players: HighlightPlayer[];
  analytics: HighlightAnalytics;
  content_flags?: Partial<HighlightContentFlags>;
}

export interface HighlightConfig {
  systemRules: HighlightSystemRules;
  scoreWeights: HighlightScoringResult["weights"];
  scoreThresholds: {
    tier1: number;
    tier2: number;
    minimumDurationSeconds: number;
    severeBlowoutClosenessRaw: number;
  };
  moneyStakeBands: Array<{ minUsd: number; scoreRaw: number }>;
  modePlayerCountScores: Record<MatchMode, number>;
  buffUsageBands: Array<{ minBuffs: number; scoreRaw: number }>;
  goldilocksRanges: {
    duration: Record<MatchMode, { min: number; sweetMin: number; sweetMax: number; high: number }>;
    swarmDensity: Record<string, { min: number; sweetMin: number; sweetMax: number; high: number }>;
  };
  badgePriorities: Record<string, number>;
  badgeCriteria: {
    majorComebackMinRaw: number;
    highStakesMinUsd: number;
    fullChaosMinPlayers: number;
    fullChaosMinBuffs: number;
  };
  contentFlagThresholds: {
    highlightGame: number;
    gameOfTheDayCandidate: number;
    top10Candidate: number;
    featuredReplay: number;
  };
  postDestinations: {
    officialHighlightChannels: string[];
    globalChannels: string[];
    teamChannels: string[];
    playerAllowedDestinations: string[];
    xQueueTargets: string[];
    internalFeaturedFeeds: string[];
  };
  replayLinks: {
    baseReplayUrl: string;
    appScheme: string;
    fallbackUrlIos: string;
    fallbackUrlAndroid: string;
  };
  acquisitionLinks: {
    basePlayUrl: string;
    campaign: string;
    ctaText: string;
  };
  render: {
    assetBaseUrl: string;
    templateKey: string;
    backgroundKey: string;
    frameKey: string;
    badgeStyleKey: string;
    outputWidth: number;
    outputHeight: number;
  };
  video: {
    assetBaseUrl: string;
    outputWidth: number;
    outputHeight: number;
    defaultClipSeconds: number;
  };
}

export interface RenderedHighlightCard {
  surface: RenderSurface;
  image_url: string;
  og_image_url: string;
  width: number;
  height: number;
  format: "png";
  metadata: {
    title: string;
    description: string;
    canonical_url: string;
    template_key: string;
  };
}

export type SocialJobType = "discord_webhook" | "x_queue" | "internal_featured_feed";

export interface SocialJob {
  job_type: SocialJobType;
  destination: string;
  match_id: string;
  replay_id: string;
  payload: Record<string, unknown>;
}
