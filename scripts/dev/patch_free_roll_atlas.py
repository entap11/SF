#!/usr/bin/env python3

from __future__ import annotations

import re
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
PNG_PATH = ROOT / "assets/fonts/atlas_free_roll_source.png"
FONT_TRES_PATH = ROOT / "assets/fonts/free_roll_display_v2_font.tres"

ATLAS_SIZE = (1536, 1024)
CELL_SIZE = (192, 125)
SCALE = 4
CELL_HI = (CELL_SIZE[0] * SCALE, CELL_SIZE[1] * SCALE)

# Grid positions inferred from the existing atlas.
GLYPH_CELLS = {
    "A": (0, 0),
    "E": (4, 0),
    "F": (5, 0),
    "O": (6, 1),
    "0": (0, 4),
}


def _new_mask() -> Image.Image:
    return Image.new("L", CELL_HI, 0)


def _downsample(mask: Image.Image) -> Image.Image:
    return mask.resize(CELL_SIZE, Image.Resampling.LANCZOS)


def _paste_mask(img: Image.Image, name: str, mask: Image.Image) -> None:
    cell_x, cell_y = GLYPH_CELLS[name]
    x0 = cell_x * CELL_SIZE[0]
    y0 = cell_y * CELL_SIZE[1]
    rgba = Image.new("RGBA", CELL_SIZE, (255, 255, 255, 0))
    rgba.putalpha(_downsample(mask))
    img.alpha_composite(rgba, (x0, y0))


def _draw_a() -> Image.Image:
    mask = _new_mask()
    draw = ImageDraw.Draw(mask)
    w = 88
    left_base = (176, 452)
    apex = (384, 40)
    right_base = (592, 452)
    draw.line([left_base, apex], fill=255, width=w)
    draw.line([apex, right_base], fill=255, width=w)
    # The A only gets the cut motif at the cross.
    draw.ellipse((330, 234, 438, 342), fill=255)
    return mask


def _draw_e() -> Image.Image:
    mask = _new_mask()
    draw = ImageDraw.Draw(mask)
    stem = (74, 34, 172, 466)
    top_bar = (74, 34, 612, 118)
    bottom_bar = (74, 382, 612, 466)
    draw.rounded_rectangle(stem, radius=12, fill=255)
    draw.rounded_rectangle(top_bar, radius=12, fill=255)
    draw.rounded_rectangle(bottom_bar, radius=12, fill=255)
    # Replace the middle dash with a dot.
    draw.ellipse((300, 206, 408, 314), fill=255)
    return mask


def _draw_f() -> Image.Image:
    mask = _new_mask()
    draw = ImageDraw.Draw(mask)
    stem = (74, 34, 172, 466)
    top_bar = (74, 34, 592, 118)
    mid_bar = (74, 206, 476, 286)
    draw.rounded_rectangle(stem, radius=12, fill=255)
    draw.rounded_rectangle(top_bar, radius=12, fill=255)
    draw.rounded_rectangle(mid_bar, radius=12, fill=255)
    # The lower terminal gets the dot treatment instead of a broad cut.
    draw.ellipse((82, 374, 162, 454), fill=255)
    return mask


def _draw_o() -> Image.Image:
    mask = _new_mask()
    draw = ImageDraw.Draw(mask)
    outer = (72, 26, 616, 474)
    draw.ellipse(outer, fill=255)
    # Only a dot inside the O, not a full hollow counter.
    draw.ellipse((302, 192, 386, 276), fill=0)
    return mask


def _draw_zero() -> Image.Image:
    mask = _new_mask()
    draw = ImageDraw.Draw(mask)
    outer = [(176, 40), (472, 40), (598, 126), (598, 374), (472, 460), (176, 460), (50, 374), (50, 126)]
    draw.polygon(outer, fill=255)
    # Only a dot inside the zero.
    draw.ellipse((294, 190, 390, 286), fill=0)
    return mask


def _render_replacements() -> dict[str, Image.Image]:
    return {
        "A": _draw_a(),
        "E": _draw_e(),
        "F": _draw_f(),
        "O": _draw_o(),
        "0": _draw_zero(),
    }


def _sync_font_tres_from_png(img: Image.Image) -> None:
    raw = ",".join(str(b) for b in img.tobytes())
    text = FONT_TRES_PATH.read_text()
    pattern = re.compile(
        r'data = \{\n"data": PackedByteArray\((.*?)\),\n"format": "RGBA8",\n"height": 1024,\n"mipmaps": false,\n"width": 1536\n\}',
        re.S,
    )
    replacement = (
        'data = {\n'
        f'"data": PackedByteArray({raw}),\n'
        '"format": "RGBA8",\n'
        '"height": 1024,\n'
        '"mipmaps": false,\n'
        '"width": 1536\n'
        '}'
    )
    updated, count = pattern.subn(replacement, text, count=1)
    if count != 1:
        raise RuntimeError("Failed to locate embedded atlas image in free_roll_display_v2_font.tres")
    FONT_TRES_PATH.write_text(updated)


def main() -> None:
    img = Image.open(PNG_PATH).convert("RGBA")
    if img.size != ATLAS_SIZE:
        raise RuntimeError(f"Unexpected atlas size: {img.size}")
    replacements = _render_replacements()
    for name, mask in replacements.items():
        _paste_mask(img, name, mask)
    img.save(PNG_PATH)
    _sync_font_tres_from_png(img)


if __name__ == "__main__":
    main()
