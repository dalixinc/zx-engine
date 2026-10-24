# Scrolling ground (v0.5, silhouettes)

The seabed is two strips that move past at different speeds while the
diver and the fish swim over them. They are not flat bars. Each one is
16 pixels tall, so the skyline can rise and fall. This file is the why.
The code is `src/scroll.asm`, called from `main_loop` in `src/main.asm`.
The colours are painted by `src/scenery.asm`.

Read this first, then the code, in this order:

1. `main_loop` in `src/main.asm` — the order of the calls, and nothing else.
2. `scroll_blit_back`, `scroll_blit_front`, `shift_one_row`,
   `scroll_front`, `scroll_back` in `src/scroll.asm`.
3. `level_silo_gap`, `next_front_tile`, `near_profile` — where the shape
   and the silos come from.
4. `clamp_to_terrain` in `src/diver.asm` — why he stops above the black.
5. `draw_scenery` in `src/scenery.asm` — which cells are which colour.
6. The note at the top of `src/sprite.asm` — why a sprite on a strip is
   saved *after* the copy.
7. `print_hex8` in `src/text.asm` — why the debug digits do not go through
   `print_char`.

---

## What you see

```
rows  0-17   title, then open water (blue paper). Not scrolled.
rows 18-19   FAR strip.  16 pixels, lines 144-159.
             Yellow sand on the blue water. A green seaweed column
             now and then. Moves 1 pixel every 2 frames.
rows 20-21   NEAR strip. 16 pixels, lines 160-175.
             Black ground on yellow. Rocks and missile silos, and
             every one of those pixels is black. Moves 1 pixel a frame.
             Sits directly under the far strip, so it reads as in front.
rows 22-23   The debug text. Not scrolled.
```

There is no separate black floor. The near strip *is* the floor. The
diver can swim down until his feet are one pixel above whatever column
of that strip is under him. A valley lets him lower. A hill, a rock or
a silo lifts him. He is allowed to overlap the far yellow hills. Those
are behind him. Only the black strip stops him.

The world scrolls left the whole time, whether or not the diver is
moving. He is still positioned in screen pixels. Tying the scroll to
his horizontal movement would stop the parallax whenever he stopped.
When a real level camera arrives it can follow him instead; the strips
do not care who asks them to move.

The speeds are the same as the flat strips were:

| strip | height | rows | pixel lines | speed |
|-------|--------|------|-------------|-------|
| far   | 16 px  | 18-19 | 144-159    | 1 pixel every 2 frames (25 px/s) |
| near  | 16 px  | 20-21 | 160-175    | 1 pixel every frame (50 px/s) |

The shapes repeat every 16 columns, and they are not the same shape, so
the far hills do not trace the near ones. Heights are pixels of solid
ground counted up from the bottom of that strip (`near_profile`,
`far_profile`):

```
near  4  5  7  9 11 13 14 14 13 11  9  7  5  4  3  4
far   2  3  4  6  8 10 10  8  6  5  4  3  2  2  3  4
```

A near peak of 14 stays inside the 16. A far peak of 10 crosses the
boundary between the two far character rows, so the skyline is not
stuck on that boundary. A silo replaces its column and is the full 16
pixels tall for collision. The yellow slots in the hatch are holes in
the picture, not a gap he can swim through.

---

## Colour, and the clash

The Spectrum stores one ink and one paper for each 8x8 cell. Pixels do
not have their own colour. A set pixel is ink, a clear pixel is paper,
and a sprite standing on that cell picks up the same pair. The strips
are tall enough to undulate, so a strip is two rows of cells, and the
pairs are chosen so the silhouette still reads while it scrolls.

**Near strip, both rows, every column, for the whole run.** Bright
black ink, yellow paper (`FRONT_ATTR`). Set once by `draw_scenery`,
never scrolled. Set bits are the black ground, rocks and silos. Clear
bits are the yellow background. Nothing in this strip is any other
colour, so a cell never has to choose between black and yellow: both
are in the one pair.

The diver on this strip is drawn in black ink. Over a yellow valley he
is a black silhouette. Over a black hill his ink matches the hill, so
he disappears into it except where his mask lets the yellow paper
through. That is the clash, and it is honest: the alternative was a
third colour, which this cell does not have.

**Far strip, top row, every column.** Bright yellow ink, blue paper
(`BACK_HILL_ATTR`). Set once, never scrolled. Set bits are sand, clear
bits are the water showing through. Peaks of 10 pixels cross into this
row, and because every column is the same pair the peak does not change
colour as it slides.

**Far strip, bottom row.** The same yellow-on-blue pair, except a
seaweed column, which is bright green ink on yellow paper
(`BACK_WEED_ATTR`). The plant has to be green. The sand behind it, in
that same cell, then has to be yellow paper, so that cell cannot also
show blue water or the yellow-on-blue hill edge. The weed graphic is
only the bottom 8 pixels (`pat_weed` is copied to byte 8 of the
column), so the plant never shares the top cell. The top of a weed
column stays yellow sand on blue. The bottom cell gives up the hill
edge and the water.

Those 32 bottom-row attribute bytes move only when a far column lines
up with the screen, which is every 8 far pixels, so every 16 frames.
`shift_back_attrs` slides the 31 bytes that are already on screen one
cell left and writes the new right-hand cell. A full repaint of the
row, with the ring index worked out per cell, was measured at 16 to 22
scanlines and missed the interrupt on that frame. The short copy does
not.

Between those moments the pixels have moved and the colour has not, so
the green cell sits up to 7 pixels to the right of the plant. The
update is also deferred to the *next show frame* (`back_attr_pending`).
Updating it on the prepare frame, when the column actually wraps, would
put the colour one frame ahead of the pixels. They move together.

The near strip has no version of this skew. Its attributes never move,
and both of its colours are in every cell.

---

## Why it is done this way

### Pixel scroll, not character scroll

Moving a whole character column (8 pixels) at a time is cheap, and it
looks like the ground is stuttering. One pixel per frame at 50 Hz is
50 pixels a second on the near strip and 25 on the far one. The far
strip moves on prepare frames only (`back_phase`): half speed, with no
fractional counter.

### A buffer in ordinary RAM, then a copy

The pixels could be rotated in place in screen memory. Two reasons not
to:

* Screen memory (`$4000-$7FFF`) is contended. The buffers live at
  `$F000`, which is not, so the rotate runs at full speed.
* Rotating the screen while the beam is on that row tears the picture.
  The rotate happens *after* the copy, in the buffer. The copy is the
  only thing that touches the screen, and it finishes before the beam
  reaches that strip (the numbers are below).

### Show frame and prepare frame

Both strips used to be 8 pixels, and copying plus rotating 8+8 fitted
in one frame. 16+16, with both strips copied *and* rotated on the same
frame, does not. The near strip is the one that has to stay at one
pixel a frame. The far strip was already one pixel every two frames, so
the work is split instead of slowing either of them down:

```
phase 0  SHOW      copy the far buffer. Do not rotate it.
                   The screen and the buffer still match.
phase 1  PREPARE   do not copy it. Rotate the buffer, off screen,
                   so the next show frame reveals the new pixel.
```

The near strip is copied and rotated every frame. It starts at line
160, so the beam reaches it later than the far strip and there is time.
Skipping the far copy on a prepare frame does not leave a stale
picture: the buffer was not rotated after the last copy, so the bytes
on screen are still the bytes in the buffer.

This is not a drop to character scroll, and it is not 25 Hz. Both
strips still move at the speeds in the table above.

### How a column is built without missing the frame

A new column has to be drawn (the hill, then maybe a rock, a silo or a
weed) and its 16 pixel bytes have to be waiting when the fine scroll
wraps. Doing that on the wrap frame, on top of rotating both strips,
ran past the next interrupt. Two things keep it off that frame.

The shape is built a few frames early, straight into a spare 16-byte
buffer. The shifter reads the other buffer, and rotates it in place.
On the wrap the two pointers are swapped (`front_feed_ptr` and
`front_ahead_ptr`, and the same pair for the far strip). The arrival
frame does not copy 16 bytes. Two of those copies, on the frame both
strips wrapped, were the last thing that still dropped a frame.

The build itself is also not on the wrap, and the two strips never
build on the same frame:

```
near build    the show frame where front_fine becomes 3
              (four shifts before the near wrap)
far request   the prepare frame where back_fine becomes 2
far build     the show frame after that, via back_build_req
near wrap     every 8 frames, and it is a prepare frame
far wrap      every 16 frames, on the same prepare frame as a near wrap
attr update   the show frame after the far wrap, during the far copy
```

`front_fine` and `back_fine` both start at 0, and the far strip moves
exactly half as often, so a near wrap and a far wrap always land
together. The schedule above is what keeps a build off that frame, and
keeps the two builds off each other. The first ahead column is built
before the first wrap (the init path has already filled columns 0-32).

The tile ids are a ring of 32, not a row that slides along.
`front_head` says which slot is the left edge. The slot that just
scrolled off the left is reused as the new right-hand column. Sliding
the other 31 bytes with `LDIR` was several scanlines, which this frame
does not have. The far attribute row is the one place a 31-byte copy
is still worth it: the bytes are already on screen, so it is a shift
rather than a rebuild, and it only happens every 16 frames.

---

## How fast it has to be

A frame is 69,888 T-states (312 lines of 224). The interrupt is at the
start of the top border. If `main_loop` is still running when the next
interrupt arrives, `wait_frame` throws that interrupt away and waits
for the one after, and the game drops from 50 frames a second to 25.

`make timing` (`-DTIMING_BARS`, `build/diver-timing.sna`) turns the
border into a clock. Line numbers are picture lines, read off a Fuse
2x window. Fuse shows the top 24 lines of the 64-line top border, so
a band that ends at line -9 is still in the top border. The window
cuts off at about line 215. The bottom border continues to line 247,
and the next interrupt is at line 248.

| border  | what it covers | diver in the water | diver on the ground |
|---------|----------------|--------------------|---------------------|
| white   | restore, then sprites still above the far strip | ends at line 36 | ends at line -9 (top border) |
| cyan    | copy the strips. Both on a show frame, the near strip only on prepare | show: ends at line 140, or 146 on the frame the seaweed colour shifts. Prepare: ends at line 88 | show: ends at line 92. Prepare: ends at line 41 |
| magenta | the diver, if his feet are on a strip. Absent in the water | not present | ends at line 139 (show) or 87 (prepare) |
| red     | rotate the near buffer. A column build, when there is one, is in this band | ends at line 194, or about 198 when a column is built | ends at line 193, or 197 when a column is built |
| green   | rotate the far buffer. Prepare frames only | ends at line 196 | ends at line 195 |
| yellow  | debug digits, input, move both sprites | starts at line 195. Latest start is line 201, on the show frame that also shifts the seaweed colour | starts at line 194. A column-build frame starts it at 198 |
| black   | this frame's work is done | past line 215, so the window does not show it. See below | same |

The far strip is pixel line 144. On a show frame in the water the cyan
band is 103 lines and the prepare frame's near-only copy is 51, so the
far copy is about 52 lines and finishes near line 90, before the beam
reaches line 144. The frame that also shifts the seaweed colour extends
cyan to line 146. Those extra lines are the attribute row, written
before the pixels, so the far copy still finishes around line 96,
before line 144, and the near pixels finish at 146 against a strip
that starts at 160. On the ground both copies finish by line 92. Either
way the beam does not meet a half-copied row.

The rotate does not touch screen memory, so red and green may still be
going while the beam is on the strips. With the diver on the ground he
is drawn during magenta, which finishes at line 139 on a show frame.
The highest he stands is on a silo: top pixel at y = 176 - 16 - 15 =
145, so the draw is done before the beam reaches him.

Black is below the 24 bottom-border lines Fuse shows, so it was not
read off the picture. It was measured by assembling the same loop with
a nop sled after the real work, one picture line (224 T-states) at a
time, and watching whether the frame counter and a counter inside the
loop stayed in step. One extra line never dropped a frame, in the water
for 12 seconds and on the ground for 10 seconds, which covers every
phase: show, prepare, a near build, a far build, the double wrap, and
the seaweed-colour frame. Two extra lines dropped a few frames. That
build printed the skip count in the IMG slot. The shipping build prints
the image index there instead, which costs a few dozen T-states more,
still inside the one line. The heaviest frame (the seaweed-colour show
frame, with the diver up in the water so the copy starts later)
therefore finishes about one scanline before the interrupt. Typical
frames start their yellow band 3 to 7 lines earlier, so they have that
much more in hand.

That is the whole margin. A later feature that needs more than about
one scanline on that frame will miss it. The options then, none of
which are taken here, are: stop printing the row-23 input digits, or
give up a pixel rate (character scroll, or moving the far strip less
often). Dropping the near strip below one pixel a frame was not done.
The one-line margin is why the column build, the 16-byte feed and the
attribute row were each taken off the heavy frame rather than the
scroll being slowed down.

The same causes as the flat-strip version are still in the code, and
still matter:

* `LDIR` is 21 T-states a byte. The copy is unrolled `LDI`. Inside one
  character cell the next pixel line is `INC D`, so the row address is
  looked up once per strip, not once per line.
* The rotate is unrolled `RL (HL)` / `DEC L` = 19 T-states a byte.
  `DEC L` rather than `DEC HL` because every row is 32 bytes on a
  32-byte boundary, so a row never crosses a 256-byte page.
* `print_hex8` writes the picture only. `print_char` would also rewrite
  the attribute byte, and the debug line prints 16 digits a frame.

---

## Order inside the frame

```
wait_frame
diver_restore             ; put back what was under him last frame
fish_restore              ; then the fish (reverse of the draw order)
fish_draw                 ; the fish is always above the strips
if the diver's feet are still above line 144:
    diver_draw            ; the copy will not touch him
scroll_blit_back          ; far buffer -> screen, show frames only
scroll_blit_front         ; near buffer -> screen, every frame
if the diver's feet were on a strip:
    diver_draw            ; he was not drawn yet; he saves THIS ground
scroll_front              ; rotate the near buffer, off screen
scroll_back               ; rotate the far buffer, prepare frames only
print the debug line, read keys, move both sprites
```

Why that order:

* The background record is a photograph of the screen at the moment of
  the save. The copy overwrites a strip completely. If a sprite was
  saved *before* the copy, the photograph is last frame's ground, and
  next frame the restore paints those pixels onto ground that has
  moved.
* If the sprite is saved while it is still on screen, the photograph
  contains the sprite. The next restore paints it back as debris.
* The fish never reaches line 144 (`FISH_SWIM_Y + FISH_HEIGHT` is
  checked with an `ASSERT`). Drawing him before the copy keeps the beam,
  which is still in the top border, ahead of him.
* The diver does both. While his lowest pixel is above line 144 he is
  drawn with the fish. The moment that pixel touches the far strip he
  is drawn after the copy, so the bytes he saves are the ground that is
  on screen now. The same test is in `main_loop` twice on purpose.
* Restore stays first even for a sprite that was on a strip. It puts
  last frame's ground back, and the copy immediately replaces the
  strip. The beam does not reach the strip until after the copy. On a
  prepare frame the far copy is skipped, which is safe only because
  the far buffer was not rotated after the previous copy, so the
  screen already matches it. The near copy still overwrites the whole
  near strip, including whatever the restore just put back.

A headless run of 1024 frames checked this with the silhouettes in
place. The diver climbed through the fish, then held Down and rode the
near hills. After every restore the open water was blank, and both
strips matched a snapshot of the buffers taken after the previous
copy and before either rotate. The border turned green and the loop
stopped. There is no blank floor to check any more: rows 20-21 are the
near strip.

Erase order is still reverse of draw order. The diver is drawn after
the fish, so when they overlap his photograph contains a piece of the
fish, and he has to be erased first. That is unchanged from
docs/SPRITES.md. They overlap in the water. The fish is at pixel y 76,
and the diver is not drawn late until his feet reach line 144.

---

## Silos, rocks, seaweed

A strip is a ring of tile ids, one per character column, plus a fine
scroll of 0..7 pixels (`front_fine`, `back_fine`).

```
screen x of the left edge of column i   =  i * 8 - front_fine
tile of screen column i                 =  front_tiles[(front_head + i) & 31]
solid height of that column             =  front_h[(front_head + i) & 31]
world column of that slot               =  front_origin + i
```

`front_head` is the slot currently at the left edge. `front_origin` is
the world column of that slot. `TILE_SILO` (2) is a silo. `TILE_ROCK`
is 1, flat is 0. The column still sliding in from the right is
`front_pending`, and its height is `front_h_pending`. It is not in the
ring until `front_fine` wraps, and its world column is
`front_origin + 32`. The same names with `back_` are the far strip.
`TILE_WEED` is the only non-flat tile there.

Missiles are not in this version. When they are, the hatch is the pair
of `%00100100` rows in `pat_silo`. Find the silo with the lines above.
The top of the near strip is pixel y `FRONT_ROW * 8` = 160, and a silo
is 16 pixels, so the tip is the top of the strip. The art is a
placeholder. The placement is not: `level_silo_gap` still decides it.

```
level 0   every 24 columns     the demo (level_index is 0)
level 1   every 16
level 2   every 12
level 3   every 8
```

Poke `level_index` (0 .. `LEVEL_COUNT-1`) before `scroll_init` to try a
later level. Column N is a silo when N mod gap = 0. Rocks are column
mod 10 = 4, unless that column was already a silo (the rock counter
still advances, so the next rocks stay on 4, 14, 24, ...). Seaweed is
column mod 11 = 3. The code counts down to the next one instead of
dividing. A divide on the frame a new column arrived was part of what
used to push that frame over the interrupt. The countdown is the same
rule. The hill shape is separate from those counters: it is just the
column number mod 16, looked up in the profile, so the hills keep
their shape however the silo gap changes.

`clamp_to_terrain` reads `front_h` back. His 24 pixels cover up to four
columns, or five when the right-hand one is the column still sliding
on (screen x + `front_fine`, then divide by 8). The right edge can
land past x = 255; that column is number 32, which is
`front_h_pending` rather than a slot in the ring. The tallest of those
columns wins. His top y is then `NEAR_BOTTOM - height - DIVER_HEIGHT`,
with `NEAR_BOTTOM` = 176, so his feet sit on the pixel above the solid.
The clamp runs every frame, including when he is holding still, because
the ground scrolls either way and a hill has to be able to lift him.

---

## Memory

| region            | address        | what |
|-------------------|----------------|------|
| code and data     | `$8000-$A927`  | `code_end` is `$A928` (10,536 bytes) |
| far buffer        | `$F000-$F1FF`  | 16 rows x 32, not on the tape |
| near buffer       | `$F200-$F3FF`  | 16 rows x 32 |
| (free)            | `$F400-$F9FF`  | |
| row address table | `$FA00-$FB7F`  | built at start-up |
| stack             | grows down from `$FDFC` | must not reach `$FB80` |
| `JP isr`          | `$FDFD`        | |
| IM2 vectors       | `$FE00-$FF00`  | 257 bytes of `$FD` |

`SCROLL_BUF_END` is `$F400`. An `ASSERT` refuses to assemble if the
buffers reach the row table, if a buffer row would cross a 256-byte
page (the `DEC L` in the rotate depends on it), or if the two strips
are not both 16 pixels with the near one sat against the far one and
stopping at row 22.

The spare 16-byte feed and ahead buffers live with the code, not in
the `$F000` block. They are four small arrays plus four pointers. The
shifter rotates the feed buffer in place. After eight rotates a byte
is back where it started, and the next build overwrites that buffer
completely, so nothing is left to clear.

---

## Not in this version

* Trigon missiles, and anything that reads the silo table yet. The ids,
  the heights and the position formula are there so that code has
  somewhere to look. The silo picture is a placeholder.
* The scroll does not follow the diver. See the top of this file.
* Sprites do not clip off the edge of the screen. The strips scroll
  under them; the sprites stay fully on screen. His lowest y is no
  longer a constant: `clamp_to_terrain` holds his feet one pixel above
  the near column under him.
* No vertical scroll.
* The seaweed colour is one cell behind the plant by up to 7 pixels.
  That is the attribute file, not a bug to be fine-scrolled away.
