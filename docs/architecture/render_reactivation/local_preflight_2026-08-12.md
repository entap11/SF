# Render Reactivation Local Preflight — 2026-08-12

Status: evidence preserved; no Render inspection or mutation performed.

## Repository identity

| Field | Observed value |
| --- | --- |
| Worktree | `project-godot-4.7.1-migration` |
| Branch | `codex/android-release-candidate-4.7.1` |
| Branch HEAD | `7742c438fcca1a7e792c3937328f8d8c490119d0` |
| Recorded upstream | `origin/codex/android-release-candidate-4.7.1` |
| Upstream SHA | `7742c438fcca1a7e792c3937328f8d8c490119d0` |
| `origin/main` | `1fb58f844fc3fd21159aa9c347e94aef8fb4288c` |
| Branch divergence from `origin/main` | 26 branch-only commits; 0 main-only commits |

## Preserved dirty state

The worktree was intentionally left unchanged during preflight. Its uncommitted
diff is limited to:

- `docs/android_ios_private_pvp_smoke_2026-08-10.md`
- `scripts/arena.gd`
- `tools/pvp_reconnect_lifecycle_smoke_test.gd`

`git diff --check` passed. The complete three-file textual diff had SHA-256
`85e877cfd393417e4fe38d311980f13c3daee28530a59321298f35378848a06e`
at preflight. This identifies the preserved original state without treating it
as a certified or committable candidate.

## Installed candidate artifacts

| Platform artifact | SHA-256 | Local build time |
| --- | --- | --- |
| Android private-PvP device APK | `f41b44ffcf54ee1b015bcad16f795b2b1220ca50292ae32013caa7dad15fccb9` | 2026-08-12 13:08:19 -0700 |
| iOS device executable | `a766ea55b6120e9becc22f02c68359b78488051dd6b4b2d73a2c2142b4dc20b9` | 2026-08-12 13:10:21 -0700 |
| iOS PCK | `7906083c33ebaf59cdab7f5561a3668600541969033a8e6c91842b9426de801e` | 2026-08-12 13:10:17 -0700 |

One physical Android device was connected over USB, and one paired physical
iPhone was available. Unique device identifiers remain outside committed
evidence.

## Boundary confirmation

This preflight did not query Render, call a live health endpoint, inspect live
environment settings, deploy, restart, create, delete, reconfigure, migrate,
rotate, or enable anything. Live Render discovery begins only in the separately
authorized read-only P2 activity.
