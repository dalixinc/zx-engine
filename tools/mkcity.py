#!/usr/bin/env python3
"""
mkcity.py - Erin's Atlantis city as a whole Spectrum screen, for the
interlude between Atlantis and Trigon (src/atlantis/interlude.asm).

Usage:  python3 tools/mkcity.py gfx/city.scr

Reads gfx/city_bitmap.bin (192 x 128 pixels, row by row, 8 pixels a
byte, left pixel in bit 7) and gfx/city_attrs.bin (24 x 16 cells), from
Erin's atlantis_spectrum_pack. Writes a 6912-byte screen with the city
in cell rows 4 to 19 and columns 4 to 27, and the play screen's water
colour round it. The game unpacks the ZX0 of this straight onto the
screen, so it needs no buffer. Only Python 3 is needed.
"""

import sys
from pathlib import Path

ROW0, COL0 = 4, 4              # where the city's top left cell goes
WIDE, HIGH = 24, 16            # its size, in cells
WATER = 0x40 | (1 << 3) | 7     # BRIGHT, blue paper, white ink: WATER_ATTR

bitmap = Path("gfx/city_bitmap.bin").read_bytes()
attrs = Path("gfx/city_attrs.bin").read_bytes()
assert len(bitmap) == WIDE * HIGH * 8 and len(attrs) == WIDE * HIGH

scr = bytearray(6144) + bytearray([WATER] * 768)
for y in range(HIGH * 8):
    sy = ROW0 * 8 + y
    addr = ((sy & 0xC0) << 5) | ((sy & 7) << 8) | ((sy & 0x38) << 2)
    scr[addr + COL0:addr + COL0 + WIDE] = bitmap[y * WIDE:(y + 1) * WIDE]
for cy in range(HIGH):
    at = 6144 + (ROW0 + cy) * 32 + COL0
    scr[at:at + WIDE] = attrs[cy * WIDE:(cy + 1) * WIDE]
Path(sys.argv[1]).write_bytes(scr)
print(f"{sys.argv[1]}: 6912 bytes, the city at rows {ROW0}-{ROW0 + HIGH - 1}, columns {COL0}-{COL0 + WIDE - 1}")
