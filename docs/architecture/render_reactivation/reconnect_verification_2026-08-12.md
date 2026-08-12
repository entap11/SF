# Reconnect Verification Evidence — 2026-08-12

Status: `PARTIAL — PHYSICAL PRESENTATION MATRIX BLOCKED`

This record separates automated authority/lifecycle coverage from behavior
actually observed on physical phones. It does not convert unavailable device
interaction into a pass.

## Candidate under presentation review

| Item | Identity |
| --- | --- |
| Source base | `7742c438fcca1a7e792c3937328f8d8c490119d0` plus preserved dirty reconnect presentation diff |
| Dirty diff SHA-256 | `85e877cfd393417e4fe38d311980f13c3daee28530a59321298f35378848a06e` |
| Android APK SHA-256 | `f41b44ffcf54ee1b015bcad16f795b2b1220ca50292ae32013caa7dad15fccb9` |
| iOS executable SHA-256 | `a766ea55b6120e9becc22f02c68359b78488051dd6b4b2d73a2c2142b4dc20b9` |
| iOS PCK SHA-256 | `7906083c33ebaf59cdab7f5561a3668600541969033a8e6c91842b9426de801e` |

## Automated evidence

Executed locally with no live Render inspection or mutation:

| Check | Result | Coverage |
| --- | --- | --- |
| Pinned Godot binary identity | `4.7.1.stable.official.a13da4feb` | Exact local engine used for the Godot checks |
| Godot 4.7.1 `engine_compatibility_boundary_smoke_test.gd` | PASS | Migration compatibility boundary |
| Godot 4.7.1 `pvp_reconnect_lifecycle_smoke_test.gd` | PASS | Overlay source contract, authority snapshot restore, lifecycle pause, shared restart copy |
| Godot 4.7.1 `private_pvp_certification_ui_smoke_test.gd` | PASS | Private-PvP certification UI wiring; not physical readability |
| VS TypeScript build | PASS | Current relay code compiles |
| VS full smoke | PASS | First and second strike accounting, immediate third-strike forfeit, grace expiry, checkpoint mismatch rejection, shared scheduled restart |

The automated checks prove the relay/state contracts exercised by the tests.
They do not prove phone readability, safe-area fit, wrapping, or both-device
visual synchronization.

The Godot runs emitted the repository's known import-time NUL-character
warnings but returned exit code zero and printed their explicit PASS markers.

## Physical-device evidence

The preceding physical-device session established, on the pre-presentation
candidate, that Android and iPhone both displayed the shared three-second
restart countdown and rejoined the same match successfully. A small host/guest
timing difference remained visible. The subsequent presentation candidate was
built, installed in place, and launched on both available phones.

The following presentation-specific rows were not interactively completed in
this execution block. Both devices were connected/available, but establishing
and operating both in-game clients requires physical interaction that was not
available to the executing agent. Each row remains blocked rather than waived.

| Fresh session case | Host direction(s) | Status | Required retained evidence |
| --- | --- | --- | --- |
| First disconnect (`1/3`) | Android/iPhone and iPhone/Android | BLOCKED — DEVICE INTERACTION | Both messages, relay strike, state after resume, both logs |
| Second disconnect (`2/3`) | Android/iPhone and iPhone/Android | BLOCKED — DEVICE INTERACTION | Both messages, relay strike, state after resume, both logs |
| Third disconnect (`3/3`) | Android/iPhone and iPhone/Android | BLOCKED — DEVICE INTERACTION | Immediate forfeit, authoritative terminal result, both logs |
| Full grace expiry | Android/iPhone and iPhone/Android | BLOCKED — DEVICE INTERACTION | Waiting-player win, offender loss, terminal reason, both logs |

Each destructive/terminal case must begin from a fresh invite/session. A failed
row must retain its original logs and identifiers before a fix or rerun.

## Commit decision

The reconnect presentation change must not be committed as a certified client
change under this authorization until the physical presentation rows above are
observed. The dirty state remains preserved and separately identifiable.
