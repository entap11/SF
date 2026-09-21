# Campaign and Jukebox pilot — September 21, 2026

Authorized outcome: Campaign on main provides guided single-player progression;
Dashboard → Jukebox selects bot, difficulty and map/variant from those same levels.
Level 1 starts open. A completed attempt, win or loss, unlocks the next level in
both routes. Quitting and no-contest do not unlock. Only wins earn stingers or a
personal best. Replay preserves previous bests and awards. Next is one tap, with
Retry and a visible exit. No automatic countdown.

## Content replacement plan

Owner clarification, September 21: most existing maps will be redesigned or
retired; only some will survive. The current 25-level lineup is temporary content
for validating the Campaign/Jukebox flow, not an approved shipping catalog.
Defer final encounter ordering, balance and stinger-time calibration until the
replacement maps are selected. Keep the progression and navigation reusable.

Before replacing the catalog, define how retired challenges, existing unlocks
and Continue bookmarks migrate. Keep old records associated with their original
challenge revisions; replacement encounters must not inherit unrelated PBs or
stingers. This migration remains future work, not a capability proven by the
current pilot. This clarification does not select maps for deletion now.

## Ownership and comparison conditions

- `data/campaign/starter_v1.json` is the authored catalog: 25 encounters, five maps,
  five personalities, three tiers, opponent order, deterministic seeds and target
  times. Targets are provisional beta tuning, not calibrated difficulty claims.
- `CampaignRuntime` owns session setup and consumes the existing simulation's
  terminal result signal. UI emits launch/return/retry intents and reads snapshots.
- OpsState owns gameplay, including applying the selected bot profile and seed.
  Pilot encounters use an empty buff loadout enforced at the simulation boundary;
  personal equipment cannot change the comparison conditions. Other modes retain
  their existing behavior.
- `CampaignProgressStore` is the single device-local persistence owner for
  campaign attempts, unlocked stable IDs, Continue bookmark, per-revision best
  times and stingers. They commit together through temporary-file replacement.
  Duplicate terminal events use one run ID; unreadable history is preserved.
- Campaign and Jukebox use identical challenge definitions and records. Display
  order is not the record key. Map and gameplay-source fingerprints separate
  records after rule/policy changes; old entries remain in the save. Cosmetic
  changes to a level's title or chapter do not change its record identity.
- `tools/refresh_campaign_fingerprints.py` updates only source/map fingerprints in
  the catalog. Its `--check` mode detects stale inputs. Fingerprints are packaged
  data so compiled iPhone and Android exports share the same identity.
- Campaign result routes are excluded from legacy map-only Jukebox record writes.
  No new verified-result, rank, cash-entry or settlement authority is introduced.
- Account deletion includes campaign progress and its temporary file.

## UI and persistence behavior

Campaign offers Continue and level browsing. Jukebox offers opponent, difficulty,
and matching map/variant choices, with campaign level number and that challenge's
board. Unsupported combinations are absent. Locked challenges are inspectable;
launch is checked by the owning state service, not only a disabled button.

A loss records an attempt, unlocks the next challenge and preserves any earlier
winning PB/stingers. A win awards one stinger; meeting the two/three-stinger time
thresholds awards the corresponding total. Rewards are mastery marks only and
have no currency/economy effect. Campaign updates its Continue bookmark when a
match starts and after a completed attempt; manual Jukebox play preserves it.

Returning from a match restores the correct hub and selected challenge. At the
end of the pilot, previously unlocked levels remain replayable. Save failures
are visible and offer Retry Save rather than pretending progress was recorded.

## Explicit limits

The pre-existing Jukebox boards are device-local. This pilot's shared level boards
are also device-local and labeled accordingly. Global verified leaderboards and
cross-device progress require their own service contract and integration; the
pilot does not claim they exist. Historical revisions are preserved in storage;
a historical-board browser is not included.

No new maps, bot behavior tuning, store publication, backend deployment, economy
changes, general menu redesign, or arena art pass is included. This is the
functional foundation for the later sprint polish. Phone readability, actual
retention, target-time calibration and real-device behavior still need pilots.

## Validation

- `tools/campaign_progress_smoke_test.gd`: catalog resolution, map loading,
  completion/unlock rules, win-only awards, duplicate events, PB preservation,
  player/revision isolation, restart persistence and corrupt-save preservation.
- `tools/campaign_flow_smoke_test.gd`: real Shell launch, actual bot/seed setup,
  loss → Next → second match, winning records, visible awards, result cleanup,
  legacy record isolation and return.
- `tools/campaign_ui_smoke_test.gd`: main/Dashboard routes, selector resolution,
  locked controls, persistent actions at portrait sizes, return context; optional
  graphics captures via `SF_CAMPAIGN_CAPTURE_DIR`.
- Fingerprint freshness is enforced by the release readiness gate.
- Run campaign checks with isolated test user data and offline service config:
  `python3 tools/run_campaign_pilot_checks.py --godot /path/to/Godot`.
  Add `--captures /path/to/output` for a graphics run and screenshots. Flow/UI
  fixtures refuse to run against an ordinary player-data directory.

Recorded desktop checks on Godot 4.7.1:

- Campaign persistence, real-scene flow and portrait layout checks: PASS.
- Existing async eligibility, legacy Jukebox runtime, outcome overlay, main-menu
  navigation and match HUD checks: PASS.
- Account deletion, including campaign save and pending save removal: PASS.
- Fast readiness stages: lane-grab regression PASS; MVP 26/26; soak launch
  contract PASS; matrix contract 15 passed; boot routes 8 passed; soak routes
  3 passed. The wrapper was stopped after it repeated the already-passed matrix
  following an edit to the running shell script; no final wrapper PASS is claimed.
- Fingerprint `--check`, Python syntax and shell syntax: PASS.

Desktop captures and logs live in
`../artifacts/campaign-pilot-2026-09-21/` relative to the project root.
They demonstrate functional desktop layouts, not physical-device acceptance.
No iPhone/Android build, installation or distribution was performed in this pass.

Retention hypothesis: attempt-based progression keeps a suggested sequence while
avoiding repeated-loss walls. Validate next-level continuation after losses,
voluntary retries, session length and return visits in beta. This policy is an
owner choice, not an experimentally established retention winner for Swarmfront.
