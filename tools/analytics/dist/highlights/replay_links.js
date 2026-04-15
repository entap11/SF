import { defaultHighlightConfig } from "./config.js";
export function resolveReplayLink(replayId, config = defaultHighlightConfig) {
    const encodedReplayId = encodeURIComponent(replayId);
    return {
        canonical_url: `${config.replayLinks.baseReplayUrl}/${encodedReplayId}`,
        deep_link_path: `${config.replayLinks.appScheme}/${encodedReplayId}`,
        fallback_url_ios: config.replayLinks.fallbackUrlIos,
        fallback_url_android: config.replayLinks.fallbackUrlAndroid
    };
}
