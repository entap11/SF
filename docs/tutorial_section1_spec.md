# Tutorial Spec: Section 1 (Point Of Game + Basic Controls)

## Scope
This spec covers only Section 1 of the tutorial flow.

Section 1 teaches:
1. What wins a match (capture/control).
2. How to issue an attack lane.
3. How to stop/retract a lane.

Out of scope for Section 1:
- Swarm execution details.
- Tower/Barracks strategy.
- Buff economy flow.

## Player Outcome
By the end of Section 1, a new player can:
1. Send units from one hive to another.
2. Stop that stream intentionally.
3. Understand that taking control of hives is the core win path.

## Runtime Model
Section 1 is a guided match scenario, not a menu overlay only.

Constraints:
- UI only shows guidance and emits requests/intents.
- OpsState/SimState remains authoritative for all gameplay changes.
- No runtime anchor/size/position mutation.

## Tutorial Steps (Section 1)

### Step 0: Objective Card (Non-blocking intro)
Copy intent:
- "Capture hives to control the map."
- "You send units by selecting your hive, then a target."

Advance condition:
- Player presses `Continue`.

### Step 1: Send First Attack Lane (Required action)
Instruction:
- "Tap your hive, then tap an enemy/neutral hive to attack."

Advance condition (authoritative):
- A valid lane intent becomes active from player-owned source to non-allied target.

Detection:
- Observe `OpsState.lane_intent_changed`.
- Resolve lane from `lane_id` against current `GameState`.
- Complete when source owner is local player and `state.intent_is_on(src_id, dst_id)` is true with hostile target.

### Step 2: Retract Lane (Required action)
Instruction:
- "Double-tap the source side of that lane to stop sending."

Advance condition (authoritative):
- Previously active tutorial lane intent is no longer active.

Detection:
- Poll/verify `state.intent_is_on(step1_src_id, step1_dst_id)` transitions from `true -> false`.
- `lane_system.lane_updated` can be used as a wakeup signal, but truth source is current state intent.

### Step 3: Capture One Hive (Required action)
Instruction:
- "Send units again and capture 1 hive."

Advance condition (authoritative):
- Local player ownership increases by at least 1 from Section 1 baseline.

Detection:
- Track baseline local-owned hive count at section start.
- Recompute from current `GameState.hives` ownership.
- Complete when `owned_now >= owned_baseline + 1`.

## Scenario Setup (Section 1)
Use a constrained tutorial setup so completion is fast and deterministic:

1. Local player seat fixed (seat 1).
2. Opponent pressure reduced (or delayed) for first minute.
3. Nearby valid target exists at start (no blocked lane ambiguity).

Implementation note:
- Preferred: dedicated tutorial map/config for Section 1.
- Acceptable temporary path: existing small map with scripted roster/bot settings.

## UX Rules
1. One guidance panel at a time.
2. Each step has short copy (1 sentence instruction + 1 sentence "why").
3. If a step is not completed after timeout, show a contextual hint (no hard reset).
4. Skip button allowed; skipped state is tracked separately from completed state.

## Persistence
Persist Section 1 status in profile/tutorial progress:
- `not_started`
- `in_progress`
- `completed`
- `skipped`

Also persist per-step completion for resume safety in case of app close.

## Telemetry (Minimum)
Track:
1. Time to complete each step.
2. Retries/fail attempts for Step 1 and Step 2.
3. Exit reason (`completed`, `skipped`, `abandoned`).

## Acceptance Criteria
1. Player cannot complete Section 1 without performing the 3 required mechanics.
2. Completion checks use authoritative state only (no visual-only heuristics).
3. Section 1 median completion time target: under 2 minutes for first-time users.
4. Section handoff emits a single completion event for Section 2 unlock.
