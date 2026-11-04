# Atlantis memory

How the 48K is laid out, what is built at start-up, and how the tape is
packed. The map below is the current one, after the levels 3 and 4
brief ([LEVELS-3-AND-4.md](LEVELS-3-AND-4.md): 173 bytes of hot code,
272 of data, 264 of the cold block, and the jet's two still pictures,
1,920 bytes built at start-up). Under it are the two briefs
that made it: Quartus's **squeeze** brief (November 2026) and, before
it, the **housekeeping** brief (PR #23).

## The map

| Address | What |
|---|---|
| `$4000-$5AFF` | screen |
| `$5B00-$5FFF` | BASIC (`CLEAR 24575`) |
| `$6000-$7188` | **cold block** (4,489 bytes): menu, the title (`title_draw`), level codes, start-up, resets, the level 2 and 3 messages, the death (`death.asm`), each level's look (`level_style`), menu words, and the raw art `preshift` reads (fish, pulsar, spinning wheel, diver), with the jet's bubbles it adds to the diver's (`diver_jet_build`) |
| `$7189-$71BF` | free (55) |
| `$71C0-$7FFF` | the spinning wheel's shifted pictures (built at start-up) |
| `$8000-$B8E1` | code (`code_end` `$B8E2`), with the power-ups' pictures, the double shot's patch tables, the round fish's raw art and tables, and start-up work the cold block has no room for (`slope_build`, `torpedo_reset`) |
| `$B8E2-$B91F` | free (62) |
| `$B920-$BC7F` | the round fish's left-facing shifted pictures (`RFISH_BUF`, 864, built at start-up; the tape build only, `TWO_FISH`: builds with the stat line and the soak have their code here instead) |
| `$BC80-$C3FF` | the diver's two still pictures with the jet's other phase (`JET_BUF`, 1,920, built at start-up; the soak build has its code here instead) |
| `$C400-$CDB2` | data: graphics, tables, `data.asm` (`data_end` `$CDB3`) |
| `$CDB3-$CF2F` | free (381) |
| `$CF30-$E5AF` | the diver's shifted pictures (5,760, built at start-up) |
| `$E5B0-$EC6F` | the fish's shifted pictures (built at start-up) |
| `$EC70-$EFFF` | the pulsar's shifted pictures (built at start-up) |
| `$F000-$F2FF` | scroll buffers |
| `$F300-$F517` | the buffers that start empty (`bss.asm`, zeroed at start-up) |
| `$F559-$F59F` | free (71) |
| `$F5A0-$F8FF` | the round fish's right-facing shifted pictures (`RFISH_HI`, 864, built at start-up, tape build only), up to `BSS_LIMIT` `$F900`, which the loader shares. The soak build keeps its title photograph at `$F600-$F8FF` (`SOAK_TITLE`) instead |
| `$FA00-$FB7F` | row table |
| `$FB80-$FC7F` | the seabed's sloped column tops (`SLOPE_GROUND`, `SLOPE_SAND`, built at start-up by `slope_build`) |
| `$FDFC` down | stack (`STACK_NEED`, 128 bytes, is kept clear above the slope tables) |
| `$FDFD`, `$FE00-$FF00` | `JP isr`, IM2 table |
| `$FF01-$FF57` | free (87) |
| `$FF58-$FFEF` | the ROM's UDG area: the title's letters, the seaweed, the rock, the hearts and the double shot's bubble (`udg.asm`, 152 bytes, its own tape block) |
| `$FFF0-$FFFF` | free (16) |

Everything from `$6000` to `$7FFF` is contended: the ULA slows each
access while it draws the picture. Only the spinning wheel's pictures
are read there in play (measured to cost nothing at 50, see
[WHEEL-BOMB.md](WHEEL-BOMB.md)). No code that runs every frame is below
`$8000`. The death runs from the cold block, but only while the game is
stopped, and a frozen step has plenty of time to spare.

The ends come from the build's `DISPLAY` lines (`atlantis code_end`,
`data_end`, `cold_end`). The `ASSERT`s at the end of main.asm stop the
build if any of them runs into the next thing up.

While the tape loads, two more things sit in memory for a moment: the
first block, from the page after `cold_end` (`$7200-$7EAA`: the
unpacker, the packed loading screen, the packed data block and the
packed UDG block), and the second, the packed cold block and code, from
the page after `data_end` (`$CE00-$F9EF`, 1,385 bytes below the ROM's
UDGs at `$FF58`, its limit). Start-up builds the shifted pictures over
both. See [UDG-AND-SEABED.md](UDG-AND-SEABED.md).

## The squeeze brief: free bytes, before and after

Before is `main` after PR #23 (`3aaa365`). After is `claudelet/dev` at
the end of the brief.

| Area | Before | After |
|---|---|---|
| code (`code_end` to `$C400`) | 4,689 | 4,696 |
| data (`data_end` to the next thing up) | 341 | **965** |
| code and data together | 5,030 | **5,661** |
| cold block (`cold_end` to `$71C0`) | 2,234 | 517 |
| empty buffers (`$F518` to `$F900`) | 1,000 | 1,000 |

The cold block gave the most. It took the raw art that only start-up
reads (624 bytes of fish, pulsar and wheel, then the diver's 540) and the
death (442).

## The tape

| Block | Before | After |
|---|---|---|
| BASIC | 62 | 63 |
| loading screen | 6,912 | packed into the next block |
| unpacker, dzx0 and the packed screen | - | 1,772 |
| cold block | 2,310 | packed into the next block |
| code | 12,719 | packed into the next block |
| data | 8,283 | packed into the next block |
| the packed game (cold, code, data) | - | 10,787 |
| **`.tap` file** | **30,411** | **12,697** |

Most of the gain is ZX0 (item 5): before the death went in, the tape
was 25,320 unpacked and 12,382 packed. The diver's start-up shifting
(item 4) took 5,091 bytes off before that.

Unpacking takes 7 frames for the screen (0.14 s, while the second
block is still loading) and 27 for the game (0.54 s), measured by
`make unpack-check`, whose sums of the unpacked screen, cold block,
code and data match the files' (`build/*.bin`, `gfx/loading.scr`).
Start-up then shifts all four sprites in 22 frames (0.44 s).

## The squeeze brief, item by item

| Item | Commit | What |
|---|---|---|
| 1 | `621d7ab` | The raw fish, pulsar and wheel art (624 bytes) into the cold block. Data free 341 to 965. All shifted bytes identical. |
| 2 | `7f56c5c` | Real asserts: the BASIC's CLEAR, `STACK_NEED` above the row table, one `BSS_LIMIT` (`$F900`) shared with the loader, and the soak's photographs. Each was tripped on purpose. |
| 3 | `b1cf1b5` | `fast_draw_gap` kept the row gap in the alternate A, which the ADD then overwrote, so a bomb clipped at either edge was drawn scrambled. The gap is now patched into each width's ADD once per draw. Timing unchanged. |
| 4 | `5f6023c` | The diver shifted at start-up like the fish: `gfx2raw.py` takes 24-pixel art, `preshift` a 4-byte working row. His 5,760-byte copies are built just below the fish's, from 540 bytes of art in the cold block. Same bytes as gfx2asm.py's. |
| - | `a671db8` | Each game starts just after an interrupt. Without it, how long start-up took decided where the first step fell in the frame, and item 4 changed that. |
| 5 | `302dc5a` | ZX0. The compressor is Einar Saukas's C source (`tools/zx0/`, BSD-3), built by make as `build/zx0`. The decoder is `tools/dzx0_standard.asm`. main.asm writes the blocks (`build/*.bin`) and an unpacked tape (`build/atlantis-plain.tap`), and `tape.asm` packs them behind the unpacker. The `.sna` and the web build are unchanged. |
| 6 | `fcf3426` | The torpedo's zap: two notes, 60 ms (was 240), and only into silence ([LASER.md](LASER.md)). |
| 7 | `27f3f78` | The diver's death: the game stops, he flashes, he blows up, then the life ([DEATH.md](DEATH.md)). |

Item 8 (shifting the diver on demand) was left out, as the brief asked.

### Timing at the end of the brief

| Build | Rate | Min spare | Late | Interrupts |
|---|---|---|---|---|
| MEAS_DOWN | 50 | 9 | 0 | 512 |
| MEAS_DOWN + MEAS_FIRE | 50 | 2 | 0 | 512 |
| MEAS_DOWN + MEAS_SPIN | 50 | 9 | 0 | 512 |
| MEAS_DOWN + MEAS_MISSILE | 50 | 4 | 0 | 512 |
| MEAS_BOOM | 50 | 0 | 1 | 512 |
| MEAS_DOWN | 25 | 48 | 0 | 1024 |
| MEAS_DOWN + MEAS_FIRE | 25 | 47 | 0 | 1024 |
| MEAS_DOWN + MEAS_SPIN | 25 | 47 | 0 | 1024 |

MEAS_FIRE at 50 was 8 in the housekeeping table below. That figure
depended on how long start-up took, which item 4 changed. Since
`a671db8`, it is 2 every time, on `main`'s code as well. The rest are
unchanged. The soak is green at 50 and 25, and Engine Demo 1 is
byte-identical.

## The housekeeping brief (PR #23)

Quartus's earlier brief: more room, a shorter tape, and no gameplay
changes. Its map, before and after:

| Address | Before | After |
|---|---|---|
| `$4000-$5AFF` | screen | screen |
| `$5B00-$5FFF` | BASIC (`CLEAR 32767`) | BASIC (`CLEAR 24575`) |
| `$6000-$6905` | free (the soak build's code) | **cold block** (2,310 bytes) |
| `$6906-$71BF` | free | free (2,234) |
| `$7000-$7E3F` | the spinning wheel's shifted pictures | |
| `$71C0-$7FFF` | | the spinning wheel's shifted pictures, packed against `$8000` |
| `$8000` | code, to `code_end` `$BEA4` | code, to `code_end` `$B1AF` |
| code/data line | `$C000` | **`$C400`** |
| data | `$C000-$EBA0` | `$C400-$E45A` |
| `$E5B0-$EFFF` | (in the data block) | the fish's and the pulsar's shifted pictures |
| `$F300-$F517` | free (the soak's photographs) | **the buffers that start empty** |

| Free bytes | Before | After |
|---|---|---|
| code | 348 | 4,689 |
| data | 1,119 | 341 |
| `$6000-$7FFF` | 4,544 (soak only) | 2,234 |

The tape went from 34,274 to 30,411 bytes.

### What each item did

**1. The line** moved from `$C000` to `$C400` (`DATA_START`, constants.asm).
The demo doesn't use it.

**2. The cold block.** Two macros in main.asm, `COLD` and `HOT`, switch
the assembly address between the hot code at `$8000` and the cold block
at `$6000`. So a routine is moved by putting `COLD` before it and `HOT`
after it, and it stays in its own file next to the code it belongs with.
In the cold block:

- the menu (`menu.asm`, except `leave_key_p`, which the chords read every
  step), its words and option table;
- the level codes: the table, showing one, typing and checking one
  (`codes.asm`);
- start-up: `boot` (the rest of `entry`), `preshift`, `text.asm`
  (`print_string` and friends: only the menu, the message and the
  test builds' hex print use it), the seabed's first build
  (`scenery.asm`, `scroll_init`);
- once-a-game: `score_reset`, `score_game_over`, the level 2 message
  (`teaser`), `rate_arm`, and the torpedo, missile, burst and wheel
  resets.

The variables stay above `$8000`, because play reads them. `snd_knell`
stays too: its pitch is its timing loop. The BASIC is now
`CLEAR 24575: LOAD ""SCREEN$: POKE 23739,111: LOAD ""CODE: LOAD ""CODE:
LOAD ""CODE: RANDOMIZE USR 32768`. `entry` is still at `$8000`.

`code_text`, which writes a level's code for the banner, runs from the
cold block on the step a level goes up. That's once per level and a few
hundred T-states, on a step whose banner is far more work.

**3. The stat line** is left out of the tape. `STATS` is defined for the
soak, MEASURE, timing, slack and screenshot builds, so they're unchanged.
`-DNO_STATS` takes it out of one of those (to compare it with the tape),
and `-DSTATS` puts it in the tape. In the tape, Symbol Shift + S does
nothing, the menu leaves out the "Symbol Shift + S stats" line (the
other two move up a row), and `stats_prepare` is a lone `ret`, because the
explosion patches that call. The two key readers in stats.asm
(`stats_key_sym`, `stats_key_s`) stay, because the P and F chords use
them. The web page's key table no longer lists Ctrl + S.

**4. The empty buffers** (`ds`) are no longer on the tape. They're listed
in one file, `bss.asm`, which gives each an address from `$F300` up.
`boot` zeroes `$F300-$F517` once. They're in one list, not in their own
files, because sjasmplus can't size a DEFL counter with a sprite's size
that is defined further down, and the sprite sizes come from the
pictures, which are assembled after the code. Each file has a comment
where its buffer was. A buffer never crosses a 256-byte page. The two
shared files (`fish.asm`, `diver.asm`) keep their `ds` for the demo under
`IFNDEF ATLANTIS`. The soak's two photographs, which were at `$F300`,
now sit after the game's code in the soak build only.

**5. The fish and the pulsar** are now shifted at start-up, like the
spinning wheel. `tools/gfx2raw.py` writes their art once
(`gfx/fish_raw.asm`, 144 bytes with both facings; `gfx/wheel_raw.asm`,
96 bytes, the two pictures and `wheel_seq`). `preshift.asm` (was
`wspin.asm`) shifts all three with one routine, and `PRESHIFT_TABLES`
builds gfx2asm.py's pointer tables, so the draws are unchanged. The fish
and the pulsar are drawn every frame, so their copies go in fast RAM, at
the top of the data area. `gfx/wheel.asm` is gone. Engine Demo 1 still
uses `gfx/fish.asm`. The diver is still gfx2asm.py's.

A scratch build checksummed the three buffers after start-up, and
gfx2asm.py's own bytes for the same art gave the same sums:

| | Bytes | Start-up copy | gfx2asm.py |
|---|---|---|---|
| fish | 1,728 | `58A4 0E50` | `58A4 0E50` |
| pulsar | 912 | `C638 6A68` | `C638 6A68` |
| spinning wheel | 3,648 | `18E0 82B4` | `18E0 82B4` |

Start-up takes about a quarter of a second longer than before, before
the menu appears.

### Checks

- **Level 1 plays identically.** SHOT_FRAME screenshots at loops 300 and
  1,200 are pixel-identical to `main`'s (the build with the stat line and
  the one without it). So are the final screens of all eight MEASURE runs
  below, which play the scripted dive with the diver, the fish, the
  bombs, torpedoes, missiles and explosions.
- **Timing:** every MEASURE number is identical to `main`'s, at 50 and 25:

| Build | Rate | Min spare | Late | Interrupts |
|---|---|---|---|---|
| MEAS_DOWN | 50 | 9 | 0 | 512 |
| MEAS_DOWN + MEAS_FIRE | 50 | 8 | 0 | 512 |
| MEAS_DOWN + MEAS_SPIN | 50 | 9 | 0 | 512 |
| MEAS_DOWN + MEAS_MISSILE | 50 | 4 | 0 | 512 |
| MEAS_BOOM | 50 | 0 | 1 | 512 |
| MEAS_DOWN | 25 | 48 | 0 | 1024 |
| MEAS_DOWN + MEAS_FIRE | 25 | 47 | 0 | 1024 |
| MEAS_DOWN + MEAS_SPIN | 25 | 47 | 0 | 1024 |

  (MEAS_BOOM's one late step at 50 was there before too.)
- **Soak:** green border, OK, at 50 and at 25.
- **Tape, in Fuse:** the menu, a bad code, level 3's code, the level 2
  message (a scratch tape scoring 50 a torpedo), Symbol Shift + P back to
  the menu, and game over.
- **Tape, loaded as a real Spectrum loads it:** Fuse with its tape
  traps and fast loading off, so the ROM's own loader reads every block
  at normal speed.
- **Engine Demo 1:** byte-identical.
- `make web` refreshed `docs/play/`.
