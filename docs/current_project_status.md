# Current Project Status

Date: March 10, 2026

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
- Explicit bot style/tier selection is not yet wired into a user-facing async flow.

## Important Future Note

At some point, swarm_lord should become swarmfather.

That bot is intended to become the first modeled-player bot based on real telemetry, not just a hand-authored style.
That future work should include:

- telemetry collection requirements
- clean storage and compilation
- analytics views
- ghost / modeled-player behavior fitting

## Recommended Next Steps

1. Wire explicit bot style plus tier assignment into the 1P async path.
2. Run bot-vs-bot and player-vs-bot passes to tune style separation.
3. Decide what "human-like" means operationally for the top half of bots.
4. Return to garage only after art/content for the remaining categories exists.

## Verification Note

Recent headless boots are passing parser/runtime initialization for this work.
The current known non-zero exit remains the existing rank transport fallback:

RANK_TRANSPORT_FALLBACK

