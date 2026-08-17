# Wax Economy Frame

Status: **superseded as an authority, reset, and Crucible settlement contract**
by [Economy ADR 001](../architecture/economy/adr-001-platform-economy-authority.md).
This file remains an inventory of the first-pass reward table still present in
code; it must not be used to authorize beta economy mutations.

The current code attempts to treat Wax as one ranking value, but it still has
overlapping Rank, client fallback, and VS Crucible writers. The actual overlap
and target disposition are recorded in the
[writer matrix](../architecture/economy/current-target-writer-matrix.md).

## Historical First-Pass Ownership

- `RankState.wax_score` is a client cache/fallback in the current code; it is not
  the target production authority.
- Rank PostgreSQL is the current standard-Wax backend. Platform Economy is the
  target canonical writer for Wax balance/custody, while Rank position and tier
  are derived projections.
- `RankConfig` owns the currently codified award/loss table.
- `CrucibleState` is intended as an escrow/UI mirror, but its current local
  fallback is itself a balance/escrow/settlement writer and must be suppressed.
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
| Crucible wager win | +0.8 net (`+800 wax_millis`) |
| Crucible wager loss | -1 net |
| Crucible no-contest/refund | 0 |
| Hive tournament victory | TBD, currently 0 Wax |
| Major event bonus | TBD, currently 0 Wax |
| Close loss vs much better opponent | +1 |
| Very close loss vs much better opponent | +2 |

## Crucible Rule

The authoritative target contract is `CRUCIBLE_WAX_V1`:

- Both players reserve exactly `1000 wax_millis` (1 Wax).
- Winner receives exactly `1800 wax_millis`.
- Exactly `200 wax_millis` credits the literal `reserve:award` Platform ledger
  account. This is custody, not a burn, and has no authorized debit path.
- Loser remains debited, for a net -1 Wax.
- Invalid source, draw, desync, or no winner refunds both players.
- Crucible has no participation rewards, Honey rewards, Nectar rewards, Hive rewards, or extra Wax rewards.

## Open Decisions

- Decide whether major events can award bonus Wax. Any approved award must be a
  trusted, audited Platform event rather than a direct `RankState` adjustment.
- Resolve the zero-start product rule: current client and Rank configurations
  enforce a floor/base of 100, while the beta target opens at zero.
- Move the existing VS-owned Crucible accounts, escrow, and award reserve to the
  Platform Economy authority without losing their double-entry audit history.

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
