# Buff Targeting Ralph-Loop Handoff

Date: 2026-07-14

Branch: `main`
Status: Loop 0 implemented; Loops 1–5 not started

## Product Intent

Buff targeting is touch-first and entirely visual. Do not add tutorials, tooltips, explanatory callouts, confirmation copy, or instructional text during a match.

Targeting behavior:

- Global buffs may be released anywhere in the eligible playfield and use the explicit target ID `"global"`.
- Hive-specific buffs must be released on an eligible stable `hive_id`.
- Lane-specific buffs must be released on an eligible stable `lane_id`.
- While dragging inside the Arena, all eligible targets should pulse white.
- The currently previewed target should receive a stronger exterior treatment that remains legible beneath a finger.
- A strong team-color success flash happens only after canonical execution succeeds—not on finger release or transport submission.
- Rejections and deterministic no-ops silently clear presentation state without displaying text.

Inventory/use behavior:

- Battle Pass levels may grant zero, one, or any quantity of a buff.
- Inventory is one shared fungible quantity ledger; do not introduce item UUIDs or a second Battle Pass ledger.
- VS: one inventory item provides one activation.
- Async: one inventory item provides two activations inside the same contest.
- Async use one consumes the inventory item after successful canonical execution.
- Async use two consumes the contest allowance only.
- If use one occurs and use two is not used before leaving the contest, use two is forfeited.
- If the buff is never fired, the inventory item remains owned.
- The Async allowance persists across maps in the same contest and does not reset per map.

## Ralph-Loop Rule

Complete, test, and review one loop before beginning the next. Do not combine later-loop visual work with an unfinished authority or lifecycle loop.

The production gate is:

```gdscript
const MATCH_BUFF_TARGETING_ENABLED: bool = false
```

It is intentionally disabled. Do not enable it until Loop 1 touch ownership, cancellation, coordinate conversion, and transaction-boundary tests pass.

## Completed: Loop 0 — Authority and Transaction

### Stable-ID target resolver

Authoritative implementation: `scripts/state/buff_target_resolver.gd`

Public contract:

```gdscript
get_preview_eligible_targets(game_state, owner_id, buff_id) -> Dictionary
validate_canonical_target(game_state, owner_id, buff_id, target_type, target_id) -> Dictionary
canonical_target_payload(target_type, target_id) -> Dictionary
```

Rules currently implemented:

- Hive targets are existing hives owned by the activator.
- Lane targets are existing active lanes with valid stable endpoints. Lanes are not modeled as friendly/enemy-owned.
- Global buffs use `target_type = "global"` and `target_id = "global"`.
- Preview and canonical execution call the same resolver rules.
- Resolver scans are request-scoped. It retains no target sets and performs no per-frame work.
- `BuffActivationSystem` delegates to this resolver; its competing hive/lane eligibility helpers were removed.

### Reservation transaction

Authoritative implementation: `scripts/state/buff_activation_transaction.gd`

`available` is represented by the absence of an active transaction. Stored states are:

```text
reserved
  → submitted
  → canonically_scheduled
  → executed
  → committed
```

Failure paths:

```text
reserved → submission_rejected → released
submitted → canonical_rejection → released
canonically_scheduled → deterministic_no_op → released
any unresolved state → match_terminated → released
```

Important invariants:

- Idempotency scope is `match_id + owner_id + activation_id`.
- The same activation ID returns its existing transaction/result before slot revalidation.
- `reservation_id` is local-only and never enters a canonical command.
- Capacity is fungible quantity minus active reservations; committed quantities are already reflected by ProfileManager.
- One equipped slot exposes at most one pending reservation at a time.
- VS permits source ordinal 1 only.
- Async permits ordinals 1 and 2 only; ordinal 3 is rejected.
- No inventory or contest use is committed before canonical execution succeeds.
- Terminal history is bounded at 256 entries. Transaction work is event-driven, not per-frame.

### UI/authority boundary

The UI-facing Arena submission accepts only:

```gdscript
submit_buff_activation(
    pid,
    slot_index,
    target_type,
    target_id,
    activation_id = ""
)
```

Arena verifies `pid` against the authoritative active owner and derives these fields from the equipped slot and runtime state:

- owner ID
- inventory buff ID
- canonical buff ID
- tier
- source kind
- source ordinal
- current inventory revision
- charge key

The command builder consumes the validated reservation. UI-provided buff identity, tier, or source values have no command path.

### Canonical PvP command

`VsPvpRuntime` supports:

```gdscript
{
    "kind": "buff_activate",
    "activation_id": "...",
    "owner_id": 1,
    "buff_id": "buff_unit_speed_classic",
    "tier": "classic",
    "target_type": "hive | lane | global",
    "target_id": 12, # or "global"
    "source_kind": "inventory | vs | async",
    "source_use_ordinal": 1
}
```

The existing authority assigns command ID, command sequence, and execution tick. Buff commands retain the existing queue ordering, late-command diagnostics, accepted-command log, duplicate identity, and desync-recovery behavior.

Contract validation rejects any canonical buff command containing:

- `world_pos`
- `local_pos`
- `grid_pos`
- `screen_pos`
- `touch_id`

### Canonical outcome

Arena records outcomes keyed by match, owner, and activation ID:

```gdscript
{
    "activation_id": "...",
    "status": "executed | rejected | deterministic_no_op",
    "reason": "activated | target_stale | unavailable | duplicate | match_ended | ...",
    "canonical_command_id": "...",
    "execution_tick": 123
}
```

At execution:

1. Target eligibility is revalidated against authoritative match state.
2. All peers call the same canonical buff intent; execution does not depend on the origin client's slot presentation state.
3. On success, the origin records the slot use and commits the reserved inventory/Async use.
4. On rejection or deterministic no-op, no effect is produced and the origin releases the reservation.
5. Duplicate canonical delivery returns the stored outcome without applying or committing again.

### Recovery

Pending transactions and canonical outcomes are stored in SceneTree meta `buff_activation_runtime_state`, not primarily in ProfileManager.

- Submitted transactions survive Arena scene replacement.
- PvP's accepted command log supplies canonical replay/desync recovery.
- Replayed commands use activation and command identities for deduplication.
- Restored executed/rejected transaction outcomes reconcile to commit/release behavior.
- Match termination releases all unresolved transactions.
- Async contest charge state remains in `async_buff_contest_state` across maps and is cleared when the contest runtime is cleared.

## Existing Buff/Inventory Work Included with Loop 0

- Battle Pass buff rewards grant their authored quantity through ProfileManager.
- Legacy Battle Pass `inventory.buffs` ownership migrates idempotently into the shared quantity ledger.
- Profile inventory exposes a deterministic revision hash.
- VS and Async loadouts are separate selections over the same owned quantities.
- Duplicate loadout slots are disallowed even when multiple copies are owned.
- Buff shop/cart supports quantity purchases and displays buff sprites.
- Nectar remains progression XP and cannot be spent as buff currency.
- Async slot UI supports `2/2`, the one-use-spent red slash state, and removal after use two.
- Crucible buff disablement remains intact.

## Loop 1 — Touch Lifecycle

Goal: make the existing `PlayerBuffStrip` a reliable production touch source without enabling visual target effects yet.

Implementation requirements:

1. Capture the initiating touch ID immediately on finger-down.
2. Apply touch slop before entering drag state.
3. Emit continuous movement for the initiating touch only.
4. Suppress conflicting Arena actions from the captured touch.
5. Convert coordinates through the full chain:

```text
root screen
→ WorldViewportContainer-local
→ SubViewport coordinates
→ world coordinates
→ Arena/map-local coordinates
```

6. Add a presentation-only drag sprite above the fingertip. It must never enter OpsState, GameState, commands, hashes, or replay state.
7. Before submission, cancel cleanly on:
   - app backgrounding
   - OS interruption/focus loss
   - lost initiating touch
   - scene exit
   - source slot loss
   - source becoming unavailable
   - match termination
8. After canonical submission:
   - remove the drag sprite
   - stop tracking the touch
   - keep the reservation pending
   - do not release merely because the app backgrounds or the scene changes
9. Wire release into `preview_buff_targets(...)` and `submit_buff_activation(...)`; never reactivate the old direct-consumption path.
10. Add tests for touch ownership, slop, foreign-touch rejection, gesture conflict, cancellation before submission, persistence after submission, and viewport conversion.

Loop 1 exit gate:

- Lifecycle and transaction-boundary tests pass.
- Existing Arena input regression tests pass.
- `MATCH_BUFF_TARGETING_ENABLED` may then be enabled for internal review.

## Loop 2 — Hive Targeting

Goal: visual eligible-hive guidance and stable hive acquisition.

Implementation requirements:

1. Ask `BuffTargetResolver` for eligible stable hive IDs when drag enters the Arena.
2. Render a white pulse only on those IDs.
3. Give the currently acquired hive a stronger exterior halo/scale treatment visible outside the fingertip.
4. Add acquisition and retention hysteresis so selection does not chatter near boundaries.
5. Keep target geometry and pulse state presentation-only.
6. Never mutate authoritative hive transforms or collision shapes.
7. Revalidate the stable ID at release and canonical execution.
8. Clear every effect on cancellation, submission, rejection, no-op, match end, and scene exit.

Tests:

- owned/eligible hive set
- enemy/stale hive rejection
- acquisition versus retention radius
- no selection chatter
- no authoritative transform/collision mutation
- visual cleanup on every exit path
- successful flash only on executed outcome

## Loop 3 — Lane and Global Targeting

Goal: add lane-specific acquisition and global anywhere-in-playfield release.

Lane requirements:

1. Resolver supplies buff-specific eligible stable lane IDs.
2. Measure touch distance against rendered lane geometry, not an inferred ownership/direction rule.
3. Use a dedicated targeting overlay; do not mutate lane renderer gameplay effects.
4. Add acquisition and retention radii suitable for intersections.
5. Carry only the selected stable `lane_id` into release validation and the command.

Global requirements:

1. Resolver returns explicit `"global"`.
2. Any eligible playfield point selects global.
3. Hit testing excludes HUD, safe margins, buff strip, and targeting overlays.
4. No release coordinate enters the command or deterministic state.

Tests:

- active versus inactive/stale lane eligibility
- intersection stability
- lane hysteresis
- global playfield acceptance
- HUD/safe-margin exclusion
- command stable-ID/coordinate prohibition
- cleanup and canonical confirmation timing

## Loop 4 — Feel

Tune on representative phones/tablets and record final values for:

- touch slop
- drag-sprite offset above fingertip
- eligible-target pulse frequency and brightness
- preview-target brightness and scale
- hive acquisition radius
- hive retention radius
- lane acquisition radius
- lane retention radius
- snap-back duration
- submitted/pending target treatment
- canonical-execution confirmation duration

Requirements:

- No text explanations.
- Broad white eligibility pulse clears on submission.
- Optional pending treatment is subtle and presentation-only.
- Strong team-color flash is outcome-driven.
- Verify color readability for every team and common accessibility settings.

## Loop 5 — Hardening

Run and document the complete matrix:

- touch ownership and foreign touches
- gesture conflict with hive/lane/Arena actions
- background, focus, interruption, scene-exit, and match-end cancellation
- pre-submission versus post-submission cancellation boundary
- hive, lane, and global release validation
- target staleness at execution
- duplicate releases and duplicate activation IDs
- transport rejection
- inventory quantities and inventory revisions
- VS ordinal 1
- Async ordinals 1 and 2; ordinal 3 rejection
- Async multi-map persistence and contest abandonment
- canonical PvP host/guest agreement
- duplicate, late, and replayed buff commands
- reconnect/desync recovery
- viewport conversion across supported aspect ratios
- complete visual cleanup
- target-query and rendering performance
- existing gameplay/input/PvP/economy regressions

Do not ship with the gate enabled until this matrix is green on both mouse-development and real touch-device paths.

## Current Validation Baseline

Passing commands:

```bash
godot --headless --path . --script tools/buff_target_resolver_smoke_test.gd
godot --headless --path . --script tools/buff_activation_transaction_smoke_test.gd
godot --headless --path . --script tools/vs_buff_command_contract_smoke_test.gd
godot --headless --path . --script tools/buff_inventory_wiring_smoke_test.gd
godot --headless --path . --script tools/buff_strip_async_charges_smoke_test.gd
godot --headless --path . --script tools/buff_sprite_mapping_smoke_test.gd
godot --headless --path . --script tools/buff_strip_visibility_policy_smoke_test.gd
godot --headless --path . --script tools/economy_buff_smoke_test.gd
godot --headless --path . --script tools/main_menu_buffs_layout_smoke_test.gd
godot --headless --path . --script tools/vs_swarm_replication_smoke_test.gd
godot --headless --path . --script tools/human_pvp_boot_smoke_test.gd
git diff --check
```

Expected diagnostic noise:

- Contract tests intentionally log violations for forbidden touch data and Async ordinal 3.
- PvP replication tests intentionally exercise contract and desync violations.
- Dummy-renderer menu tests log existing `TEXTURE` shader compilation warnings.
- Human PvP boot logs existing ObjectDB/resource-at-exit warnings.
- Headless editor/project scans may exit 1 with `Scan thread aborted` and NUL parsing warnings despite script and boot tests passing.

## Primary Files for the Next Sprint

- `scripts/ui/player_buff_strip.gd` — touch capture and continuous movement source
- `scripts/shell.gd` — production gate, HUD/container coordinate boundary, UI wiring
- `scripts/arena_helpers/input_bridge_utils.gd` — correct viewport conversion
- `scripts/arena.gd` — preview/submission API and presentation orchestration
- `scripts/state/buff_target_resolver.gd` — sole deterministic target eligibility source
- `scripts/state/buff_activation_transaction.gd` — reservation lifecycle
- `scripts/state/vs_pvp_runtime.gd` — canonical command scheduling/replay
- `scripts/state/buff_state.gd` — canonical buff effect execution

## Non-Negotiable Guardrails

- No per-item inventory UUIDs.
- No second buff inventory ledger.
- No Nectar spending for buffs.
- No tutorial or tooltip copy.
- No coordinates, touch state, camera state, or presentation state in canonical commands or deterministic simulation.
- No final success flash before canonical execution.
- No independent UI target-eligibility rules.
- No lane ownership shortcut.
- No consumption on finger release or submission success.
- No enabling the production gate before Loop 1 passes.
