# Beta Spectator Mode Plan

## Decision

Implement beta spectator mode only through a separate read-only observer path.

Spectators do not attach to the player-oriented VS runtime. They receive server-authorized event and visual snapshot streams, while host/guest players remain the only participants in input, ready, pause, tick, and hash flows.

## Safe Architecture

- Spectators join through a separate server-side spectator grant.
- Spectators are never added to host, guest, roster, ready, pause, sync, or hash participant state.
- Spectators cannot call gameplay endpoints.
- Default spectator feed is delayed by 10 to 30 seconds.
- Live spectate is admin/dev only and disabled unless explicitly configured.
- Spectator disconnect only removes spectator connection state.

## Server V1

- Add `create_spectator_grant` for admin/dev use.
- Add `join_spectate` for grant validation.
- Add `poll_spectator_events` for read-only delayed event retrieval.
- Add `publish_spectator_snapshot` for player-only visual snapshot upload.
- Add `poll_spectator_snapshots` for grant-only visual snapshot retrieval.
- Keep `publish_intent`, `poll_intents`, `set_ready`, `start_session`, and `leave_session` player-only.
- Add authorization roles:
  - `admin_spectate`
  - `tournament_observer`
  - `invited_spectator`
  - `public_delayed_spectate` later only

## Client V1

- Add a separate `SpectatorRuntime`.
- Do not reuse `VsPvpRuntime` for spectators.
- Render from delayed replay events and server snapshots.
- Show `SPECTATING` badge.
- Show delay indicator.
- Hide or disable lane, swarm, ready, pause, and recovery controls.
- In Ops Console, use the Spectate tab to create an admin grant, join, poll, and render snapshots in `MatchReplayMapView`.
- During live PvP, the host client publishes visual snapshots asynchronously at low rate; network failures drop spectator frames rather than stalling gameplay.

## Required Tests

- Spectator cannot publish lane intent.
- Spectator cannot pause.
- Spectator cannot ready or unready.
- Spectator does not change player count.
- Spectator disconnect does not close or alter match.
- Host and guest hashes are unchanged with spectator connected.
- Spectator cannot poll player-only intent stream without a valid player UID.
- Spectator cannot publish visual snapshots.
- Live admin spectator can receive a player-published visual snapshot and render a replay frame.

## Implemented V1 Boundary

- Server spectator grants and delayed/live event polling are isolated in `tools/vs-service`.
- Visual snapshot streams are separate from gameplay intent streams.
- `VsSpectatorRuntime` has no player input methods.
- `VsPvpRuntime` only exposes an async player-side snapshot publisher; it does not consume spectator state.
- `Arena` only asks the active host runtime to publish visual snapshots during RUNNING matches.
- Snapshot publishing is best-effort and skipped while a previous upload is in flight.

## Sharpened V1 Execution Boundary

- Require admin authorization for grant creation via `VS_SPECTATOR_ADMIN_TOKEN` or explicit local/dev opt-in via `VS_SPECTATOR_DEV_OPEN=1`.
- Keep spectators identified by grant tokens, not player UIDs.
- Keep `publish_intent`, `poll_intents`, `set_ready`, `start_session`, and `leave_session` protected by existing player membership checks.
- Serve spectators from delayed read-only intent events and replay visual snapshots.
- Allow live admin spectate only when `VS_SPECTATOR_LIVE_ENABLED=1`.
- Keep public spectate disabled until a separate authorization and abuse review.
