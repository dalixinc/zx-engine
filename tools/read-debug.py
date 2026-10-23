#!/usr/bin/env python3
"""
read-debug.py - read the hex debug values off a Fuse screenshot.

usage: tools/read-debug.py shot.png [shot.png ...]
prints: <file> X=<hex> Y=<hex> IMG=<hex>

The program prints the diver's X, Y and image index in hex on row 22
(columns 17, 22 and 29). Rather than trust a human to read them, we compare
each character cell with the Spectrum ROM font, which is where the program's
print routine gets its letters. Expects Fuse's 2x filter (640x480 window,
32-pixel border). The ROM is the one Fuse uses.
"""
import sys
from PIL import Image

ROM = "/usr/share/spectrum-roms/48.rom"
font = open(ROM, "rb").read()[0x3D00:0x4000]      # chars 32..127, 8 bytes each


def glyph(ch):
    o = (ord(ch) - 32) * 8
    return font[o:o + 8]


def cell_bits(img, row, col):
    out = []
    for line in range(8):
        b = 0
        for px in range(8):
            x = 64 + (col * 8 + px) * 2
            y = 48 + (row * 8 + line) * 2
            r, g, bl = img.getpixel((x, y))[:3]
            b = (b << 1) | (r + g + bl > 300)       # bright = ink
        out.append(b)
    return bytes(out)


def read_hex(img, row, col):
    s = ""
    for c in range(col, col + 2):
        bits = cell_bits(img, row, c)
        m = [ch for ch in "0123456789ABCDEF" if glyph(ch) == bits]
        s += m[0] if m else "?"
    return s


for f in sys.argv[1:]:
    im = Image.open(f).convert("RGB")
    print(f, "X=" + read_hex(im, 22, 17), "Y=" + read_hex(im, 22, 22),
          "IMG=" + read_hex(im, 22, 29))
