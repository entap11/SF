#!/usr/bin/env python3
"""Regenerate the native drawing template. PNG output requires Pillow.

Usage: python3 tools/generate_map_grid.py [--font /path/to/font.ttf]
SVG is also retained as an editable, resolution-independent source.
"""
from argparse import ArgumentParser
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--font", type=Path)
    args = parser.parse_args()
    output = Path(__file__).resolve().parents[1] / "addons/map_sketch_tracer/templates"
    cols, rows, cell = 18, 28, 64
    width, height = cols * cell, rows * cell
    image = Image.new("RGB", (width, height), "white")
    draw = ImageDraw.Draw(image)
    font_path = args.font or Path("/System/Library/Fonts/Helvetica.ttc")
    font = ImageFont.truetype(str(font_path), 10) if font_path.exists() else ImageFont.load_default()
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
           f'<rect width="{width}" height="{height}" fill="white"/>']
    for x in range(cols + 1):
        draw.line((x * cell, 0, x * cell, height), fill="#c3ccda")
        svg.append(f'<path d="M{x * cell},0 V{height}" stroke="#c3ccda" stroke-width="1"/>')
    for y in range(rows + 1):
        draw.line((0, y * cell, width, y * cell), fill="#c3ccda")
        svg.append(f'<path d="M0,{y * cell} H{width}" stroke="#c3ccda" stroke-width="1"/>')
    for y in range(rows):
        for x in range(cols):
            cx, cy = (x + 0.5) * cell, (y + 0.5) * cell
            draw.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), fill="#a4b0bf")
            draw.text((x * cell + 3, y * cell + 3), f"{x},{y}", font=font, fill="#a4b0bf")
            svg.extend([f'<circle cx="{cx}" cy="{cy}" r="2" fill="#a4b0bf"/>',
                        f'<text x="{x * cell + 3}" y="{y * cell + 13}" font-family="sans-serif" font-size="10" fill="#a4b0bf">{x},{y}</text>'])
    draw.rectangle((1, 1, width - 1, height - 1), outline="#394f6a", width=2)
    svg.extend([f'<rect x="1" y="1" width="{width - 2}" height="{height - 2}" fill="none" stroke="#394f6a" stroke-width="2"/>', "</svg>"])
    (output / "SF_18x28_grid.svg").write_text("\n".join(svg) + "\n")
    image.save(output / "SF_18x28_grid.png")


if __name__ == "__main__":
    main()
