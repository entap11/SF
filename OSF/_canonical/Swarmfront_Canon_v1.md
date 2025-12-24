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

Lane canon (one lane per pair)
- Between any two hives A and B, there is only one lane ever.
- Lane identity is the unordered pair (min(a_id,b_id), max(a_id,b_id)).
- Each lane stores:
  - id
  - a_id, b_id
  - dir: +1 means a->b, -1 means b->a (used for friendly lanes)
  - sending_from_a, sending_from_b (bools, for opposing lanes)
  - a_pressure, b_pressure (float, opposing lanes)
  - a_stream_len_px, b_stream_len_px (float, for lane growth)

Lane modes
- FRIENDLY: A.owner_id == B.owner_id and owner_id != 0
  - Exactly one active direction at a time (use dir).
  - Lane color is the origin hive's color.
  - Segmentation (dash length) uses origin interval_ms.
  - Lane grows from origin as first unit advances (stream_len).
- OPPOSING: A.owner_id != B.owner_id and both owner_id != 0
  - Each side may be attacking independently.
  - One-way if only one side attacks.
  - Split if both attack, with impact point between colors.
- NEUTRAL_INVOLVED: at least one owner_id == 0
  - NPC does not originate flow.
  - Only the claimed side may send toward NPC until it is claimed.

Lane reversal ("available lane" rule)
- A lane may reverse only if the new source hive has outgoing capacity available.
- Disallow reversal if new_src.owner_id == 0.
- outgoing_count(hive_id) = number of lanes where src_id == hive_id
- Allow reversal if outgoing_count(new_src) < max_out_lanes(new_src.power)
- On reversal, lane.dir *= -1

Lane visual growth (origin-reveal rule)
- A lane appears starting at the origin hive and grows as the first unit travels.
- Each active stream has a visible length:
  - stream_len_px += unit_speed_px_per_s * dt
  - clamp to lane length
- For opposing lanes, draw from each origin toward the impact point, but clamp by that side's stream_len.

Lane segmentation (tempo encoding)
- segment_len_px = unit_speed_px_per_s * (interval_ms / 1000.0)
- gap_px = 6 (constant for now)
- Draw dashed segments from origin toward destination or impact point.

Opposing lane impact point (stateful)
- Maintain a_pressure and b_pressure.
- If A is attacking: a_pressure += rate_a * dt
- If B is attacking: b_pressure += rate_b * dt
- rate = 1 / interval_seconds
- If both pressures > 0:
  - f = a_pressure / (a_pressure + b_pressure)
  - impact_pos = lerp(pos_a, pos_b, f)
- This means equal hives do not necessarily meet at midpoint unless they started together.

Selector intent (tap + drag)
- Tap = click for dev; touch will map 1:1 later.
- Two ways to ENABLE intent (attack/feed) from origin -> target:
  - Tap origin, then tap target (neighbor with a lane).
  - Press/hold origin, drag to target, release.
- Two ways to DISABLE intent origin -> target:
  - Tap target, then tap origin.
  - Press/hold target, drag back to origin, release.
- Drag preview line:
  - Gray by default.
  - Turns player color when hovering a valid target (lane exists).
- Haptics:
  - On drag-hover entering a valid target, vibrate once (20–35ms).
  - Do not spam; pulse only on hover-enter or target change.

NPC selectability
- NPC (owner_id == 0) cannot be an origin for tap or drag.
- NPC can be a valid target (end of a lane) for intent.
- Tapping NPC alone does nothing (no selection as origin).

End of canon
