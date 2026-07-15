# Buff Targeting Loop 5 Evidence and Rollout Recommendation

Date: 2026-07-15

Baseline commit: `26127d43dbb599023e82318d42bbc49d957be72b`

Production gate: `const MATCH_BUFF_TARGETING_ENABLED: bool = false`

Status: **Automated hardening complete; first physical pass blocked; remediated device evidence pending.**

Rollout recommendation: **HOLD. Do not enable the production gate.**

## Scope and Authority Result

Loop 5 introduced no gameplay rules, buff types, targeting behavior, command fields, reservation semantics, or state-authority changes.

Release builds receive bounded, epoch-scoped, presentation-only latency distribution reporting in `BuffCanonicalFeedbackController`, larger presentation artwork and buff-strip dimensions, and iOS-compatible shader helper signatures. The targeting acquisition, retention, switch, touch-slop, and raw-fingertip rules remain unchanged. The latency sample window is capped at 256 entries and uses the nearest-rank rule.

The device-evidence session is an Arena-owned debug-build facility. It fails closed in release exports, supplies a fixed match-scoped loadout only when the explicit device-harness argument is present, and never reads or writes persisted inventory. Its charges still pass through the existing resolver, reservation, canonical command, effect, and outcome path; it does not mutate render- or input-owned state.

The automated cross-layer matrix proves:

- Presentation receipt clear, expiry, replay handling, and Arena epoch replacement do not release, commit, cancel, or resolve an accepted gameplay reservation.
- Pre-submission lifecycle cancellation submits and consumes nothing.
- Post-submission presentation teardown leaves accepted canonical work under authoritative transaction control.
- Only `executed / activated` can start success feedback.
- Match ID, owner ID, activation ID, Arena presentation epoch, target type, and stable target ID must match.
- Submission, scheduling, transport rejection, deterministic no-op, unavailable, stale target, match end, wrong target, expired receipt, replay, and missing render probes produce no success flash.
- VS ordinal 2 and Async ordinal 3 reject without allocation.
- Duplicate releases and duplicate canonical outcomes remain idempotent.
- Match termination releases only unresolved reservations in that match.
- Receipt, handled-outcome, transaction-terminal, and latency histories remain bounded.

## Automated Matrix Result

All executed suites produced their expected PASS marker:

- `buff_target_resolver_smoke_test.gd`
- `buff_activation_transaction_smoke_test.gd`
- `buff_inventory_wiring_smoke_test.gd`
- `buff_strip_async_charges_smoke_test.gd`
- `buff_pointer_session_smoke_test.gd`
- `buff_pointer_coordinate_smoke_test.gd`
- `player_buff_strip_touch_source_smoke_test.gd`
- `buff_touch_lifecycle_smoke_test.gd`
- `buff_hive_targeting_smoke_test.gd`
- `buff_hive_release_smoke_test.gd`
- `buff_lane_global_targeting_smoke_test.gd`
- `buff_lane_global_release_smoke_test.gd`
- `buff_lane_renderer_probe_smoke_test.gd`
- `buff_targeting_loop4_smoke_test.gd`
- `buff_targeting_loop5_hardening_smoke_test.gd`
- `vs_buff_command_contract_smoke_test.gd`
- `buff_sprite_mapping_smoke_test.gd`
- `buff_strip_visibility_policy_smoke_test.gd`
- `economy_buff_smoke_test.gd`
- `main_menu_buffs_layout_smoke_test.gd`
- `app_lifecycle_smoke_test.gd`
- `arena_lifecycle_pause_source_smoke_test.gd`
- `shell_async_continuation_prematch_smoke_test.gd`
- `vs_swarm_replication_smoke_test.gd`
- `human_pvp_boot_smoke_test.gd`, host role
- `human_pvp_boot_smoke_test.gd`, guest role

The command-contract and replication suites intentionally emitted their invalid-contract and artificial hash-mismatch diagnostics, then passed. Host and guest PvP boot both passed and retained the known ObjectDB/resources-at-exit warnings.

Two orphaned headless Godot smoke-test processes from 2026-07-14 were found during validation and stopped before the isolated PvP runs. No application server or deployed game process was affected.

## Lifecycle and Presentation Coverage

The Loop 5 hardening harness covers:

- Incomplete and invalid presentation receipt identity.
- Duplicate receipt registration without timestamp or target replacement.
- Match, owner, activation, epoch, target-type, and target-ID mismatch.
- Exact timeout boundary and expired late outcome behavior.
- Canonical replay and exactly-once feedback.
- Arena epoch replacement and presentation clear.
- Hidden or missing hive and lane probes.
- Hive render-node rebinding to a new render instance.
- Camera-transform movement while the finger is stationary.
- Invalid root-screen-to-Arena conversion.
- Old pointer-session cleanup against a newer session.
- Dirty lane geometry blocking release until the rebuilt geometry has rendered.
- Global-target invalidation and lifecycle teardown.
- Presentation processing stopping when no live effect or receipt remains.

Existing Loop 1–4 suites continue to cover foreign touches, touch slop, touch/mouse forwarding, raw fingertip conversion, source revision changes, source disappearance, duplicate release, overlay generation, snap-back interruption, and stable-ID-only submission.

## Controlled Latency Evidence

Clock definition:

- Start: successful local presentation-receipt registration following accepted submission.
- End: receipt consumption through the canonical production event bridge.
- Clock: monotonic `Time.get_ticks_msec()`.
- Percentiles: nearest rank over the bounded current-Arena sample window.

Controlled event-bridge result:

| Samples | Minimum | p50 | p95 | p99 | Maximum |
|---:|---:|---:|---:|---:|---:|
| 6 | 10 ms | 30 ms | 60 ms | 60 ms | 60 ms |

This is deterministic harness evidence for measurement correctness, not production network evidence. The 256-entry latency window bound also passed.

Production accepted-submission-to-canonical-outcome distributions remain unmeasured for:

- Local device play.
- PvP host on a physical device.
- PvP guest on a physical device.
- Async on a physical device.

No pending-state treatment was added. A pending proposal remains prohibited until real production-role measurements show a usability need.

## Performance Evidence

Measurement environment:

- macOS 15.7.7, x86_64.
- Godot 4.2 stable.
- Same 64-lane / 640-segment headless fixture and camera path as Loop 4.
- Three isolated candidate runs.
- Repository gates: 10% regression warning, 20% regression failure.

| Run | Forced invalidation avg | Realistic frame avg | Rebuilds | Rebuild avg | Max rebuilds/frame | Node growth | Material growth |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 16.036 µs | 6.707 ms | 59 | 3.073 ms | 1 | 0 | 0 |
| 2 | 17.436 µs | 6.704 ms | 59 | 3.297 ms | 1 | 0 | 0 |
| 3 | 16.696 µs | 6.698 ms | 59 | 3.023 ms | 1 | 0 | 0 |
| Median | 16.696 µs | 6.704 ms | 59 | 3.073 ms | 1 | 0 | 0 |

The production-relevant realistic rebuild result remains effectively level with the Loop 4 handoff baseline of approximately 3.06 ms/rebuild. The forced same-frame invalidation microbenchmark is approximately 11% above the rounded 15 µs Loop 4 baseline, which is a warning-tier variance but below the 20% failure gate; the absolute change is approximately 1.7 µs/call. Coalescing still limits work to one rebuild per rendered frame, and no node or material growth occurred.

Additional current measurements:

- Pointer session: 3.428 µs/event over 100,000 events.
- Hive typical: 95.806 µs/event; node and material growth zero.
- Hive crowded: 487.773 µs/event; node and material growth zero.
- Lane typical: 94.090 µs/event; node and material growth zero.
- Lane crowded: 571.021 µs/event; node and material growth zero.
- Stationary-camera lane invalidations: 1.376 µs/update; node and material growth zero.

## Physical-Device Matrix

Device discovery found:

- One connected physical iPhone running iOS 26.5.
- No connected physical iPad.
- No connected Android device.
- iPhone and iPad simulators are installed, but simulators are not accepted as physical touch, thumb-occlusion, interruption, or low-end performance evidence.

A signed, commit-isolated debug build was installed with explicit user authorization and run on the connected iPhone. The first corrected harness process was attributed to `b0b6880eb1c6ca1841e148fca06f97a9d7bb5345`, kept the production gate false, and emitted periodic evidence JSON. It produced a blocking result rather than a pass:

- No usable persisted buff loadout was available, so pointer, receipt, outcome, and latency counts remained zero.
- The physical match presentation and diagnostics were too small to read comfortably.
- Three decorative text shaders failed compilation on iOS.
- The inactive CTF frame distribution reached p50 `31.67 ms`, p95 `43.07 ms`, p99 `51.63 ms`, and maximum `143.01 ms` over approximately 135 seconds.
- Three inactive targeting presentation nodes remained stable with zero measured node/material growth, but no active targeting path was exercised.

The remediation adds a release-inert, Arena-owned evidence loadout, explicit READY/BLOCKED assertions, phone-scale targeting controls, iOS-safe shader helpers, and additional CPU/render counters. It must be rebuilt and physically rerun before any item below can pass:

- Small-phone, large-phone, tablet, and lowest-supported-device coverage.
- Physical single-touch, foreign multi-touch, and touch-to-mouse adaptation where supported.
- Safe-area, HUD, SubViewport, aspect-ratio, and supported-orientation boundaries.
- OS interruption, focus loss, background/foreground, and lost initiating touch.
- Source icon stability, thumb occlusion, acquisition, retention, switching, cancellation, invalid release, and snap-back interruption.
- All four team colors and accessibility scale, contrast, and motion settings.
- Physical-device camera performance and production-role latency.

## Remaining Completion Gates

Loop 5 must remain incomplete until all of the following are recorded and accepted:

1. User-assisted execution on representative physical phones and a physical tablet, including the lowest-supported device.
2. Real local, PvP host, PvP guest, and Async latency distributions with device, OS, connection, build, role, sample count, minimum, p50, p95, p99, maximum, and expired-receipt count.
3. Physical visual review using production components and current artwork.
4. Low-end physical-device verification of one rebuild maximum per rendered frame and zero sustained node/material growth.
5. Resolution or explicit acceptance of the forced-invalidation warning-tier variance.

## Rollout Recommendation

Automated behavior, authority isolation, replay safety, lifecycle cleanup, and desktop reference performance are suitable for continued internal validation. Physical-device usability and production latency evidence are not complete, so Loop 5 cannot be marked complete and the production gate must remain off.

Do not enable `MATCH_BUFF_TARGETING_ENABLED`, add pending UI, or begin a rollout checkpoint based on this report.
