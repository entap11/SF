# First automatic beta uploads — September 28, 2026

Two completed owner games reached the private archive without a device-file
transfer. This validates the real iPhone capture → authenticated upload → durable
archive → private export path for build `2026092802`. The first fetch contained
one game; the next fetch contained both. Server receipt times were 18:52:13 and
18:52:28 UTC (11:52 Pacific).

The participant key was matched to the local human identity in the earlier owner
phone recording before applying the server-side `owner` cohort annotation. Both
exports now carry that label. No identity is included in this report. Preserve
the [owner calibration decision](bot_owner_playtest_2026-09-28.md): these games
inform tactical interpretation and bug review, not the strength target for medium.

## Verified results

Both games used Simple Syrup, seed `9282026`, human seat 1, CPU seat 2, medium
profiles, and ended in human conquest wins. Recorded policy identities match the
intended opponents. Bot policy/system source hashes and map bytes match the
prior phone playtest; the new build added capture, not a strength change.

| Evidence | Balancer | Raider |
| --- | --- | --- |
| Policy | `human_balancer_v3` | `baseline_v3` |
| Simulation duration | 109.5 seconds | 94.4 seconds |
| Recorded human intents | 20 | 18 |
| Applied bot commands | 12 | 7 |
| Total projected events, including diagnostics | 259 | 78 |
| Board samples | 219 | 189 |
| Dropped events / rejected recorded intents | 0 / 0 | 0 / 0 |
| Units produced, human / bot | 602 / 308 | 539 / 211 |
| Swarms sent, human / bot | 4 / 6 | 2 / 2 |

Samples are spaced 500 ms apart. Final samples precede the terminal conquest
capture by 400 ms and 300 ms respectively; winner/completion comes from the
terminal record, not inference from the final sampled board. Event totals are
not move totals: the Balancer policy emits additional diagnostic records.

## Tactical observations

Hive references: human home 1, lower-left 2, lower-right 3, center 4, upper-left 5,
upper-right 6, CPU home 7. Action timestamps are simulation times; ownership
changes below are the first matching samples, not exact capture times.

**Balancer:** The owner attacks CPU home from the upper-left at 17.4s. Balancer
pressures the upper-left from the upper-right at 19.6s, expands toward the
lower-right at 27.9s, and sends a defensive swarm there at 35.0s. The lower-right
changes hands several times, then stays CPU-owned in samples from 36.6s through
101.1s. Balancer also attacks the human home from that position at 38.1s.

The owner reverses supply 5→2 at 40.4s, reinforces the contest with 2→3 at 41.0s,
and adds attacks into center from 1 at 48.6s and 2 at 62.3s. Center stabilizes
under human ownership by the 65.1s sample. Balancer keeps swarming center from
the upper-right at 71.6s, 78.3s and 86.1s, then reinforces the lower-right at
93.0s and 98.7s. CPU home falls by the 90.1s sample. This is active expansion,
pressure and defense; the recording does not show an execution rejection.

**Raider:** It opens direct pressure from upper-right into the human home at
25.4s and into the upper-left at 27.5s. The owner reverses lower-left supply into
home at 25.9s and opens a counterattack 1→6 at 26.9s. Later the owner changes
upper-left supply back toward the lower-left and uses 2→3 to expand. Raider
attacks the lower-right at 49.3s, then sends swarms there at 72.7s and toward home
at 79.0s. The owner adds two routes toward CPU home at 56.1s and 57.9s; it falls
by the 70.1s sample. This trace shows direct pressure and the owner's route
adjustments. The baseline does not expose the human policy's delayed plan
context, so its private reasoning cannot be reconstructed from these records.

The owner produces about 1.95× Balancer's units and 2.55× Raider's. Those are
outcomes of these particular games, not a measured isolated cause of the wins.
Neither win establishes that medium needs strengthening. Both records provide
concrete examples of recognizable behavior and player adaptation. The next
population difficulty evidence still needs newer/intermediate testers and their
reported challenge/readability/enjoyment.

## Capture evidence and follow-ups

Private evidence is retained at
`SF/artifacts/beta-capture-2026-09-28/first-phone-review/`: authenticated archive
`index.json`, cohort-grouped `participants.json`, original gzip payloads, and
`review.json`. Run its `review.py` to reproduce digest, identity, source/map,
policy, completion, command matching, regular sampling and timeline checks.
No gameplay changes were made during this review.

Two metadata gaps are visible and retained as follow-ups for the next capture
build:

- The payload has the correct map ID, but its `map_path` and `map_sha256` are
  empty on this launch route. This review resolves the map using the exact
  captured source manifest and verifies it against the prior phone map hash
  (`03e332c6e96aa17773c47bb7093a16500f5994105da89bb9f4fdad4e354bba14`).
  The original payload is not altered. Capture should populate path/hash on
  this route before general map-comparison reporting relies on those fields.
- These solo games contain SHA-256 of an empty string as `shared_match_key`.
  Treat that sentinel as absent, never as evidence that two records belong to
  the same multiplayer match. A future capture should leave it empty when no
  shared session exists.

This is a successful real-device upload pilot, not proof of every interruption,
offline, account deletion, or multiplayer scenario on devices. Those paths have
separate automated evidence. The broader onboarding release-check timeout and
beta distribution work remain as documented in [beta capture](beta_match_capture.md).
