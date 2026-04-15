import { defaultHighlightConfig } from "./config.js";
import type { HighlightConfig, ReplayLinkPayload } from "./types.js";

export function resolveReplayLink(replayId: string, config: HighlightConfig = defaultHighlightConfig): ReplayLinkPayload {
  const encodedReplayId = encodeURIComponent(replayId);
  return {
    canonical_url: `${config.replayLinks.baseReplayUrl}/${encodedReplayId}`,
    deep_link_path: `${config.replayLinks.appScheme}/${encodedReplayId}`,
    fallback_url_ios: config.replayLinks.fallbackUrlIos,
    fallback_url_android: config.replayLinks.fallbackUrlAndroid
  };
}
