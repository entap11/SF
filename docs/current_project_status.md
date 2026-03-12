# Current Project Status

Date: March 12, 2026

## Executive Summary

The project is in a good transition state.

The dash/garage pillar is scaffolded enough to pause.
The next active pillar is bot depth for 1P async.

## What Changed Recently

### Dash / Garage

- The dash drawer now uses top tabs:
  - Garage
  - Buffs
  - Achievements
- The old right-side dash hex stack is suppressed in the main dash flow.
- The garage is now the primary dash hero.
- The garage hero supports grab-and-rotate on the preview.
- The garage loadout shelf now has PvP and Time Puzzles context tabs.
- Power Bars are live through the existing theme system.
- Other garage categories are scaffolded and profile-backed, but not fully live due to missing assets/content.

### Dash Content Direction

- Buffs now have a dedicated dash hero surface.
- Achievements now have a dedicated dash hero surface.
- Achievements is intentionally broader than badges and is the likely future home for:
  - async records
  - awards
  - ribbons
  - recognition layers

### Bot Depth

- Bot support now has first-class style plus tier profile merging.
- Styles currently supported:
  - balancer
  - turtle
  - raider
  - greedy
  - swarm_lord
- Tiers currently supported:
  - easy
  - medium
  - hard
- The baseline bot policy now reads more style-specific scoring weights, so the bots differ in actual decision-making rather than only speed/aggression timing.
- Bot logging now includes style and tier in intent telemetry logs.
- Async `VsLobby` now has debug CPU style and tier selectors for 1P testing.

### Async / Stage Race Stability

- `MAP_TEST` was removed from the normal playable map path.
- `Stage Race` contest map resolution was fixed to stop falling back from stale `tp_map_*` ids into unintended boards.
- Camera fit was corrected so full-board map bounds are used unless node-bounds fit is explicitly enabled.
- The `PowerBar` alpha/visibility path was corrected so it can actually appear once the match goes live.
- Match flow start is now deferred by a couple of frames so async prematch is less likely to burn during shell boot.
- Async prematch now has a dedicated mode card path instead of relying entirely on the default 1v1 countdown presentation.
- The async prematch card now covers:
  - `Stage Race`
  - `Timed Race`
  - `Miss N Out`
  - direct Jukebox single-map runs
- Async prematch keeps the `PowerBar` visible during those modes so the run starts with better gameplay context.
- Jukebox easy-bot prematch labeling no longer falls back to misleading generic bot text.

## Current Product Read

### Solid

- Dash shell direction is coherent.
- Garage belongs inside dash.
- Top-tab structure is the right long-term move.
- 1P bot work is the correct next focus and is the backbone for async.

### Not Done

- Garage categories beyond Power Bars still need assets/content before they can be fully validated.
- Buffs dash surface is still a summary/scaffold rather than the final full editor.
- Achievements/records schema is not fully defined yet.
- Bot personality separation still needs tuning; early playtest read is that `balancer` and `raider` currently feel too similar.
- Async prematch presentation exists now, but the next pass should be UI/UX polish rather than more plumbing:
  - layout
  - spacing
  - copy hierarchy
  - overall readability / feel
- Player-facing bot customization UI/UX is still intentionally unresolved beyond the current debug selectors.

## Important Future Note

At some point, swarm_lord should become swarmfather.

That bot is intended to become the first modeled-player bot based on real telemetry, not just a hand-authored style.
That future work should include:

- telemetry collection requirements
- clean storage and compilation
- analytics views
- ghost / modeled-player behavior fitting

## Recommended Next Steps

1. Spend the next work block on async prematch UI/UX polish, not new system plumbing.
2. Tune bot separation, starting with `balancer` vs `raider`.
3. Start capturing structured playtest perception notes so bot feel can be tuned against human-readable reports, not just telemetry.
4. Return to garage only after art/content for the remaining categories exists.

## Verification Note

Validated on March 12, 2026:

- `godot --headless --path . -s tools/map_record_stage_race_runtime_smoke_test.gd` passes.
- `scripts/dev/run_mvp_smoke.sh` passes with `18` passes and `0` fails.
- `godot --headless --path . --quit` still returns the known non-zero headless exit tied to the existing rank transport fallback.

Known existing non-zero exit:

RANK_TRANSPORT_FALLBACK
