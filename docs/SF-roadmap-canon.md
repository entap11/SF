# Swarmfront Roadmap Canon (MVP -> v1)

This document codifies the agreed Swarmfront roadmap, scope boundaries, and remaining major work items.
Assume prior specs (maps, buffs, OT, pricing, leagues) are canonical.

## Current Roadmap (2026-01-31)

Swarmfront - MVP to v1 Roadmap

PHASE 0 — Visual Foundation (MVP Critical)
- Wire all skins (.tres + PNG) and get all art rendering in-game (MVP quality, not polish).
- Orient units down lanes with correct 3/4 perspective.
- Tilt barracks to match camera POV.
- Increase hive vertical height for visual authority.
- Render lanes emitting from the top of hives to create depth ("Coruscant traffic" effect).
- Verify team color projection on hives, units, towers, barracks, and lanes.

PHASE 1 — Combat Feedback & Juice
- Code and wire tower spike logic and animations.
- Implement spike impact effects (pixelize unit + crash).
- Implement unit vaporization on impact with units, friendly towers, and enemy towers.
- Add a minimal but effective sound FX set (spawn, impact, fire, death).
- Wire sound on/off toggle.

PHASE 2 — HUD & Player Feedback
- Convert power bar from static art to fully dynamic indicator.
- Ensure power bar works in 1v1, 2v2, 3p, and 4p layouts.
- Design buff icon art.
- Use bottom buffer area for buff display.
- Show opponent buffs (available and used) and player buffs.
- Implement drag-and-drop buff usage (logic may be stubbed initially).

PHASE 3 — Identity & Settings
- Implement persistent UUID system.
- Create basic player profile structure.
- Add settings: sound toggle, vibration toggle, and other core options.

PHASE 4 — Multiplayer Expansion
- Create 3-player and 4-player maps.
- Wire 2v2 gameplay mode.
- Validate power bar behavior and team dynamics.
- Assign unit class by player slot: P1 Yellow Bees, P2 Green Yellowjackets, P3 Red Wasps, P4 Blue Hornets.

PHASE 5 — Async Games (v1 Core)
- Define async match formats.
- Implement scoring systems and record keeping.
- Build 12–15 dialed maps for async play.

PHASE 6 — Parked for v2+
- Jukebox system with royalty-free music playlists.
- Economy and monetization systems.
- Deeper progression and unlocks.

## MVP ROADMAP — Playable Core Loop

### MVP Definition (Hard Exit)
“Play any valid map, start a match, reach OT, finish with a deterministic winner.”

No additional features may block MVP exit.

### 1. Map + Arena Integrity
Goal: Any valid JSON map loads and plays with stable lanes and ownership.

Tasks:
- Ensure MapBuilder always emits:
  - kind
  - owner_id
  - grid_pos
  - lanes
- Ensure arena initializes fully before sim starts.
- Fail fast with readable error on malformed map.

Tests:
- Load >=3 different JSON maps.
- Verify all hives and lanes spawn correctly.
- Run sim >=2 minutes:
  - no errors
  - no duplicate visuals
  - no null references

### 2. Sim Stability + Match Resolution
Goal: 5-minute match ends deterministically with correct tie-break logic.

OT Clarification (Canonical):
- OT is a state transition (not just triggers).
- OT state activates once at T = 4:00.
- OT state:
  - reveals clock
  - unlocks 3rd buff slot
  - enables Tap-to-Top
  - optionally speeds up music
- OT cannot retrigger.

Tasks:
- Track SimPhase:
  - INIT
  - RUNNING
  - OT
  - RESOLVED
- Ensure tie-break stats update continuously:
  - total hive power
  - hive count
  - units landed
  - tower control duration
  - barracks control duration

Tests:
- Force timeouts with known outcomes.
- Verify winner selection order.
- Regression: elimination still ends match immediately (bypasses OT).

### 3. UI Usability (Dev Flow)
Goal: Load maps and start/reset matches without UI clipping or friction.

Tasks:
- Ensure DevMapLoader fits viewport in portrait and landscape.
- Add:
  - “Start Match” (load + run)
  - “Reset Match” (full state reset)
- Optional debug overlay:
  - OT active
  - time remaining
  - SimPhase

Tests:
- Resize window (portrait / landscape).
- UI remains usable and readable.
- Reset clears arena, stats, and BuffState cleanly.

### 4. Buff System Stub (Non-Gameplay)
Goal: Buffs exist as a state machine only (no effects yet).

Tasks:
- Implement BuffState lifecycle:
  - LOADED
  - READY
  - ACTIVE
  - EXPIRED
  - CONSUMED
- Wire buff loadout from profile/UI.
- Enforce slot rules:
  - 2 slots pre-OT
  - 3rd unlocks at OT
- Implement Tap-to-Top (inventory refill only).

Tests:
- Slot 3 locked pre-OT, unlocks at OT.
- Tap-to-Top only works in OT.
- Buff cannot activate twice without refill.

## MVP EXIT CRITERIA
- Any valid map loads.
- Match runs to OT.
- Match resolves deterministically.
- No crashes, no UI blockers.

## v1 ROADMAP — Content + Polish

### 5. Buff Effects v1
Goal: Minimal, real gameplay impact.

Tasks:
- Select 3–6 core buffs only.
- Implement effect hooks:
  - unit speed / durability
  - production interval
  - lane modifier
  - info/visibility
- Enforce:
  - max 1 Elite
  - max 1 Premium
  - durations (10/15/20)

Tests:
- Buff duration accuracy.
- Slot enforcement.
- No cross-buff leakage.

### 6. Lane Rules + Visibility
Goal: Lanes are readable and match author intent.

Tasks:
- Optional lane debug toggles:
  - legal vs blocked lanes
  - occlusion radius (MAX hive footprint)
- Validate auto-lane symmetry.

Tests:
- Symmetric maps produce symmetric lanes.
- No lane passes through hive occlusion.

### 7. Map Authoring Pipeline Hardening
Goal: iPad -> tracer -> JSON -> game with no manual fixes.

Tasks:
- Tracer export preview.
- Schema validation before export.
- Reject non-12×8 grids.
- Enforce _schema version.

Tests:
- Exported JSON loads cleanly with no warnings.

### 8. Sprites, Skins, and UX (Major Remaining Lift)
Goal: Visual clarity and player-readable state.

Tasks:
- Finalize core sprites:
  - hives (all tiers)
  - towers
  - barracks
  - units
- Ensure MAX hive footprint is always visually represented.
- Implement:
  - basic skin system (non-gameplay)
  - buff activation feedback (icon, pulse, tint)
  - OT visual/audio escalation
- Ensure UX communicates:
  - lane intent
  - buff activation
  - OT state
  - match resolution reason

Tests:
- Visual state always matches gameplay state.
- No ambiguity about why lanes are blocked or buffs active.

## Explicit Non-Goals (Do NOT implement yet)
- Full buff catalog
- Fog of war
- NPC intelligence buffs
- Geometry-breaking lanes
- Esports / Steroids League overrides
- Monetization tuning

## Design Principle (Lock This)
- Engine integrity > content
- Determinism > spectacle
- Skill > spend
- Expression > power

## Working v1 Order (2026-03-09)
- Detailed working list: `docs/v1_launch_worklist_2026-03-09.md`
- Current recommended order:
  - Gameplay safety rails
  - Next game type(s)
  - Battle pass and economy finalization
  - Contest and tournament layer
