#!/usr/bin/env python3
"""
mkloadscreen.py - build the Atlantis loading screen from the game's sprites.

Usage:  python3 tools/mkloadscreen.py gfx/loading.scr [preview.png]

Writes a 6912-byte Spectrum screen: 6144 bytes of pixels in the ROM's
interleaved row order, then 768 bytes of colour, one per 8x8 cell. The
tape loads it with LOAD ""SCREEN$ before the game.

The picture is painted at full colour first, and each 8x8 cell is then
cut down to the two colours the Spectrum allows in it (the two most
common there; any other pixel takes whichever of the two is nearer).
The scene is laid out so that almost no cell needs that, and the script
prints the cells that did, so a change that causes colour clash shows.

The sprites are read from gfx/*.txt, the same art the game draws, and
drawn twice the size. The title letters are drawn in this file.

The optional second argument writes a PNG of the result (needs Pillow).
Only Python 3 is needed for the .scr itself.
"""

import math
import random
import sys
from collections import Counter
from pathlib import Path

W, H = 256, 192

# Colours 0-7 as on the Spectrum. Add BRIGHT for the bright set.
BLACK, BLUE, RED, MAGENTA, GREEN, CYAN, YELLOW, WHITE = range(8)
BRIGHT = 8


def rgb(c):
    level = 0xFF if c & BRIGHT else 0xD7
    b = c & 7
    return ((level if b & 2 else 0), (level if b & 4 else 0), (level if b & 1 else 0))


# --- The canvas -----------------------------------------------------------------

pix = [[BLACK] * W for _ in range(H)]


def plot(x, y, c):
    if 0 <= x < W and 0 <= y < H:
        pix[y][x] = c


def fill(x, y, w, h, c):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            plot(xx, yy, c)


def cell_row(row, c):
    fill(0, row * 8, W, 8, c)


# --- Sprites from gfx/*.txt ------------------------------------------------------

def load_frames(path):
    """Frames of a gfx/*.txt file, each a list of rows of '#', '-', '.'."""
    frames, cur = [], None
    for line in Path(path).read_text().splitlines():
        s = line.strip()
        if s.startswith("frame"):
            cur = []
            frames.append(cur)
        elif cur is not None and s and set(s) <= set("#-."):
            cur.append(s)
    return frames


def sprite(rows, x, y, ink, scale=2, mirror=False, paper=None):
    """'#' in ink, '-' in paper (skipped when paper is None), '.' left alone."""
    for r, row in enumerate(rows):
        if mirror:
            row = row[::-1]
        for col, ch in enumerate(row):
            c = ink if ch == "#" else paper if ch == "-" else None
            if c is not None:
                fill(x + col * scale, y + r * scale, scale, scale, c)


# --- The title -------------------------------------------------------------------
# Letters on a grid of 2x2-pixel units, 16 units tall (32 pixels). Stems
# are four units wide and bars three units tall. N's diagonal is worked
# out below.

LETTERS = {
    "A": [
        "..##########..",
        ".############.",
        "##############",
        "####......####",
        "####......####",
        "####......####",
        "####......####",
        "##############",
        "##############",
        "##############",
        "####......####",
        "####......####",
        "####......####",
        "####......####",
        "####......####",
        "####......####",
    ],
    "T": ["##############"] * 3 + [".....####....."] * 13,
    "L": ["####........."] * 13 + ["#############"] * 3,
    "I": ["####"] * 16,
    "S": [
        ".#############",
        "##############",
        "##############",
        "####..........",
        "####..........",
        "####..........",
        "#############.",
        "##############",
        ".#############",
        "..........####",
        "..........####",
        "..........####",
        "..........####",
        "##############",
        "##############",
        "#############.",
    ],
}


def make_n():
    rows = []
    for r in range(16):
        row = ["#" if c < 4 or c >= 10 else "." for c in range(14)]
        s = round(r * 10 / 15)          # the diagonal's left edge, 0..10
        for c in range(s, s + 4):
            row[c] = "#"
        rows.append("".join(row))
    return rows


LETTERS["N"] = make_n()

# One ink for each cell row of the title, top to bottom: white hot at
# the top, through yellow, to red.
TITLE_INKS = [WHITE | BRIGHT, YELLOW | BRIGHT, YELLOW, RED | BRIGHT]

# Pixel rows of the title left empty: thin cuts that get closer
# together towards the bottom, the old arcade way of shading chrome.
TITLE_CUTS = {18, 22, 25, 27, 29, 31}


def title(word, top):
    gap = 2
    widths = [len(LETTERS[ch][0]) for ch in word]
    total = (sum(widths) + gap * (len(word) - 1)) * 2
    x = (W - total) // 2
    for ch, w in zip(word, widths):
        for r, row in enumerate(LETTERS[ch]):
            for c, bit in enumerate(row):
                if bit != "#":
                    continue
                for dy in range(2):
                    py = r * 2 + dy
                    if py in TITLE_CUTS:
                        continue
                    for dx in range(2):
                        plot(x + c * 2 + dx, top + py, TITLE_INKS[py // 8])
        x += (w + gap) * 2


# --- The scene -------------------------------------------------------------------

SKY = BLACK
SURFACE = CYAN | BRIGHT         # rows 6 to 9: lit water near the top
MID = BLUE | BRIGHT             # rows 11 to 17: the game's water colour
DEEP = BLUE                     # rows 18 to 20
DEEP_TOP = 18 * 8
SAND_DIM = YELLOW
SAND = YELLOW | BRIGHT

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def weed(y):
    # Green, bright or not to match the water it grows through.
    return GREEN | BRIGHT if y < DEEP_TOP else GREEN


def checker(x, y):
    return (x + y) & 1


def paint():
    rnd = random.Random(1986)

    # Sky, with stars in the rows the title leaves free.
    for row in range(0, 6):
        cell_row(row, SKY)
    for _ in range(40):
        x, y = rnd.randrange(W), rnd.choice([rnd.randrange(0, 7), rnd.randrange(42, 47)])
        c = WHITE | BRIGHT if rnd.random() < 0.5 else WHITE
        if c == WHITE | BRIGHT and rnd.random() < 0.4 and 1 <= y and x >= 1:
            for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                plot(x + dx, y + dy, WHITE | BRIGHT)
        plot(x, y, WHITE | BRIGHT)

    # The sea surface on row 6: sky above a gentle swell.
    for x in range(W):
        top = 48 + 3 + round(1.6 * math.sin(x / 7.0) + 0.8 * math.sin(x / 2.9))
        for y in range(48, 56):
            plot(x, y, SURFACE if y >= top else SKY)

    for row in range(7, 10):
        cell_row(row, SURFACE)
    # Row 10 fades the lit water into the deeper blue.
    for y in range(80, 88):
        for x in range(W):
            t = (y - 80) / 8
            plot(x, y, MID if (checker(x, y) if 0.25 < t < 0.75 else t >= 0.5) else SURFACE)
    for row in range(11, 18):
        cell_row(row, MID)
    for row in range(18, 21):
        cell_row(row, DEEP)

    # Shafts of light from the surface, in the lit rows only.
    for start, width in ((0, 6), (100, 8), (178, 5)):
        for y in range(56, 80):
            x0 = start + (y - 56)
            for x in range(x0, x0 + width):
                if pix[y][x] == SURFACE and BAYER[y & 3][x & 3] < 4 - (y - 56) // 7:
                    plot(x, y, WHITE | BRIGHT)

    # Seabed: weed on row 21, sand fading in on row 22, ground on 23.
    cell_row(21, DEEP)
    x = 0
    while x < W:
        h = rnd.randint(3, 8)
        lean = rnd.choice((-1, 0, 1))
        for i in range(h):
            plot(x + (lean if i > h // 2 else 0), 175 - i, weed(175 - i))
        x += rnd.choice((2, 2, 3))
    for y in range(176, 184):
        for x in range(W):
            # An ordered dither, more sand than water further down.
            on = BAYER[y & 3][x & 3] < (y - 176) * 2 + 2
            plot(x, y, SAND_DIM if on else DEEP)
    for y in range(184, 192):
        for x in range(W):
            plot(x, y, SAND)
    for _ in range(30):
        x, y = rnd.randrange(W - 2), rnd.randrange(185, 191)
        fill(x, y, rnd.choice((1, 2, 3)), 1, BLACK)

    # Tall kelp, rising from the weed.
    for base_x, height, phase in ((6, 46, 0.0), (18, 34, 1.3), (100, 22, 2.1)):
        for i in range(height):
            y = 175 - i
            x = base_x + round(2.5 * math.sin(i / 6.0 + phase))
            plot(x, y, weed(y))
            plot(x + 1, y, weed(y))
            if i % 7 == 3:
                plot(x + 2, y, weed(y))
                plot(x + 3, y - 1, weed(y - 1))

    ruins()

    diver = load_frames("gfx/diver.txt")
    wheel = load_frames("gfx/wheel.txt")
    fish = load_frames("gfx/fish.txt")
    torpedo = load_frames("gfx/torpedo.txt")

    # The diver, firing at a bomb.
    dx, dy = 24, 92
    mx, my = big_diver(dx, dy)
    big_torpedo(mx + 14, my - 2)
    for i, x in enumerate(range(mx + 2, mx + 12, 4)):
        plot(x, my - 1 + (i & 1) * 2, WHITE | BRIGHT)

    # His bubbles, rising to the surface. Row 10 is left alone.
    for x, y, r in ((dx + 56, 91, 1), (dx + 60, 72, 2), (dx + 54, 62, 3)):
        circle(x, y, r, WHITE | BRIGHT)

    # Bombs: one in the torpedo's path, one in the lit water above.
    sprite(wheel[2], 150, my - 12, BLACK)
    sprite(wheel[0], 136, 56, BLACK)

    # Fish, in the game's own size.
    sprite(fish[0], 120, 156, YELLOW, scale=1)
    sprite(fish[1], 40, 62, BLUE | BRIGHT, scale=1, mirror=True)
    sprite(fish[0], 216, 66, BLUE | BRIGHT, scale=1, mirror=True)


# --- The big diver ----------------------------------------------------------------
# The game's diver is 24 x 15, drawn to read at 1:1. Blown up three times
# it turns to blocks, so this screen has its own, 64 x 38, in the same
# pose: facing right, helmet at the front, air tank on his back, legs
# kicking behind, and the jet unit held out under the helmet with its
# propeller at the back and the dark mouth at the nose. He is white on
# the game's blue water. Every detail is a line of that blue cut
# through the white, so no cell needs a third colour.

def disc(cx, cy, rx, ry, c):
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            if ((x - cx) / (rx + 0.5)) ** 2 + ((y - cy) / (ry + 0.5)) ** 2 <= 1:
                plot(x, y, c)


def thick_line(x0, y0, x1, y1, w, c):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        x = x0 + (x1 - x0) * i / n
        y = y0 + (y1 - y0) * i / n
        disc(round(x), round(y), w // 2, w // 2, c)


def polygon(points, c):
    ys = [y for _, y in points]
    for y in range(min(ys), max(ys) + 1):
        xs = []
        for (xa, ya), (xb, yb) in zip(points, points[1:] + points[:1]):
            if (ya <= y < yb) or (yb <= y < ya):
                xs.append(xa + (y - ya) * (xb - xa) / (yb - ya))
        xs.sort()
        for xa, xb in zip(xs[::2], xs[1::2]):
            for x in range(round(xa), round(xb) + 1):
                plot(x, y, c)


def big_diver(ox, oy):
    """Top-left at ox, oy. Returns where the jet unit's mouth is."""
    ink, cut = WHITE | BRIGHT, MID

    def P(x, y):
        return (ox + x, oy + y)

    # Legs, the upper one kicked up and the lower one down, then fins
    # that widen away from the ankles.
    # A flutter kick: the upper leg bent at the knee, the lower straight.
    thick_line(*P(24, 16), *P(17, 12), 6, ink)
    thick_line(*P(17, 12), *P(9, 14), 5, ink)
    thick_line(*P(24, 23), *P(9, 25), 6, ink)
    polygon([P(10, 11), P(10, 16), P(0, 12), P(0, 5)], ink)
    polygon([P(10, 23), P(10, 28), P(0, 33), P(0, 26)], ink)
    for x0, y0, x1, y1 in ((9, 13, 1, 9), (9, 25, 1, 29)):
        thick_line(*P(x0, y0), *P(x1, y1), 1, cut)      # the fin's rib
    for y in range(11, 16):
        plot(*P(10, y), cut)                            # ankle from fin
    for y in range(23, 28):
        plot(*P(10, y), cut)

    # Body, and the tank along his back.
    disc(*P(35, 19), 13, 7, ink)
    disc(*P(34, 9), 13, 4, ink)
    fill(*P(47, 7), 3, 4, ink)                          # the valve
    for x in range(22, 47):
        plot(*P(x, 13), cut)                            # tank from body
    for x in (28, 40):
        for y in range(6, 13):
            plot(*P(x, y), cut)                         # its straps
    for y in range(14, 26):
        plot(*P(26, y), cut)                            # the belt
    fill(*P(25, 18), 3, 3, cut)
    plot(*P(26, 19), ink)                               # the buckle

    # Helmet, with a collar line and a round porthole.
    disc(*P(54, 15), 9, 9, ink)
    for y in range(9, 24):
        plot(*P(46, y), cut)
    disc(*P(56, 14), 5, 5, cut)
    disc(*P(56, 14), 3, 3, ink)
    disc(*P(56, 14), 2, 2, cut)                         # the glass
    plot(*P(55, 13), ink)                               # a glint

    # The arm, down to the jet unit, then the jet unit itself.
    thick_line(*P(42, 22), *P(48, 28), 5, ink)
    disc(*P(52, 30), 11, 3, ink)
    fill(*P(43, 27), 20, 7, ink)
    for x in (48, 51, 54):
        for y in range(29, 32):
            plot(*P(x, y), cut)                         # vents
    fill(*P(62, 29), 2, 3, cut)                         # the dark mouth
    # The propeller at the back: a hub and two blades.
    fill(*P(39, 29), 4, 3, ink)
    fill(*P(38, 24), 2, 13, ink)
    plot(*P(38, 30), cut)
    return P(64, 30)


def big_torpedo(x, y):
    """18 x 7, nose to the right, tail fins at the left."""
    ink = WHITE | BRIGHT
    fill(x + 3, y + 2, 12, 3, ink)                      # the body
    fill(x + 15, y + 2, 2, 3, ink)
    plot(x + 17, y + 3, ink)                            # the nose
    fill(x + 4, y + 1, 10, 1, ink)
    fill(x + 4, y + 5, 10, 1, ink)
    for dx, dy in ((0, 0), (1, 0), (1, 1), (2, 1), (0, 6), (1, 6), (1, 5), (2, 5)):
        plot(x + dx, y + dy, ink)                       # the fins
    fill(x, y + 3, 3, 1, ink)
    plot(x + 12, y + 3, MID)                            # a band near the nose
    plot(x + 12, y + 2, MID)
    plot(x + 12, y + 4, MID)


def circle(cx, cy, r, c):
    for a in range(0, 360, 10):
        plot(cx + round(r * math.cos(math.radians(a))), cy + round(r * math.sin(math.radians(a))), c)


def ruins():
    """A sunken temple on the right: steps, columns (one broken), a lintel."""
    stone = CYAN
    lit = CYAN | BRIGHT
    base_y = 168                         # top of the weed row's water
    left, right = 184, 252
    # Three steps.
    for i, (x0, x1) in enumerate(((left - 4, right), (left, right - 2), (left + 4, right - 6))):
        y = base_y - 4 * (i + 1)
        for yy in range(y, y + 4):
            for x in range(x0, x1):
                plot(x, yy, lit if yy < DEEP_TOP else stone)
    floor = base_y - 12
    # Columns: fluted, with a capital and a base.
    tops = (108, 108, 128, 108)
    for i, top in enumerate(tops):
        x0 = left + 8 + i * 16
        for y in range(top, floor):
            for dx in range(8):
                if dx in (2, 5) and top + 4 <= y < floor - 3:
                    continue             # the flutes
                plot(x0 + dx, y, lit if y < DEEP_TOP else stone)
        if top == 108:
            fill(x0 - 2, top - 4, 12, 4, lit)
        else:
            # Broken: a jagged top and a drum fallen at its foot.
            for dx in range(8):
                for dy in range((dx * 7) % 4):
                    plot(x0 + dx, top + dy, MID if top + dy < DEEP_TOP else DEEP)
            fill(x0 + 12, floor - 6, 10, 6, stone)
    # The lintel over the standing columns, cracked through the middle.
    for y in range(98, 104):
        for x in range(left + 4, right - 4):
            if not (x == left + 40 and y > 99):
                plot(x, y, lit)
    # The pediment: a low triangle, its right half fallen.
    for y in range(88, 98):
        half = (y - 88) * 3 + 2
        cx = left + 32
        for x in range(cx - half, cx + half):
            if x < cx + 4 or y >= 96:
                plot(x, y, lit)


# --- Fit every cell to two colours ----------------------------------------------

def dist(a, b):
    ra, rb = rgb(a), rgb(b)
    return sum((p - q) ** 2 for p, q in zip(ra, rb))


def quantise():
    clashes = []
    attrs = []
    bits = [[0] * W for _ in range(H)]
    for cy in range(24):
        for cx in range(32):
            cells = [(x, y) for y in range(cy * 8, cy * 8 + 8) for x in range(cx * 8, cx * 8 + 8)]
            count = Counter(pix[y][x] for x, y in cells)
            # Black looks the same bright or not. Count it as either.
            bright = sum(n for c, n in count.items() if c & BRIGHT) >= \
                sum(n for c, n in count.items() if c not in (BLACK, BLACK | BRIGHT) and not c & BRIGHT)
            base = Counter()
            for c, n in count.items():
                base[c & 7] += n
            if len(base) > 2 or any((c & BRIGHT) != (BRIGHT if bright else 0)
                                    for c in count if c & 7):
                clashes.append((cx, cy, dict(count)))
            pair = [c for c, _ in base.most_common(2)]
            paper = pair[0]
            ink = pair[1] if len(pair) > 1 else pair[0]
            b = BRIGHT if bright else 0
            for x, y in cells:
                c = pix[y][x]
                use_ink = (c & 7) == ink if (c & 7) in (ink, paper) else \
                    dist(c, ink | b) < dist(c, paper | b)
                if ink == paper:
                    use_ink = False
                bits[y][x] = 1 if use_ink else 0
                pix[y][x] = (ink if use_ink else paper) | b
            attrs.append((0x40 if bright else 0) | (paper << 3) | ink)
    return bits, attrs, clashes


def scr_bytes(bits, attrs):
    out = bytearray(6912)
    for y in range(H):
        addr = ((y & 0xC0) << 5) | ((y & 7) << 8) | ((y & 0x38) << 2)
        for col in range(32):
            v = 0
            for b in range(8):
                v = (v << 1) | bits[y][col * 8 + b]
            out[addr + col] = v
    out[6144:] = bytes(attrs)
    return out


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    paint()
    title("ATLANTIS", 8)
    bits, attrs, clashes = quantise()
    Path(sys.argv[1]).write_bytes(scr_bytes(bits, attrs))
    print(f"{sys.argv[1]}: 6912 bytes, {len(clashes)} cells had to lose a colour")
    for cx, cy, count in clashes:
        print(f"  cell {cx},{cy}: {count}")
    if len(sys.argv) > 2:
        from PIL import Image
        img = Image.new("RGB", (W, H))
        img.putdata([rgb(pix[y][x]) for y in range(H) for x in range(W)])
        img.save(sys.argv[2])


if __name__ == "__main__":
    main()
