# Swarmfront Roadmap Planning

Date: May 6, 2026

## Current Read

Gameplay is at or very near MVP. The core match feel now has enough clarity and juice to stop treating gameplay as a prototype blocker.

The remaining work is mostly product hardening:
- menu cleanup
- map/mode eligibility rules
- performance and determinism soak
- beta packaging
- content/polish passes

## MVP Definition

MVP means:

Play a valid map, understand the board state, make lanes, watch deterministic unit flow, finish the match, and trust the result.

MVP does not require:
- final menus
- final economy
- final progression
- all map families
- all async formats
- final art for every surface

## Gameplay MVP Status

Likely MVP-ready:
- hive readability and lane readability
- transparent lanes with readable arrows/sides
- hive power projection and lane indicators
- unit readability with outline/glow
- max-hive pass-through flow
- lane budget constraints
- narrower lanes
- throttle tuning
- Delta and public No Man's Land map set direction
- Hidden CTF map safety rule: no NPC hives in the live match; all hives are split evenly between P1/P2 by a small seeded allotment randomizer before hidden flags are selected

Needs targeted validation:
- perceptible hive pulse on device
- pass-through smoothness under high unit counts
- honey drip boot effect after latest shape pass
- unit/lane/hive visual readability on small phones
- 5-10 minute device soak on the current public map pool

## Immediate Priority Order

### 1. Gameplay Soak And Lag Pass

Goal: prove the current gameplay loop holds up under pressure.

Status:
- Headless soak gate now measures Arena script cost, lane/unit renderer script cost, and sim tick cost separately; raw headless frame delta is retained as info only because it reflects idle-loop pacing.
- 30-second gate passes are green on the current public 545, 323, and Delta targets.
- Execution-opportunity telemetry is throttled to avoid spending every sim tick scanning lane opportunities.

Tasks:
- Run repeated matches on the public 545, 323, and Delta pools.
- Track visible unit count, frame hitches, and lane-heavy scenarios.
- Fix only the top lag sources that affect actual play.
- Keep changes surgical; avoid broad renderer rewrites unless profiling demands it.

Exit:
- no obvious frame hitches during normal MVP play
- no visible pause in max-hive pass-through
- no unreadable unit/lane/hive state on target phone viewport

### 2. Map And Mode Eligibility

Goal: stop invalid map/mode combinations before they reach play.

Rules:
- Free Roll should keep the available map catalog open, but filter by game type/topology.
- 3P games can only use maps tagged or declared as `3p`.
- 1v1, 2v2, 4P FFA, CTF, and Hidden CTF can use the shared non-3P map set; runtime ownership/start placement adapts the map for the selected game.
- Hidden CTF can use only maps with an even hive count; the runtime Hidden CTF map state should contain no NPC hives and should assign hives evenly through a seeded allotment pattern such as left/right, top/bottom, diagonal, checkerboard, or shuffle.
- 656 maps remain sandboxed unless deliberately reintroduced.

Tasks:
- Keep Free Roll randomizer mode-aware.
- Add smoke coverage for CTF/Hidden CTF candidate filtering once UI autoload test setup is clean.
- Add author-facing map metadata only when filename and structural checks are not enough.

### 3. Menu Cleanup

Goal: make the product shell feel intentional enough for beta.

Status: parked for now while map/mode rules, soak, and beta infrastructure are checked. Current read is that the main menus are working well enough to avoid more churn in this pass.

Tasks:
- Clean Free Roll game hub flow.
- Remove dead/debug menu paths from player-facing screens.
- Normalize labels for Race, Stage Race, Miss-N-Out, CTF, Hidden CTF.
- Ensure back/close behavior is consistent.
- Keep dashboard/garage/buffs/achievements scaffolded but not overbuilt.

Exit:
- user can launch the MVP modes without dev knowledge
- no duplicated or misleading mode buttons
- no stale debug wording in the main flow

### 4. Map Type Lock

Goal: keep Free Roll broad while preventing invalid map/game-type combinations.

Current direction:
- Keep all currently available maps eligible for Free Roll when their map metadata/topology supports the selected game type.
- Delta/3P maps are public for 3P games only.
- No Man's Land and other non-3P maps remain usable across 1v1, 2v2, 4P FFA, CTF, and Hidden CTF, subject to mode-specific constraints such as Hidden CTF's even hive split.
- 656 maps stay governed by the sandbox switch until deliberately reintroduced.

Tasks:
- Confirm every Free Roll mode uses map metadata/topology instead of filename suffix assumptions.
- Confirm CTF and Hidden CTF filter from the shared non-3P set.
- Add smoke coverage proving 3P modes only draw 3P maps and non-3P modes exclude 3P maps.

Exit:
- Free Roll can randomize any available map that matches the selected game type.

### 5. Beta Packaging Gate

Goal: get a build that can go to TestFlight without gameplay churn.

Tasks:
- Run current smoke suite.
- Run device viewport review.
- Confirm iOS signing/export path.
- Confirm privacy/crash reporting status.
- Decide whether beta backend mode stays hybrid local-authoritative.

Exit:
- build exports
- smoke tests pass except known rank transport fallback
- no gameplay blocker remains

## v1 After MVP

### Async Formats

Prioritize:
1. Race
2. Stage Race
3. Miss-N-Out
4. CTF
5. Hidden CTF

Tasks:
- tighten scoring and record storage
- ensure each format has a map eligibility rule
- ensure each format has clear pre-match copy

### Progression And Economy

Keep out of MVP unless needed for beta framing.

Tasks:
- rank write safety
- honey/wax clarity
- battle pass/swarm pass copy
- paid entry gates only after backend confidence

### Content And Feel

Tasks:
- final hive/unit/lanes polish
- sound pass
- vibration pass
- mode-specific celebration/loss feedback
- bot personality tuning

## Known Technical Risks

- `main_menu.gd` is too large and mixes launch flow, dashboard, async, store, and mode selection.
- Some UI smoke tests cannot preload main menu cleanly without autoload setup.
- Current broad worktree is dirty; future commits should be smaller and grouped by feature.
- Headless Godot check still exits non-zero on known `RANK_TRANSPORT_FALLBACK connect_timeout`.

## Suggested Next Work Block

1. Run a focused gameplay soak on current public maps.
2. Fix only visible hitches or deterministic movement issues.
3. Do a menu cleanup pass around Free Roll and mode launch.
4. Add map/mode eligibility smoke tests once test harness can instantiate UI with autoloads.
5. Commit in coherent chunks:
   - gameplay polish
   - map/mode rules
   - menu cleanup
   - docs/tests
