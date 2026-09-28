# Combined-build iPhone capture and feedback acceptance

Both owner games from development build `2026092804` reached the private
archive, and the second game's feedback was received independently. This
completes the real-phone submission check for the
[combined controls and feedback build](bot_beta_integration_2026-09-28.md).

## Results

Both recordings identify iOS, Simple Syrup, seed `9282026`, human seat 1,
medium CPU seat 2, and completed human conquest wins.

| Evidence | Balancer | Raider |
| --- | --- | --- |
| Archive record | 3 | 4 |
| Policy | `human_balancer_v3` | `baseline_v3` |
| Simulation duration | 80.1 seconds | 94.1 seconds |
| Game received, UTC | 23:00:33.644 | 23:02:33.435 |
| Feedback received, UTC | Unanswered | 23:02:48.296 |
| Challenge | Unanswered | Too easy |
| Interesting | Unanswered | Yes |
| Control problems | Unknown | No |
| Self-reported experience | Unanswered | Experienced |
| Recorded human evaluation intents | 22 | 16 |
| Applied bot commands | 7 | 7 |
| Events / board samples | 200 / 160 | 71 / 188 |
| Dropped events / frame stride | 0 / 1 | 0 / 1 |
| Rejected recorded intents | 1, human lane-budget rejection | 0 |

The owner clarified that the first feedback screen was missed before Raider
began, and considers the timing acceptable. The clarification concerns the
postgame prompt, not distraction during the match. Its exact dismissal
mechanism is unconfirmed. No timing change is requested, and no answers are
inferred for the first game. The raw 80.1-second duration is preserved.

The existing report consequently excludes Balancer from clean duration
comparisons because its control answer is missing. Raider qualifies within
the owner cohort. The earlier build's control-affected Balancer record retains
its annotation and original 109.5-second duration. Absence of rejected commands
does not establish that every touch gesture was recognized.

## Verification

- Each compressed recording matches the server's SHA-256 digest and capture
  identity. Both participant keys match the previously verified owner; no
  participant identity is included here.
- Both recordings match source fingerprint
  `6d8a1190cc0a9cdbe9659c53ebb120dde2265ec2cae00d53a61172516c8eb562`.
- The payload now includes the exact map path and SHA-256
  `03e332c6e96aa17773c47bb7093a16500f5994105da89bb9f4fdad4e354bba14`,
  matching the build manifest and Simple Syrup bytes. The solo shared-match
  key is empty. Both metadata gaps from the earlier capture build are resolved.
- Board samples are 500 ms apart with no downsampling. The final sample is
  500 ms before completion in each game. Completion and winner come from the
  terminal record, not inference from the final sampled board.
- Original archive recordings 1 and 2 are byte-for-byte unchanged. The private
  report now has four owner recordings across two builds, with one feedback
  response. Builds and policies remain separate in its groups.

Private evidence is retained under
`SF/artifacts/beta-integration-2026-09-28/phone-review/`: original gzip files,
authenticated archive index, source manifest, annotations, generated report,
and `review.py`/`review.json`. Run `review.py` to reproduce the identity,
digest, source/map, profile, sampling, completion, and feedback checks.

The server's feedback receipt verifies upload beyond a local Save action.
These games do not establish a physical-phone offline/reconnect exercise or
every control edge case; existing automated transport and controls checks
remain separate evidence.

## Decision

Keep medium policies unchanged. The owner remains an expert reviewer and is
not the population difficulty target; the self-reported experienced answer
does not override that cohort. Too easy plus interesting is useful owner
feedback, not evidence to strengthen medium for everyone. The faster Balancer
win is not a controlled measurement of the integrated control/swarm changes.

The next calibration input is willing newer/intermediate players trying both
opponents on the same build and map. Follow the
[next-session checklist](bot_beta_next_session.md) for that sample. No further
owner replay is required to prove the basic game-and-feedback upload path.
