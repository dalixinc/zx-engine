# Scrolling ground (v0.5)

The seabed is no longer a picture drawn once. Two strips move past at
different speeds while the diver and the fish swim over them. This file is
the why. The code is `src/scroll.asm`, called from `main_loop` in
`src/main.asm`. The colours are painted by `src/scenery.asm`.

Read this first, then the code, in this order:

1. `main_loop` in `src/main.asm` — the order of the calls, and nothing else.
2. `scroll_blit`, `shift_one_row` and `scroll_world` in `src/scroll.asm`.
3. `level_silo_gap`, `next_front_tile` — where the silos come from.
4. `draw_scenery` in `src/scenery.asm` — why the colours are attributes.
5. The note at the top of `src/sprite.asm` — why a sprite on a strip is
   saved *after* the copy.
6. `print_hex8` in `src/text.asm` — why the debug digits do not go through
   `print_char`.

---

## What you see

```
rows  0-17   title, then open water (blue paper). Not scrolled.
row  18      FAR strip.  Yellow paper, green ink.  8 pixels.
             Seaweed now and then. Moves 1 pixel every 2 frames.
row  19      NEAR strip. Black paper, white ink.   8 pixels.
             Mostly flat, a rock now and then, missile silos.
             Moves 1 pixel every frame.
rows 20-21   Solid black. Not scrolled. The diver can sit down here.
rows 22-23   The debug text. Not scrolled.
```

Both strips are exactly one character row. Colour on the Spectrum is one
byte per 8x8 cell, so a strip that is a whole row can be one colour pair
for its whole length. The pixels move; the colour bytes stay where they
are. A sprite over the far strip turns green-on-yellow, over the near
strip white-on-black, over the water white-on-blue. That is attribute
clash, and because each strip is one pair it happens once, at the
boundary, instead of flickering from cell to cell.

The world scrolls left the whole time, whether or not the diver is
moving. He is still positioned in screen pixels, exactly as in v0.4.
Tying the scroll to his horizontal movement was the other option: the
ground would stop when he stopped, which looks more like "he is pushing
the camera", but then a demo with him sitting still would not show the
two speeds. Continuous scroll makes the parallax obvious. When the real
level scroll arrives it can follow him instead; the strips do not care
who asks them to move.

---

## Why it is done this way

### Pixel scroll, not character scroll

Moving a whole character column (8 pixels) at a time is cheap: it is a
copy of bytes, and the attributes can move with them. It also looks like
the ground is stuttering. One pixel per frame at 50 Hz is 50 pixels a
second on the near strip and 25 on the far one, which reads as two
depths. The far strip moves on even frames only (`back_phase` in
`scroll_world`): half speed, with no fractional counter to keep in your
head.

### A buffer in ordinary RAM, then a copy

The pixels of a strip could be rotated in place in screen memory. Two
reasons not to:

* Screen memory (`$4000-$7FFF`) is contended: the ULA slows the Z80 down
  while it is reading the picture. The buffers live at `$F000`, which is
  not contended, so the rotate runs at full speed.
* Rotating the screen while the beam is on that row tears the picture.
  The rotate happens *after* the copy, in the buffer, where the beam
  cannot see it. The copy is the only thing that touches the screen, and
  it is done while the beam is still up in the water.

Pre-shifted columns (8 copies of every tile, like the sprites) would
remove the rotate. They would not remove the copy: 32 bytes times the
rows still have to be written to the screen every frame, and the bookkeeping
for "which shift is showing" is harder to read than a buffer that just
*is* the picture. The rotate is the simple part. It had to be made fast
enough, which is the unroll in `shift_one_row`, not replaced.

### Attributes stay put

Scrolling the attribute file as well would cost another 32 bytes per
strip per frame, and it would scroll the colour of any sprite standing
there. Leaving the attributes alone is both faster and the right clash.

### How fast the copy and the rotate have to be

A frame is 69,888 T-states (312 lines of 224). The interrupt is at the
start of the top border. If `main_loop` is still running when the *next*
interrupt arrives, `wait_frame` throws that interrupt away and waits for
the one after, and the game drops from 50 frames a second to 25.

That happened on the first versions of this strip. Two specific causes,
both left in the comments where the code changed:

* `LDIR` is 21 T-states a byte. Copying both strips with it was still
  going when the beam reached them, so the ground tore. `LDI` is 16, and
  unrolled it has no loop test per byte. Inside one character cell the
  next pixel line is `INC D` (see docs/SPRITES.md), so the row address is
  looked up once per strip, not once per line.
* A `DJNZ` around `RL (HL)` was 34 T-states a byte. Across both strips
  that, plus the sprites, plus the debug digits, ran past the next
  interrupt. Unrolled it is `RL (HL)` / `DEC L` = 19. `DEC L` rather than
  `DEC HL` because every row is 32 bytes on a 32-byte boundary
  (`SCROLL_BASE` is `$F000`), so a row never crosses a 256-byte page.
* The debug line prints 16 hex digits a frame. `print_char` also rewrites
  the attribute byte. That was enough, on top of the rest, to miss the
  interrupt. `print_hex8` writes the picture only: `cls` already painted
  those cells white on black. The eight glyph bytes are unrolled for the
  same reason as the strip copy.
* A 16-pixel near strip (two character rows) missed the interrupt on the
  frame a new column arrived, about one frame in eight, even after the
  unroll. One character row each is enough for a silo to read — roof,
  hatch, legs, footing — and the loop then finishes inside the frame on
  every phase, including with the diver down on the ground. Measured,
  not assumed: over two seconds the frame counter and a counter inside
  `scroll_front` advanced by the same amount (102, then 101 with him on
  the ground). The near strip moved that many pixels; the far strip moved
  half as many.

`make timing` (`-DTIMING_BARS`, `build/diver-timing.sna`) turns the border
into a clock. `build/diver-timing.png` is the diver in open water;
`build/diver-timing-ground.png` is him on the ground.

| border   | what it covers                                      | diver in the water | diver on the ground |
|----------|-----------------------------------------------------|--------------------|---------------------|
| white    | restore, then draw sprites that are in open water  | ends at pixel line 37 | ends in the top border (about 8 lines above the picture) |
| cyan     | copy both strips to the screen                      | ends at line 89    | ends at line 42 |
| magenta  | diver, if he is on a strip, then rotate the buffers | ends at line 144 (rotate only) | ends at line 116 (he is drawn here, then the rotate) |
| yellow   | debug digits, input, move the diver and the fish   | lines 144-184      | lines 116-157 |
| black    | this frame's work is finished                       | from line 184      | from line 157 |

The far strip is pixel line 144. In the water case the copy (cyan) is
done at line 89, 55 lines before the beam reaches it. On the ground the
copy is done at line 42. Either way the beam never meets a half-copied
row. The rotate is magenta and does not touch screen memory, so it may
still be going while the beam is on the strips: there is nothing for it
to tear. With the diver on the ground he is drawn during magenta and that
finishes at line 116; his top pixel is at y 153, so the beam has not
reached him yet. Black well before the bottom of the picture means the
loop is waiting for the next interrupt, not running into it.

Line numbers are read off the screenshot. Fuse shows the top 24 lines of
the 64-line top border, so "line 37" means pixel line 37 of the picture.
White ending there is the same number v0.4 measured for the two sprites
alone: the strip copy was added *after* them, not in front of them.

---

## Order inside the frame

This is the part that keeps the sprites from leaving pixels behind.

```
wait_frame
diver_restore          ; put back what was under him last frame
fish_restore           ; then the fish (reverse of the draw order)
fish_draw              ; fish is always above the strips
if diver's feet are still above row 18:
    diver_draw         ; the copy will not touch him
scroll_blit            ; buffers -> the two strips, every byte
if diver's feet were on a strip:
    diver_draw         ; he was not drawn yet; he saves THIS ground
scroll_world           ; rotate the buffers, off screen
print the debug line, read keys, move both sprites
```

Why that order, and not "draw everything, then copy":

* The background record is a photograph of the screen at the moment of
  the save. The copy overwrites both strips completely. If a sprite was
  saved *before* the copy, the photograph is last frame's ground, and
  the copy has already rubbed the sprite out. Next frame the restore
  paints last frame's pixels onto ground that has moved. That is a smear
  of "pixels left behind", and it is exactly what a wrong order does.
* If the sprite is saved *while it is still on screen* (drawn, then
  saved again), the photograph contains the sprite itself. The next
  restore paints the sprite back as debris. One save, and it has to be
  of the bare ground.
* The fish never reaches row 18 (`FISH_SWIM_Y + FISH_HEIGHT` is checked
  with an `ASSERT`). Drawing him before the copy means the beam, which
  is still in the top border, is ahead of him. Drawing him after the
  copy would be correct but later, and the beam would be closer.
* The diver does both. While his lowest pixel is above line 144 he is
  drawn with the fish. The moment that pixel touches the far strip he is
  drawn after the copy, so the bytes he saves are the ground that is on
  screen now. The same test is done twice in `main_loop` on purpose: it
  is the same question, asked at the two places the answer matters.
* Restore stays first even for a sprite that was on a strip. It puts
  last frame's ground back, and the copy immediately replaces the whole
  strip. The beam does not reach the strip until after the copy, so it
  never sees that intermediate picture. The water part of the restore
  is the part that has to stick, because the copy does not touch it.

Erase order is still reverse of draw order. The diver is drawn after the
fish, so when they overlap his photograph contains a piece of the fish,
and he has to be erased first. That is unchanged from docs/SPRITES.md.
They only overlap in the water: the fish is at pixel y 76 and the diver
is not drawn late until his feet reach y 144.

---

## Silos, rocks, seaweed

A strip is a row of tile ids, one per character column, plus a fine
scroll of 0..7 pixels (`front_fine`, `back_fine`).

```
screen x of the left edge of column i  =  i * 8 - front_fine
world column of front_tiles[i]         =  front_origin + i
```

`front_tiles[i] = TILE_SILO` (2) is a silo. `TILE_ROCK` is 1, flat is 0.
The column still sliding in from the right is `front_pending`; it is not
in the table until `front_fine` wraps to 0, and its world column is
`front_origin + 32`. The same names with `back_` are the far strip.
`TILE_WEED` is the only non-flat tile there.

Missiles are not in this version. When they are, the hatch is the dark
slit in `pat_front_silo` (the rows `%00100100`). Find the silo with the
two lines above; the top of the strip is pixel y `FRONT_ROW * 8` = 152.

Which columns are silos is `level_silo_gap`:

```
level 0   every 24 columns     the demo (level_index is 0)
level 1   every 16
level 2   every 12
level 3   every 8
```

Poke `level_index` (0 .. `LEVEL_COUNT-1`) before `scroll_init` to try a
later level. Column N is a silo when N mod gap = 0. Rocks are column
mod 10 = 4, unless that column was already a silo. Seaweed is column
mod 11 = 3. The code counts down to the next one instead of dividing:
a 16-step divide on the frame a new column arrived was part of what
pushed that frame over the interrupt. The countdown is the same rule.

---

## Memory

| region            | address        | what                          |
|-------------------|----------------|-------------------------------|
| code and data     | `$8000-$A701`  | `code_end` is `$A702`         |
| far buffer        | `$F000-$F0FF`  | 8 rows x 32, not on the tape  |
| near buffer       | `$F100-$F1FF`  | 8 rows x 32                   |
| (free)            | `$F200-$F9FF`  |                               |
| row address table | `$FA00-$FB7F`  | built at start-up             |
| stack             | grows down from `$FDFC` | must not reach `$FB80` |
| `JP isr`          | `$FDFD`        |                               |
| IM2 vectors       | `$FE00-$FF00`  | 257 bytes of `$FD`            |

`SCROLL_BUF_END` is `$F200`. An `ASSERT` refuses to assemble if the
buffers reach the row table, or if a buffer row would cross a 256-byte
page (the `DEC L` in the rotate depends on it).

---

## Not in this version

* Trigon missiles, and anything that reads the silo table yet. The ids
  and the position formula are there so that code has somewhere to look.
* The scroll does not follow the diver. See the top of this file.
* Sprites do not clip off the edge of the screen. The strips scroll
  under them; the sprites stay fully on screen, clamped as in v0.4
  (his lowest y is now 153, because the black floor starts at row 20).
* No vertical scroll.
