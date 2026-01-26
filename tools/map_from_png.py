#!/usr/bin/env python3
import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple

from PIL import Image

GRID_WIDTH = 12
GRID_HEIGHT = 8

COLOR_P1 = (255, 192, 0)
COLOR_P2 = (255, 43, 43)
COLOR_NPC = (168, 199, 255)
COLOR_WALL = (51, 51, 51)

KNOWN_COLORS = {
    COLOR_P1: "P1_HIVE",
    COLOR_P2: "P2_HIVE",
    COLOR_NPC: "NPC",
    COLOR_WALL: "WALL",
}


@dataclass
class TileHit:
    x: int
    y: int
    kinds: List[str]
    counts: Dict[str, int]


def _warn(msg: str) -> None:
    sys.stderr.write(msg + "\n")


def _error(msg: str) -> None:
    sys.stderr.write(msg + "\n")
    sys.exit(1)


def _iter_tile_pixels(
    pixels, tile_x: int, tile_y: int, tile_w: int, tile_h: int
) -> Iterable[Tuple[int, int, int]]:
    start_x = tile_x * tile_w
    start_y = tile_y * tile_h
    for py in range(start_y, start_y + tile_h):
        for px in range(start_x, start_x + tile_w):
            yield pixels[px, py]

def _scan_tile(
    pixels,
    tile_x: int,
    tile_y: int,
    tile_w: int,
    tile_h: int,
) -> TileHit:
    counts: Dict[str, int] = {}
    for color in _iter_tile_pixels(pixels, tile_x, tile_y, tile_w, tile_h):
        rgb = tuple(color[:3])
        kind = KNOWN_COLORS.get(rgb)
        if kind:
            counts[kind] = counts.get(kind, 0) + 1
    kinds = list(counts.keys())
    if len(kinds) > 1:
        _warn(
            "Warning: multiple gameplay colors in tile (%d, %d): %s"
            % (tile_x, tile_y, ", ".join(sorted(kinds)))
        )
    return TileHit(tile_x, tile_y, kinds, counts)


def _load_image(path: Path) -> Image.Image:
    try:
        img = Image.open(path)
    except Exception as exc:
        _error("Failed to open image: %s" % exc)
    return img.convert("RGB")



def _kind_priority(kind: str) -> int:
    order = ["WALL", "NPC", "P2_HIVE", "P1_HIVE"]
    try:
        return order.index(kind) + 1
    except ValueError:
        return 0


def _pick_kind(hit: TileHit) -> Optional[str]:
    if not hit.kinds:
        return None
    return max(
        hit.kinds,
        key=lambda k: (
            _kind_priority(k),
            hit.counts.get(k, 0),
            k == "P1_HIVE",
        ),
    )


def _build_map_data(
    hits: List[TileHit], map_id: str, map_name: str
) -> Dict[str, object]:
    hives: List[Dict[str, object]] = []
    npcs: List[Dict[str, int]] = []
    walls: List[Dict[str, int]] = []

    p1_count = 0
    p2_count = 0

    for hit in hits:
        kind = _pick_kind(hit)
        if kind is None:
            continue
        if kind == "P1_HIVE":
            p1_count += 1
            hive_id = "P1_MAIN" if p1_count == 1 else "P1_H%d" % p1_count
            tier = "MAX" if p1_count == 1 else "MEDIUM"
            hives.append(
                {
                    "id": hive_id,
                    "x": hit.x,
                    "y": hit.y,
                    "tier": tier,
                    "owner": "P1",
                }
            )
        elif kind == "P2_HIVE":
            p2_count += 1
            hive_id = "P2_MAIN" if p2_count == 1 else "P2_H%d" % p2_count
            tier = "MAX" if p2_count == 1 else "MEDIUM"
            hives.append(
                {
                    "id": hive_id,
                    "x": hit.x,
                    "y": hit.y,
                    "tier": tier,
                    "owner": "P2",
                }
            )
        elif kind == "NPC":
            npcs.append({"x": hit.x, "y": hit.y})
        elif kind == "WALL":
            walls.append({"x": hit.x, "y": hit.y})

    return {
        "id": map_id,
        "name": map_name,
        "grid_width": GRID_WIDTH,
        "grid_height": GRID_HEIGHT,
        "hives": hives,
        "npcs": npcs,
        "walls": walls,
        "towers": [],
        "barracks": [],
        "spawns": [],
        "lanes": [],
    }


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate SwarmFront map JSON from a color-coded PNG."
    )
    parser.add_argument("input_png", help="Path to input PNG")
    parser.add_argument("--id", required=True, help="Map id to embed in JSON")
    parser.add_argument("--name", required=True, help="Human-readable map name")
    return parser.parse_args(argv)


def main() -> None:
    args = parse_args()
    input_path = Path(args.input_png)
    if not input_path.exists():
        _error("Input PNG not found: %s" % input_path)

    img = _load_image(input_path)
    width, height = img.size

    if width % GRID_WIDTH != 0 or height % GRID_HEIGHT != 0:
        if width % GRID_HEIGHT == 0 and height % GRID_WIDTH == 0:
            _warn("Image appears rotated; rotating 90 degrees to fit 12x8 grid")
            img = img.transpose(Image.Transpose.ROTATE_90)
            width, height = img.size
        else:
            _error(
                "Image size %dx%d not divisible by grid %dx%d"
                % (width, height, GRID_WIDTH, GRID_HEIGHT)
            )

    if width % GRID_WIDTH != 0 or height % GRID_HEIGHT != 0:
        _error(
            "Image size %dx%d not divisible by grid %dx%d"
            % (width, height, GRID_WIDTH, GRID_HEIGHT)
        )

    tile_w = width // GRID_WIDTH
    tile_h = height // GRID_HEIGHT

    pixels = img.load()
    hits: List[TileHit] = []
    for y in range(GRID_HEIGHT):
        for x in range(GRID_WIDTH):
            hit = _scan_tile(
                pixels,
                x,
                y,
                tile_w,
                tile_h,
            )
            hits.append(hit)

    map_data = _build_map_data(hits, args.id, args.name)
    json.dump(map_data, sys.stdout, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
