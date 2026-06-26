# Swarmfront Advertising Policy

Advertising must support free play without interrupting matches or degrading the player experience.

## Approved Placements

- `handshake`: pre-match loading or connection handshake only.
- `in_game`: reserved HUD banner areas only.
- `post_match`: after match completion only.

Any other placement must be hidden by default.

Current slot IDs:

- `prematch_handshake`
- `vs_handshake`
- `in_game_hud`
- `post_match_summary`

## Timing

- Pre-match ads auto-dismiss after about 5-10 seconds. Current target: 8 seconds.
- In-match banners may persist during the match and refresh according to provider policy.
- Post-match ads auto-dismiss after about 7-10 seconds. Current target: 9 seconds.

No ad may require interaction before the match or menu flow continues.

## Premium And Safety Rules

- Players with `zero_ads` must never be shown ads.
- Ads must not pause gameplay, cover controls, obscure critical information, or launch external destinations without an intentional player tap.
- Family-safe rules must be respected for SFA/minor profiles.
- Personalized ads are disabled by default until a compliant consent/privacy path exists.
- If no eligible ad is available, the reserved space remains empty.

The player experience always takes priority over ad revenue.

## Implementation Notes

`AdManager` is the policy and provider adapter boundary. Ad surfaces must call through it instead of talking directly to an ad SDK.

Provider adapter methods:

- `request_ad(slot_id, placement, policy)`
- `mark_filled(slot_id, placement, policy, creative)`
- `mark_empty(slot_id, placement, policy, reason)`
- `record_impression(slot_id)`
- `record_tap(slot_id)`

Set `SF_FAKE_ADS=1` or `swarmfront/ads/fake_ads=true` to fill approved placements with fake ENTaP test ads. Set `SF_AD_PLACEHOLDERS=1` or `swarmfront/ads/show_placeholders=true` to show passive placeholder boxes without filling an ad.
