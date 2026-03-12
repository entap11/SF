# Work Codex Handoff (2026-03-11)

## Pull Target

- Authoritative branch: `main`
- Latest committed work at handoff: `4501e72` `improve bot telemetry and style separation`

## What Shipped Tonight

- Bot style separation work was pushed to `main`.
- Execution telemetry was added so post-match analysis can measure:
  - reaction timing
  - idle high-power hives
  - unused available lanes
  - action cadence
  - intent mix
- Current bot telemetry files:
  - `user://bot_intent_telemetry_v1.jsonl`
  - `user://bot_intent_summary_v1.json`

## Important Product Read

- Gameplay is solid enough to keep building on.
- Do not over-tune bots while signaling and UX clarity are still weak.
- Do not tune bots specifically to one player's personal style.
- Input method matters. Mouse versus touch is still muddying the line between:
  - player execution failure
  - weak signaling
  - actual bot strength

## Turtle Bot Direction

Current turtle is too PvP-forward for the intended identity.

Desired direction:

- Turtle should feed slightly more than it expands early.
- Rough target for early opportunities: `feed 6 / NPC attack 5`.
- Turtle should attack NPC hives almost exclusively until neutrals are gone.
- Turtle should rarely initiate the first PvP attack.
- Do not rush this retune tonight-style. Make the change after UX/VFX clarity improves enough to judge it honestly.

## Next Work Items

### 1. Increase Swarm Penalty

- Add a bigger gameplay penalty for swarming.
- This should make swarm a more deliberate commitment instead of a near-free pressure tool.

### 2. Add Unused-Lane UX Signal and Sound

- Add a subtle gameplay-facing signal when a lane is available and remains unused for about `3-4s`.
- Candidate direction:
  - top light / power hologram flicker
  - subtle matching sound cue
- This is intended for real gameplay UX, not just debug tooling.

### 3. Make Bases Bigger

- Increase base size enough to reduce available attack lanes.
- Goal: cut down lane clutter and narrow the decision graph.

### 4. Replace Lane Visuals

- Current lane sprite/look is not acceptable.
- Lane visuals need a stronger full replacement, not micro-tweaks.

### 5. Prioritize UX / VFX Before Heavy Tuning

- Do not tune too aggressively before the player can clearly read:
  - lane opportunity
  - threat
  - available action windows
- Better gameplay read is required before judging how hard the player should have to work to win.

## Post-Match Scoring Direction

Start categorizing player performance after each game and assign a score.

Suggested categories:

- reaction time
- best available attack chosen versus missed
- time unused lanes sat available
- high-power idle time
- action cadence
- swarm usage quality
- budget/no-lane failed intents

Goal:

- score each game
- compare score against win/loss result
- find the threshold where scores above a certain band usually win and scores below it usually lose

This should become a structured player-performance readout, not just raw telemetry logs.

## Validation Baseline at Handoff

- `godot --headless -s tools/bot_style_separation_smoke_test.gd` passes
- `scripts/dev/run_mvp_smoke.sh` passes
- Known pre-existing warning still exists:
  - `scripts/ui/power_bar.gd:509`
  - nil `match_phase` access during smoke boot path

