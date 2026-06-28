# Wax Balance Simulation

Status: first-pass deterministic simulator lives in `scripts/state/wax_economy_simulator.gd` and is covered by `tools/economy_layer_smoke_test.gd`.

## Purpose

- Exercise the canonical `RankConfig` table rather than the deprecated `WaxRewardPolicy` competitive ledger path.
- Compare 90-day Wax output across casual, average, competitive, hardcore, paying competitor, async specialist, Hive champion, and abuse/farmer profiles.
- Confirm repeated-opponent and minimum-quality gates keep the abuse/farmer profile below normal average play.

## Current Assumptions

- Live PvP uses the current `RankConfig` win/loss table.
- Async and tournament placement events use the current `RankConfig` placement table.
- Win gains use 50% base against lower-Wax opponents, 100% against contemporaries, 130% against higher-Wax opponents, and 160% against opponents with at least 20% more Wax.
- Close-loss Wax uses +1 for final-minute losses and +2 for overtime losses against opponents with at least 20% more Wax.
- Normal losses use 150% base loss when the loser was at least 20% stronger and 50% base loss when the loser was at least 20% weaker.
- Hive tournament Wax and major event Wax are TBD and should be simulated as 0 until codified.
- Abuse/farmer profile should remain below average play once opponent-repeat rules are finalized.

## Launch Use

Before public tuning, run the simulator with updated profile assumptions and compare:

- total Wax over 30/60/90 days
- Wax/hour by player type
- live vs async vs tournament contribution
- whether any single source dominates
- whether farming beats normal play
