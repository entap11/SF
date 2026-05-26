# Swarmfront Coding Governance

This document is canonical for engineering decisions unless Matthew explicitly overrides it.

## One Authority

- Maintain one authoritative game state: `OpsState` / `SimState`.
- UI, renderers, input, menus, diagnostics, and overlays must not mutate simulation state directly.
- Non-authoritative systems emit intents/requests and render from authoritative state.
- Only simulation/state systems may mutate game state, and only through the owning authority boundary.
- If two modules can change the same fact, stop and choose one owner before coding.

## Minimal Mechanics

- Build the smallest universal mechanic that satisfies the confirmed request.
- Do not bundle adjacent behavior into a mechanic because it is convenient in the current flow.
- If extra behavior is useful, add it as a separate layer after the core mechanic works.
- Prefer reusable primitives over mode-specific shortcuts.

## Confirmed Scope

For any non-trivial feature or architecture-sensitive change:

1. Restate the requested behavior in plain language.
2. Identify the smallest module/mechanic that should own that behavior.
3. Explicitly list what is out of scope.
4. Ask for confirmation before coding.

Do not add adjacent functionality, convenience behavior, gameplay rules, UI flow, persistence, monetization, matchmaking, randomization, telemetry, or diagnostics unless it is explicitly requested or confirmed as part of the current layer.

Tiny mechanical fixes, obvious typo fixes, and direct test commands do not need a confirmation round unless they change behavior or ownership.

## Layer Boundaries

Use separate mechanics for separate responsibilities:

- Handshake / matchmaking: find eligible devices or players and put them in the same session. It does not choose maps, randomize gameplay, start countdowns, award prizes, or run gameplay.
- Session setup: records who is in the match, what mode/session identity they share, and what authority will coordinate the next step.
- Pregame setup: chooses shared map/rules/randomizer/countdown and prepares all clients from the agreed session.
- Gameplay runtime: runs the match from already-agreed setup.
- Postgame: handles results, rewards, reports, replays, and progression.

If a requested feature crosses one of these boundaries, implement the first confirmed layer only, then propose the next layer separately.

## Helper Extraction

- When a file starts owning multiple responsibilities, extract helper modules around stable responsibilities.
- Helpers should have a narrow contract and a clear owner.
- Avoid helpers that merely move complexity sideways; extract when the boundary makes reasoning, testing, or reuse better.
- Keep orchestration code thin: it should call dedicated mechanics rather than become the mechanic.

## State And Context

- Shared context should carry only facts needed by the current authority.
- Do not pass future-step decisions through an earlier authority just because the data is available.
- Derived or randomized values should be produced by the layer that owns that decision.
- If two clients need the same derived result, seed it from shared session state or have the owning authority publish it once.

## Implementation Discipline

- Prefer existing project patterns and local helper APIs.
- Keep changes surgical and scoped to the confirmed mechanic.
- Add tests at the boundary being changed.
- If existing code violates these rules, do not expand the violation. Either isolate it or propose a cleanup layer.
