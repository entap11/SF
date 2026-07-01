# ENTaP Cinematics: In-Game Cinematic Triggers

Status: Deferred planning note

Category: ENTaP-Cinematics / In-Game Cinematic Triggers

Not current trailer v1. Revisit when the team has time and dedicated cinematic/FX talent.

## Core Idea

This is not trailer-only tech. It is in-game cinematic payoff tech.

The key premise:

> The sim knows.

Because the simulation can know whether a player action is decisive, the game can trigger cinematic payoff deterministically instead of faking spectacle.

## Victory Chase Cam Concept

1. Player launches a swarm.
2. The sim predicts that the swarm will create a final lethal hive outcome.
3. The game enters Victory Chase Cam.
4. Camera follows the winning swarm.
5. Impact animation plays: hive collapse, screen shake, glow burst.
6. Camera pulls back to the normal game camera.
7. Victory decision resolves normally.

The important part is that this celebrates the actual decisive move. It should not be random, cosmetic, or disconnected from the sim.

## Reusable Cinematics Pattern

```text
CinematicTrigger:
    lethal_final_attack_detected

CameraRig:
    chase_swarm

ImpactFX:
    hive_break

ReturnMode:
    pullback_to_game_camera
```

## Cross-Game Pattern

This should become a reusable ENTaP cinematic trigger pattern:

- Swarmfront: final swarm chase cam into hive break.
- Operation Fury: final HQ charge cam.
- OLH: last beam-break chase cam.
- Hyperballic: winning goal follow cam.

## Design Notes

- Trigger from sim authority, not from presentation guesswork.
- Resolve the actual match outcome normally after the cinematic beat.
- Keep the camera handoff brief and readable on mobile.
- Make the cinematic optional/tunable for competitive modes if needed.
- Treat this as a cinematics engine feature, not a one-off effect.

## Open Questions

- How early can the sim safely predict a lethal final attack without false positives?
- Should the camera follow the swarm packet, the leading unit cluster, or a generated cinematic target?
- How long can the camera leave the normal play view without harming competitive clarity?
- Should players be able to disable or reduce cinematic interruptions?
- What fallback plays when the decisive action is not visually trackable?
