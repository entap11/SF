import type { HighlightConfig } from "./types.js";

export const defaultHighlightConfig: HighlightConfig = {
  systemRules: {
    purpose:
      "Select, score, badge, and render high-value matches for social distribution without exposing the scoring model to players.",
    design_principles: [
      "Reward reality, not manipulation.",
      "Do not expose scoring inputs or formulas to players.",
      "Players should optimize for winning, not for content creation.",
      "Epic moments should emerge naturally from real gameplay.",
      "One render system should power all public-facing share assets."
    ],
    badge_rules: {
      max_badges_rendered: 2,
      render_only_highest_priority_badges: true,
      headline_uses_highest_priority_badge: true,
      badge_priority_source: "display_priority",
      badge_categories: ["match_badge", "player_milestone_badge"]
    },
    render_rules: {
      single_render_system: true,
      render_outputs: ["discord_og_card", "x_share_card", "in_app_highlight_card", "web_replay_hero_card"]
    },
    posting_rules: {
      auto_post_requires_watchability_pass: true,
      auto_post_requires_threshold: true,
      do_not_post_all_games: true,
      posting_goal: "Curate signal, avoid noise."
    }
  },
  scoreWeights: {
    stakes: 20,
    mode_player_count: 20,
    buff_usage: 15,
    comeback: 20,
    swarm_density: 15,
    duration: 10
  },
  scoreThresholds: {
    tier1: 88,
    tier2: 72,
    minimumDurationSeconds: 75,
    severeBlowoutClosenessRaw: 0.12
  },
  moneyStakeBands: [
    { minUsd: 100, scoreRaw: 1 },
    { minUsd: 50, scoreRaw: 1 },
    { minUsd: 20, scoreRaw: 0.82 },
    { minUsd: 10, scoreRaw: 0.68 },
    { minUsd: 5, scoreRaw: 0.5 },
    { minUsd: 1, scoreRaw: 0.32 },
    { minUsd: 0, scoreRaw: 0 }
  ],
  modePlayerCountScores: {
    async: 0.42,
    pvp_1v1: 0.68,
    pvp_3p: 0.88,
    pvp_4p: 1,
    money_game: 0.9
  },
  buffUsageBands: [
    { minBuffs: 8, scoreRaw: 1 },
    { minBuffs: 5, scoreRaw: 0.82 },
    { minBuffs: 3, scoreRaw: 0.58 },
    { minBuffs: 1, scoreRaw: 0.3 },
    { minBuffs: 0, scoreRaw: 0 }
  ],
  goldilocksRanges: {
    duration: {
      async: { min: 75, sweetMin: 120, sweetMax: 270, high: 420 },
      pvp_1v1: { min: 90, sweetMin: 150, sweetMax: 330, high: 480 },
      pvp_3p: { min: 105, sweetMin: 165, sweetMax: 390, high: 540 },
      pvp_4p: { min: 120, sweetMin: 180, sweetMax: 450, high: 600 },
      money_game: { min: 90, sweetMin: 150, sweetMax: 360, high: 510 }
    },
    swarmDensity: {
      async_2: { min: 0.16, sweetMin: 0.38, sweetMax: 0.78, high: 1.25 },
      pvp_1v1_2: { min: 0.22, sweetMin: 0.48, sweetMax: 0.92, high: 1.42 },
      pvp_3p_3: { min: 0.32, sweetMin: 0.7, sweetMax: 1.35, high: 2.1 },
      pvp_4p_4: { min: 0.44, sweetMin: 0.95, sweetMax: 1.75, high: 2.7 },
      money_game_2: { min: 0.24, sweetMin: 0.5, sweetMax: 1, high: 1.55 },
      default: { min: 0.2, sweetMin: 0.45, sweetMax: 1, high: 1.6 }
    }
  },
  badgePriorities: {
    game_of_the_day_candidate: 100,
    wins_500: 90,
    top_10_candidate: 86,
    first_money_win: 84,
    major_comeback: 82,
    high_stakes: 78,
    top_100_player: 76,
    full_chaos_match: 74,
    wins_100: 68,
    highlight_game: 55,
    featured_replay: 52
  },
  badgeCriteria: {
    majorComebackMinRaw: 0.82,
    highStakesMinUsd: 20,
    fullChaosMinPlayers: 4,
    fullChaosMinBuffs: 6
  },
  contentFlagThresholds: {
    highlightGame: 72,
    gameOfTheDayCandidate: 92,
    top10Candidate: 86,
    featuredReplay: 88
  },
  postDestinations: {
    officialHighlightChannels: ["discord:official-highlights"],
    globalChannels: ["discord:global-feed"],
    teamChannels: ["discord:team-highlights"],
    playerAllowedDestinations: ["player:share-inbox"],
    xQueueTargets: ["x:official-highlights"],
    internalFeaturedFeeds: ["internal:featured-replays"]
  },
  replayLinks: {
    baseReplayUrl: "https://swarmfront.com/replay",
    appScheme: "swarmfront://replay",
    fallbackUrlIos: "https://apps.apple.com/app/idXXXXXXXXX",
    fallbackUrlAndroid: "https://play.google.com/store/apps/details?id=com.swarmfront.app"
  },
  render: {
    assetBaseUrl: "https://swarmfront.com/assets/highlights",
    templateKey: "match_highlight_v1",
    backgroundKey: "premium_dark_hex",
    frameKey: "highlight_gold",
    badgeStyleKey: "sf_badges_v1",
    outputWidth: 1200,
    outputHeight: 630
  }
};
