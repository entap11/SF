# Wax Economy Frame

Status: active code now treats Wax as one canonical ranking value. The source of truth is `RankState.wax_score`; Crucible uses that same concept only as an optional 1-Wax wager. There is no separate Crucible Wax, Hive tournament Wax, or async contest Wax pool.

## Canonical Ownership

- `RankState.wax_score` owns player Wax for rank, tier movement, and leaderboard placement.
- `RankConfig` owns the currently codified award/loss table.
- `CrucibleState` owns Crucible escrow, settlement audit, and UI balance mirrors only.
- `record_competitive_wax_result` and `CrucibleState.intent_apply_competitive_wax_result` are deprecated/suppressed. They must not mint or subtract Wax.
- Async payout approval and Hive tournament closeout must not publish Wax into the Crucible ledger.

## Current Codified Wax Table

These values are currently implemented in `scripts/state/rank_config.gd` and `data/rank/rank_config.tres`.

| Activity | Wax change |
| --- | ---: |
| New player/base floor | 100 |
| Free PvP win vs lesser opponent | +5 |
| Free PvP win vs contemporary opponent | +10 |
| Free PvP win vs better opponent | +13 |
| Free PvP win vs much better opponent | +16 |
| Free PvP loss | -4 |
| Money PvP tier 1 win | +12 |
| Money PvP tier 1 loss | -5 |
| Money PvP tier 2 win | +16 |
| Money PvP tier 2 loss | -7 |
| Money PvP tier 3 win | +20 |
| Money PvP tier 3 loss | -9 |
| Much better loser modifier | 150% of base loss |
| Much worse loser modifier | 50% of base loss |
| Small contest 1st | +3 |
| Small contest 2nd | +1 |
| Small contest 3rd | +0 |
| Daily contest 1st | +5 |
| Daily contest 2nd | +2 |
| Daily contest 3rd | +1 |
| Weekly contest 1st | +10 |
| Weekly contest 2nd | +5 |
| Weekly contest 3rd | +2 |
| Monthly contest 1st | +20 |
| Monthly contest 2nd | +10 |
| Monthly contest 3rd | +5 |
| Crucible wager win | +1 net |
| Crucible wager loss | -1 net |
| Crucible no-contest/refund | 0 |
| Hive tournament victory | TBD, currently 0 Wax |
| Major event bonus | TBD, currently 0 Wax |
| Close loss vs much better opponent | +1 |
| Very close loss vs much better opponent | +2 |

## Crucible Rule

Crucible is a pure 1v1 wager:

- Both players stake exactly 1 Wax.
- There is no burn.
- Winner receives the 2-Wax pot, for a net +1 Wax.
- Loser remains debited, for a net -1 Wax.
- Invalid source, draw, desync, or no winner refunds both players.
- Crucible has no participation rewards, Honey rewards, Nectar rewards, Hive rewards, or extra Wax rewards.

## Open Decisions

- Decide whether major events can award bonus Wax, and whether those awards are direct RankState adjustments or a separate reviewed operation in the future rank service.
- Move canonical Wax persistence to the ENTaP/rank backend once that platform service is ready.

## Close-Loss Rule

- “Much better” means the opponent has at least 20% more Wax than the player before the match.
- “Much worse” means the opponent has at least 20% less Wax than the player before the match.
- A close loss is a loss that resolves in the final minute of regulation.
- A very close loss is a loss that resolves in overtime.
- A close loss against a much better opponent awards +1 Wax instead of applying the normal loss penalty.
- A very close loss against a much better opponent awards +2 Wax instead of applying the normal loss penalty.

## Loss Strength Modifier

- If the loser had at least 20% more Wax than the winner before the match, the loser takes 150% of the base loss.
- If the loser had at least 20% less Wax than the winner before the match, the loser takes 50% of the base loss.
- These modifiers apply to normal losses only; final-minute and overtime close-loss awards against much better opponents override the normal loss.

## Win Strength Modifier

- Contemporary opponent wins use the configured base win value.
- Beating any lower-Wax opponent applies a 50% win multiplier.
- Beating a higher-Wax opponent below the 20% “much better” line applies a 130% win multiplier.
- Beating an opponent with at least 20% more Wax applies a 160% win multiplier.
