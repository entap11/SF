# Wax First-Pass Economy Frame

Status: backend first slice implemented. `WaxRewardPolicy` exists locally, `waxRewardPolicy.ts` mirrors it in the VS service, and `record_competitive_wax_result` applies competitive Wax awards/losses into the same `wax_millis` pool used by Crucible wagering. Live PvP, async money payout approval, free/tournament contest rank closeout, and Hive tournament bracket winner closeout now publish into that backend path when configured. RankState `wax_score` remains a separate rating/progression score.

## Core Philosophy

- Honey rewards participation.
- Nectar rewards participation + winning / seasonal commitment.
- Wax rewards competitive prestige.
- Wax is not spendable.
- Wax cannot be bought, gifted, traded, converted, claimed from ads, claimed from login rewards, or awarded by Battle Pass.
- Wax can only be accumulated through competitive achievement or wagered/burned in Crucible.
- Crucible itself does not award Wax for participation; it only settles wagered Wax.

## Design Principle

Every Wax source must answer:

"Does this demonstrate competitive excellence?"

If not, reward Honey or Nectar instead.

## Wax Behavior

- Wax can increase or decrease through competition.
- Wins award Wax.
- Losses to weaker opponents can subtract Wax.
- Close losses to stronger opponents may award small Wax because the player exceeded expectation.
- Normal losses to equal/stronger opponents award 0.
- No consolation trophies.
- No Wax for simply playing.

## Relative Mode Efficiency

- Live PvP is the heart of Swarmfront.
- Keep modes roughly equal, but bias slightly toward live H2H.
- Live PvP / CTF / HCTF: 100% target efficiency.
- Progressive: 100% target efficiency.
- Async: 95% target efficiency.
- Tournaments: 105-115% depending on placement/prestige.

## Standard Competitive PvP Group

Includes:

- Standard PvP
- CTF
- HCTF

## Base Wax Table For Standard Competitive PvP And Progressive

- Win vs much weaker opponent: +1 Wax
- Win vs slightly weaker opponent: +2 Wax
- Win vs equal opponent: +3 Wax
- Win vs slightly stronger opponent: +4 Wax
- Win vs much stronger opponent: +5 Wax
- Loss vs much weaker opponent: -2 Wax
- Loss vs slightly weaker opponent: -1 Wax
- Loss vs equal opponent: 0 Wax
- Close loss vs slightly stronger opponent: +1 Wax
- Close loss vs much stronger opponent: +2 Wax
- Normal loss vs stronger opponent: 0 Wax

Opponent strength should be derived from rating/MMR/rank delta using configurable bands:

- much_weaker
- slightly_weaker
- equal
- slightly_stronger
- much_stronger

## Close Loss Definition

- Must be configurable.
- Should not simply mean "lost."
- Should represent a quality loss where the player meaningfully exceeded expectation against a stronger opponent.
- If no reliable close-loss metric exists yet, defer close-loss Wax or use a conservative placeholder until the metric is trustworthy.

## Async

- Async should award Wax based on overall competitive outcome, not every individual map, unless the current async format truly treats each map as a full competitive match.
- Target Async Wax efficiency around 95% of live PvP.
- Head-to-head Async can use the same opponent-strength table, then apply async multiplier/tuning.
- Multi-player Async / W-M-S contests should award by final placement bands.

Async multi-player / W-M-S first-pass placement table:

- Champion: +5 Wax
- Runner-up: +3 Wax
- Top 25%: +1 Wax
- Middle: 0 Wax
- Bottom quartile / underperformed: -1 Wax

Important:

- Make W/M/S awards field-size aware.
- Avoid hard-coding only 6-player or 15-player assumptions.
- Use percentile/placement-band logic so rewards still make sense when participation varies.

## Tournament Wax

Use percentile bands, not raw placement only.

Weekly tournament first pass:

- Champion: +25 Wax
- Runner-up: +15 Wax
- Top 1-5%: +10 Wax
- Top 10%: +6 Wax
- Top 25%: +3 Wax

Monthly tournament first pass:

- Champion: +100 Wax
- Runner-up: +60 Wax
- Top 1-5%: +40 Wax
- Top 10%: +25 Wax
- Top 25%: +10 Wax

Seasonal championship first pass:

- Champion: +500 Wax
- Runner-up: +300 Wax
- Top 1% / Top 10 depending field size: +150 Wax
- Top 100 / meaningful elite band: +75 Wax

Tournament implementation note:

- If bracket size is small, collapse invalid percentile bands safely.
- Do not double-award overlapping bands.
- Award the highest qualifying band only.
- Tournament Wax should be config-driven by tournament type.
- Hive tournament bracket winners currently credit the winning Hive's queen/creator representative through the player-owned Wax ledger, with Hive/team metadata attached for audit. This is a first slice until team distribution rules are finalized.

## Never Award Wax For

- Match participation alone
- Logging in
- Daily login rewards
- Battle Pass purchase
- Battle Pass rewards
- Ads
- Honey purchases
- Store purchases
- Cosmetics
- Tutorial
- Practice
- Custom/private matches
- Hive membership alone
- Crucible participation alone

## Anti-Harvest Rules

No Wax or held Wax for:

- Tutorial/practice/custom/private match
- AFK
- Match below minimum quality threshold
- Immediate surrender
- Duplicate result event
- No contest
- Refunded match
- Invalid/desynced result
- Suspicious win trading
- Same account cluster/device/IP abuse
- Repeated same opponent abuse

Repeated opponent logic:

- Repeated same opponent in a rolling window should diminish Wax and eventually award 0.
- Do not punish legitimate tournament rematches unless tournament structure requires them.
- Make the rolling window configurable.

Collusion handling:

- First pass can log/hold rather than fully adjudicate.
- Emit telemetry for suspicious Wax awards.
- Include match_id, player IDs, mode, opponent strength band, award amount, and block/hold reason.

## Implementation Requirements

1. Centralize Wax config:
   - opponent strength MMR/rating delta bands
   - base reward table
   - async multiplier / placement bands
   - tournament award bands
   - anti-harvest thresholds
   - repeated-opponent rules
   - close-loss definition
   - enabled modes
2. Add WaxRewardPolicy helper:
   - classify mode group
   - verify eligible mode
   - classify opponent strength
   - determine win/loss/close-loss result
   - apply base Wax table
   - apply async/tournament tuning where appropriate
   - apply anti-harvest gates
   - return structured reward result
3. Add Wax ledger fields distinct from any existing rank wax score:
   - competitive_wax_balance or crucible_wax_balance, depending final naming
   - lifetime_wax_won
   - lifetime_wax_lost
   - lifetime_wax_burned
   - lifetime_wax_net
   - largest_wax_award
   - largest_wax_loss
   - source metadata for audit
4. Do not mix this with RankState.wax_score if that is a float/rating-like score:
   - If current code has rank Wax as float/decay score, keep it separate.
   - Wagerable/accumulated Wax should be deterministic integer or fixed-point ledger value.
5. Add idempotency:
   - Wax rewards/losses apply once per match_id/player_id/reward_type.
   - Duplicate events must not double-award or double-subtract.
6. Add audit/reward breakdown object:
   - match_id
   - player_id
   - opponent_id
   - mode_group
   - result
   - opponent_strength_band
   - close_loss_qualified
   - base_wax_delta
   - mode_multiplier
   - final_wax_delta
   - validity_status
   - anti_harvest_reason_if_blocked
   - config_version
7. Tests:
   - PvP win vs weaker/equal/stronger opponent.
   - PvP loss vs weaker opponent subtracts Wax.
   - PvP loss vs equal gives 0.
   - Normal loss vs stronger gives 0.
   - Close loss vs stronger gives +1/+2.
   - Standard PvP, CTF, HCTF map to Standard Competitive PvP group.
   - Progressive uses same table.
   - Async uses expected 95% tuning / placement outcome.
   - W/M/S placement awards adapt to different field sizes.
   - Tournament percentile awards highest qualifying band only.
   - Tutorial/practice/custom gives 0.
   - Crucible participation gives 0 outside wager settlement.
   - Duplicate result ignored.
   - Repeated opponent diminishing works.
   - Invalid/desync/no-contest/refund gives 0.
8. Telemetry:
   - wax_award_attempt
   - wax_awarded
   - wax_subtracted
   - wax_blocked_antiharvest
   - wax_held_suspicious
   - wax_duplicate_ignored
   - wax_close_loss_awarded
   - wax_repeated_opponent_diminished
   - wax_tournament_awarded
   - wax_async_awarded

## Implementation Status And Open Questions

1. Wagerable/earned Wax is stored as integer `wax_millis` in the Crucible ledger.
2. `RankState.wax_score` remains rating-like progression data and is not the spendable/wagerable Wax balance.
3. Opponent strength currently uses player/opponent rating fields supplied by match authority.
4. Close-loss Wax is supported by policy, but production should only pass `close_loss_qualified` after the sim exposes a trusted metric.
5. CTF/HCTF/Progressive/Async/Tournament mode mapping is policy-supported, but each result publisher still needs to pass clean mode/placement metadata.
6. Async money payout approval publishes Wax for approved payout rows and, when backend result-ledger rows are available, ranked leaderboard rows. Free/tournament contest rank closeout returns the competitive Wax publish result for audit/debug visibility.
7. Production persistence should eventually move this ledger from the local/dev file adapter to the canonical ENTaP player economy ledger.

## Recommended First Slice

- Done: centralized Wax config, local/backend WaxRewardPolicy calculators, Standard Competitive PvP / Progressive win-loss table, opponent strength banding, idempotency, Crucible no-participation-award guard, repeated-opponent diminishing, and backend smoke coverage for core win/loss outcomes.
- Remaining: wire additional bracket/Hive tournament completion paths, add clean close-loss metrics, and move production persistence/identity to the canonical ENTaP economy service.
