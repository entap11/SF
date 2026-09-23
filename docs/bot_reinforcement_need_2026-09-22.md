# Balancer reinforcement need — September 22, 2026

Status: complete; candidate rejected after screening. Development remains at the retained
[attention-capacity checkpoint](bot_attention_capacity_2026-09-22.md), with the
[broad concentration bonus](bot_concentration_2026-09-22.md) still rejected.
The owner authorized checking whether an existing attack actually needs help,
and requested that completed work be committed and pushed. Phone comparison is
planned separately for tomorrow in
[the TestFlight session proposal](bot_phone_comparison_2026-09-23.md).

## Candidate

The existing policy gives an enemy target 20 extra ranking points when friendly
pressure already reaches it. The candidate removes that bonus for a second
attacker when visible arriving friendly forces exceed target power plus visible
enemy arrivals with a two-unit cushion, or when the original attacker meets the
existing source-threat/stall withdrawal criteria. A watched attack with newly
observed progress remains eligible; the existing counterpressure exception is
preserved for source-threat/stall checks. The covered-arrivals check applies
independently. Checking another plan does not review it or extend its deadline.

The medium Balancer option is `human_check_reinforcement_need`. It defaults off
when absent, changes only the exactly-one-friendly-stream ranking case, and
does not ban an otherwise legal attack. A second attacker can still be the best
available choice when alternatives are blocked. There is no new concentration
bonus, new observation field, new memory field or private opponent information.
The arrival estimate remains uncertain because growth and collisions can change
what reaches the target; it does not guarantee a capture.

Defense priority, capacity, cooldowns, timing and command validation remain in
place. No production, movement, combat or capture rate changes are included.
This remains the opt-in medium Balancer pilot in two-seat conquest; the other
four personalities retain their baseline policies.

## Diagnostic evidence

Twelve complete control replays cover both seats in six selected cases: Two Hubs
versus Greedy on seed 453006544, Two Hubs versus Raider on 774025457, Corridors
versus Greedy and Raider on 774025457, CS3 versus Raider on 774025457, and Two Hubs
versus Turtle on 1185698927. The wrapper records decisions in the first 90
seconds and leaves gameplay to the unchanged policy. After removing only the
diagnostic payload, every complete result, state/runtime hash and trace matches
its saved control exactly.

The 638 archived decisions are replayed independently. Declared integer fields
and engine float32 route distances are restored after JSON loading. Canonical
serialized decisions match; decimal JSON scores are compared in serialized form,
not as unavailable original floating-point bits. Both policies receive separate
memory copies, and observation immutability is checked.

Two candidate choices differ, both in seat two against Turtle on Two Hubs:

- At 18.4 seconds, 14→4 neutral expansion replaces 14→3 enemy pressure. The
  original attacker at hive 13 is under observed threat.
- At 36.8 seconds, 3→4 neutral expansion replaces 3→13 enemy pressure. Seven
  visible friendly units are headed toward a one-power target with three enemy
  units approaching it, exceeding the estimate's two-unit cushion.

These are selected counterfactual choices, not two improved match outcomes.
They do not establish how frequently each condition matters across the roster.

## Evaluation declared before candidate matches

Screening pairs 112 new candidate matches with saved controls on seven maps,
four opponents, both seats and seeds 453006544 and 1185698927. The maps are CS2,
CS3, Closequarters, Corridors, Pinched Spine, Knife Fight and Two Hubs.

Only an aggregate screening score improvement, passing focused scenarios and
seven regression suites permit confirmation. If eligible, the same frozen
candidate runs 224 fresh pairs on seeds 231925416, 1424128253, 830130296 and
490200076, excluded from the previous 26 sampled seeds. Retention then requires
another aggregate improvement, neither fresh seat declining, gains against at
least two opponents, and review of map/opponent costs and behavior. These are
engineering criteria, not a significance test or a requirement for equal bots.
No retuning occurs between panels. Failed screening ends this candidate without
spending the reserved confirmation games.

Every pair verifies complete authoritative outcomes, initial board, profiles,
pinned Godot 4.7.1, canonical 100ms clock, notice/motor bounds, isolated user data,
source fingerprints and result checksums. The maximum planned evaluation is
560 new games and 336 pairs; actual completed counts are reported below.

The candidate is frozen at `SF/project-bot-reinforcement-need-20260922` and the
diagnostic checkout at `SF/project-bot-reinforcement-audit-20260922`. Evidence,
before-file copies, the prototype and reproducible commands are under
`SF/artifacts/bot-reinforcement-need-2026-09-22/`.

## Completed result and decision

The screening gate failed. Across 112 pairs, the retained controller scored
24 wins, 83 losses and 5 draws; the candidate scored 23 wins, 84 losses and
5 draws. Counting a draw as half a win, score fell from 23.661% to 22.768%
(−0.893 percentage points). No confirmation games were run, as declared.

| Opponent | Retained W/L/D | Candidate W/L/D | Score change |
| --- | --- | --- | --- |
| Greedy | 4/22/2 | 4/22/2 | 0 pp |
| Raider | 12/16/0 | 12/16/0 | 0 pp |
| Swarm Lord | 5/20/3 | 5/20/3 | 0 pp |
| Turtle | 3/25/0 | 2/26/0 | −3.571 pp |

Each opponent has 28 pairs. Seat one and seed 453006544 were unchanged in
outcomes. The single lost win occurred in seat two on Two Hubs, seed 1185698927;
the other six maps were unchanged in outcomes. This is a failed engineering
screen, not evidence of a statistically established disadvantage.

Twelve applied order sequences changed: one against Greedy, three against
Raider, four against Swarm Lord and four against Turtle. Eleven retained the
same outcome. These counts exclude score-only changes and compare order time,
source, destination, intent and goal.

The lost Turtle win is the first counterfactual found by the diagnostic audit:
at 18.4 seconds the candidate scheduled 14→4 neutral expansion instead of
14→3 enemy pressure, applying it at 18.7 seconds. The control subsequently
ordered from the captured hive 3 toward hive 2 at 28.2 seconds; the candidate
instead fed hive 8 from hive 14. The candidate lost at 110.9 seconds, while the
control won at 264.2 seconds. The separate 36.8-second archived counterfactual
belongs to the control timeline and is not a second observed candidate choice.

The interpretation is narrow: suppressing reinforcement because its original
source is threatened can discard a useful attack in this case. A neutral
expansion can look sensible locally without producing a better position. The
screen does not establish that every reinforcement estimate is harmful or
isolate the later effect of each condition in this combined candidate.

There was no broader improvement in the monitored behavior: both versions had
38 command rejections, zero quick feed reversals, one match with a rejection
run of at least three, and seven time-limit endings with no ownership change
in the final minute. Median first order remained 3.8 seconds. Applied commands
fell from 4,098 to 4,009; raw command totals are not a quality measure. The
changed-outcome trace and all seven quiet-ending witnesses were reviewed.

## Verification and retained checkpoint

All seven candidate regression suites passed, including 118 runtime assertions,
two identical complete canonical match replays, snapshot continuation, correct
incomplete-horizon reporting and rejection of accelerated clocks. The focused
scenario covers covered arrivals, resistance and cushion, stalled versus newly
progressing attacks, source threat, counterpressure, ordinary defense priority,
legal fallback and application without removing existing lanes.

The initial scenario incorrectly assumed explicit lane candidates excluded a
legal defense route. The controller correctly chose defense. The fixture was
corrected to assert that priority, then use known cooldowns to make defense
donors unavailable for the lower-priority ranking checks. No policy retuning
followed that correction; both initial and final logs remain in the artifacts.

The human policy, Balancer profile and runtime smoke file were restored exactly
to their saved pre-experiment bytes. The earlier attention-capacity checkpoint,
safe neutral attention release, spare-reserve supply feed, Raider/Greedy neutral
expansion fix and deterministic scheduling restoration remain. The rejected
option and its focused scenario are archived in the frozen candidate and
`implementation.patch`, rather than included in the retained controller.
After restoration, the retained runtime suite also passed all 100 assertions
on an isolated worker with the exact retained source fingerprint. Its log and
summary are in `retained-runtime/`.

Completed evaluation: **112 new candidate games against 112 saved controls**,
plus **12 diagnostic full replays** and **638 canonical archived decision
replays**. The seven regression suites are separate from these game counts.
`final_checks.json` verifies coverage, fingerprints, checksums, the audit,
regressions, patch applicability and exact restoration. Phone comparison is
the next source of decision evidence; the proposal still requires TestFlight
build/profile and full-match export verification before play.
