# Balancer attention capacity — September 22, 2026

Status: complete; the additional watched commitment is retained.

The owner authorized continued bot work and left reaction-time adjustments to
engineering judgment. This pass starts from the retained
[attention checkpoint](bot_attention_balance_2026-09-22.md); the rejected
[support](bot_pressure_support_2026-09-22.md) and
[progress](bot_pressure_progress_2026-09-22.md) candidates remain removed.

## Timing and decision audit

In the retained 240-game Balancer panel, the median interval between observations
is 1.6 seconds. The median scheduled observation-to-execution delay is 700ms.
There are 27,421 observations and 7,436 scheduled orders, about 27 orders per 100
observations. Some observations or orders remain pending when a match ends.
Only 109 of 7,435 attempted orders are rejected (1.47%). These figures point to
selection and waiting as useful targets for investigation; they do not establish
that a different reaction delay could never help.

Eight diagnostic replays cover both seats on four selected map/opponent cases.
A wrapper executes the original policy normally. When it waits, the wrapper also
asks the policy for a counterfactual choice using a separate copy of its memory
with current and watched commitments cleared. It keeps the same delayed
observation, profile, cooldowns and avoided targets. The counterfactual is never
applied to gameplay. All eight complete results, state/runtime hashes and action
traces match their controls exactly after removing the diagnostic-only payload.

Across those cases, 178 of 490 waiting decisions occur with a full watch list
after the ordinary review interval has elapsed. In 159 of those 178 decisions,
the counterfactual produces an order from the same observation. These are
observed candidate opportunities, not proof that an alternative is better or
would remain legal when executed. The diagnostic cases are selected examples,
not an estimate for every map or opponent.

## Candidate and focused scenario

The medium Balancer profile sets `human_watch_limit` to three. This permits three
watched commitments alongside the current plan, instead of two plus the current
plan. The policy defaults to two when the option is absent and clamps configured
values to one through three. It still reviews only one watched commitment per
decision; adding a slot can therefore make each individual watched route wait
longer between reviews. Existing plans are retained when attention moves.

The focused scenario fills the former three total slots with active enemy
commitments. A different owned hive has spare capacity and a legal neutral
expansion. The old limit blocks that order even after the current review interval
has passed. The candidate keeps the earlier plans watched and opens the expansion
through the ordinary authoritative command path. Follow-up assertions check that
a fifth commitment remains blocked, excessive profile values cannot remove the
bound, planning does not mutate the observation or authoritative routes, and an
exposed source can still trigger withdrawal.

No reaction-time adjustment is included. Observation, motor and thinking delays,
opening delay, cooldowns, progress/stall rules, production, movement, combat and
capture stay fixed. The other personalities and default pilot enablement stay
fixed. This remains the opt-in medium Balancer pilot for two-seat conquest; the
policy tag remains `human_balancer_v3`, with the profile option and source hashes
identifying this revision.

## Evaluation design

Before candidate results, `experiment.json` declares an 80-match screen on the
first two seeds of the retained panel and reserves its other four seeds for 160
confirmation matches. All five maps, four opponents and both seats are included.
Confirmation runs only if screening improves. Both stages use identical frozen
candidate source and exact saved attention controls. Each paired game checks
engine, canonical clock, initial board, profiles and notice/motor bounds.

Retention requires the scenario and full regression checks to pass, improvements
in both stages, and review of map/opponent losses and behavior changes. These
known maps and previously used seeds check this candidate without retuning it
between stages; they do not establish performance on unseen maps or human
likeness.

## Evidence

`SF/artifacts/bot-attention-audit-2026-09-22/` retains the wrapper, exact-replay
checks and copied observation witnesses. Its checkout is
`SF/project-bot-attention-audit-20260922`.

`SF/artifacts/bot-attention-capacity-2026-09-22/` retains the declared experiment,
timing audit, source checks, before-file backups, tests and paired match results.
Its frozen candidate checkout is `SF/project-bot-attention-capacity-20260922`.

## Screening review

The old policy fails the new scenario for the expected additional-expansion and
watch-list assertions. The frozen candidate passes all 100 runtime assertions
and seven regression suites, including identical repeated canonical match traces,
snapshot restoration, horizon handling and accelerated-clock rejection.

Across 80 paired screening matches, Balancer improves from 17 wins / 62 losses /
1 draw to 20 / 59 / 1. Score, including half credit for draws, rises from 21.9% to
25.6%. Five outcomes improve and two worsen. No map or opponent aggregate
declines in this screen. Gains occur against Turtle, Greedy and Swarm Lord;
Raider's aggregate is unchanged. The candidate proceeds unchanged to confirmation.

Orders per minute rise from 10.36 to 11.03; scheduled orders per observation rise
from 29.3% to 31.1%. Rejections stay at 45, falling from 1.76% to 1.63% of attempts
because there are more successful orders. The maximum rejection run remains four;
matches with a run of at least three fall from two to one. There are no quick
feed reversals. Withdrawals increase from 225 to 251 alongside an increase from
960 to 1,053 attacks. Quiet final-minute timeouts fall from one to zero.

The two worsened matches are Centerstrike CS3 against Turtle and Pinched Spine
against Raider, both with Balancer in seat two. Each first diverges at an earlier
neutral expansion. The CS3 candidate opens 8→4 at 29.7 seconds and does not make
the control's later 8→6 development feed. The Pinched candidate opens 7→10 at
28.8 seconds and later support differs. Those traces show a capacity-allocation
tradeoff, but do not isolate a single order as the cause of either loss.

The previously reviewed CS2/Greedy loss now includes the formerly blocked 4→8
attack at 78.8 seconds; it still loses at 141.8 seconds versus the control's
140.3 seconds. The scenario correction does not resolve every strategic weakness.

## Confirmation and retention

The unchanged candidate completes all 160 reserved matches. Balancer improves
from 26 wins / 126 losses / 8 draws to 39 / 113 / 8: score rises from 18.75% to
26.875%. Fifteen outcomes improve and two worsen. Every map and opponent
aggregate improves in confirmation.

Across all 240 paired matches, Balancer improves from **43 wins / 188 losses /
9 draws to 59 / 172 / 9**, raising score from **19.8% to 26.5%**. Twenty outcomes
improve and four worsen. Every map, opponent and seed aggregate improves. Both
seats improve: seat one from 16.25% to 26.25%, and seat two from 23.33% to 26.67%.

| Balancer opponent | Control score | Candidate score |
| --- | ---: | ---: |
| Turtle | 13.3% | 16.7% |
| Raider | 31.7% | 38.3% |
| Greedy | 14.2% | 20.8% |
| Swarm Lord | 20.0% | 30.0% |

| Map | Control score | Candidate score |
| --- | ---: | ---: |
| Centerstrike CS2 | 10.4% | 14.6% |
| Centerstrike CS3 | 27.1% | 37.5% |
| Closequarters | 36.5% | 40.6% |
| Corridors | 20.8% | 31.3% |
| Pinched Spine | 4.2% | 8.3% |

There are 8,121 successful orders versus 7,326 before. Orders per minute rise
from 9.66 to 10.30, and scheduled orders per observation rise from 27.1% to 28.9%.
Rejected orders remain at 109, reducing their fraction from 1.47% to 1.32%.
Capacity rejections rise from 22 to 24; ownership rejections fall from 85 to 83.
The maximum rejection run remains four, with two matches containing a run of at
least three in each arm. There are no quick feed reversals. Withdrawals rise
from 629 to 685 alongside an increase from 2,802 to 3,120 attacks.

Median first order and opening expansion gap stay at 3.9 and 1.8 seconds. Median
match duration rises from 167.15 to 170.5 seconds; the 90th percentile rises from
300 to 360 seconds. Time-ended matches rise from 37 to 40. Each arm has one quiet
final-minute timeout. The candidate's case is a Balancer time-limit win against
Greedy on CS3, seed 1561495190, with the last ownership change at 224.2 seconds
of a 300-second match. The quiet-timeout metric is a review cue, not proof of
unnecessary inactivity. First-minute lane use rises from 70.7% to 71.1%; idle
productive-hive samples remain about 5.9%.

The two confirmation regressions are against Turtle, with Balancer in seat two.
One repeats the CS3 pattern of an earlier 8→4 expansion displacing a later 8→6
development feed. The other begins with an earlier Closequarters pressure order
and then different withdrawal timing. Their exact order sequences are retained
in `confirmation_changed_trace_review.json`. The broader positive results justify
retention, while these cases identify expansion-versus-support decisions for
further work.

The composite roster panel uses the 240 updated Balancer matches and 360 unchanged
non-Balancer controls. Those controls are reused, not newly simulated matches.
Only the human policy and its medium Balancer profile option changed; each paired
match verifies the other profiles remain identical.

| Bot | Retained-control score | Updated roster score |
| --- | ---: | ---: |
| Turtle | 74.2% | 73.3% |
| Greedy | 63.3% | 61.7% |
| Swarm Lord | 52.9% | 50.4% |
| Raider | 39.8% | 38.1% |
| Balancer | 19.8% | 26.5% |

The roster panel changes from 504 conquest wins / 85 time-limit wins / 11 draws
to 501 / 88 / 11. This pass runs 240 new candidate evaluation matches, eight exact
diagnostic replays and the regression suite. The frozen candidate remains intact
and matches the development game source; `final_checks.json` certifies the source,
coverage, profile, timing, regression and incremental-patch checks.

The extra attention slot meets the declared screen, confirmation and behavior
gates and is retained. Reaction delays and gameplay rates remain unchanged.
Balancer still trails the other personalities on this panel, especially against
Turtle and on Pinched Spine. The results establish an improvement on the tested
panel, not finished balance, human likeness, other-tier performance or release
readiness. Human playtesting and evaluation on additional maps remain separate.
