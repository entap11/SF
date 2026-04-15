import { defaultHighlightConfig } from "./config.js";
import type { HighlightConfig, HighlightPayload, SocialJob } from "./types.js";

function tierDestinations(payload: HighlightPayload, config: HighlightConfig): string[] {
  if (!payload.posting_rules.eligible_for_auto_post) {
    return [];
  }
  if (payload.scoring.auto_post_tier === "tier_1") {
    return [
      ...config.postDestinations.officialHighlightChannels,
      ...config.postDestinations.globalChannels,
      ...config.postDestinations.teamChannels,
      ...config.postDestinations.playerAllowedDestinations,
      ...config.postDestinations.xQueueTargets,
      ...config.postDestinations.internalFeaturedFeeds
    ];
  }
  if (payload.scoring.auto_post_tier === "tier_2") {
    return [...config.postDestinations.teamChannels, ...config.postDestinations.playerAllowedDestinations];
  }
  return [];
}

export function buildPostingDestinations(
  payload: HighlightPayload,
  config: HighlightConfig = defaultHighlightConfig
): string[] {
  return tierDestinations(payload, config);
}

export function buildSocialJobs(payload: HighlightPayload, config: HighlightConfig = defaultHighlightConfig): SocialJob[] {
  const destinations = tierDestinations(payload, config);
  const jobs: SocialJob[] = [];

  for (const destination of destinations) {
    if (destination.startsWith("discord:")) {
      jobs.push({
        job_type: "discord_webhook",
        destination,
        match_id: payload.match.match_id,
        replay_id: payload.match.replay_id,
        payload: {
          content: payload.message_templates.discord.content,
          embeds: [
            {
              title: payload.message_templates.discord.embed_title,
              description: payload.message_templates.discord.embed_description,
              url: payload.message_templates.discord.embed_url,
              image: { url: payload.share_card.output.og_image_url }
            }
          ]
        }
      });
    } else if (destination.startsWith("x:")) {
      jobs.push({
        job_type: "x_queue",
        destination,
        match_id: payload.match.match_id,
        replay_id: payload.match.replay_id,
        payload: {
          text: payload.message_templates.x.text,
          image_url: payload.share_card.output.image_url,
          canonical_url: payload.replay_link.canonical_url
        }
      });
    } else if (destination.startsWith("internal:")) {
      jobs.push({
        job_type: "internal_featured_feed",
        destination,
        match_id: payload.match.match_id,
        replay_id: payload.match.replay_id,
        payload: {
          title: payload.share_card.title,
          subtitle: payload.share_card.subtitle,
          canonical_url: payload.replay_link.canonical_url,
          badges: payload.share_card.badges_to_render
        }
      });
    }
  }

  return jobs;
}
