# Balancer concentration experiment — September 22, 2026

Status: complete; candidate rejected and the three development files restored
exactly. The retained controller remains the
[attention-capacity checkpoint](bot_attention_capacity_2026-09-22.md); the
[earlier-supply experiment](bot_supply_choice_2026-09-22.md) remains rejected.

The experiment changes choices, but does not establish the predicted stable
matchup trade-off. Screening is flat; fresh confirmation gains two net wins,
with benefits concentrated on Two Hubs and costs elsewhere. Neither declared
retention route passes. Earlier improvements remain in place.

The owner asked whether opponent-specific gains and losses would reveal useful
style trade-offs, then authorized a bounded concentration test. The prediction
is that concentrating a second attacker could punish Greedy's spread-out
positions, while leaving Balancer more exposed to Raider elsewhere. This is a
testable hypothesis, not an established matchup relationship. The policy reads
public observations and never reads the opposing personality.

## Observation audit

The audit reuses 118 recorded attack-decision witnesses from eight previously
verified control matches: both seats against Greedy on CS2, Turtle on CS3 and
Corridors, and Raider on Pinched Spine, seed 1941614430. These selected witnesses
cover attack choices, not every decision in those matches.

The saved observations and memory are replayed through the retained policy.
JSON's floating-point representation of integers must first be restored to the
declared observation/memory types; route distances are restored to the engine's
float32 representation. All 118 control choices then match their recorded
orders exactly. The audit checks that policy evaluation does not mutate the
observation. Prototype choices use separate memory copies and are never applied
to the game. The prototype matches the candidate implementation apart from
explanatory comments.

Three choices change with the proposed preference:

- CS2/Greedy, seat two at 58.4 seconds: 8→10 joins one existing friendly stream
  instead of 5→9 opening a different enemy front.
- CS3/Turtle, seat one at 116.6 seconds: the same target, hive 6, receives an
  attack from hive 8 rather than hive 5; the joining-source margin changes the
  preference.
- Corridors/Turtle, seat one at 40.9 seconds: 11→10 joins one friendly stream
  instead of 11→9 expanding to a neutral.

These are plausible missed concentration opportunities. They do not establish
that the alternatives would execute successfully or win the match.

## Candidate and behavior checks

The medium Balancer profile enables `human_concentrate_pressure`. An enemy
target with friendly pressure already receives a 20-point ranking bonus. The
candidate adds another 20 points only when exactly one friendly stream is
already attacking, the joining source has no observed threat, and its power is
within eight points of the target's power plus visible incoming enemy forces.
The option defaults off. This is a bounded preference for the second attacker;
it does not add further bonuses for a third or later attacker.

Existing feasibility filters, remembered-target restrictions, attention limits,
defensive interruptions, withdrawals, supply policy, opening and reaction
timing remain fixed. A watched target with two attackers remains excluded from
new commitments. The policy still produces one ordinary delayed command.
Production, speed, combat and capture are unchanged. This remains the opt-in
medium Balancer pilot in two-seat conquest; the other four personalities use
the baseline policy.

The focused scenario compares an accessible neutral with a comparable enemy
already under attack. It checks the preference shift, preserved observation and
existing watched commitment, visible reinforcement margin, defensive priority,
cooldowns, authoritative command execution and the existing watched-target
limit. A real separate enemy hive supplies the synthetic incoming-force witness.

## Declared evaluation

Screening uses 80 candidate matches paired with saved attention-capacity
controls on the familiar five maps and seeds 1941614430 and 1545051845.
Confirmation runs both arms anew on seven maps with four fresh seeds:
453006544, 1185698927, 1116930232 and 774025457. These seeds are excluded from
the original 20-seed panel and the previous experiment's two fresh seeds.

The seven maps are CS2, CS3, Closequarters SBASE, Corridors SBASE, Pinched Spine,
Knife Fight SBASE and No Man's Land Two Hubs. These are existing eligible maps;
no map changes are made. Both seats and all four opponents appear in each
map/seed job. Confirmation contains 224 paired comparisons and 448 new games;
with screening, the pass contains 304 pairs and 528 new evaluation games.

The same frozen candidate runs both panels without retuning. Score gives half
credit to a draw. The declared style gate requires Greedy gains in both panels,
gains on at least three of four fresh seeds and both fresh seats, and no overall
fresh score decline. Opponent losses may be acceptable trade-offs but are not
evidence of success by themselves. An alternative broad improvement may be
retained if total score improves in both panels without broad new weakness;
the specific Greedy/Raider prediction must still be reported separately. Either
route also requires all tests and behavior review to pass. These are engineering
retention criteria, not a statistical significance test or a 50/50 balance target.

Every pair checks the initial board, expected effective profiles, complete
outcome, pinned Godot 4.7.1 engine, canonical 100ms clock, isolated user data,
notice/motor bounds, source fingerprints and result checksums. The candidate
checkout is `SF/project-bot-concentration-20260922`; evidence is under
`SF/artifacts/bot-concentration-2026-09-22/`. No fresh full-roster result or human
playtest is claimed.

## Screening

The candidate passes all seven regression suites and 112 runtime checks. The
two repeated canonical matches have identical outcomes and decision traces;
snapshot continuation, horizon handling and accelerated-clock rejection pass.

Both arms finish the 80-match screen with **20 wins / 59 losses / 1 draw**, a
25.625% score. One loss becomes a win against Swarm Lord on CS2; one win becomes
a loss against Raider on Corridors. Both changes occur in seat one on seed
1545051845. Each seed and seat aggregate is unchanged. Opponent score changes
are Swarm Lord +5 points, Raider -5 points, Greedy zero and Turtle zero.

This is a small observed trade-off, but it does not confirm the predicted
Greedy benefit. Both declared retention routes fail their screening condition.
The unchanged candidate still completes fresh confirmation as declared, so the
Swarm Lord/Raider pattern can be checked for recurrence rather than inferred
from two outcome flips.

Successful commands decrease from 2,720 to 2,698, or 11.03 to 10.89 per minute.
Rejections fall from 45 to 42, while the maximum rejection run remains four.
Quick feed reversals and quiet final-minute timeouts remain zero. Withdrawals
rise from 251 to 255; time-ended matches rise from ten to eleven. The opening
expansion gap remains 1.8 seconds.

The full matches containing the three audited decisions reproduce the predicted
first order changes at 58.6, 116.9 and 41.2 seconds respectively. Their outcomes
remain unchanged. In the Corridors case, hive 10 changes to friendly ownership
during the normal delay, so the prepared attack executes as a feed. The audit
therefore establishes changed choices, not three successful concentrated attacks
or improved outcomes.

A descriptive comparison of scheduled and applied orders finds changed sequences
in 24 of the 80 screening matches. Twenty-two keep the same win/loss/draw result.
Against Greedy, nine of twenty sequences change and all twenty outcomes remain
unchanged. This confirms that the preference affects real choices, while the
screening outcomes show no Greedy benefit. The comparison excludes score-only
changes and includes order timing, source, target, intent and goal; it is not a
new retention criterion or proof that each changed order was successful.

## Fresh confirmation and repeatability

All 224 fresh pairs complete. Control finishes **58 wins / 160 losses / 6 draws**;
candidate finishes **60 wins / 158 losses / 6 draws**. Score rises from 27.232%
to 28.125%, or **0.893 percentage points**. Eight losses become wins and six wins
become losses. The combined 304-pair record is 78/219/7 versus 80/217/7, a
0.658-point score gain; this pooled result does not replace the separate gates.

| Balancer opponent | Screening score change, 20 games | Fresh score change, 56 games |
| --- | ---: | ---: |
| Greedy | 0.000 pp | +5.357 pp |
| Raider | -5.000 pp | 0.000 pp |
| Swarm Lord | +5.000 pp | 0.000 pp |
| Turtle | 0.000 pp | -1.786 pp |

The screening Swarm Lord gain does not recur: every fresh Swarm Lord outcome
is unchanged. Raider gains one net win on each of the first three fresh seeds,
then loses three on the fourth. The fresh net is zero in both seats. Greedy's
fresh net gain is three wins, but only two of four seeds improve; the other two
are flat. Seat one gains three net wins and seat two is flat. Thus the declared
style gate fails screening, seed coverage and seat coverage. The broad gate
fails because screening did not improve. The original Greedy-up/Raider-down
prediction is not confirmed across the two panels.

The fresh changes are strongly localized. Two Hubs gains five net wins out of
32 matches (+15.625 points), Corridors loses two (-6.250 points), CS3 loses one
(-3.125 points), and the other four maps have unchanged scores. The five familiar
maps together lose three net wins out of 160 matches; the two additional maps
gain five out of 64. On Two Hubs specifically, all four seat-one Greedy losses
become wins. That is a useful scenario lead, not evidence of a general matchup
advantage or permission to tune to a map ID.

## Trace and behavior review

Across all 304 pairs, 106 scheduled and applied order sequences change; 90 of
those retain their win/loss/draw result. The first differing applied order is
an attack in 91 matches and a feed in 15. Existing delayed-command handling can
turn a prepared enemy attack into a feed when ownership changes. These counts
describe what executed, not 106 successful concentrated attacks.

The fresh traces give specific examples of both opportunities and costs:

- Two Hubs, Greedy, seat one: on seeds 453006544 and 1185698927, the first
  difference is 12→13 pressure instead of 12→3 supply at 24.0 and 24.6 seconds.
  Hive 1 is already attacking 13. On the other two seeds, 3→13 pressure takes
  priority over 3→4 neutral expansion at 23.8 and 23.3 seconds. All four matches
  flip to wins, but the full subsequent trajectories also differ.
- Corridors, seed 774025457: against Raider, 14→7 pressure displaces 14→12
  expansion at 37.4 seconds; the original 13→7 stream withdraws at 42.7 seconds
  and the added stream withdraws at 45.9. Against Greedy, 11→10 pressure
  displaces 11→9 expansion at 40.9 seconds; the original 13→10 stream withdraws
  at 42.7 and the added stream at 49.4. Both matches flip to losses. This
  suggests investigating whether the original attack is worth sustaining.
- Two Hubs, Raider, seat one on the fourth seed: 3→13 pressure displaces 3→4
  expansion at 23.3 seconds; that expansion is delayed until 40.9 seconds.
  This match flips to a loss, unlike the three earlier seeds on this map.

These are verified first divergences and later outcomes. They do not isolate
the first order as the sole explanation of a win or loss. A follow-up should
compare the observed progress of existing attacks, likely capture before help
arrives, and the cost of the displaced expansion or supply task. Those are
board-based questions; no opponent label or map-specific exception is proposed.
This pass makes no further policy change.

Fresh successful orders per minute remain similar, 10.55→10.57. Rejections fall
78→71 and the maximum rejection run falls four→three. Quick feed reversals
remain zero. Time-ended matches fall 52→50, while time-ended matches without an
ownership change in the last minute rise 13→14. The additional case is the CS3
Raider loss on seed 774025457: it still applies ten orders in the last minute,
including one at 299.9 seconds. It is stalled territorial progress, not an idle
controller. Early idle productive hives rise slightly, 6.53%→6.79%, and early
lane use falls 70.14%→69.81%. Behavior checks give no reason to override the
failed retention criteria.

## Final checkpoint and evidence

The candidate passes seven regression suites, 112 runtime checks, deterministic
canonical repeats, snapshot continuation and clock/horizon checks. Those checks
establish correctness of the candidate, not improved balance or human likeness.
After the screening gate failed, the three development files were restored from
their exact saved copies while the frozen candidate completed confirmation.
The retained runtime suite is again the previous 100-check version. Reaction
times, production, movement and combat/capture rules remain unchanged.

The experiment contains 528 new evaluation games and 304 paired comparisons;
80 screening controls are reused. No full-roster rebalance, other human-policy
personality, or human playtest is claimed. The final source fingerprint matches
the retained checkpoint and unrelated working changes are preserved.

Evidence is in `SF/artifacts/bot-concentration-2026-09-22/`: `experiment.json`,
the screening/confirmation/all comparisons, `gate_assessment.json`,
`retention.json`, `restore_receipt.json`, `all_choice_impact.json`,
`confirmation_trace_review.json`, `quiet_ending_changes.json`, and regression
logs. `implementation.patch` preserves this rejected change for review;
`final_checks.json` certifies source, coverage, checksums, tests and restoration.
