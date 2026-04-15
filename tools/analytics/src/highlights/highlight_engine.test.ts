import assert from "node:assert/strict";
import { buildHighlightPayload } from "./payload_builder.js";
import { renderHighlightCard } from "./renderer.js";
import { computeDurationBand, computeSwarmDensityBand } from "./scorer.js";
import { buildSocialJobs } from "./social_routing.js";
import {
  asyncNoPostFixture,
  fourPlayerChaosFixture,
  majorComebackMoneyMatchFixture,
  tooManyBadgesFixture
} from "./fixtures.js";

function assertIncludes<T>(values: T[], expected: T, message: string): void {
  assert.ok(values.includes(expected), `${message}: expected ${String(expected)} in ${JSON.stringify(values)}`);
}

const moneyPayload = buildHighlightPayload(majorComebackMoneyMatchFixture);
assert.equal(moneyPayload.schema_version, "swarmfront.highlight.v1.1");
assert.equal(moneyPayload.scoring.watchability_pass, true);
assert.equal(moneyPayload.scoring.auto_post_tier, "tier_1");
assert.ok(moneyPayload.scoring.excitement_score >= 88);
assert.equal(moneyPayload.scoring.scoring_visibility.visible_to_players, false);

const durationBand = computeDurationBand("money_game", moneyPayload.match.duration_seconds);
assert.equal(durationBand.label, "goldilocks");
const swarmBand = computeSwarmDensityBand(
  moneyPayload.match.mode,
  moneyPayload.match.player_count,
  moneyPayload.match.swarms_sent_total,
  moneyPayload.match.duration_seconds
);
assert.equal(swarmBand.label, "goldilocks");

assert.equal(moneyPayload.derived_badges.selected_badges.length, 2);
assert.equal(moneyPayload.derived_badges.selected_badges[0]?.badge_key, "game_of_the_day_candidate");
assert.equal(moneyPayload.derived_badges.selected_badges[0]?.headline_selected, true);
assert.equal(moneyPayload.derived_badges.selected_badges[1]?.badge_key, "wins_500");
assert.equal(moneyPayload.share_card.title, "Game of the Day");
assert.equal(moneyPayload.share_card.story_focus.primary_badge_key, "game_of_the_day_candidate");
assert.equal(moneyPayload.share_card.story_focus.secondary_badge_key, "wins_500");

const tooManyPayload = buildHighlightPayload(tooManyBadgesFixture);
assert.ok(tooManyPayload.derived_badges.candidate_badges.length > 2);
assert.equal(tooManyPayload.derived_badges.selected_badges.length, 2);
assert.equal(tooManyPayload.share_card.badges_to_render.length, 2);
assert.deepEqual(
  tooManyPayload.derived_badges.selected_badges.map((badge) => badge.badge_key),
  ["game_of_the_day_candidate", "wins_500"]
);

const chaosPayload = buildHighlightPayload(fourPlayerChaosFixture);
assertIncludes(
  chaosPayload.derived_badges.candidate_badges.map((badge) => badge.badge_key),
  "full_chaos_match",
  "4-player chaos fixture should derive chaos badge"
);
assert.equal(chaosPayload.scoring.watchability_pass, true);
assert.equal(chaosPayload.scoring.auto_post_tier, "tier_2");

const asyncPayload = buildHighlightPayload(asyncNoPostFixture);
assert.equal(asyncPayload.scoring.watchability_pass, false);
assert.equal(asyncPayload.scoring.auto_post_tier, "no_auto_post");
assert.equal(asyncPayload.posting_rules.eligible_for_auto_post, false);
assert.equal(buildSocialJobs(asyncPayload).length, 0);

const tier1Jobs = buildSocialJobs(moneyPayload);
assert.ok(tier1Jobs.some((job) => job.destination === "discord:official-highlights"));
assert.ok(tier1Jobs.some((job) => job.destination === "discord:global-feed"));
assert.ok(tier1Jobs.some((job) => job.destination === "x:official-highlights"));

const tier2Jobs = buildSocialJobs(chaosPayload);
assert.ok(tier2Jobs.length > 0);
assert.ok(tier2Jobs.every((job) => !["discord:official-highlights", "discord:global-feed"].includes(job.destination)));

const rendered = renderHighlightCard(tooManyPayload, "x_share_card");
assert.equal(rendered.width, 1200);
assert.equal(rendered.height, 630);
assert.ok(rendered.image_url.endsWith("/x_share_card.png"));

assert.equal(moneyPayload.replay_link.canonical_url, "https://swarmfront.com/replay/ABC123");
assert.equal(moneyPayload.replay_link.deep_link_path, "swarmfront://replay/ABC123");

console.log("HIGHLIGHT_ENGINE_TEST: PASS");
