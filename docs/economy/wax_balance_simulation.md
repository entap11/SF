# Wax Balance Simulation

Status: first-pass deterministic simulator lives in `scripts/state/wax_economy_simulator.gd` and is covered by `tools/economy_layer_smoke_test.gd`.

## Purpose

- Exercise the actual `WaxRewardPolicy` rather than a separate spreadsheet-only table.
- Compare 90-day Wax output across casual, average, competitive, hardcore, paying competitor, async specialist, Hive champion, and abuse/farmer profiles.
- Confirm repeated-opponent and minimum-quality gates keep the abuse/farmer profile below normal average play.

## Current Assumptions

- Live PvP uses the standard opponent-strength table.
- Async placement events use field-size placement bands.
- Weekly tournament events use tournament placement bands.
- Hive champion profile receives one weekly Hive bracket representative award per month.
- Abuse/farmer profile uses repeated-opponent count and failed minimum-quality metadata, so expected Wax/hour should remain below average play.

## Launch Use

Before public tuning, run the simulator with updated profile assumptions and compare:

- total Wax over 30/60/90 days
- Wax/hour by player type
- live vs async vs tournament contribution
- whether any single source dominates
- whether farming beats normal play

