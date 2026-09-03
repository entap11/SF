# Android/iOS Private PvP Regression — 2026-09-02

This is a private-certification regression record. It does not certify or
enable public matchmaking, rank settlement, contests, rewards, purchases, or
economy mutation.

## Scope

- Android hosted and iPhone joined a private Free Roll 1v1 invite.
- Both phone builds came from source commit `844d9db`.
- The isolated private-certification relay reported build `be694dd`.
- No invite code, player identifier, session identifier, or device identifier
  is retained in this document.

## What passed

- Invite creation, join, readiness, session start, and Arena entry completed.
- The relay returned successful responses throughout the match; no HTTP error
  response was observed.
- Both players' intents were published and polled through the relay.
- Both phones agreed on the winning side. Android displayed `You won` with
  `Win by domination`; the product owner confirmed that iPhone displayed
  `You lost`.
- Both apps remained alive through the result screens.

## What did not pass

The determinism/latency portion of the regression cell failed.

- The product owner observed Android running more than one second behind
  iPhone during play.
- The product owner was not tracking both boards closely enough to determine
  whether that gap grew over time or whether detailed hive ownership/counts
  visibly disagreed. Those points remain unknown and must not be inferred from
  this run.
- The phone-local match-start events were only 103 ms apart, but iPhone
  recorded its match-end summary 3,546 ms before Android. Android's recorded
  match duration was 2,941 ms longer.
- Both clients independently detected the same first divergent hash checkpoint
  at tick 1310, with tracking identifying tick 1300 as the first mismatch.
- The mismatch remained through tick 2225: 170 consecutive mismatched samples
  over 925 ticks, approximately 94 seconds.
- Each phone's reported local hash matched the other phone's reported remote
  hash at the first and final retained checkpoints. This confirms that the
  comparison paired the two real peer states; it was not an asymmetric logging
  artifact.
- The certification debug summaries still agreed on map, players, hive-count
  summary, active-lane summary, and swarm summary. The differing field is in
  authoritative state not decomposed by the current diagnostic summary.
- Hash recovery was explicitly suppressed by this candidate's setting, so the
  clients continued rather than pausing for recovery or failing closed.

Android accumulated 31 late-command bookkeeping observations versus one on
iPhone. The retained late-event samples were one-tick, within-tolerance
`state_hash` bookkeeping commands. That asymmetry is evidence worth preserving,
but it does not establish that late gameplay delivery caused the state split.

iPhone recorded one failed `state_hash` publish with `json_parse_failed` near
the end of the match. It occurred well after the first divergent checkpoint and
therefore does not explain the onset.

Android also emitted repeated non-fatal warnings because vibration was invoked
without the manifest permission. Play continued; treat this separately as a
configuration/polish observation.

## Classification

- Handshake and relay transport: **pass for this direction**.
- Terminal winning side: **consistent**.
- Cross-platform deterministic state: **fail**.
- Cross-platform latency/pacing: **fail**.
- Overall private PvP certification status: **open**.

This result must not be promoted to a broad root-cause claim. In particular,
successful HTTP responses do not prove equal simulation state, and the
three-second result gap alone does not distinguish render latency from earlier
simulation pacing drift.

## Next diagnostic step

The follow-up is an instrumentation-only certification pair that preserves all
gameplay rules and authoritative-state ownership:

1. The private iOS and Android device presets enable the existing bounded PvP
   runtime JSONL telemetry. Ordinary iOS and Android store presets remain
   unchanged.
2. Existing one-second samples record each local simulation tick against app
   monotonic time, system wall time, and transport RTT so pacing can be measured
   without relying on visual observation.
3. At the first persistent hash mismatch, each phone retains its already-built
   full authoritative recovery checkpoint. The one-time serialization and file
   write are deferred outside the authoritative simulation tick.
4. After one short physical match, compare the paired checkpoint objects field
   by field to locate the first exact difference. If no mismatch recurs, compare
   the one-second tick/time series instead.
5. Discuss the resulting field and pacing evidence before changing simulation,
   input, or rendering behavior.

This diagnostic implementation passes the exact Godot 4.7.1 replication and
private-certification UI smoke suites. It is not a frozen or release candidate;
the paired phone artifacts must be labeled and retained as diagnostic builds.

## Follow-up diagnostic match

A second Android-host/iPhone-guest match used the matching diagnostic pair.
Android won, and both local match records identified seat 1 as the winner. The
product owner reported that visible divergence was smaller than in the first
match but was still perceptible. Treat that as a product observation, not a
determinism pass.

The pacing evidence does not show an accumulating clock-rate split:

- local match starts were 26 ms apart;
- local match ends were 203 ms apart and recorded durations differed by 177 ms;
- Android and iPhone advanced at 9.9880 and 9.9885 simulation ticks per second,
  respectively;
- close wall-time samples placed Android zero to four ticks ahead, averaging
  1.94 ticks, with one tick at the first retained pair and two at the last;
- Android transport RTT averaged 262 ms and reached 684 ms, versus 157 ms and
  450 ms on iPhone.

The state evidence identifies the first concrete split. An iPhone lane command
was issued at tick 42 with canonical execution tick 48. iPhone applied it on
the scheduled simulation transition, but Android did not receive it until its
tick-50 transition. The runtime accepted that two-tick delay because it was
inside the configured eight-tick late tolerance, then applied the gameplay
mutation at Android's later tick.

Relative to each phone's match-start record, the active-match samples place the
iPhone simulation phase about 219 ms behind Android on average even though both
tick rates are the same. The command took 496 ms from the iPhone's recorded send
to Android's recorded receipt. Thus the sender-relative six-tick lead left only
about four ticks on the already-ahead peer, and the command missed that peer's
deadline. This identifies a concrete interaction among start phase, scheduling,
and delivery; it does not establish which layer created the initial phase offset.

State hashes first differed at checkpoint tick 50. At the first persistent
mismatch snapshot (tick 60), the authoritative state objects differed in only
one lane's timing fields: Android recorded lane establishment at 4,900 ms with
a 1,100 ms spawn accumulator, while iPhone recorded 4,700 ms and 1,300 ms.
That exact 200 ms displacement follows from the two-tick late application. The
snapshot also showed a one-power difference in the derived maximum team hive
power statistic.

The mismatch never healed through the final published checkpoint at tick 1180.
The final coarse summaries agreed when tick and hash were excluded, but the
phone-local match totals differed in capture, unit spawn, first-land, friendly-
land, and enemy-land categories. The result is therefore not merely a render
offset even though the winning side agreed.

No gameplay fix has been applied. The evidence supports discussing a contract
change in which gameplay commands must either reach every peer before one
canonical execution tick or trigger deterministic pause/recovery/rollback;
silently applying the same command on different ticks cannot remain an
acceptable late-within-tolerance path. A larger or adaptive command lead may
reduce incidence, but it is not by itself a correctness guarantee.

Sanitized summaries and Android screenshots are retained under the ignored
`artifacts/device-cert/2026-09-02-private-pvp-regression/` directory.
