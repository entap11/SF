# Buff Targeting Sprint Handoff — Loop 4 to Loop 5

Date: 2026-07-14

Branch: `main`

Current production gate: `const MATCH_BUFF_TARGETING_ENABLED: bool = false`

## Current State

Buff targeting Ralph Loops 0–4 are implemented. Loop 5 has not started.

Checkpoint history before this handoff:

- Loop 0 — authority, stable target IDs, reservations, and canonical execution: `cacf1b3`
- Loops 1–2 — touch lifecycle and hive targeting: `a3dc7e895f49370a3ac001aac47ac752958b5e83`
- Loop 3 — lane and global targeting: `213877456b68000f0f2d3a2c9832802d8c9d851d`
- Loop 4 — touch feel, centralized tuning, canonical feedback, cache coalescing, tests, and visual harness: committed together with this handoff

The authority boundary remains unchanged:

- `OpsState` / `SimState` are the only gameplay state authorities.
- UI, input, receipt history, targeting overlays, tweens, and success flashes are presentation-only.
- Canonical commands contain stable `hive_id`, `lane_id`, or the explicit `"global"` token—never pointer or presentation coordinates.
- Inventory and Async charges commit only after canonical execution succeeds.

## Loop 4 Delivered

### Centralized presentation tuning

Authoritative presentation config:

`scripts/renderers/buff_targeting_presentation_config.gd`

Final values:

| Setting | Value |
|---|---:|
| Touch slop | 18 root-screen px |
| Touch overlay offset | `(0, -56)` root-screen px |
| Mouse overlay offset | `(0, -28)` root-screen px |
| Drag overlay size | 64 × 64 UI px |
| Eligible pulse | 1.6 Hz |
| Eligible alpha | 0.26–0.64 |
| Preview strength | 0.98 |
| Hive acquisition / retention / switch | 52 / 72 / 14 root-screen px |
| Hive eligible / preview ring width | 3.5 / 5.5 root-screen px |
| Lane acquisition / retention / switch | 44 / 64 / 12 root-screen px |
| Lane eligible / preview width | 7 / 16 local px |
| Invalid-release snap-back | 0.16 seconds |
| Canonical success flash | 0.42 seconds, strength 1.0 |

No presentation scaling was added.

### Touch feel and safety

- Target acquisition continues to use the unshifted fingertip.
- The source strip icon remains stationary.
- The drag overlay ignores input and stays offset above touch/mouse pointers.
- Invalid release begins one immediate snap-back toward the source slot.
- Snap-back completion requires the same pointer session, overlay generation, and overlay instance.
- A new capture kills the prior tween before it can affect the newer drag.
- Dirty or rebuilt-but-not-yet-rendered lane geometry cannot submit.

### Canonical execution feedback

Arena emits a production presentation event from the real canonical finalizers. Strong feedback requires:

```text
status = executed
reason = activated
```

The local presentation receipt must match exactly on:

```text
match identity
+ owner identity
+ activation_id
+ Arena presentation epoch
```

The submitted stable target is retained in the receipt and checked against the outcome before feedback. Feedback resolves the current production hive probe, lane path, or global boundary. Missing probes cleanly skip the cosmetic effect.

Receipt policy:

- Timeout: 8,000 ms using `Time.get_ticks_msec()`
- Maximum live receipts: 32
- Maximum handled outcomes: 128
- Eviction: oldest timestamp, then deterministic local sequence
- Late legitimate outcome: gameplay result stands; expired presentation receipt produces no flash

Receipt timeout and handled history never submit, release, commit, cancel, or otherwise modify gameplay transactions or reservations.

No pending treatment was added. Local canonical feedback measured 0 ms in the production-component harness and 25 ms in the controlled event test. PvP command scheduling currently shows a five-tick expected window (approximately 500 ms at 100 ms/tick), but an end-to-end gated device measurement is still required before adding persistent pending UI.

### Lane cache performance

Loop 3 upper-bound baseline:

```text
64 lanes / 640 segments
approximately 3.53 ms per deliberately forced rebuild update
```

Loop 4 results:

```text
Typical movement:                 ~90 µs/event
Crowded movement:                ~549 µs/event
250 same-frame invalidations:     ~15 µs/call, maximum one rebuild
Realistic 60-frame camera motion: 59 rebuilds, ~3.06 ms/rebuild
Node growth:                      0
Material growth:                  0
```

Transform/camera invalidations are coalesced to at most one rebuild per rendered frame. Movement continues to use the cached eligible-ID geometry.

## Validation Completed

All completed suites passed:

- Buff target resolver
- Buff activation transactions
- Inventory wiring and Async charges
- Pointer session and coordinate conversion
- Buff-strip touch ownership and lifecycle
- Hive targeting and release
- Lane/global targeting, release, and renderer probes
- Loop 4 receipt, feedback, snap-back, cache, bounds, and latency checks
- Buff command contract
- Sprite mapping and strip visibility
- Economy buff and menu layout
- VS replication, handshake, sequencing, hash, replay, and recovery checks
- Human PvP boot

The command-contract and replication tests deliberately emit invalid-contract/hash-mismatch diagnostics and still report `PASS`. Human PvP reports `PASS role=host` followed by its known resources-at-exit warning.

Primary Loop 4 test:

```sh
godot --headless --path . \
  --script res://tools/buff_targeting_loop4_smoke_test.gd
```

Production-component capture:

```sh
godot --path . --resolution 960x640 \
  --write-movie artifacts/buff_targeting_loop4/buff_targeting_loop4_production.avi \
  --fixed-fps 30 \
  --script res://tools/buff_targeting_loop4_visual_harness.gd
```

Generated evidence remains intentionally untracked under:

```text
artifacts/buff_targeting_loop2/
artifacts/buff_targeting_loop3/
artifacts/buff_targeting_loop4/
```

Do not add the generated AVI, screenshots, or existing matrix logs to a normal source checkpoint. Archive them separately if long-term review evidence is required.

## Remaining Sprint Work — Loop 5 Hardening

Loop 5 is the only unfinished Ralph loop. Do not combine it with new gameplay rules or new buff types.

### 1. Run the full device/input matrix

Validate on representative physical phones and tablets:

- Single touch and foreign concurrent touches
- Touch-to-mouse adaptation where supported
- Touch slop at different display scales
- Drag across HUD, Arena, safe margins, and viewport boundaries
- Gesture conflict with ordinary hive/lane/Arena input
- Selected ring/path visibility beneath an actual thumb
- Source icon remains fixed while the overlay moves
- Snap-back interruption by an immediate new capture

### 2. Run every lifecycle boundary

Cover both pre-submission and post-submission behavior for:

- App backgrounding
- Focus loss / OS interruption
- Lost initiating touch
- Source-slot disappearance or inventory revision change
- Arena scene replacement
- Map reconstruction
- Renderer node pooling/rebinding
- Match termination
- Reconnect and canonical replay reconciliation

Pre-submission cancellation must submit and consume nothing. Post-submission lifecycle changes must not release an accepted reservation.

### 3. Exercise canonical outcome permutations

For hive, lane, and global targets, prove:

- `executed / activated` flashes exactly once
- Submission or scheduling alone produces no success flash
- Transport rejection produces no success flash
- `deterministic_no_op`, `target_stale`, `unavailable`, duplicate, and `match_ended` produce no success flash
- Missing/freed/hidden probes skip feedback
- An expired receipt never flashes a later outcome
- Old match/owner/activation/epoch combinations never match a new Arena
- Receipt and handled histories stay at 32 and 128 maximum respectively

### 4. Complete inventory and contest permutations

Re-run the authority matrix for:

- VS ordinal 1
- Async ordinal 1 and ordinal 2
- Async ordinal 3 rejection
- Multiple inventory quantities and deterministic inventory revisions
- Async multi-map persistence
- Contest abandonment and forfeiture of unused second activation
- Duplicate release and duplicate `activation_id`
- Match termination of unresolved reservations

### 5. Measure production latency and low-end performance

- Collect actual accepted-submission-to-canonical-outcome receipt samples in local, PvP host, PvP guest, and Async modes.
- Decide whether the observed production gap warrants a restrained activation-bound pending treatment.
- If added, pending must remain weaker than selection, distinct from success, bounded by `activation_id`, and presentation-only.
- Profile the 64-lane/640-segment camera fixture on the lowest supported device.
- Confirm one rebuild maximum per rendered frame and zero node/material growth.
- Review all four team colors plus color-accessibility settings on device.

### 6. Production-gate decision

The gate remains deliberately off:

```gdscript
const MATCH_BUFF_TARGETING_ENABLED: bool = false
```

Do not enable it as part of ordinary Loop 5 test fixes. Enable it only in a separate, explicitly approved checkpoint after:

- The full Loop 5 matrix passes
- Physical-device visual review is accepted
- PvP/Async end-to-end latency is understood
- Replay/reconnect/desync baselines remain unchanged
- Product explicitly authorizes internal rollout

## Frozen Contracts for the Next Agent

Do not change without explicit product approval:

- One authoritative game state
- Shell-owned pointer session
- Resolver-owned eligibility
- Stable target identity
- `submit_buff_activation(...)` signature
- Canonical `buff_activate` payload
- Reservation and charge commitment timing
- Command IDs, sequencing, or execution ticks
- Hash, replay, reconnect, or desync behavior
- Production gate value

Stop after Loop 5 hardening and report results. Do not enable the gate or begin unrelated gameplay work automatically.
