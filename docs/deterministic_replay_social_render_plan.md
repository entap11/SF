# Deterministic Replay → Social Render Plan

Status: **planned for implementation weekend of 2026-09-19**

## Product decision

SwarmFront should **not continuously record video of ordinary matches** for future social use.

Instead, retain the compact authoritative data required to deterministically reconstruct a match. Score matches after completion, recreate only the matches worth watching, and render permanent social clips only for selected highlights.

Core flow:

```text
Match
  -> canonical replay package
  -> deterministic verification
  -> analytics/highlight scoring
  -> selected matches only
  -> replay exact match in actual Arena scene
  -> render social clips
  -> social/replay queue
```

This makes replay truth the durable source and video a derived artifact.

## Reuse-first finding

Most of the architecture already exists and should be reused rather than replaced.

### Canonical match/replay authority

Existing VS durable data already records the critical deterministic inputs:

- `vs_match_contracts`
  - `sim_build_id`
  - mode/ruleset ID and ruleset hash
  - map ID and map hash
  - deterministic seed
  - roster/contract data
- `vs_command_events`
  - authoritative `command_seq`
  - `issued_tick`
  - `requested_execute_tick`
  - authoritative `execute_tick`
  - seat/player identity
  - command payload and hashes
- `vs_terminal_results`
  - final command sequence
  - command-log hash
  - terminal result
  - verified result payload

The existing Match Authority already replays the canonical command stream in pinned headless Godot **twice** and rejects disagreement. It verifies the same map/rules artifacts and compares winner, elapsed ticks, terminal reason, and final state hash.

That system should remain the source of replay truth.

### Existing visual/telemetry replay seams

`MatchTelemetryModel` and `MatchTelemetryCollector` already contain:

- `replay`
- `video_replay`
- `render_mode: "actual_arena_scene"`
- `deterministic: true`
- input events
- player loadouts
- cosmetics
- clip windows
- 1080x1920 / 30 fps / MP4 export intent
- `swing_moment_ms`

The existing sampled-frame replay remains useful for telemetry, debugging, spectator previews, and lightweight visualization. It should **not** become a second canonical gameplay authority.

### Existing highlight/social pipeline

`tools/analytics/src/highlights` already provides most of the selection layer:

- excitement scoring
- comeback/closeness/swarm-density/duration factors
- watchability gate
- Tier 1 / Tier 2 selection
- Game of the Day / Top 10 / Featured Replay flags
- replay links
- social routing
- Discord/X/internal jobs
- `source: "deterministic_replay_render"`
- `retention_policy: "ephemeral_source_permanent_clip"`

The renderer/export implementation should plug into this existing contract rather than creating another social pipeline.

### Existing viewer/spectator pieces

Reuse where appropriate:

- `MatchReplayMapView`
- spectator delayed replay/event path
- existing replay/snapshot visualization

Spectator snapshots are a viewing aid, not replay authority.

## Canonical replay package

Define one durable replay package assembled from authoritative backend records.

Minimum identity:

- replay schema version
- match ID / epoch
- exact `sim_build_id`
- protocol/command schema versions
- exact map ID + map hash
- exact ruleset ID + ruleset hash
- deterministic seed
- roster/seats/teams
- relevant starting loadouts/buffs/cosmetics needed to reproduce presentation
- ordered authoritative command stream with exact execute ticks
- terminal result
- command-log hash
- final authoritative state hash
- optional checkpoint state hashes

Do not store raw device video as the normal source.

Do not make telemetry timestamps or sampled frames authoritative when exact simulation ticks already exist.

## Deterministic checkpoints

Extend the current final-state verification with periodic lightweight checkpoints.

Recommended first pass:

- every 50-100 simulation ticks, or approximately every 5-10 seconds
- store:
  - simulation tick
  - canonical state hash

Do **not** store giant state snapshots unless later profiling proves they are useful.

Purpose:

- detect replay drift early
- identify the first divergence window
- protect old replays across engine/game changes
- give the renderer a hard verification gate before publishing a clip

A social render must fail closed if canonical checkpoint/final hashes do not match.

## Rendering model

For selected matches:

1. Load the exact compatible simulation build/artifact contract.
2. Load exact map and rules artifacts.
3. Restore deterministic seed and initial match state.
4. Apply the canonical command stream at exact `execute_tick` values.
5. Verify checkpoint hashes while replaying.
6. Render through the **actual Arena presentation**, not a fake approximation.
7. Export only the desired windows.

Gameplay truth must remain exact.

Presentation may be enhanced independently, for example:

- portrait 1080x1920 social framing
- spectator-safe UI
- zoom/camera emphasis
- player handles/rank overlays
- captions
- slow motion
- cleaner HUD
- alternate YouTube/landscape render later

Presentation changes may never alter gameplay events, timing, outcome, or player actions.

## Highlight-window selection

Reuse existing analytics instead of rendering full matches by default.

First-pass candidate windows should include:

- `swing_moment_ms`
- decisive final attack
- comeback inflection
- major swarm collision
- rapid hive-control reversals
- unusually high density/pressure
- significant buff interaction
- close finish

The renderer can fast-forward/headlessly simulate to shortly before a target window, then begin frame production only when needed.

Example:

```text
interesting moment: 04:17
simulation replay: 00:00 -> 03:55 without video frames
render window:     03:55 -> 04:35
permanent output:  selected 40-second clip
```

## Storage policy

Default architecture:

- **Keep:** compact canonical replay truth for eligible matches according to retention policy.
- **Do not keep:** continuous video for every match.
- **Generate:** video only for high-value or manually selected matches.
- **Keep permanently/long-term:** only published/featured clips as product policy requires.
- **Ephemeral:** intermediate full renders and temporary render assets.

Before production rollout, measure actual replay-package size by match duration/mode and set retention windows from measured data rather than assumptions.

## Social/privacy boundary

Public clips must use only public-safe presentation data:

- public handle/display name, not private player/device IDs
- approved cosmetics/loadouts
- no auth/session/device identifiers
- no hidden moderation/admin metadata
- honor deletion/privacy policy where applicable
- honor future player/publicity controls if product policy adds them

## Weekend implementation target

### P0 — Audit and bind the existing seams

- Trace one real completed match from VS contract -> command events -> verification worker -> telemetry/highlight payload.
- Document which modes currently have complete deterministic replay support.
- Identify any command kinds not handled by `match_authority_replay.gd`.
- Confirm seed/RNG ownership for every gameplay-random path.
- Confirm exact build/map/rules artifact retention needed to replay older matches.

Exit: one authoritative replay contract and no competing replay authority.

### P1 — Canonical replay bundle

- Add a server-side replay-bundle/read model using existing durable data.
- Bind replay ID to match ID/epoch and hashes.
- Include exact ordered canonical commands.
- Add schema/versioning.
- Add authorization/privacy boundary for replay retrieval.

Exit: a completed eligible match can be exported as one compact canonical replay package.

### P2 — Checkpoint determinism

- Add periodic canonical state hashes.
- Replay a fixture and a real test match.
- Prove all checkpoints and final hash match.
- Fail closed on intentional mutation.

Exit: deterministic reconstruction is continuously verifiable, not merely terminally verifiable.

### P3 — Actual Arena replay renderer

- Feed the canonical replay package into the existing simulation.
- Render using actual Arena presentation.
- Support headless/fast-forward simulation before the render window.
- Produce one portrait MP4 using the existing 1080x1920 contract.

Exit: one real match can be recreated as a video without any original screen recording.

### P4 — Highlight integration

- Connect replay IDs to the existing highlight scorer.
- Use `swing_moment_ms` and existing scoring as the first clip-window selectors.
- Queue renders only for qualifying/manual matches.
- Preserve `ephemeral_source_permanent_clip`.
- Hand rendered asset URLs back to the existing social-routing payload.

Exit: completed match -> score -> deterministic replay render -> social-ready clip.

### P5 — Measurement and hardening

Measure:

- replay bytes per match
- render CPU/time per minute of gameplay
- cost per selected clip
- deterministic failure rate
- percentage of matches entering render queue
- generated-video storage versus hypothetical record-everything storage

Add retention policy only after measurements.

## Non-goals for the first weekend

Do not:

- build a second replay engine
- replace Match Authority
- record every match as video
- make sampled telemetry frames authoritative
- auto-post publicly before review controls are ready
- attempt cinematic AI editing before exact deterministic rendering is proven
- broaden public spectator permissions as part of this project

## Success criterion

A real SwarmFront match can be reconstructed from compact authoritative data, verified against deterministic hashes, selectively rendered through the actual Arena into a social-format MP4, and handed to the existing highlight/social pipeline — with no original match video recording required.
