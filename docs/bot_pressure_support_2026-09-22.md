# Balancer active-front support — September 22, 2026

Status: rejected after the screening stage; the attention control is restored.

Follows the retained [attention correction](bot_attention_balance_2026-09-22.md).
The owner authorized the next pressure/support pass. Production, movement,
combat, capture, observation delay, motor delay and thinking cadence remain fixed.

## Reproduced behavior and candidate

Once an attack route is active, the previous controller considers a swarm but
does not request another supply route for that commitment. Routine development
can supply the front, but requires movement toward the nearest non-allied hive.
It therefore skips an available donor beside the front when both hives are the
same distance from the enemy.

The scenario uses a 12-power attacking hive, a 25-power enemy and a safe
25-power lateral ally with a legal unused route. The control leaves that donor
unused. The candidate requests a friendly feed into the attacking hive.

`human_reinforce_active_fronts` is enabled in the medium Balancer profile. For
an active enemy commitment, the controller can request support when its source
is below 40 power, has fewer than two incoming friendly streams and lacks the
existing five-power preparation margin over observed enemy resistance. A ready,
capacity-preserving swarm still takes priority. Reinforcement uses the ordinary
donor power, threat, capacity and cooldown checks. It also follows observed
friendly supply paths to reject indirect cycles, as well as direct reversals.

The order uses goal `reinforce`. Goal `supply` belongs to the prepared opening
sequence, so reusing it for a watched front would mark the wrong plan and shorten
the next decision interval. The new goal preserves the current plan, review
deadline, progress deadline and ordinary decision cadence. The watch list remains
bounded at two entries; defensive interruptions and stalled-front withdrawal
remain in place. Planning reads a delayed observation and emits a command, which
the normal simulation path validates and applies.

The change remains inside the opt-in medium Balancer pilot for two-seat conquest.
The policy tag stays `human_balancer_v3`; the profile option and source fingerprint
identify this revision. Other profiles and default pilot enablement are unchanged.

## Evaluation design

Before candidate results, the experiment declares 80 screening matches on the
first two seeds of the previous panel, followed by 160 reserved confirmation
matches on its other four seeds. Both stages include five maps, every opponent
and both seats. The candidate source remains frozen across both stages. Controls
are the retained attention build's exact paired results, with matching initial
boards, engine and canonical clock. These are known maps and seeds; the reserved
candidate runs are a consistency check, not evidence about unseen maps.

The acceptance gate requires the scenario and full regression suite to pass,
improvement in both stages, unchanged reaction timing and other profiles, and
review of map-specific losses and behavior regressions. A better aggregate score
alone does not establish a balanced roster or perceived human likeness.

## Evidence

`SF/artifacts/bot-pressure-support-2026-09-22/` contains the declared experiment,
before-file backups, scenario logs, source fingerprints, frozen run commands,
paired stage comparisons and compressed game traces. The candidate is frozen in
`SF/project-bot-pressure-support-20260922`. The separate attention and neutral
control artifacts are preserved.

## Screening decision

The 80-match screen changes Balancer from 17 wins / 62 losses / 1 draw to
16 / 63 / 1: score falls from 21.9% to 20.6%. No outcome improves and one
Centerstrike CS3 match against Turtle changes from a win to a loss. The earlier
Centerstrike CS2/Greedy loss is unchanged. The candidate issues 43 reinforcement
orders, of which 13 are followed within ten seconds by a withdrawal from the
recipient hive. This is a review cue, not proof each withdrawal was mistaken.

All 60 non-Balancer replays match the controls exactly. All seven regression
suites pass, including 105 runtime assertions and repeated
canonical match traces. The initial timing assertion wrongly required the next
review timestamp to stay identical; it was corrected to allow the normal command
cooldown to postpone review while still rejecting acceleration or plan mutation.
The policy was not changed for that assertion repair. Rejected orders remain
about 1.76%; no quick feed reversals occur. Quiet final-minute timeouts rise
from one to two.

The support-only candidate fails the declared improvement gate and is not
retained. Its code and results remain in the frozen candidate checkout. No
reserved confirmation games were run. The development policy, profile and runtime
test are restored to the retained attention control before the next experiment.
