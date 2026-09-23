# Balancer pressure progress — September 22, 2026

Status: rejected after reserved confirmation; the attention control is restored.

Follows the retained [attention correction](bot_attention_balance_2026-09-22.md).
The separate [lateral-support experiment](bot_pressure_support_2026-09-22.md)
failed its screening gate and was removed before this candidate was created.

## Reproduced behavior

The previous controller measures progress against the lowest enemy power seen
since a commitment began. An enemy can grow before pressure takes effect, then
start losing power without reaching that historical low. The bot can withdraw
despite the observed decline.

In the reviewed Centerstrike CS2/Greedy control, the 7→5 attack starts with target
power 13. Board samples then show 15 at 35.1 seconds and 14 at 40.1 seconds, before
withdrawal at 41.2 seconds. Those samples motivate the focused scenario; they do
not by themselves establish that maintaining this route wins the match.

The focused test observes target power rise from 25 to 32, then fall to 30. The
old policy still withdraws at nine seconds. The candidate recognizes the decline
at five seconds and gives it the existing eight-second progress interval. When
power remains unchanged afterward, it still withdraws. Rising power alone does
not extend the commitment, and an exposed source can still trigger withdrawal.
The scenario exercises both current and watched plans without changing routes
or observation contents during planning.

## Candidate

The medium Balancer profile enables `human_track_recent_pressure`. For enemy
targets, simulation-owned plan memory records `last_observed_power`. A decline
from that value refreshes `progress_ms`; `best_power` still records the historical
minimum. Neutral expansion retains its existing progress rule. The current plan
and the single watched plan reviewed in that decision use the same helper.

This changes the interpretation of observed progress. It does not change the
eight-second no-progress timeout, review cadence, two-entry watch limit, delayed
observation, motor delay, command validation, or any gameplay rate. The source
receives no private information. Other bot profiles and default pilot enablement
are unchanged. This remains the opt-in medium Balancer controller for two-seat
conquest, identified by `human_balancer_v3`, its profile option and source hash.

A limitation to review is that a small decline can interrupt a longer-term
upward trend. More persistent pressure may help, but could also retain weak
commitments longer. Match outcomes, withdrawals and quiet timeouts are evaluated
alongside the scenario rather than treating the scenario as evidence of balance.

## Evaluation

The frozen candidate is compared with the retained attention build on the same
five maps, four opponents and both seats. Before results, the experiment declares
an 80-match screen on two known seeds and reserves four more seeds for 160
confirmation matches. Confirmation runs only if screening improves. The source
must remain identical across both stages. Initial boards, profiles, engine,
canonical clock and notice/motor bounds are checked per game.

The candidate must pass the focused scenario and seven regression suites, improve
both stages, and have its map-specific losses and behavior changes reviewed.
The fixed map panel and previously used seeds do not establish unseen-map balance
or human likeness.

## Evidence

`SF/artifacts/bot-pressure-progress-2026-09-22/` retains the declared experiment,
before-file backups, source fingerprints, scenario and regression logs, frozen
commands, paired comparisons and compressed game traces. The candidate checkout
is `SF/project-bot-pressure-progress-20260922`; the attention control and rejected
support candidate remain separately preserved.

## Screening review

All 99 runtime assertions and seven regression suites pass, including repeated
canonical match results and traces, snapshot restoration, horizon handling and
accelerated-clock rejection. The focused scenario fails against the old policy
for the expected progress and withdrawal assertions.

The 80-match screen changes Balancer from 17 wins / 62 losses / 1 draw to
18 / 61 / 1: score rises from 21.9% to 23.1%. Two losses become wins and one win
becomes a loss. The gains occur against Turtle on Centerstrike CS3 and Raider on
Corridors; the loss is against Raider on Pinched Spine. All three changes are
with Balancer in seat two. This is a small screening gain, not a strong balance
result, so the unchanged candidate proceeds to its reserved confirmation panel.

Withdrawals fall from 225 to 191. Rejections fall from 45/2,563 attempts to
42/2,574 (1.76% to 1.63%), with the same maximum rejection run of four. Quiet
final-minute timeouts fall from one to zero. There are no quick feed reversals;
the median first order and opening expansion interval remain 3.85 and 1.8 seconds.

The three changed-outcome traces are retained in
`screening_changed_trace_review.json`. Each first diverges at a withdrawal:
the candidate delays or skips it, with both beneficial and adverse later results.
In the Pinched Spine loss, withdrawal from 11→10 moves from 49.8 to 56.7 seconds
and later support choices also change. The trace does not isolate that delay as
the sole cause of the loss. The original Centerstrike CS2/Greedy example remains
unchanged; its board-sample dip does not establish that the controller observed
the same decline at its delayed decision times.

## Confirmation and final decision

The unchanged candidate completes all 160 reserved matches. Balancer changes from
26 wins / 126 losses / 8 draws to 25 / 127 / 8: score falls from 18.75% to 18.125%.
One loss becomes a win and two wins become losses. The gains from screening do
not hold up in confirmation, so the declared retention gate fails.

Across all 240 paired matches, both versions finish with **43 wins / 188 losses /
9 draws**, or **19.8% score**. Three outcomes improve and three worsen. Turtle
and Greedy matchup scores are unchanged. Raider score falls from 31.7% to 30.0%;
Swarm Lord score rises from 20.0% to 21.7%. Centerstrike CS3 and Corridors each gain
one win; Closequarters and Pinched Spine each lose one. Centerstrike CS2 is
unchanged.

Withdrawals fall from 629 to 559, about 11%. Rejections are nearly unchanged,
109/7,435 attempts versus 107/7,367 (1.47% versus 1.45%); the maximum run remains
four. Time-ended matches fall from 37 to 35, with quiet final-minute timeouts
falling from one to zero. No quick feed reversals occur. Median first order and
opening expansion gap remain 3.9 and 1.8 seconds. First-minute lane utilization
changes from 70.7% to 71.0%; idle productive-hive samples fall from 6.0% to 5.8%.
These small behavior changes do not establish a competitive improvement.

The implementation, profile option and added tests are removed from the working
checkout. Their before-file hashes and the complete development game-source
fingerprint match the retained attention control. The candidate's 99 passing
runtime checks, seven-suite regression results, code and all match artifacts
remain in its frozen checkout and artifact directory. `implementation.patch`
records the rejected code/test changes; `retention.json` and `final_checks.json`
certify the decision and restoration.

This pass ran 320 new Balancer evaluation games: 80 for the rejected support
candidate and 240 for the rejected progress candidate. The support experiment
also completed 60 exact non-Balancer replays. The pressure-progress composite
roster report reuses 360 non-Balancer controls; it is not 600 fresh games. Both
candidates used seven-suite regression checks, including repeated canonical
matches, in addition to those evaluation games.

The retained Balancer remains at the attention checkpoint's 19.8% score on this
panel. Neither more lateral support nor more persistent pressure alone resolved
its strategic weakness. Further work should reproduce how it chooses and
concentrates forces across fronts before attempting another balance change.
Production, movement, combat, capture and reaction settings remain unchanged.
