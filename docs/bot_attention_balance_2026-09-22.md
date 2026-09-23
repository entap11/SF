# Balancer attention and balance — September 22, 2026

Status: complete; the attention correction is retained.

Follows the [neutral-expansion correction](bot_neutral_expansion_2026-09-22.md).
The owner authorized further tweaks. Production, lane speed, combat, capture,
observation delay, motor delay and thinking cadence remain fixed.

## Behavior correction

In the previous control, Balancer commonly waits about six seconds after an
expansion order before considering its next front. That is an attention rule,
separate from the normal delay between decisions. The reviewed Centerstrike and
Corridors losses open at 3.8 seconds, then wait until 10.3 seconds for the second
route, while the opposing baseline bots have opened two routes by 4.8 seconds.

The medium Balancer profile now sets `human_review_uncontested_expansion` to true.
Once its delayed observation confirms that an expansion route is active and its
target is still neutral, it can move that plan to its existing watch list at the
next ordinary decision. A hostile route or observed incoming enemy convoy at the
target prevents this early handoff. An observed threat at the source also prevents
it. Pressure against an enemy keeps the existing review rule.

The two-entry watch limit, stalled-plan review, defensive interruptions, command
cooldowns, capacity checks and delayed command validation remain in place. The
policy reads the observation and changes only simulation-owned cognitive memory;
it does not open lanes itself. A new action still passes through the ordinary
observation, notice and motor pipeline. Turning the profile option off reproduces
the former expansion wait.

This remains the opt-in medium Balancer pilot for two-seat conquest. Its policy
tag remains `human_balancer_v3`; the explicit profile option and exact source
fingerprints distinguish this revision. Default pilot enablement and the four
baseline personalities are unchanged. Cross-version snapshot continuation is not
certified by this experiment.

## Tests and schedule

The focused scenario fails against the old policy for the expected expansion and
watch-list assertions. The candidate passes all 88 runtime checks. These include
the new free-route scenario, immutable observation/authoritative routes, opt-out
control, command cooldown, rival convoy and rival active route cases. The initial
cooldown assertion incorrectly required no action at all; it was corrected to
reject the blocked route while allowing a legal alternative. The failed assertion
log is retained; the policy did not need a change for it.

All seven regression suites pass, including repeated full canonical match traces,
snapshot restoration, horizon-limit handling and accelerated-clock rejection.

Before candidate match results, `experiment.json` declares an 80-game screen on
the first two seeds of the previous six-seed panel. It reserves the other four
seeds for 160 confirmation games, with all five maps, all four opponents and both
seats. Existing results supply the exact paired controls. The candidate remains
frozen across both stages. Per-game checks verify initial boards, engine, clock,
profiles, complete coverage and notice/motor delay bounds.

A separate 60-game invariance check replays every ordered matchup among the four
non-Balancer personalities on all five maps using the first screening seed. It
requires identical complete results and traces. This supports reusing the 360
non-Balancer control games when describing the roster after replacing its 240
Balancer games; those 360 games are not represented as new candidate runs.

## Screening result

Balancer improves from 7 wins / 72 losses / 1 draw to 17 / 62 / 1 across the 80
matched games. Score, including half-credit for draws, rises from 9.4% to 21.9%.
Every tested map improves. Opponent gains are against Turtle and Raider; the
aggregate results against Greedy and Swarm Lord are unchanged in this screen.

The median interval between the first two successful expansion orders falls from
7.4 seconds to 1.8 seconds. The median first order remains at 3.85 seconds.
There are no quick feed reversals in either arm. Rejected orders rise from 1.57%
to 1.76%, with the same maximum rejection run of four; ownership changes account
for most failures. The idle productive-hive sample fraction rises from 5.1% to
6.2%, so the earlier opener does not resolve all unused capacity.

The inspected Centerstrike/Greedy loss now opens at 3.8 and 5.6 seconds, but Greedy
still wins at 140.3 seconds. Later pressure commitments, withdrawals and use of
additional lane capacity remain candidates for focused behavior work. This single
trace does not determine which follow-up change would improve the matchup.

## Confirmation and retention

The unchanged candidate completes all 160 reserved-seed games. Balancer improves
from 11 wins / 140 losses / 9 draws to 26 / 126 / 8, raising score from 9.7% to
18.8%. All opponent aggregates improve; four maps improve and Pinched Spine is
unchanged on this confirmation subset.

Across all 240 matched Balancer games, the result is 18 / 212 / 10 before and
43 / 188 / 9 after: **9.6% to 19.8% score**. Twenty-eight outcomes improve, four
worsen, and the rest are unchanged. Every map and opponent aggregate improves
on the combined panel. The median opening expansion gap falls from 6.7 to 1.8
seconds, while the median first order stays at 3.9 seconds.

| Balancer opponent | Control score | Candidate score |
| --- | ---: | ---: |
| Turtle | 3.3% | 13.3% |
| Raider | 13.3% | 31.7% |
| Greedy | 10.0% | 14.2% |
| Swarm Lord | 11.7% | 20.0% |

| Map | Control score | Candidate score |
| --- | ---: | ---: |
| Centerstrike CS2 | 2.1% | 10.4% |
| Centerstrike CS3 | 4.2% | 27.1% |
| Closequarters | 33.3% | 36.5% |
| Corridors | 8.3% | 20.8% |
| Pinched Spine | 0.0% | 4.2% |

All 60 non-Balancer replays match their previous complete results and traces
exactly. With the 240 updated Balancer games and 360 unchanged controls, the
600-game roster panel becomes:

| Bot | Control score | Updated score |
| --- | ---: | ---: |
| Turtle | 76.7% | 74.2% |
| Greedy | 64.4% | 63.3% |
| Swarm Lord | 55.0% | 52.9% |
| Raider | 44.4% | 39.8% |
| Balancer | 9.6% | 19.8% |

This panel has 504 conquest wins, 85 time-limit wins and 11 draws, compared with
501 / 87 / 12 before. In Balancer's matches, quiet final-minute timeouts fall
from three to one; median duration rises from 146.55 to 167.15 seconds.

Rejected Balancer orders rise from 78/6,354 attempts (1.23%) to 109/7,435 (1.47%),
mostly from ownership changes between observation and execution. Capacity
rejections fall from 29 to 22. The maximum rejection run remains four; matches
with at least three consecutive rejections fall from three to two. No quick feed
reversals occur in either arm. First-minute lane utilization rises from 69.8% to
70.7%, while idle productive-hive samples rise from 5.4% to 6.0%; those samples do
not establish that another useful legal route existed.

The correction meets its declared screening, confirmation and behavior gates and
is retained. It does not make the roster balanced. Balancer's pressure and support
decisions remain weak, especially on Pinched Spine and against Greedy. Existing
map-specific dominance among the other personalities is not tuned in this pass.
Further work should reproduce those later decisions before adjusting more profile
weights. Production and movement rates remain fixed.

## Evidence

`SF/artifacts/bot-attention-balance-2026-09-22/` retains the declared experiment,
frozen-source check, scenario and regression logs, paired stage comparisons,
compressed game traces, source hashes and exact commands. The candidate is frozen
in `SF/project-bot-attention-20260922`. `run_focus.py` and `compare_focus.py` reproduce
the focused stages; `check_invariance.py` verifies the unchanged opponents.

These six seeds belong to the known fixed map panel. Reserved candidate seeds
check consistency without retuning the candidate, but do not establish balance
on unseen maps or perceived human likeness. Human playtesting and other tiers or
team modes remain separate evaluations.
