#!/usr/bin/env python3
"""
make-diver-montage.py - build/montage-diver.png from the diver art and the
screenshots taken by tools/sprite-test.sh (run `make sprite-test` first).

Top strip: every frame straight from gfx/diver.txt, facing right and
mirrored left (what gfx2asm.py turns into data), 8x zoom, with red lines
on the 8-pixel byte boundaries. White = ink, blue = paper (opaque),
grey = transparent.
Bottom strip: for each image index 00..05 the first screenshot in which the
emulator showed it (read off the debug line by tools/read-debug.py), cropped
round the diver and zoomed 2x more. Shots in open water (y < 140) are
preferred over ones on the seabed, where attribute clash hides the shape. Same art top and bottom = the data is right.
"""
import glob, os, subprocess, sys
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from gfx2asm import load_frames          # same parser the build uses

INK, PAPER, GRID = (255, 255, 255), (0, 0, 205), (255, 0, 0)
frames = load_frames("gfx/diver.txt")
names = ["0 legs apart", "1 half way", "2 together"]


def art_tile(rows, label, z=8):
    w, h = len(rows[0]), len(rows)
    im = Image.new("RGB", (w * z, h * z + 16), (220, 220, 220))
    d = ImageDraw.Draw(im)
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            d.rectangle([x * z, 16 + y * z, x * z + z - 1, 16 + y * z + z - 1],
                        fill=INK if c == "#" else PAPER if c == "-" else (140, 140, 140))
    for gx in range(0, w + 1, 8):
        d.line([gx * z, 16, gx * z, 16 + h * z], fill=GRID)
    d.text((2, 2), label, fill=(0, 0, 0))
    return im


tiles = []
for i, f in enumerate(frames):
    tiles.append(art_tile(f, "R " + names[i]))
for i, f in enumerate(frames):
    tiles.append(art_tile([r[::-1] for r in f], "L " + names[i]))

# emulator crops, chosen automatically by image index
shots = {}
out = subprocess.run([sys.executable, "tools/read-debug.py"] +
                     sorted(glob.glob("build/diver-0*.png")),
                     capture_output=True, text=True).stdout.split("\n")
for line in out:
    if not line:
        continue
    f, xs, ys, imgs = line.split()
    img = imgs[4:]
    x, y = int(xs[2:], 16), int(ys[2:], 16)
    if img not in shots or (shots[img][2] >= 140 and y < 140):
        shots[img] = (f, x, y)
emu = []
for k in ["00", "01", "02", "03", "04", "05"]:
    if k not in shots:
        print("no screenshot shows image", k)
        continue
    f, x, y = shots[k]
    cx, cy = max(0, x - 8), max(0, y - 4)
    cx, cy = min(cx, 256 - 48), min(cy, 192 - 24)
    sc = Image.open(f).convert("RGB").crop(
        (64 + 2 * cx, 48 + 2 * cy, 64 + 2 * (cx + 48), 48 + 2 * (cy + 24)))
    sc = sc.resize((sc.width * 2, sc.height * 2), Image.NEAREST)
    t = Image.new("RGB", (sc.width, sc.height + 16), (220, 220, 220))
    t.paste(sc, (0, 16))
    ImageDraw.Draw(t).text((2, 2), "emu IMG %s x=%d y=%d (%s)" %
                           (k, x, y, os.path.basename(f)[6:-4]), fill=(0, 0, 0))
    emu.append(t)

pad = 8
row1w = sum(t.width for t in tiles[:3]) + pad * 4
row3w = sum(t.width for t in emu[:3]) + pad * 4
W = max(row1w, row3w)
rows = [tiles[:3], tiles[3:], emu[:3], emu[3:]]
H = sum(max(t.height for t in r) + pad for r in rows if r) + pad
out = Image.new("RGB", (W, H), (255, 255, 255))
y = pad
for r in rows:
    if not r:
        continue
    x = pad
    for t in r:
        out.paste(t, (x, y))
        x += t.width + pad
    y += max(t.height for t in r) + pad
out.save("build/montage-diver.png")
print("wrote build/montage-diver.png")
