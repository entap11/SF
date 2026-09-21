# Map Authoring Governance

## Usage and fairness

Every newly finalized map explicitly declares `map_usage`: `campaign`,
`multiplayer`, or `both`. Multiplayer and Both require exact layout symmetry and
equivalent player-start orbits. Walls, hives, neutral power, start power, slots,
and structure control relationships participate. Unequal counterparts must be
resolved in the retained source sector and regenerated, never accepted as close
enough. Only numerical floating-point tolerance is permitted.

The compiler, runtime contract, preview, and rollout boundaries are documented in
`docs/map_authoring_pipeline.md`; authoring controls and the grid template are in
`addons/map_sketch_tracer/README.md`. Public wall-map rollout remains sandboxed.

## Structure Slots

Tower and barracks placement should be authored as legal slots, not as random coordinates.

For new public nomansland variants, add `structure_slots` to the map JSON:

```json
"structure_slots": [
  { "id": "structure_slot_a", "pos": { "x": 5, "y": 13 }, "allowed": ["tower", "barracks"] },
  { "id": "structure_slot_b", "pos": { "x": 13, "y": 14 }, "allowed": ["tower", "barracks"] }
]
```

Rules:
- Slots mark where towers or barracks are allowed to appear; they do not create structures by themselves.
- Slots must not overlap hive cells.
- `allowed` must contain only `tower`, `barracks`, or both.
- The match setup randomizer owns whether slots are populated, which structure type is used, and the structure power.
- New 323/444 nomansland maps are audited for explicit `structure_slots`.

Legacy nomansland 545 maps receive a compatibility slot pair at load time until they are re-authored with explicit slots.
