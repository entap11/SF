# Reconnect Verification Evidence — 2026-08-17

Status: `PASS — THIRD-STRIKE PRESENTATION AND AUTHORITATIVE OVERRIDE`

This record closes the physical presentation gate left open on 2026-08-14. It
does not authorize public matchmaking, Rank or economy mutation, production
topology changes, or release to players.

## Candidate identity

| Item | Identity |
| --- | --- |
| Source | `b409fc9797274c4a8a3cf895de7ba3d2d968197a` |
| Branch | `codex/android-release-candidate-4.7.1` |
| Godot | `4.7.1.stable.official.a13da4feb` |
| Android package | `com.entap.swarmfront`, version code `2`, version `0.1.2-rc1` |
| Android APK SHA-256 | `a1c365f37abfc7c4f00132ed211c028e6c0fc50865f4f0e4f6d320d5db094360` |
| iOS bundle | `com.matthew.swarmfront`, version `0.1.1`, build `2026071701` |
| iOS executable SHA-256 | `7db8333f9b2564bdca9aad0dd0ca676990613a28f779f8915718ce79792f0a15` |
| iOS PCK SHA-256 | `d3871b719ffd3bb7863dd27c8ad7df339f646bcbca1e96686255502ed7ca77e0` |

The installed Android APK was re-hashed directly from the connected phone and
matched the candidate artifact. The paired iPhone ran the installed candidate
recorded above. Unique physical-device identifiers are intentionally omitted.

## Physical results

Two fresh private matches were exercised with iPhone as the deliberately
interrupted player and Android as the waiting player.

### Match 1 — strike accounting and authoritative terminal priority

- Disconnect one resumed normally and displayed `1/3`.
- Disconnect two resumed normally and displayed `2/3`.
- Disconnect three awarded Android the win.
- When iPhone was reachable again, it displayed the authoritative terminal
  loss for `disconnect_strike_limit` rather than retaining a local transport
  overlay.
- Android console evidence for session `S64189333` recorded authoritative
  lifecycle phase `forfeit`, epoch 18.

This match proved strike accounting, third-strike server authority, and
terminal-result priority. It did not attempt to keep the iPhone offline while
the app remained visible, so it was not used as evidence for the pending
presentation.

### Match 2 — offline pending presentation and authoritative replacement

- Disconnect one resumed normally and displayed `1/3`.
- Disconnect two resumed normally and displayed `2/3`.
- For disconnect three, Airplane Mode was enabled and retained Wi-Fi was
  explicitly disabled before returning to the still-offline app.
- Android received the authoritative win.
- While unreachable, iPhone displayed the final-disconnect pending message:
  it stated that the player was already at `2/3` and that controls were locked
  while the server determined whether the match was forfeited.
- The offline iPhone displayed no invented 60-second countdown.
- After connectivity was restored, the pending presentation was replaced by
  the authoritative disconnect-strike-limit loss.
- Android console evidence for session `S87915322` recorded authoritative
  lifecycle phase `forfeit`, epoch 17.
- The iPhone console connection was invalidated when the transport was
  deliberately removed, which is expected for an attached remote console;
  physical screen observation supplies the offline-only presentation evidence.

## Timing observation

During the second reconnect sequence, Android showed approximately 46 seconds
remaining when iPhone showed approximately 52–53 seconds. This roughly
six-second display difference is retained as a non-blocking observation. The
offline-side value is an estimate derived from the last reachable server clock,
while the waiting side follows the server-observed stale-presence transition.
The server remained authoritative, both clients resumed normally, and the
third-strike path did not depend on either displayed estimate.

## Automated confirmation

The release-critical local suite was rerun after the device pass with exact
Godot `4.7.1.stable.official.a13da4feb`:

- engine compatibility boundary: PASS;
- reconnect lifecycle, including 2/3 pending and terminal priority: PASS;
- app lifecycle and Arena lifecycle pause source: PASS;
- private-PvP certification UI: PASS;
- VS swarm replication: PASS;
- human PvP boot and outcome overlay: PASS;
- repository all-off staging preflight: PASS;
- VS TypeScript build and full service smoke: PASS;
- Rank player-token, embedded device-session/restart, migrations, and economy
  quarantine: PASS; and
- match-authority TypeScript build and exact-4.7.1 deterministic double replay:
  PASS, final hash
  `1f1b5b8c77cc57fce7623ed6b5cd1a28ea176fcd95b1bd275f1517e54ebaab33`.

An initial invocation of Rank's HTTP identity smoke without its required base
URL failed configuration before testing. That output is retained as an
orchestration error, not converted into a pass; the HTTP identity smoke remains
required against the upgraded certification service.

Known import-time NUL warnings, headless shader-compiler warnings, and expected
negative-path contract errors were emitted by their existing test cases. Every
accepted check returned zero and printed its explicit PASS marker.

## Disposition

The reconnect presentation gate is closed for this candidate. The candidate is
eligible to be frozen for all-off certification deployment. Overall release
status remains `HOLD` pending the unchanged performance threshold and the rest
of the certification/production program.
