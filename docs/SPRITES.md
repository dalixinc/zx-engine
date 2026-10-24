# Sprites on the ZX Spectrum: how DIVER ENGINE does it

This walks through the techniques behind milestones 4 and 5, "Sprites" and
"Diver": a 16-pixel fish and a 24-pixel diver that swim smoothly over the
scenery and each other without flicker or damage. The code is in
`src/screen.asm` (addressing), `src/sprite.asm` (drawing, any width),
`src/diver.asm` (the player), `src/fish.asm` (the fish, now swimming by
itself), `src/scenery.asm` (backdrop) and `tools/gfx2asm.py`
(graphics converter). Read this first, then the code: the comments in the
code use the same words.

---

## 1. The screen layout

The display is 256 x 192 pixels, 1 bit per pixel, at `$4000-$57FF` (6144
bytes), followed by 768 bytes of colour attributes at `$5800-$5AFF`, one per
8x8 character cell.

Each byte of the bitmap holds 8 horizontal pixels; bit 7 is the leftmost.
A pixel row is 32 bytes. So far so simple. The catch is the **order** of
the rows in memory. It is not row 0, row 1, row 2... Instead the screen is cut
into three "thirds" of 64 rows, and inside each third the memory goes:

```
$4000  pixel line 0 of character row 0
$4020  pixel line 0 of character row 1
...    (line 0 of all 8 character rows in this third)
$4100  pixel line 1 of character row 0
...
$4700  pixel line 7 of character row 7      -> end of the top third
$4800  the middle third starts, same pattern
$5000  the bottom third
```

(You can see this when a game loads a SCREEN$ from tape: it fills in as
stripes, then each third.)

### The address of pixel row y

Write y (0-191) in binary as three groups:

```
 y =  y7 y6 | y5 y4 y3 | y2 y1 y0
      third   char row   line inside the cell
```

The address of the first byte of that row is:

```
 H = 0 1 0 y7 y6 y2 y1 y0
 L = y5 y4 y3 0 0 0 0 0         (+ column 0-31 for the byte across)
```

i.e. the bits are shuffled: the "line in cell" bits move up into H, the
"character row" bits go into the top of L.

**Worked example**, y = 100 = `%01 100 100`:

| part         | bits  | goes to       |
|--------------|-------|---------------|
| third        | `01`  | H bits 4-3    |
| char row     | `100` | L bits 7-5    |
| line in cell | `100` | H bits 2-0    |

H = `010 01 100` = `$4C`, L = `100 00000` = `$80`, so row 100 starts at
`$4C80`. That is what `screen_row_addr` in `screen.asm` computes, with a few
ANDs and rotates.

Two useful consequences:

* Inside one character cell, moving down a pixel line is just `INC H`
  (+256). The ground copy in `scroll.asm` uses that: it looks the first
  line of a strip up in the row table, then `INC D` for the other seven.
* Crossing a cell boundary or a third needs a different adjustment each
  time. Getting that right in every drawing loop is fiddly and slow.

### The row lookup table

So we work every address out **once**. At start-up `build_row_table` calls
`screen_row_addr` for y = 0..191 and stores the 192 results as words at
`ROW_TABLE` (`$FA00`, 384 bytes). After that, "address of row y" is just the
word at `ROW_TABLE + 2*y`, and the next row down is the next word. Sprite
loops point IX at the entry for the top row and do `INC IX : INC IX` per row.
Adding the column to the low byte (`ld a,(ix+0) : add a,c`) can never carry,
because the low 5 bits of every row address are zero and the column is 0-31.

The table is filled at run time rather than stored in the program, so it
costs nothing on tape and is obviously correct (it is produced by the very
routine you can read).

---

## 2. Masked drawing: AND the mask, OR the data

The simplest way to put a sprite on screen is to OR or XOR its pixels in.
Both look bad over scenery: OR merges the sprite into what is behind it, and
XOR inverts the background inside the sprite.

A **mask** fixes this. Every sprite byte comes with a mask byte:

* mask bit **1**: this pixel is see-through, keep the background
* mask bit **0**: the sprite is solid here, clear the background

and the screen byte becomes

```
screen = (screen AND mask) OR data
```

In Z80, with DE pointing at the screen and HL at the (mask, data) pairs:

```
ld a,(de)     ; background byte
and (hl)      ; punch a sprite-shaped hole in it
inc hl
or (hl)       ; fill the hole with the sprite's ink pixels
inc hl
ld (de),a
```

The screen pointer lives in DE, not HL, because the Z80 can only `AND (HL)`
and `OR (HL)`. It is the image we need to AND and OR with.

Masks also give a third kind of pixel. In `gfx/fish.txt`:

| char | meaning | mask | data |
|------|---------|------|------|
| `#`  | ink     | 0    | 1    |
| `-`  | paper (solid but "off"), e.g. the eye | 0 | 0 |
| `.`  | transparent | 1 | 0 |

In the montage you can see the seabed pebbles through the gaps in the
fish's tail while its body hides them.

**Attribute clash.** Colour is per 8x8 cell, not per pixel, so a sprite has
whatever INK and PAPER the cells it covers have: white on blue in the water,
yellow on blue over the far hills, green on yellow on a seaweed cell, and
black on yellow over the near hills. That is the famous Spectrum "clash".
On the near strip his ink is black, so he reads as a silhouette in a yellow
valley and disappears into a black hill. A seaweed cell cannot also be
yellow-on-blue; the trade-off is written out in docs/SCROLLING.md.

---

## 3. Pre-shifted frames

A sprite at x = 13 starts in column 13/8 = 1, but 13 AND 7 = 5 pixels into
that byte. Every byte of its image has to move right by 5 bits, and the bits
that fall off the right go into the next byte, so a 16-pixel sprite now
covers **3** bytes per row.

You can do that shifting at run time (`SRL` / `RR` loops), but it costs
roughly 8 T-states per bit per byte, every frame, for every sprite, and it
makes the draw routine much harder to read.

Instead we store **8 copies** of every frame, already shifted by 0, 1, ..., 7
pixels and already 3 bytes wide. The draw routine picks copy number
`x AND 7` and then just copies bytes, as above.

### Build time, not run time

The copies could be made by a Z80 routine at start-up, but we generate them
with a short Python script, `tools/gfx2asm.py`, when the program is built:

* the shifting and mirroring maths is a dozen readable lines of Python;
* the generated `gfx/fish.asm` shows each row in binary with an ASCII
  picture beside it, so you can *see* the shift (open it and look at
  `fish_right_f0_s0` vs `fish_right_f0_s5`);
* the Z80 side stays small: one plain draw routine.

`gfx/fish.asm` is committed to git, so on Windows you only need Python if
you change the art. `make` regenerates it whenever `gfx/fish.txt` changes.

The left-facing frames are made by mirroring the right-facing art (each row
reversed), so you draw the fish only once.

### Memory cost

Each row of one shifted copy is 3 bytes of mask + 3 bytes of data = 6 bytes.

```
6 bytes x 9 rows x 8 shifts x 2 frames x 2 facings = 1728 bytes
```

versus 2 x 9 x 2 x 2 x 2 = 144 bytes unshifted: 12x the memory to save the
CPU work. For a 48K game that's a trade worth thinking about per sprite.

The diver (24 x 15, 3 frames) is 4 bytes wide once shifted, so 8 bytes per
row with the mask:

```
8 bytes x 15 rows x 8 shifts x 3 frames x 2 facings = 5760 bytes
```

That is why the diver has 3 frames, not 4: the kick goes apart, half way,
together, half way, and the "half way" frame is shown twice from a little
table (`kick_sequence` in `src/diver.asm`) instead of being stored twice,
which would cost another 1920 bytes. Tricks to cut memory further (only 4
shifts and moving in 2-pixel steps, or shifting at start-up into spare RAM)
can come later if memory gets tight.

---

## 4. Erasing: save and restore the background

To move a sprite we have to remove it from its old position. Options:

* **Erase by clearing** the old area to paper. Cheap, but it wipes out
  any scenery under the sprite.
* **Redraw the scenery** under the old position. Fine for a plain
  background, complicated once the ground scrolls.
* **Save and restore**, which we use: just before drawing, copy the screen bytes
  the sprite will cover (bytes per row x height) into that sprite's own
  background record. Next frame, copy them
  back. That removes the sprite *and* repairs whatever was underneath,
  whatever it was.

Each frame, for each sprite:

```
sprite_restore_bg   ; put back what was under it last frame
sprite_set_pos      ; work out column, shift and row for the new position
sprite_save_bg      ; copy what is under the new position
sprite_draw         ; AND mask / OR data
```

The ground now scrolls, so those rows are not the same pixels as at the
start: they have moved. What has to stay true is that restoring a sprite
puts back exactly the bytes it saved, and that the save happened after
this frame's ground was copied up. A headless run of 1024 frames (the
diver climbing through the fish, then holding Down and riding the near
hills) checked the open water was blank after every restore, and that
both silhouette strips matched the off-screen buffers from the moment
the sprites were saved. There is no separate blank floor: rows 20-21
are the near strip. The order that makes that true is in docs/SCROLLING.md.

### Two sprites: one record each, and erase in reverse order

Each sprite has its own **background record** (`fish_bg`, `diver_bg`), a
small header (valid flag, y, column, height, bytes per row) followed by the
saved bytes. The routines in `src/sprite.asm` are told which record to use
in **IY**, because `(iy+BG_COL)` and friends let them read the header fields
by name while HL and DE are busy copying.

The order in `main_loop` is restore both, then draw whoever is still in
open water, then copy the scrolling strips, then draw the diver if his
feet are on a strip. Full diagram in docs/SCROLLING.md. The part that
matters for overlap is unchanged:

```
diver_restore   ; erase in the REVERSE order of drawing...
fish_restore
fish_draw       ; ...then save + draw, back to front
diver_draw      ; the diver is drawn last, so he is in front of the fish
```

(When the diver is on the ground, his draw is the one that moves to after
the strip copy. The fish is never that low.)

Why reverse? The fish is drawn first, so when the diver overlaps it, the
diver's saved background *contains part of the fish*.

* Right order: restore the diver (puts back water plus that bit of fish),
  then restore the fish (puts back the water under the fish). Clean.
* Wrong order: restore the fish first (water), then the diver, whose saved
  bytes still hold the old bit of fish, so a fragment of fish is painted
  back and left behind as debris.

Undo in the opposite order to do, like taking plates off a stack. The test run
(`07-cross-*` shots) has the fish swim right behind the diver and out the
other side with no debris left behind.

---

## 5. Timing: draw straight after HALT

The TV picture is drawn top to bottom, 50 times a second. The ULA raises an
interrupt at the start of each frame. Our IM2 handler sets `vsync_flag`, and
`wait_frame` `HALT`s until that happens.

On a 48K machine the beam then spends roughly **14,336 T-states** (64 lines x
224 T-states) in the top border before it reaches pixel line 0. Each picture
line after that takes 224 T-states. The water starts at character row 7 =
pixel line 56, so the beam reaches the top of the fish's area about
14,336 + 56 x 224 = **26,880 T-states** after the interrupt.

If we change the screen bytes *after* the beam has passed them, the old
picture has already been shown for this frame and the new one appears next
frame: no problem. The danger is when the beam passes **while** the sprite is
half done, e.g. erased but not yet redrawn. Then you see a flicker or a torn
sprite.

So `main_loop` does all sprite work **first**, straight after `wait_frame`,
before the border/debug printing and input reading.

### Measured: the timing build

`make timing` assembles the same program with `-DTIMING_BARS` into
`build/diver-timing.sna`. The border changes colour as the frame goes, so
the bands show which part of the work the beam has reached. v0.4 (sprites
only, no scrolling ground) finished both sprites around pixel line 37.
v0.5 has more to do; the bands and the T-state sums are in
docs/SCROLLING.md. The rule is the same: finish writing a row before the
beam gets there.

Rule of thumb for later: do all sprite erasing and drawing as early in the
frame as possible, and keep the slower game logic for after. When there are
many sprites, draw them in order of screen position from top to bottom, so
the beam is always behind you (the "chase the beam" trick).

---

## 6. Clipping

`update_diver` clamps the diver to the play area: x 0-231, and y from the
top of the water down to one pixel above the ground.
`clamp_to_terrain` reads the height of every near column under his 24
pixels and lifts him when a hill scrolls underneath. The right limit is
`256 - bytes*8 + 7`: at that x all
bytes of a shifted row still land on the same screen line (diver: column
28 + 3 = 31; fish, 3 bytes: x 239, column 29 + 2 = 31). Pushing a direction
against an edge still counts as "moving", so he kicks against the wall.
The fish uses the same kind of limit and turns round there. Both of them,
and Engine Demo 1, call `sprite_set_pos` / `sprite_draw`, which still
require the whole sprite on the screen.

### Sliding off the edge

A wheel bomb has to enter from the right and leave through the left, a
pixel at a time, so part of it is off the screen for a while. That is
`sprite_set_pos_x` and `sprite_draw_clip` in `src/sprite.asm`. They are
assembled only when `ATLANTIS` is defined. The demo does not define it,
the routines above those two are unchanged, and `build/diver.tap` is the
same file it was at tag `engine-demo-1`.

x is a signed 16-bit pixel. Negative means "this many pixels past the
left", 256 and above means "not yet on the right". The pre-shifted copies
are the same ones as before. The copy is still chosen by the low 3 bits
of x, and the column is still floor(x / 8), only now that divide keeps
the sign (three `SRA`/`RR` pairs). So x = -1 is column -1, shift 7, which
is the copy whose first pixel sits in the right-hand bit of the first
byte: one pixel off the left, the rest on screen.

Bytes that would land in a column below 0 or past 31 are not written.
`spr_col` and `spr_bytes` are set to the visible column and the visible
count, and `sprite_save_bg` stores those in the background record. Restore
is the ordinary routine. It puts back exactly the bytes that were saved,
so a half-drawn sprite does not wrap onto the next screen line and does
not leave a copy of itself behind. When the sprite is completely off
screen, `spr_hidden` is set. The caller skips the save and the draw and
clears `BG_VALID`. The restore at the start of the frame has already
erased the old position; leaving the flag set would paint that old
photograph a second time.

If the sprite is fully on screen, `sprite_draw_clip` jumps straight to
`sprite_draw`. The test is about 70 T-states, a third of a scanline, and
the byte loop is the original one. While it is actually clipped, each row
adds the hidden image bytes onto HL so the next row starts in the right
place:

```
ld a,(spr_gap2)   ; 13
add a,l           ;  4
ld l,a            ;  4
jr nc             ; 12, or 7 when the add crosses a 256-byte boundary
inc h             ;  4, only on that cross
```

33 T-states on a normal row. A 16-row sprite pays 16 × 33 = 528
T-states, 528 / 224 = 2.4 scanlines, and the byte loop is shorter by
every byte that is off screen (one masked byte in the shared loop is
about 57 T-states). Skipping the hidden bytes is cheaper than the other
approach, an off-screen margin: that would draw the whole sprite into a
wider buffer and then copy the visible part, so the hidden bytes would
still be drawn.

Atlantis does not draw the wheel, the fish or the diver with that shared
loop. `src/atlantis/fastsprite.asm` steps down the screen by adding to
the high byte, and writes each width out in full. The wheel is 12 by 12.
A shift of 0 to 4 is two bytes wide and a shift of 5, 6 or 7 is three,
which is what `gfx/wheel.txt` asks for. The three-byte copy is the slow
one, so those twelve rows are written out with no per-byte loop. The
spare this leaves, and the one seabed frame that was still short, are
in `docs/SCROLLING.md`.

Vertical clipping is not done. Callers keep y on the screen. A sprite
wider than the screen, clipped on the left and the right at the same
time, is not handled either. Nothing in the game is that wide.

---

## Changing the art

Edit `gfx/fish.txt`, `gfx/diver.txt` or `gfx/wheel.txt` (`#` ink, `-` paper,
`.` transparent; frames separated by `frame` lines; `;` starts a comment),
then run `make`. A line that says `mirror off` skips the left-facing copy.
The wheel bomb uses that, because its T must not be mirrored. The fish
and the diver do not, so they still get both facings. With no `make`, run
e.g. `python3 tools/gfx2asm.py gfx/diver.txt gfx/diver.asm diver` and then
`build.bat`.

## Making a sprite wider

The width is no longer built into the code. To make a 32-pixel sprite:

1. **Draw it** 32 characters wide. The width must be a multiple of 8
   (gfx2asm.py stops with an error otherwise). It reads the width from the
   first row and writes `NAME_WIDTH` (32), `NAME_BYTES` (5) and
   `NAME_HEIGHT` into the generated file.
2. **Why `NAME_BYTES` is width/8 + 1.** Shifting a row right by 1..7 pixels
   pushes its rightmost pixels out of the last byte and into the next one,
   so a shifted 32-pixel row touches 5 bytes. At shift 0 that fifth byte is
   empty (all transparent), but every copy is stored at the same size so
   the draw loop doesn't need to know which shift it is drawing. That spare
   column is the price of having one simple loop.
3. **Give it a background record** big enough:
   `my_bg: ds BG_DATA + NAME_BYTES * NAME_HEIGHT`.
4. **Pass the size** when you position it: `D = NAME_BYTES`,
   `E = NAME_HEIGHT` into `sprite_set_pos`; `IY = my_bg` for
   `sprite_save_bg` / `sprite_restore_bg`. `sprite_draw` uses whatever
   `sprite_set_pos` stored.
5. **Clamp x** to `256 - NAME_BYTES*8 + 7` (here 223) and y to
   `176 - NAME_HEIGHT`.
6. **Check the cost**: memory is `2 x NAME_BYTES x height x 8 shifts x
   frames x facings`, and the draw time grows with bytes x rows. Re-run
   `make timing` and read the border bands against docs/SCROLLING.md.
