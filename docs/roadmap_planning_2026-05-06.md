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
- Hidden CTF map safety rule: multiple owned starting hives required

Needs targeted validation:
- perceptible hive pulse on device
- pass-through smoothness under high unit counts
- honey drip boot effect after latest shape pass
- unit/lane/hive visual readability on small phones
- 5-10 minute soak on the current public map pool

## Immediate Priority Order

### 1. Gameplay Soak And Lag Pass

Goal: prove the current gameplay loop holds up under pressure.

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
- CTF can use any valid `1p`, `2p`, or `4p` map.
- Hidden CTF can use only maps where each participating owner has multiple owned starting hives.
- 3p maps are FFA-specific unless explicitly tagged otherwise later.
- 656 maps remain sandboxed unless deliberately reintroduced.

Tasks:
- Keep Free Roll randomizer mode-aware.
- Add smoke coverage for CTF/Hidden CTF candidate filtering once UI autoload test setup is clean.
- Add author-facing map metadata only when filename and structural checks are not enough.

### 3. Menu Cleanup

Goal: make the product shell feel intentional enough for beta.

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

### 4. Map Pool Lock

Goal: lock a small, playable public pool instead of shipping every experiment.

Current direction:
- Keep Delta maps public.
- Keep selected No Man's Land 545 and 323 maps public.
- Sandbox 656 maps.

Tasks:
- Mark the first MVP public map pool explicitly.
- Confirm CTF and Hidden CTF pools from that same set.
- Remove or hide maps that create overwhelming starts.

Exit:
- Free Roll only randomizes maps we actually want players to see.

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
