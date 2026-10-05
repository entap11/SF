# Swarmfront Advertising Policy

Advertising must support free play without interrupting matches or degrading the player experience.

## Approved Placements

- `handshake`: pre-match loading or connection handshake only.
- `in_game`: reserved HUD banner areas only.
- `post_match`: after match completion only.

Any other placement must be hidden by default.

Current slot IDs:

- `match_loading`: large sponsor area below the logo, preparation progress, and rotating copy; pre-game only, never app startup or menu navigation.
- `prematch_handshake`
- `vs_handshake`
- `in_game_hud`
- `in_game_footer`: bottom banner when buffs are disabled (including Crucible).
- `post_match_summary`

## Timing

- `match_loading` targets a 10-second creative in a 10–12 second loading transition. Arena preparation and ad playback run concurrently. Release requires both arena readiness and ad completion; real loading can take longer.
- Count playback from the first presented ad frame, not the request time. Static creatives receive ten seconds of visible exposure; local video creatives finish on playback completion, capped at ten seconds. A 12-second deadline from preparation abandons stalled playback. Missing/failed ads never add an ad hold.
- Ad-free players use the same ten-second loading presentation with first-party Swarmfront content in the lower panel. It has its own bounded presentation timer, with no paid-ad request or measurement. Real arena preparation can take longer.
- The existing match-loading cover holds the pre-match countdown. The ad UI must never mutate simulation state.
- Legacy handshake banner slots retain their eight-second auto-dismiss.
- In-match banners may persist during the match and refresh according to provider policy.
- Post-match ads auto-dismiss after about 7-10 seconds. Current target: 9 seconds.

No ad may require interaction before the match or menu flow continues.

## Premium And Safety Rules

- Players with `zero_ads` must never be shown paid ads; HUD surfaces switch to internal ticker content. The loading panel shows company messages, match highlights/upsets, accomplishments, or internal promo media, with a category heading instead of "Sponsored".
- Ads must not pause gameplay, cover controls, obscure critical information, or launch external destinations without an intentional player tap.
- Tapping any ad copies its destination URL to the clipboard and briefly displays "Link copied" without pausing playback or opening a browser. If copying is unavailable, report that honestly; never fall back to opening a window. In-match taps also retain the existing Saved Ads entry, where a separate explicit Open action is available after the match.
- Family-safe rules must be respected for SFA/minor profiles.
- Personalized ads are disabled by default until a compliant consent/privacy path exists.
- If no eligible ad is available, the reserved space remains empty unless the player has `zero_ads`, in which case approved surfaces show internal ticker content.

The player experience always takes priority over ad revenue.

## Implementation Notes

`AdManager` is the policy and provider adapter boundary. Ad surfaces must call through it instead of talking directly to an ad SDK.

Beta builds now enable the bundled top and bottom Biodynamic banners by default via `swarmfront/ads/beta_biodynamic_banners=true`. This applies to `beta_capture` exports (including release-mode TestFlight/Android builds) and local non-store debug games. Non-beta store releases cannot use this allowance. It covers only `in_game_hud` and `in_game_footer`, independently of live external inventory; loading/handshake/post-match ads keep their existing gates. Ad-free entitlements and placement switches still apply, and the footer remains reserved for buffs in modes that use them. Disable the setting or set `SF_BIODYNAMIC_TEST_ADS=0` to stop the beta banners.

Support diagnostics and existing beta-capture checkpoints include an `app_session` ad summary: fills, no-fill reasons, impressions, taps, texture-load failures, and last/max texture-load time in milliseconds. Counts span the current app session, not just one match. Updates occur on ad events and texture loads; there is no new per-frame logging or telemetry upload path. Capture sharing uses the existing player's beta-sharing choice. Both in-memory measurement histories retain at most 256 recent events while summary counters continue accumulating. Test creatives are marked non-billable. Texture-load timing measures the local loading call, not overall FPS or GPU rendering cost.

The loading surface supports existing static creative fields and a `video_path` pointing to an already available Godot `VideoStream` resource. Video starts muted, preserves its aspect ratio, and stops when the transition is canceled. Provider requests must return promptly from cached inventory; downloading/SDK acquisition belongs outside the loading UI. A production network SDK and its native playback callbacks are not installed by this surface implementation. Bundled external-ad enablement remains off.

Ad-free loading content is a separate UI surface (`match_loading_content.gd`) and never calls ad request, fill, impression, or tap APIs. Configure `ads.loading_content_items` in OpsConfig with a list of cards:

```json
{"kind": "company", "title": "Thanks for backing the swarm.", "body": "Your support helps us build Swarmfront."}
```

Supported kinds are `company`, `match_highlight`, `upset`, `accomplishment`, and `promo`. Optional `image_path` and `video_path` reference already available local media; videos play muted. Cards rotate in order between games. An empty/invalid catalog uses the built-in company thank-you message. Unavailable media leaves the card's text visible. Highlights and accomplishments must be supplied from verified editorial or backend data; this surface does not fabricate results or automatically query a live match feed.

Provider adapter methods:

- `request_ad(slot_id, placement, policy)`
- `record_ad_event(event)`
- `open_ad(slot_record, event)`
- `mark_filled(slot_id, placement, policy, creative)`
- `mark_empty(slot_id, placement, policy, reason)`
- `record_impression(slot_id)`
- `record_tap(slot_id)`
- `record_conversion(slot_id, attribution)`

Client impression/tap events are measurement candidates only. Final billable impressions, clicks, downloads, installs, or other conversions must be verified by the installed ad network SDK, mediation provider, or backend attribution service. Internal ticker surfaces must never emit ad measurement events.

Set `SF_FAKE_ADS=1` or `swarmfront/ads/fake_ads=true` to fill approved placements with fake ENTaP test ads. Set `SF_AD_PLACEHOLDERS=1` or `swarmfront/ads/show_placeholders=true` to show passive placeholder boxes without filling an ad.

For local in-game banner testing, set `SF_BIODYNAMIC_TEST_ADS=1` or `swarmfront/ads/dev_biodynamic_test_ads=true`. The top slot (`in_game_hud`) serves `swarmfront/ads/dev_biodynamic_top_image_path` (Mold Remediation), and the bottom slot (`in_game_footer`) serves `swarmfront/ads/dev_biodynamic_bottom_image_path` (2,000+ Passed ERMI Tests). Both supplied PNGs are 1440 × 240. Other static placements use `swarmfront/ads/dev_biodynamic_image_path`. Intentional taps copy `swarmfront/ads/dev_biodynamic_destination_url`.

The same test provider now serves the supplied Biodynamic Restoration ten-second video exclusively in `match_loading`, using `swarmfront/ads/dev_biodynamic_video_path`. The runtime asset is `res://assets/ads/test_creatives/biodynamic_mobile_loading_10s.ogv`; the original MP4 and conversion recipe are retained in the adjacent ignored `source` folder. `swarmfront/ads/dev_biodynamic_video_destination_url` is independently configurable and defaults to `https://www.biodynamicusa.com`, as requested. Handshake and post-match slots retain the static Laser Cleaning banner. Installing these creatives does not change external-ad enablement or ad-free routing.

Run `python3 tools/run_match_loading_ad_checks.py` for isolated loading timing, no-fill, entitlement, cancellation, failure, and measurement checks. Add `--visual-dir /path/to/output` to render a preview, and `--video-path /path/to/short-fixture.ogv` to exercise actual video completion. The harness enables fake inventory only in its isolated test config.
