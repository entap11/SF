import { defaultHighlightConfig } from "./config.js";
import { normalizeMatchAnalytics } from "./analytics_adapter.js";
import { buildDerivedBadges, deriveCandidateBadges } from "./badges.js";
import { resolveReplayLink } from "./replay_links.js";
import { scoreMatch } from "./scorer.js";
import { buildPostingDestinations } from "./social_routing.js";
import { buildShareStory } from "./story.js";
import { HIGHLIGHT_SCHEMA_VERSION } from "./types.js";
function contentFlagsFromScore(explicitFlags, excitementScore, config) {
    return {
        highlight_game: explicitFlags?.highlight_game ?? excitementScore >= config.contentFlagThresholds.highlightGame,
        game_of_the_day_candidate: explicitFlags?.game_of_the_day_candidate ?? excitementScore >= config.contentFlagThresholds.gameOfTheDayCandidate,
        top_10_candidate: explicitFlags?.top_10_candidate ?? excitementScore >= config.contentFlagThresholds.top10Candidate,
        featured_replay: explicitFlags?.featured_replay ?? excitementScore >= config.contentFlagThresholds.featuredReplay
    };
}
function buildMessageTemplates(payload) {
    const link = payload.acquisition_link.universal_url;
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
            text: `${title} in Swarmfront. ${payload.acquisition_link.cta_text}: ${link}`
        }
    };
}
function buildAcquisitionLink(payload, config) {
    const replayId = encodeURIComponent(payload.match.replay_id);
    const matchId = encodeURIComponent(payload.match.match_id);
    const campaign = encodeURIComponent(config.acquisitionLinks.campaign);
    const universalUrl = `${config.acquisitionLinks.basePlayUrl}?replay=${replayId}&match=${matchId}&utm_source=social&utm_medium=highlight&utm_campaign=${campaign}`;
    return {
        universal_url: universalUrl,
        app_deep_link: `${config.replayLinks.appScheme}/${replayId}?source=social_highlight`,
        app_store_url_ios: config.replayLinks.fallbackUrlIos,
        app_store_url_android: config.replayLinks.fallbackUrlAndroid,
        desktop_fallback_url: payload.replay_link.canonical_url,
        campaign: config.acquisitionLinks.campaign,
        cta_text: config.acquisitionLinks.ctaText
    };
}
function buildHighlightVideoAsset(payload, config) {
    const safeMatchId = encodeURIComponent(payload.match.match_id);
    const safeReplayId = encodeURIComponent(payload.match.replay_id);
    const clipSeconds = Math.min(config.video.defaultClipSeconds, Math.max(1, payload.match.duration_seconds));
    return {
        source: "deterministic_replay_render",
        status: payload.posting_rules.eligible_for_auto_post ? "queued" : "skipped",
        video_url: `${config.video.assetBaseUrl}/${safeMatchId}/${safeReplayId}.mp4`,
        poster_url: `${config.render.assetBaseUrl}/${safeReplayId}/og.png`,
        duration_seconds: clipSeconds,
        width: config.video.outputWidth,
        height: config.video.outputHeight,
        format: "mp4",
        retention_policy: "ephemeral_source_permanent_clip",
        cta: {
            text_overlay: payload.acquisition_link.cta_text,
            link_url: payload.acquisition_link.universal_url,
            safe_area: "bottom"
        }
    };
}
export function buildHighlightPayload(input, config = defaultHighlightConfig) {
    const normalized = normalizeMatchAnalytics(input);
    const scoring = scoreMatch(normalized, config);
    const contentFlags = contentFlagsFromScore(normalized.content_flags, scoring.excitement_score, config);
    const candidateBadges = deriveCandidateBadges(normalized.match, normalized.players, normalized.analytics, contentFlags, config);
    const derivedBadges = buildDerivedBadges(candidateBadges, config);
    const replayLink = resolveReplayLink(normalized.match.replay_id, config);
    const eligibleForAutoPost = scoring.watchability_pass && scoring.auto_post_tier !== "no_auto_post";
    const payload = {
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
        highlight_video: {
            source: "deterministic_replay_render",
            status: "skipped",
            video_url: "",
            poster_url: "",
            duration_seconds: 0,
            width: config.video.outputWidth,
            height: config.video.outputHeight,
            format: "mp4",
            retention_policy: "ephemeral_source_permanent_clip",
            cta: {
                text_overlay: config.acquisitionLinks.ctaText,
                link_url: "",
                safe_area: "bottom"
            }
        },
        replay_link: replayLink,
        acquisition_link: {
            universal_url: "",
            app_deep_link: "",
            app_store_url_ios: config.replayLinks.fallbackUrlIos,
            app_store_url_android: config.replayLinks.fallbackUrlAndroid,
            desktop_fallback_url: replayLink.canonical_url,
            campaign: config.acquisitionLinks.campaign,
            cta_text: config.acquisitionLinks.ctaText
        },
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
    payload.acquisition_link = buildAcquisitionLink(payload, config);
    payload.highlight_video = buildHighlightVideoAsset(payload, config);
    payload.message_templates = buildMessageTemplates(payload);
    payload.posting_rules.destinations = buildPostingDestinations(payload, config);
    return payload;
}
