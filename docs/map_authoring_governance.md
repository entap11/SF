# Map Authoring Governance

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
