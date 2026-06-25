# Beta Spectator Mode Plan

## Decision

Do not implement spectator mode in the current beta build until the read-only server path is isolated from player match runtime.

The current VS runtime is player-oriented and participates in input, intent polling, and hash checks. Spectators must not attach to that path.

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
- Keep `publish_intent`, `poll_intents`, `set_ready`, `start_session`, and `leave_session` player-only.
- Add authorization roles:
  - `admin_spectate`
  - `tournament_observer`
  - `invited_spectator`
  - `public_delayed_spectate` later only

## Client V1

- Add a separate `SpectatorRuntime`.
- Do not reuse `VsPvpRuntime` for spectators.
- Render from delayed replay events or server snapshots.
- Show `SPECTATING` badge.
- Show delay indicator.
- Hide or disable lane, swarm, ready, pause, and recovery controls.

## Required Tests

- Spectator cannot publish lane intent.
- Spectator cannot pause.
- Spectator cannot ready or unready.
- Spectator does not change player count.
- Spectator disconnect does not close or alter match.
- Host and guest hashes are unchanged with spectator connected.
- Spectator cannot poll player-only intent stream without a valid player UID.

## First Order Tomorrow

Build server-only spectator grant and delayed event polling tests first. Do not touch `VsPvpRuntime`, `OpsState`, or match contract surfaces until those tests prove the spectator path is isolated.
