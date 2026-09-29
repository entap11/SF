# Next bot beta session

Keep the current medium bot profiles. The owner is an expert reviewer, not the
difficulty target. Use Simple Syrup, one human versus one CPU, and no buffs for
the initial Balancer/Raider comparison. Do not pool builds, maps, or experience
groups when comparing results.

## Engineering handoff

The feedback source is `codex/beta-match-capture-20260928`, initially at
`07b096d`. Capture and feedback acceptance are already live on the isolated
backend deployment branch. No further backend deployment is needed merely to
combine the client with the control fixes.

The controls checkout is `SF/project` on
`codex/iphone-startup-hitch-diagnosis`. Its September 28 preflight found eight
changed/untracked files, including a new
`tools/fixtures/input_controls_arena_api.gd`. The owner confirmed that these
changes are ready to combine. The integration checkout is
`SF/project-bot-beta-integrated-20260928` on
`codex/bot-beta-integrated-20260928`, with development build `2026092804`.
Do not substitute its older checkout wholesale for the feedback source: the
feedback branch also contains later mobile, campaign, and bot work.

The integration, automated checks, export, and installation below are complete;
see the [integration evidence](bot_beta_integration_2026-09-28.md). Retain this
procedure for the next combined build:

1. Integrate the finished controls change into a separate checkout based on the
   feedback branch. Preserve the original working trees. Include the committed
   tutorial work at `7e50220` as well as the approved working-copy patch. The
   input-test overlap is resolved by retaining both sets of cases and adapting
   the later readability case to the fixture's 64-pixel cell coordinates.
   Include the new fixture. Review the final diff against both inputs.
2. Run the controls/swarm regressions and the existing beta capture, feedback,
   transport, and real Arena tests on the combined source. Refresh generated
   campaign fingerprints when simulation source changes, without changing
   campaign definitions. Assign a fresh unused build and regenerate the beta
   source manifest. Run the complete fast release gate serially before export.
3. Export/sign the development app, check the embedded package and manifest,
   then update the existing iPhone installation without uninstalling or
   resetting its account. Restore live endpoint settings before export; test
   overrides and fixture identities must not ship.

Preflight evidence is in `SF/artifacts/beta-integration-2026-09-28/`.
The working-copy patch and hashes there identify the approved integration input;
neither original checkout is modified by the merge.

## Owner phone acceptance

Passed on September 28 with build `2026092804`. The owner opened the installed
app and played both opponents. The private archive contains Balancer at 80.1
seconds and Raider at 94.1 seconds, both completed human wins, with matching
source/map fingerprints and intact recording digests. Raider's independently
received feedback says too easy, interesting, no control problems, experienced.
The owner missed the first feedback screen before Raider began and considers
the timing acceptable. Leave Balancer's answers and control status unknown;
this clarification does not describe an inattentive match. Full evidence is in
the [phone acceptance review](bot_beta_phone_acceptance_2026-09-28.md).

There is no need to repeat the basic owner submission check. If time permits,
the remaining optional device check is a game played offline after the app has
loaded: save honest feedback, restore connectivity, and leave the app idle at
the result screen or hub for about 30 seconds. Then retrieve the archive to
verify both receipts. These two games do not establish that offline/reconnect
was exercised on the phone; automated transport retry coverage already passed.

For future testers, record failed touch gestures explicitly: commands that
never reached simulation are absent from telemetry. Sharing and answers remain
optional; a missed prompt must not be converted into a rating.

## Audience sample

The owner arranges access to a few willing newer/intermediate players. The
agent prepares and reviews the build and recordings; it does not contact
testers on the owner's behalf without an instruction to do so.

Ask each tester to play one game against each opponent when possible. Alternate
who starts with Balancer versus Raider; the current hub permits either button
first despite its Game 1/Game 2 labels. Keep difficulty, map, seat, and buffs
consistent. Let testers choose their experience level and answer without
coaching them toward a rating. Sharing and feedback remain optional.

Every archive pull rebuilds the private report. Review challenge and interest
alongside result, control problems, participant counts, and recording coverage.
Keep owner games separate; exclude control-affected or unanswered-controls
games from clean performance comparisons. Preserve original durations. A small
initial sample can reveal usability and behavior issues, not establish a target
win rate or population balance. No report flag automatically changes bots.

The feedback loop is now proven on the phone. The immediate next evidence is
the newer/intermediate-player Balancer/Raider sample above. Subsequent bot work
can expand to Turtle, Greedy, and Swarm Lord, then additional maps. Keep those
samples separate from the initial comparison.
