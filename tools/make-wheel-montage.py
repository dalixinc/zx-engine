#!/usr/bin/env python3
"""
make-wheel-montage.py - build/montage-wheel.png from gfx/wheel.txt.

The four rotation frames, enlarged, so the hub T and the moving legs
can be judged without a Spectrum. Same colours the game uses: white
ink, blue paper in the hub, dark blue where the sea shows through.
Red lines mark the 8-pixel byte boundaries. This is the art only;
the emulator shots are separate.
"""
import os
import sys
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from gfx2asm import load_frames

INK = (255, 255, 255)
PAPER = (0, 0, 205)
SEA = (0, 0, 90)
GRID = (255, 60, 60)
LABEL = (0, 0, 0)

frames = load_frames("gfx/wheel.txt")
names = [
    "0  wide leg up",
    "1  wide leg left",
    "2  wide leg down",
    "3  wide leg right",
]


def art_tile(rows, label, z=16):
    w, h = len(rows[0]), len(rows)
    im = Image.new("RGB", (w * z + 2, h * z + 28), (230, 230, 230))
    d = ImageDraw.Draw(im)
    d.text((4, 4), label, fill=LABEL)
    ox, oy = 1, 24
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            fill = INK if c == "#" else PAPER if c == "-" else SEA
            d.rectangle(
                [ox + x * z, oy + y * z, ox + x * z + z - 1, oy + y * z + z - 1],
                fill=fill,
            )
    for gx in range(0, w + 1, 8):
        d.line([ox + gx * z, oy, ox + gx * z, oy + h * z], fill=GRID)
    for gy in range(0, h + 1, 8):
        d.line([ox, oy + gy * z, ox + w * z, oy + gy * z], fill=GRID)
    return im


tiles = [art_tile(f, names[i]) for i, f in enumerate(frames)]
pad = 12
W = sum(t.width for t in tiles) + pad * (len(tiles) + 1)
H = tiles[0].height + pad * 2 + 36
out = Image.new("RGB", (W, H), (255, 255, 255))
d = ImageDraw.Draw(out)
d.text(
    (pad, 8),
    "Trigon wheel bomb  (placeholder)   white = ink   blue = hub   dark = sea   red = byte grid",
    fill=LABEL,
)
x = pad
for t in tiles:
    out.paste(t, (x, pad + 28))
    x += t.width + pad
os.makedirs("build", exist_ok=True)
out.save("build/montage-wheel.png")
print("wrote build/montage-wheel.png", out.size)
