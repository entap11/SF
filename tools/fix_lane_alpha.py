#!/usr/bin/env python3
"""Fix baked checkerboard transparency in lane_final.png.

Requires: Pillow, numpy
"""

from __future__ import annotations

import argparse
import json
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

TOL_DEFAULT = 18


def _border_mask(h: int, w: int, border: int) -> np.ndarray:
    mask = np.zeros((h, w), dtype=bool)
    b = max(1, border)
    mask[:b, :] = True
    mask[-b:, :] = True
    mask[:, :b] = True
    mask[:, -b:] = True
    return mask


def _kmeans2(pixels: np.ndarray, iters: int = 10) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    # pixels: (N, 3) float32
    mean = pixels.mean(axis=0)
    idx1 = int(np.argmax(np.sum((pixels - mean) ** 2, axis=1)))
    c1 = pixels[idx1].copy()
    idx2 = int(np.argmax(np.sum((pixels - c1) ** 2, axis=1)))
    c2 = pixels[idx2].copy()

    for _ in range(iters):
        d1 = np.sum((pixels - c1) ** 2, axis=1)
        d2 = np.sum((pixels - c2) ** 2, axis=1)
        mask = d1 <= d2
        if mask.any():
            c1 = pixels[mask].mean(axis=0)
        if (~mask).any():
            c2 = pixels[~mask].mean(axis=0)
    # final assignment
    d1 = np.sum((pixels - c1) ** 2, axis=1)
    d2 = np.sum((pixels - c2) ** 2, axis=1)
    mask = d1 <= d2
    return c1, c2, mask, ~mask


def _dilate(mask: np.ndarray) -> np.ndarray:
    h, w = mask.shape
    padded = np.pad(mask, 1, mode="constant", constant_values=False)
    out = np.zeros((h, w), dtype=bool)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            out |= padded[1 + dy : 1 + dy + h, 1 + dx : 1 + dx + w]
    return out


def _erode(mask: np.ndarray) -> np.ndarray:
    h, w = mask.shape
    padded = np.pad(mask, 1, mode="constant", constant_values=False)
    out = np.ones((h, w), dtype=bool)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            out &= padded[1 + dy : 1 + dy + h, 1 + dx : 1 + dx + w]
    return out


def _close(mask: np.ndarray) -> np.ndarray:
    return _erode(_dilate(mask))


def _flood_fill_background(mask: np.ndarray) -> np.ndarray:
    h, w = mask.shape
    bg = np.zeros((h, w), dtype=bool)
    q: deque[tuple[int, int]] = deque()

    # seed from border
    for x in range(w):
        if mask[0, x]:
            q.append((0, x))
        if mask[h - 1, x]:
            q.append((h - 1, x))
    for y in range(h):
        if mask[y, 0]:
            q.append((y, 0))
        if mask[y, w - 1]:
            q.append((y, w - 1))

    while q:
        y, x = q.popleft()
        if y < 0 or y >= h or x < 0 or x >= w:
            continue
        if bg[y, x] or not mask[y, x]:
            continue
        bg[y, x] = True
        q.append((y - 1, x))
        q.append((y + 1, x))
        q.append((y, x - 1))
        q.append((y, x + 1))

    return bg


def _color_dist(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    return np.sqrt(np.sum((a - b) ** 2, axis=-1))


def _update_manifest(manifest_path: Path, baked: bool, fixed_rel: str, orig_rel: str) -> None:
    with manifest_path.open("r", encoding="utf-8") as f:
        data = json.load(f)

    sprites = data.get("sprites", {})
    for key in ("lane.segment", "lane.connector"):
        entry = sprites.get(key)
        if isinstance(entry, dict):
            entry["path"] = fixed_rel if baked else orig_rel
        elif isinstance(entry, str):
            sprites[key] = fixed_rel if baked else orig_rel

    with manifest_path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Fix baked checkerboard in lane_final.png")
    parser.add_argument("--tol", type=float, default=TOL_DEFAULT, help="color distance tolerance")
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    repo_root = Path(__file__).resolve().parents[1]
    lane_path = repo_root / "assets/sprites/sf_skin_v1/lane_final.png"
    out_path = repo_root / "assets/sprites/sf_skin_v1/lane_final_fixed.png"
    manifest_path = repo_root / "assets/sprites/sf_skin_v1/skin_manifest.json"

    if not lane_path.exists():
        raise SystemExit(f"missing: {lane_path}")

    img = Image.open(lane_path).convert("RGBA")
    arr = np.array(img)
    h, w = arr.shape[:2]

    border = int(max(2, min(12, min(h, w) * 0.06)))
    bmask = _border_mask(h, w, border)

    rgb = arr[:, :, :3].astype(np.float32)
    alpha = arr[:, :, 3]

    cand = rgb[bmask]
    cand_alpha = alpha[bmask]

    baked_checkered = False
    checker_colors = (np.array([0, 0, 0], dtype=np.float32), np.array([0, 0, 0], dtype=np.float32))

    if cand.size > 0:
        opaque_ratio = float(np.mean(cand_alpha > 200))
        if opaque_ratio > 0.6:
            c1, c2, m1, m2 = _kmeans2(cand.reshape(-1, 3), iters=12)
            dist = float(np.linalg.norm(c1 - c2))
            r1 = float(np.mean(m1))
            r2 = float(np.mean(m2))
            if dist >= 10.0 and r1 >= 0.15 and r2 >= 0.15:
                baked_checkered = True
                checker_colors = (c1, c2)

    # Build fixed image
    fixed = arr.copy()

    pixels_cleared = 0
    if baked_checkered:
        c1, c2 = checker_colors
        cand_pixels = cand.reshape(-1, 3)
        # Thresholds based on candidate pixels
        d1 = _color_dist(cand_pixels, c1)
        d2 = _color_dist(cand_pixels, c2)
        thr1 = float(np.percentile(d1, 95)) + float(args.tol)
        thr2 = float(np.percentile(d2, 95)) + float(args.tol)
        thr1 = max(8.0, min(45.0, thr1))
        thr2 = max(8.0, min(45.0, thr2))

        d1_full = _color_dist(rgb, c1)
        d2_full = _color_dist(rgb, c2)
        mask = (d1_full <= thr1) | (d2_full <= thr2)
        mask = _close(mask)
        bg_mask = _flood_fill_background(mask)
        fixed[bg_mask, 0:3] = 0
        fixed[bg_mask, 3] = 0
        pixels_cleared = int(np.count_nonzero(bg_mask))

    out_img = Image.fromarray(fixed, mode="RGBA")
    out_img.save(out_path)

    orig_rel = "res://assets/sprites/sf_skin_v1/lane_final.png"
    fixed_rel = "res://assets/sprites/sf_skin_v1/lane_final_fixed.png"
    _update_manifest(manifest_path, baked_checkered, fixed_rel, orig_rel)

    c1_i = tuple(int(round(x)) for x in checker_colors[0])
    c2_i = tuple(int(round(x)) for x in checker_colors[1])

    print(f"baked_checkered={str(baked_checkered).lower()}")
    print(f"checker_colors={c1_i} {c2_i}")
    print(f"wrote={out_path}")
    total_px = h * w
    pct = (pixels_cleared / total_px * 100.0) if total_px > 0 else 0.0
    print(f"total_pixels={total_px}")
    print(f"pixels_cleared={pixels_cleared}")
    print(f"percent_cleared={pct:.2f}")


if __name__ == "__main__":
    main()
