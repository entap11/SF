# Tutorial Spec: Section 1 (Point Of Game + Basic Controls)

## Scope
This spec covers only Section 1 of the tutorial flow.

Section 1 teaches:
1. How to select a starting hive.
2. How to issue an attack lane.
3. How hives flip, feed, and unlock more lanes by power tier.
4. How opposing unit streams cancel into a standoff.
5. How to activate a buff from the bottom buff strip.
6. How to launch a finishing swarm.

Out of scope for Section 1:
- Tower/Barracks strategy.
- Buff economy flow.

## Player Outcome
By the end of Section 1, a new player can:
1. Select their hive and recognize the selected state.
2. Send units from one hive to another.
3. Understand that captured hives become new attack/feed sources.
4. Understand that higher-power hives support more lanes and create units faster.
5. Activate a buff by dragging it from the bottom buff strip.
6. Use a swarm as a deliberate finishing move.

## Runtime Model
Section 1 is a guided match scenario, not a menu overlay only.

Constraints:
- UI only shows guidance and emits requests/intents.
- OpsState/SimState remains authoritative for all gameplay changes.
- No runtime anchor/size/position mutation.

## Tutorial Steps (Section 1)

### Step 0: Objective Card (Non-blocking intro)
Copy intent:
- "Selecting your hive is pretty simple. Tap it. It should glow or have a selector ring around it."

Advance condition:
- Player selects a local hive.

### Step 1: Send First Attack Lane (Required action)
Instruction:
- "With your hive selected, tap the NPC hive right below."

UX:
- Show a pointer/ring on the NPC hive.
- Dim the rest of the arena around the target when possible.

Advance condition (authoritative):
- A valid lane intent becomes active from player-owned source to non-allied target.

Detection:
- Observe `OpsState.lane_intent_changed`.
- Resolve lane from `lane_id` against current `GameState`.
- Complete when source owner is local player and `state.intent_is_on(src_id, dst_id)` is true with hostile target.

### Step 2: Explain Capture And Lane Tiers
Instruction:
- "Once you flip this hive, it can attack enemies or feed friendly hives."

Advance condition (authoritative):
- Local player ownership increases from the Section 1 baseline.

Detection:
- Track baseline local-owned hive count at section start.
- Recompute from current `GameState.hives` ownership.
- Complete when `owned_now >= owned_baseline + 1`.

### Step 3: Enemy Standoff
Instruction:
- "Attack as you see fit. When the opponent counterattacks, oncoming units cancel each other out."

Advance condition (authoritative):
- Player has active pressure against an enemy hive, or owns a hive adjacent to an enemy hive.

Detection:
- Observe active local attack lanes and adjacent owned/enemy hives.
- Continue when the final enemy hive is low enough for a finishing swarm.

### Step 4.5: Activate A Buff
Instruction:
- "Tap and drag the glowing buff from the bottom of the screen."
- "If the buff affects one hive or lane, drop it on that target. Otherwise, anywhere on the screen is fine."

UX:
- Pulse the ready buff slot in the bottom buff strip.
- Dim the rest of the screen around the highlighted buff slot when possible.

Advance condition (authoritative):
- Local player has at least one buff slot active or consumed in the runtime buff UI snapshot.

Detection:
- Read `get_buff_ui_snapshot()`.
- Resolve the local player's slots.
- Complete when any local slot is active or consumed.

### Step 5: Launch Finishing Swarm (Required action)
Instruction:
- "Double-tap the enemy side of your active attack lane to launch a swarm."

Advance condition (authoritative):
- A local swarm request or packet targets the final low-power enemy hive.
- Section completion remains gated until the match ends after this swarm launch.

Detection:
- Observe `GameState.swarm_requests` and `GameState.swarm_packets`.
- Confirm source hive is local, target hive is non-allied, and the target is the current low-power enemy hive.
- Store a runtime `swarm_finish_launched` flag so match end cannot complete Section 1 before the required swarm.

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
1. Player cannot complete Section 1 without performing the required tutorial beats, including buff use and swarm use.
2. Completion checks use authoritative state only (no visual-only heuristics).
3. Section 1 median completion time target: under 2 minutes for first-time users.
4. Section handoff emits a single completion event for Section 2 unlock.
