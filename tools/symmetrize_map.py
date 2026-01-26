#!/usr/bin/env python3
import argparse
import json
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple


def _warn(msg: str) -> None:
    sys.stderr.write(msg + "\n")


def _error(msg: str) -> None:
    sys.stderr.write(msg + "\n")
    sys.exit(1)


def mirror_x(x: int, width: int) -> int:
    return width - 1 - x


def _swap_owner(owner: str) -> str:
    if owner == "P1":
        return "P2"
    if owner == "P2":
        return "P1"
    return owner


def _mirror_hive_id_base(hive_id: str) -> str:
    if hive_id.startswith("P1_"):
        return "P2_" + hive_id[3:]
    if hive_id.startswith("P2_"):
        return "P1_" + hive_id[3:]
    if hive_id:
        return hive_id + "_MIRROR"
    return "HIVE"


def _reserve_id(
    desired: str,
    id_counts: Dict[str, int],
    counter: int,
    allow_duplicate: bool = False,
) -> Tuple[str, int]:
    if desired and desired not in id_counts:
        id_counts[desired] = 1
        return desired, counter
    if desired and allow_duplicate:
        id_counts[desired] = id_counts.get(desired, 0) + 1
        return desired, counter
    while True:
        candidate = "HIVE_%d" % counter
        counter += 1
        if candidate not in id_counts:
            id_counts[candidate] = 1
            return candidate, counter


def _release_id(hive_id: str, id_counts: Dict[str, int]) -> None:
    if not hive_id:
        return
    if hive_id not in id_counts:
        return
    id_counts[hive_id] -= 1
    if id_counts[hive_id] <= 0:
        del id_counts[hive_id]


def _hive_mismatch(a: Dict[str, object], b: Dict[str, object]) -> bool:
    if str(a.get("owner", "")) != str(b.get("owner", "")):
        return True
    if str(a.get("tier", "")) != str(b.get("tier", "")):
        return True
    if str(a.get("id", "")) != str(b.get("id", "")):
        return True
    return False


def symmetrize_hives(map_data: dict) -> Dict[str, str]:
    width = int(map_data.get("grid_width", 0))
    if width <= 0:
        _error("Invalid grid_width in map data")
    mid_x = width // 2

    hives = map_data.get("hives", [])
    if not isinstance(hives, list):
        hives = []
    map_data["hives"] = hives

    id_counts: Dict[str, int] = {}
    for hive in hives:
        hive_id = str(hive.get("id", ""))
        if hive_id:
            id_counts[hive_id] = id_counts.get(hive_id, 0) + 1

    pos_index: Dict[Tuple[int, int], Dict[str, object]] = {}
    for hive in hives:
        pos = (int(hive.get("x", 0)), int(hive.get("y", 0)))
        if pos in pos_index:
            _warn("Warning: duplicate hive position at (%d,%d)" % pos)
            continue
        pos_index[pos] = hive

    left_positions = set()
    for hive in hives:
        x = int(hive.get("x", 0))
        y = int(hive.get("y", 0))
        if x < mid_x:
            left_positions.add((x, y))

    hive_id_map: Dict[str, str] = {}
    counter = 1

    for hive in list(hives):
        x = int(hive.get("x", 0))
        y = int(hive.get("y", 0))
        if x >= mid_x:
            continue
        mx = mirror_x(x, width)
        mirror_pos = (mx, y)

        original_id = str(hive.get("id", ""))
        owner = str(hive.get("owner", ""))
        owner_m = _swap_owner(owner)

        desired_id = _mirror_hive_id_base(original_id)
        allow_dup = desired_id.startswith("P1_") or desired_id.startswith("P2_")

        existing = pos_index.get(mirror_pos)
        if existing is None:
            new_id, counter = _reserve_id(desired_id, id_counts, counter, allow_dup)
            new_hive = dict(hive)
            new_hive["x"] = mx
            new_hive["y"] = y
            new_hive["owner"] = owner_m
            new_hive["id"] = new_id
            hives.append(new_hive)
            pos_index[mirror_pos] = new_hive
            if original_id:
                hive_id_map[original_id] = new_id
            if new_id:
                hive_id_map[new_id] = original_id
        else:
            old_id = str(existing.get("id", ""))
            if old_id != "":
                _release_id(old_id, id_counts)
            new_id, counter = _reserve_id(desired_id, id_counts, counter, allow_dup)
            new_hive = dict(hive)
            new_hive["x"] = mx
            new_hive["y"] = y
            new_hive["owner"] = owner_m
            new_hive["id"] = new_id
            if _hive_mismatch(existing, new_hive):
                _warn("Warning: overwriting hive at (%d,%d)" % mirror_pos)
            existing.clear()
            existing.update(new_hive)
            if original_id:
                hive_id_map[original_id] = new_id
            if new_id:
                hive_id_map[new_id] = original_id

    for hive in hives:
        x = int(hive.get("x", 0))
        y = int(hive.get("y", 0))
        if x >= mid_x:
            if (mirror_x(x, width), y) not in left_positions:
                _warn(
                    "Warning: unsymmetrized right-side hive at (%d,%d)" % (x, y)
                )

    p1_hives = [h for h in hives if str(h.get("id", "")) == "P1_MAIN"]
    p2_hives = [h for h in hives if str(h.get("id", "")) == "P2_MAIN"]

    p1 = p1_hives[0] if p1_hives else None
    p2 = p2_hives[0] if p2_hives else None

    if p1 is None and p2 is None:
        _error("Missing both P1_MAIN and P2_MAIN hives")
    elif p1 is not None and int(p1.get("x", 0)) < mid_x:
        _ensure_main_mirror(
            source=p1,
            target_id="P2_MAIN",
            target_owner="P2",
            width=width,
            hives=hives,
            pos_index=pos_index,
            id_counts=id_counts,
        )
    elif p2 is not None and int(p2.get("x", 0)) < mid_x:
        _ensure_main_mirror(
            source=p2,
            target_id="P1_MAIN",
            target_owner="P1",
            width=width,
            hives=hives,
            pos_index=pos_index,
            id_counts=id_counts,
        )
    else:
        _warn("Warning: main hives are not on the left side")

    _dedupe_hive_ids(hives, mid_x)

    p1_hives = [h for h in hives if str(h.get("id", "")) == "P1_MAIN"]
    p2_hives = [h for h in hives if str(h.get("id", "")) == "P2_MAIN"]
    if len(p1_hives) == 0 or len(p2_hives) == 0:
        _warn("Warning: missing P1_MAIN or P2_MAIN after dedupe")
    if len(p1_hives) > 1:
        _warn("Warning: multiple P1_MAIN hives found")
    if len(p2_hives) > 1:
        _warn("Warning: multiple P2_MAIN hives found")

    return hive_id_map


def _ensure_main_mirror(
    source: Dict[str, object],
    target_id: str,
    target_owner: str,
    width: int,
    hives: List[Dict[str, object]],
    pos_index: Dict[Tuple[int, int], Dict[str, object]],
    id_counts: Dict[str, int],
) -> None:
    x = int(source.get("x", 0))
    y = int(source.get("y", 0))
    mx = mirror_x(x, width)
    mirror_pos = (mx, y)
    existing = pos_index.get(mirror_pos)
    if existing is None:
        new_hive = dict(source)
        new_hive["x"] = mx
        new_hive["y"] = y
        new_hive["id"] = target_id
        new_hive["owner"] = target_owner
        hives.append(new_hive)
        pos_index[mirror_pos] = new_hive
        id_counts[target_id] = id_counts.get(target_id, 0) + 1
    else:
        old_id = str(existing.get("id", ""))
        if old_id != "":
            _release_id(old_id, id_counts)
        existing.clear()
        existing.update(dict(source))
        existing["x"] = mx
        existing["y"] = y
        existing["id"] = target_id
        existing["owner"] = target_owner
        id_counts[target_id] = id_counts.get(target_id, 0) + 1


def _select_main_hive(
    candidates: List[Dict[str, object]], prefer_right: bool, mid_x: int
) -> Dict[str, object]:
    if not candidates:
        return {}
    if prefer_right:
        right = [h for h in candidates if int(h.get("x", 0)) >= mid_x]
        if right:
            return max(right, key=lambda h: int(h.get("x", 0)))
    else:
        left = [h for h in candidates if int(h.get("x", 0)) < mid_x]
        if left:
            return min(left, key=lambda h: int(h.get("x", 0)))
    return candidates[0]


def _dedupe_hive_ids(hives: List[Dict[str, object]], mid_x: int) -> None:
    by_id: Dict[str, List[Dict[str, object]]] = {}
    used: Dict[str, bool] = {}
    for hive in hives:
        hive_id = str(hive.get("id", ""))
        if not hive_id:
            continue
        by_id.setdefault(hive_id, []).append(hive)
        used[hive_id] = True

    counter = 1

    def next_id() -> str:
        nonlocal counter
        while True:
            candidate = "HIVE_%d" % counter
            counter += 1
            if candidate not in used:
                used[candidate] = True
                return candidate

    for main_id, prefer_right in (("P1_MAIN", False), ("P2_MAIN", True)):
        lst = by_id.get(main_id, [])
        if len(lst) <= 1:
            continue
        keep = _select_main_hive(lst, prefer_right, mid_x)
        for hive in lst:
            if hive is keep:
                continue
            new_id = next_id()
            _warn(
                "Warning: renaming duplicate %s at (%d,%d) to %s"
                % (main_id, int(hive.get("x", 0)), int(hive.get("y", 0)), new_id)
            )
            hive["id"] = new_id

    for hive_id, lst in by_id.items():
        if hive_id in ("P1_MAIN", "P2_MAIN", ""):
            continue
        if len(lst) <= 1:
            continue
        for hive in lst[1:]:
            new_id = next_id()
            _warn(
                "Warning: renaming duplicate %s at (%d,%d) to %s"
                % (hive_id, int(hive.get("x", 0)), int(hive.get("y", 0)), new_id)
            )
            hive["id"] = new_id


def _structure_mismatch(existing: Dict[str, object], mirrored: Dict[str, object]) -> bool:
    for field in ("tier", "owner"):
        if field in existing or field in mirrored:
            if str(existing.get(field, "")) != str(mirrored.get(field, "")):
                return True
    return False


def symmetrize_structures(map_data: dict, key: str) -> None:
    width = int(map_data.get("grid_width", 0))
    if width <= 0:
        _error("Invalid grid_width in map data")
    mid_x = width // 2

    items = map_data.get(key, [])
    if not isinstance(items, list):
        items = []
    map_data[key] = items

    pos_index: Dict[Tuple[int, int], Dict[str, object]] = {}
    for obj in items:
        pos = (int(obj.get("x", 0)), int(obj.get("y", 0)))
        if pos in pos_index:
            _warn("Warning: duplicate %s position at (%d,%d)" % (key, pos[0], pos[1]))
            continue
        pos_index[pos] = obj

    left_positions = set()
    for obj in items:
        x = int(obj.get("x", 0))
        y = int(obj.get("y", 0))
        if x < mid_x:
            left_positions.add((x, y))

    for obj in list(items):
        x = int(obj.get("x", 0))
        y = int(obj.get("y", 0))
        if x >= mid_x:
            continue
        mx = mirror_x(x, width)
        mirror_pos = (mx, y)
        mirrored = dict(obj)
        mirrored["x"] = mx
        mirrored["y"] = y

        existing = pos_index.get(mirror_pos)
        if existing is None:
            items.append(mirrored)
            pos_index[mirror_pos] = mirrored
        else:
            if _structure_mismatch(existing, mirrored):
                _warn(
                    "Warning: overwriting %s at (%d,%d)" % (key, mirror_pos[0], mirror_pos[1])
                )
            existing.clear()
            existing.update(mirrored)

    for obj in items:
        x = int(obj.get("x", 0))
        y = int(obj.get("y", 0))
        if x >= mid_x:
            if (mirror_x(x, width), y) not in left_positions:
                _warn(
                    "Warning: unsymmetrized right-side %s at (%d,%d)" % (key, x, y)
                )


def _mirror_hive_id(hive_id: str, hive_id_map: Dict[str, str]) -> Optional[str]:
    if hive_id in hive_id_map:
        return hive_id_map[hive_id]
    if hive_id.startswith("P1_"):
        return "P2_" + hive_id[3:]
    if hive_id.startswith("P2_"):
        return "P1_" + hive_id[3:]
    return None


def symmetrize_lanes(map_data: dict, hive_id_map: Dict[str, str], width: int) -> None:
    lanes = map_data.get("lanes", [])
    if not isinstance(lanes, list):
        lanes = []
    new_lanes: List[Dict[str, object]] = list(lanes)

    for lane in lanes:
        if not isinstance(lane, dict):
            continue
        from_id = str(lane.get("from_hive", ""))
        to_id = str(lane.get("to_hive", ""))
        if not from_id or not to_id:
            continue
        mirror_from = _mirror_hive_id(from_id, hive_id_map)
        mirror_to = _mirror_hive_id(to_id, hive_id_map)
        if mirror_from is None or mirror_to is None:
            _warn(
                "Warning: cannot mirror lane from %s to %s" % (from_id, to_id)
            )
            continue
        path = lane.get("path", [])
        if not isinstance(path, list):
            path = []
        mirrored_path: List[Dict[str, int]] = []
        for point in path:
            if not isinstance(point, dict):
                continue
            x = int(point.get("x", 0))
            y = int(point.get("y", 0))
            mirrored_path.append({"x": mirror_x(x, width), "y": y})
        mirrored_lane = dict(lane)
        mirrored_lane["from_hive"] = mirror_from
        mirrored_lane["to_hive"] = mirror_to
        mirrored_lane["path"] = mirrored_path
        new_lanes.append(mirrored_lane)

    map_data["lanes"] = new_lanes


def _load_json(path: Path) -> dict:
    if not path.exists():
        _error("Input JSON not found: %s" % path)
    try:
        with path.open("r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as exc:
        _error("Failed to read JSON: %s" % exc)
    if not isinstance(data, dict):
        _error("JSON root must be an object")
    return data


def _save_json(path: Path, data: dict) -> None:
    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def main() -> None:
    parser = argparse.ArgumentParser(description="Symmetrize SwarmFront map JSON.")
    parser.add_argument("input_json", help="Input JSON path")
    parser.add_argument("output_json", help="Output JSON path")
    args = parser.parse_args()

    input_path = Path(args.input_json)
    output_path = Path(args.output_json)

    map_data = _load_json(input_path)

    width = int(map_data.get("grid_width", 0))
    if width <= 0 or width % 2 != 0:
        _error("grid_width must be a positive even number")

    map_id = str(map_data.get("id", ""))
    map_name = str(map_data.get("name", ""))
    if map_id:
        map_data["id"] = map_id + "_SYM"
    if map_name:
        map_data["name"] = map_name + " (Sym)"

    hive_id_map = symmetrize_hives(map_data)
    symmetrize_structures(map_data, "towers")
    symmetrize_structures(map_data, "barracks")
    symmetrize_lanes(map_data, hive_id_map, width)

    _save_json(output_path, map_data)


if __name__ == "__main__":
    main()
