import { buildHighlightPayload } from "./payload_builder.js";
import type { CompletedMatchInput } from "./analytics_adapter.js";
import type { HighlightBadge } from "./types.js";

const wins500Badge: HighlightBadge = {
  badge_key: "wins_500",
  badge_name: "500 Wins",
  badge_type: "player_milestone_badge",
  badge_tier: "milestone",
  display_priority: 90
};

const wins100Badge: HighlightBadge = {
  badge_key: "wins_100",
  badge_name: "100 Wins",
  badge_type: "player_milestone_badge",
  badge_tier: "milestone",
  display_priority: 68
};

export const majorComebackMoneyMatchFixture: CompletedMatchInput = {
  match: {
    match_id: "match_money_50_comeback",
    replay_id: "ABC123",
    mode: "money_game",
    player_count: 2,
    is_money_game: true,
    stake_amount_usd: 50,
    duration_seconds: 232,
    buffs_used_total: 8,
    swarms_sent_total: 148,
    disconnect: false,
    ended_normally: true,
    timestamp_utc: "2026-04-15T17:12:00Z"
  },
  players: [
    {
      player_id: "player_123",
      username: "Ninja123213",
      team_id: "team_alpha",
      placement: 1,
      won: true,
      wins_total_after_match: 500,
      badges_earned_in_match: [wins500Badge]
    },
    {
      player_id: "player_456",
      username: "HexRush",
      team_id: "team_beta",
      placement: 2,
      won: false,
      wins_total_after_match: 311,
      badges_earned_in_match: []
    }
  ],
  analytics: {
    comeback_factor: { label: "major", score_raw: 0.91 },
    closeness_factor: { label: "tight_finish", score_raw: 0.84 },
    efficiency_factor: { label: "elite", score_raw: 0.88 }
  },
  content_flags: {
    game_of_the_day_candidate: true,
    top_10_candidate: true,
    featured_replay: true
  }
};

export const fourPlayerChaosFixture: CompletedMatchInput = {
  match: {
    match_id: "match_4p_chaos",
    replay_id: "CHAOS4",
    mode: "pvp_4p",
    player_count: 4,
    is_money_game: false,
    stake_amount_usd: 0,
    duration_seconds: 360,
    buffs_used_total: 9,
    swarms_sent_total: 520,
    disconnect: false,
    ended_normally: true,
    timestamp_utc: "2026-04-15T18:20:00Z"
  },
  players: [
    {
      player_id: "p1",
      username: "QueenCut",
      team_id: "alpha",
      placement: 1,
      won: true,
      wins_total_after_match: 92,
      badges_earned_in_match: []
    },
    {
      player_id: "p2",
      username: "LaneKnife",
      team_id: "beta",
      placement: 2,
      won: false,
      wins_total_after_match: 71,
      badges_earned_in_match: []
    },
    {
      player_id: "p3",
      username: "NorthHive",
      team_id: "gamma",
      placement: 3,
      won: false,
      wins_total_after_match: 44,
      badges_earned_in_match: []
    },
    {
      player_id: "p4",
      username: "SouthHive",
      team_id: "delta",
      placement: 4,
      won: false,
      wins_total_after_match: 39,
      badges_earned_in_match: []
    }
  ],
  analytics: {
    comeback_factor: { label: "swingy", score_raw: 0.78 },
    closeness_factor: { label: "tight_finish", score_raw: 0.79 },
    efficiency_factor: { label: "solid", score_raw: 0.64 }
  },
  content_flags: {
    highlight_game: true
  }
};

export const asyncNoPostFixture: CompletedMatchInput = {
  match: {
    match_id: "match_async_short",
    replay_id: "ASYNCNO",
    mode: "async",
    player_count: 2,
    is_money_game: false,
    stake_amount_usd: 0,
    duration_seconds: 58,
    buffs_used_total: 0,
    swarms_sent_total: 12,
    disconnect: false,
    ended_normally: true,
    timestamp_utc: "2026-04-15T19:00:00Z"
  },
  players: [
    {
      player_id: "async_1",
      username: "WorkerBee",
      team_id: "solo",
      placement: 1,
      won: true,
      wins_total_after_match: 8,
      badges_earned_in_match: []
    }
  ],
  analytics: {
    comeback_factor: { label: "none", score_raw: 0.05 },
    closeness_factor: { label: "severe_blowout", score_raw: 0.08 },
    efficiency_factor: { label: "normal", score_raw: 0.4 }
  }
};

export const tooManyBadgesFixture: CompletedMatchInput = {
  ...majorComebackMoneyMatchFixture,
  match: {
    ...majorComebackMoneyMatchFixture.match,
    match_id: "match_many_badges",
    replay_id: "BADGECAP"
  },
  players: [
    {
      ...majorComebackMoneyMatchFixture.players[0],
      badges_earned_in_match: [wins500Badge, wins100Badge]
    },
    ...majorComebackMoneyMatchFixture.players.slice(1)
  ],
  content_flags: {
    highlight_game: true,
    game_of_the_day_candidate: true,
    top_10_candidate: true,
    featured_replay: true
  }
};

export const sampleHighlightPayloads = {
  majorComebackMoneyMatch: buildHighlightPayload(majorComebackMoneyMatchFixture),
  fourPlayerChaos: buildHighlightPayload(fourPlayerChaosFixture),
  asyncNoPost: buildHighlightPayload(asyncNoPostFixture),
  tooManyBadges: buildHighlightPayload(tooManyBadgesFixture)
};
