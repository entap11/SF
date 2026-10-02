# Saved solo matches

Implemented policy (2026-10-01): independently played, non-money matches can be saved on the current device and resumed by the same player. Live multiplayer and cash-entry/Crucible games are excluded. `saved_match_policy.gd` centralizes that decision; changing the money policy later also requires reviewing attempt and settlement behavior.

## Player experience

- Eligible games checkpoint approximately every two seconds, on backgrounding, and on scene exit. A clean departure saves the current state; an abrupt kill recovers the last completed checkpoint.
- The main menu offers Resume, Later, and Discard. Resume Game remains available on Home, with Other Game when several saves exist. The match menu offers Save & Exit for eligible matches; confirmed Leave discards the active saved attempt.
- A restored board and its game clock stay frozen during a three-second countdown. A tutorial reading step remains paused afterward until its normal continue action.
- Resume waits for Shell to apply the saved map before restoring the checkpoint. Creating the arena alone does not mean its simulation state exists; fresh-game simulation startup stays blocked while a restore is pending.
- Completed matches and explicitly discarded attempts remove their checkpoint. Between maps, an unfinished async run saves the next stage and the previous results; it does not replay a completed map or buy another entry.
- The earliest contest, round, or attempt deadline governs eligibility. There is no absence-duration limit. Expired contest attempts are not offered for resume. The deadline is checked again after loading and at the end of the countdown.
- Jukebox results belong to the weekly/monthly/season/all-time periods active when the map started. Each closed period is excluded independently; the run never moves into the new period. The resume prompt explains closed boards. Still-open periods, including all-time, remain eligible.

## Authority and persistence

`SavedMatch` owns persistence and launch requests, not gameplay authority. `SimRunner.capture_match_checkpoint()` and `restore_match_checkpoint()` capture and hydrate the existing OpsState/GameState through the simulation-owned `match_checkpoint.gd`. This extends the existing authority snapshot with runtime queues, counters, bot scheduling, RNG state, structure aliases, and production/capture timing. No second live simulation is created. Existing PvP recovery keeps the default notification behavior of `restore_authority_snapshot`.

The save also carries explicit data-only DTOs for campaign identity, progressive runs, prior stages, spent ability slots/transactions, tutorial instruction progress, tap selection, and match telemetry. Presentation nodes, callbacks, drag gestures, and login credentials are not serialized. Process-uptime match deadlines are rebuilt from remaining duration; real contest deadlines are retained unchanged.

Each account has separate files under `user://saved_matches/<owner hash>/`. Versioned binary Variants retain integer keys, 64-bit RNG values, vectors, and typed arrays. Object deserialization is disabled. Checksum validation and temporary-file replacement reject corrupt or interrupted writes without replacing a valid previous save. Simulation-source/bytecode and map fingerprints prevent restoring incompatible rules or changed maps. Account deletion clears this directory.

This is same-device recovery. It does not upload saves, provide cross-device synchronization, or make local files tamper-proof. The existing contest service remains responsible for accepting and verifying submitted results. Older builds did not write these checkpoints, so already-lost matches cannot be recovered retroactively.

## Verification

Use the repository-pinned Godot 4.7.1 executable:

```sh
python3 tools/run_saved_match_checks.py --godot /path/to/pinned/Godot
```

The runner uses isolated player storage and disables live backend traffic. Coverage includes disk corruption/interrupted writes, account separation, eligibility/deadlines, leaderboard rollover, deterministic simulation continuation, full process exit/restart, campaign identity, frozen countdowns, backgrounding, stage transitions, and paused tutorial recovery. Physical-device suspension/force-kill and exported-build checks remain release QA tasks.
