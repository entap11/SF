Swarmfront Canon v1 (Hive + Lane Core)

Version lock
- Target Godot 4.2.x only.

Entity naming
- Use "Hive" in code and docs (not "Tower").

Owner / Team IDs
- 0 = NPC (White)
- 1 = P1 (Yellow)
- 2 = P2 (Black)
- 3 = P3 (Red)
- 4 = P4 (Blue)

Hive state
- owner_id: int (0..4)
- power: int (0..50)
- grid_pos: Vector2i (grid cell)

Neutral rule (NPC)
- NPC is only the starting state.
- Once claimed (owner_id becomes 1..4), the hive never returns to owner_id 0.
- While owner_id == 0:
  - No spawning.
  - max_out_lanes = 0 (cannot be a lane source).

Combat / arrival rules
- Case A: NPC hive (owner_id == 0)
  - If power == 0 and a unit arrives, claim immediately:
    - owner_id = unit_owner
    - power = 1
- Case B: Friendly unit arrives (owner_id == unit_owner)
  - If power < 50: power += 1
  - If power == 50: no increase; apply pass-through
- Case C: Enemy unit arrives (owner_id != 0 and owner_id != unit_owner)
  - power -= 1
  - If power == -1: flip immediately
    - owner_id = unit_owner
    - power = 1
  - If power >= 0: ownership stays the same

Power tiers (outgoing lane capacity)
- power 0..9: max_out_lanes = 1
- power 10..24: max_out_lanes = 2
- power 25..50: max_out_lanes = 3
- If owner_id == 0: max_out_lanes = 0

Send interval (power 0 produces)
- BASE_MS = 1000
- PER_POWER_MS = 2
- BONUS_10_MS = 2 if power >= 10
- BONUS_25_MS = 2 if power >= 25
- interval_ms = BASE_MS - (power * PER_POWER_MS) - BONUS_10_MS - BONUS_25_MS
- Clamp to a safe minimum (e.g., 200ms) to prevent extremes.
- If owner_id == 0: do not spawn.

Power 50 pass-through
- Friendly unit arriving at power 50 does not increase power.
- Unit is forwarded along an outgoing lane if any exist.
- If no outgoing lane exists, the unit is removed.

Lane canon (single lane, one-way at a time)
- Between any two hives A and B, there is only one lane ever.
- Lane identity is the unordered pair (min(a_id,b_id), max(a_id,b_id)).
- Each lane stores:
  - id
  - a_id, b_id
  - dir: +1 means a->b, -1 means b->a
- Flow is only from src_id -> dst_id based on dir.

Lane reversal ("available lane" rule)
- A lane may reverse only if the new source hive has outgoing capacity available.
- Disallow reversal if new_src.owner_id == 0.
- outgoing_count(hive_id) = number of lanes where src_id == hive_id
- Allow reversal if outgoing_count(new_src) < max_out_lanes(new_src.power)
- On reversal, lane.dir *= -1

End of canon
