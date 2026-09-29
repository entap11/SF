# Balancer supply-choice investigation — September 22, 2026

Status: complete; candidate rejected and all three code/test files restored
exactly to the retained
[attention-capacity checkpoint](bot_attention_capacity_2026-09-22.md).

The owner requested investigation of expansion versus support, one focused
candidate, and validation beyond the familiar seeds and maps. The objective is
competitive styles with different strengths, not equal matchup win rates.

## What the observations showed

Eight diagnostic replays cover both seats against Greedy on CS2, Turtle on CS3
and Corridors, and Raider on Pinched Spine, using seed 1941614430. The wrapper
records the policy's actual delayed observations and asks what ordinary
development would offer. It never applies the alternative. After removing the
diagnostic payload, all eight complete results, traces and state/runtime hashes
match the retained controls exactly.

Across 784 decisions and 118 attacks, only two attacks coincide with an eligible
development feed. One uses the same donor, but neither competes for that donor's
last lane. The specific CS3 8→4 expansion at 29.7 seconds does not have an
eligible 8→6 feed at decision time: the donor has 10 power against a 12-power
minimum, and the recipient is farther from the nearest non-allied hive. The
control's later feed became eligible on a changed board. Those traces therefore
do not justify simply making supply outrank expansion.

A second eight-match diagnostic replay changes only the minimum power in an
unapplied supply query. With a 10-power minimum, five waiting decisions have a
new feed available. Examples include CS3 5→10 at 47.2 seconds and Corridors 6→8
at 27.5 seconds. Ten attacks, one feed and one swarm also coincide with newly
available supply alternatives; the candidate does not override those decisions.
All eight second-pass results also exactly match the controls. These selected
observations identify a concrete hesitation; they do not establish that every
alternative would execute successfully or improve an outcome.

## Candidate

The medium Balancer profile enables `human_develop_at_lane_threshold`.
`_develop_supply` caps its ordinary minimum at the existing medium growth
threshold, 10 power, instead of requiring 12. A steady feed opens a lane without
spending stored power; the observation must still show available lane capacity.
The option defaults off for callers that do not supply it.

All existing development guards remain: a safe donor, legal route, cooldown,
forward direction, no active reverse feed, recipient below 40 power and fewer
than two incoming friendly streams. A busy donor still needs an active front to
support. Development preserves the current plan and its review deadline.

Attack priority, pre-attack supply, emergency supply and burst thresholds remain
fixed, as do attention limits, reaction timing, production, movement, combat and
capture. This is still the opt-in medium Balancer pilot for two-seat conquest.
The other four personalities continue to use the baseline policy.

The focused scenario compares the old and candidate settings on the same delayed
view. A 10-power donor already uses one route while an allied front needs supply.
Assertions check the candidate's feed, preserved plan and observation, donor
threat/cooldown/capacity constraints, authoritative execution without a power
cost, and absence of duplicate supply.

## Evaluation design

The experiment is declared before candidate match results. Screening pairs 80
candidate games with saved attention-capacity controls on the familiar five maps
and seeds 1941614430 and 1545051845. Confirmation runs both arms anew: 112 pairs
using seeds 203924908 and 238997064 on the original five maps plus Knife Fight
SBASE and No Man's Land Two Hubs. The seeds are outside the original 20-seed panel;
the additional maps broaden this balance panel without modifying map files.

The original declaration selected No Man's Land SBASE. Its two control jobs
failed discovery before running a game because the current map-loader allowlist
rejects that path. A recorded eligibility amendment replaces it with existing
`MAP_nomansland__545__v18_two_hubs_each__1p`, which passes loader and two-seat
checks. This selection occurs before any candidate confirmation result. The
candidate source, seeds, other six maps and retention gate stay fixed. The 96
valid controls from those other maps are reused; both arms run Two Hubs. The
original declaration, plan and failed logs remain archived with the amendment.

The same frozen candidate runs both panels without retuning. Retention requires
the focused scenario and all regression gates to pass, score improvements in
both panels, and a review of behavior and matchup regressions. Both seats and
all four opponents are included. Score gives draws half credit. Only two fresh
seeds are sampled, so confirmation is a limited robustness check.

Every paired game verifies initial board, complete outcome, canonical 100ms
clock, pinned Godot 4.7.1 build, isolated user data and expected profile changes.
Source fingerprints and result checksums prevent mixing versions. No non-Balancer
matchups are newly simulated in this pass, and no full-roster result is claimed.

Evidence: `SF/artifacts/bot-supply-choice-2026-09-22/` contains the two diagnostic
replay sets, observation witnesses, declared experiment, before-file backups,
frozen source hashes, harness scripts, regression logs and paired results.
The candidate checkout is `SF/project-bot-supply-choice-20260922`.

## Screening review

The candidate passes 112 runtime checks and all seven regression suites, plus
identical repeated canonical matches, snapshot continuation, horizon handling
and accelerated-clock rejection.

Screening improves from 20 wins / 59 losses / 1 draw to 22 / 57 / 1. Score rises
from 25.625% to 28.125%, a 2.5-point increase: two outcomes improve and none
worsen. Each seed gains one win. The improvements are CS2 against Raider in seat
one and Corridors against Greedy in seat two. No map/opponent aggregate declines.

The CS2 improvement first diverges with a 7→9 development feed at 31.2 seconds.
The nearby board sample shows the donor at 10 power with one outgoing route.
The Corridors improvement first diverges with 6→8 supply at 26.9 seconds; the
control supplies that route at 32.3 seconds. These are whole-policy paired
outcomes, not proof that one isolated order caused a win.

Development feeds increase from 106 to 112, while total successful commands
fall from 2,720 to 2,667 and total feeds fall from 316 to 301 as subsequent play
changes. Command rate stays similar, 11.03 to 10.95 per minute. The opening
expansion gap stays at 1.8 seconds. Rejections fall from 45 to 43; the maximum
rejection run stays at four, and quick feed reversals stay at zero. Development
followed within ten seconds by a recipient withdrawal rises from 20 to 22.

Two candidate Corridors games have no captures during the final minute; both
are time-limit wins. Against Raider, a former 242.1-second conquest win becomes
a 300-second time win. Against Greedy, a former loss becomes a 300-second time
win. These are active stalemates: Balancer issues nine and seventeen orders in
the respective final minutes. Last captures occur at 132.5 and 132.4 seconds.
They remain a limitation for finishing behavior even though the outcomes are
favorable. Overall time-ended matches increase from ten to eleven.

One Corridors/Turtle loss has nine rejected orders instead of seven. All nine
are ownership failures on delayed defensive feeds, eight from a repeatedly
contested hive. The aggregate rejection rate improves slightly, but this case
remains a concrete weakness. The unchanged candidate proceeds to the fresh
confirmation panel.

## Fresh confirmation and final decision

All 112 fresh pairs finish and pass engine, source, initial-board, profile,
clock and outcome validation. The candidate declines from **28 wins / 80 losses /
4 draws to 26 / 82 / 4**. Score falls from **26.79% to 25.00%**, a 1.79-point
decline. Two losses become wins and four wins become losses. One fresh seed is
unchanged; seed 238997064 loses two net wins. Seat one is unchanged overall and
seat two declines by two wins.

| Fresh map | Control score | Candidate score |
| --- | ---: | ---: |
| Centerstrike CS2 | 18.75% | 25.00% |
| Centerstrike CS3 | 68.75% | 50.00% |
| Closequarters | 31.25% | 37.50% |
| Corridors | 31.25% | 31.25% |
| Pinched Spine | 6.25% | 6.25% |
| Knife Fight | 12.50% | 6.25% |
| No Man's Land Two Hubs | 18.75% | 18.75% |

Each fresh map has 16 games. On the original five maps, score falls by 1.25
points; on the two added maps it falls by 3.125 points. Against Greedy and Raider,
fresh score falls by 3.57 points each; Turtle and Swarm Lord aggregates are
unchanged. This is not a requirement that every matchup improve: the candidate
fails the overall confirmation gate and gives up existing CS3 strengths.

The four worsened games provide concrete capacity-allocation examples:

- CS3 against Greedy, seat one: new 7→9 supply at 30.3 seconds uses the donor's
  last free lane; the control's later 7→1 expansion is absent from the candidate.
- CS3 against Turtle and Raider, seat two: new 6→8 supply at 28.1 seconds
  precedes a different expansion pattern. The control's 6→9 pressure against
  Turtle, or 6→1 expansion against Raider, at 29.4 seconds is displaced.
- Knife Fight against Greedy, seat one: the candidate starts 3→1 and 4→1
  development earlier. The resulting reserve growth permits earlier central
  pressure, but the full match changes from a time-limit win to a time-limit
  loss. The trace alone does not isolate why that earlier commitment loses.

The additional supply is legal and uses ordinary reaction timing. Its opportunity
cost still matters: opening a feed can occupy capacity needed by the next attack.
These observations support investigating donor capacity and the value of the
recipient's commitment, rather than assuming every legal early feed is useful.
No follow-up heuristic is implemented in this pass.

Fresh development feeds increase from 161 to 195. Early productive-hive idle
samples fall from 6.28% to 5.23%, and lane utilization rises from 70.91% to 72.00%.
Those activity improvements do not translate into better results. Commands per
minute fall slightly from 10.75 to 10.60, rejected orders rise from 55 to 56,
and quick feed reversals remain zero. Withdrawals fall from 353 to 332. Quiet
final-minute timeouts fall from eight to seven, and total time-ended matches
fall from 25 to 24. Development followed by a recipient withdrawal within ten
seconds rises from 19 to 20.

Across **192 paired comparisons**, both arms finish with **48 wins / 139 losses /
5 draws**, a **26.30% score**. Four outcomes improve and four worsen, and each
opponent aggregate is unchanged. Development feeds rise from 267 to 307, but
there is no net competitive gain. The familiar screen's improvement therefore
does not justify retention.

The candidate is rejected. The human policy, OpsState profile and runtime test
file are restored byte-for-byte from the before-file backups, preserving the
earlier attention-capacity improvement and every other existing change. The
retained pilot still has its previous 100-check runtime suite; the rejected
candidate and its passing 112-check suite remain in the frozen checkout.
Reaction timing and gameplay rates remain unchanged.

This pass completes 304 new evaluation games, sixteen diagnostic replays (two
passes over the same eight selected matches), and the candidate regression gate.
The two excluded-map jobs run no games. The saved control results provide the
remaining 80 members of the paired comparison. `retention.json` records rejection;
`implementation.patch` preserves the rejected code change; `final_checks.json`
verifies restoration, source integrity, paired coverage and all test evidence.
