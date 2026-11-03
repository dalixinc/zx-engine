# Atlantis memory reorganisation

Branch `claudelet/dev`. Quartus's housekeeping brief: more room, a
shorter tape, and no gameplay changes. Items 1 to 5 are done. Item 6
(ZX0) is not; see the end.

## The map

| Address | Before | After |
|---|---|---|
| `$4000-$5AFF` | screen | screen |
| `$5B00-$5FFF` | BASIC (`CLEAR 32767`) | BASIC (`CLEAR 24575`) |
| `$6000-$6905` | free (the soak build's code) | **cold block**: menu, level codes, start-up, resets, level 2 message, menu words (2,310 bytes, loaded from tape) |
| `$6906-$71BF` | free | free (2,234) |
| `$7000-$7E3F` | the spinning wheel's shifted pictures | |
| `$71C0-$7FFF` | | the spinning wheel's shifted pictures, packed against `$8000` (built at start-up) |
| `$8000` | code, to `code_end` `$BEA4` | code, to `code_end` `$B1AF` |
| code/data line | `$C000` | **`$C400`** |
| data | `$C000-$EBA0` | `$C400-$E45A` |
| `$E5B0-$EC6F` | (in the data block) | the fish's shifted pictures (built at start-up) |
| `$EC70-$EFFF` | (in the data block) | the pulsar's shifted pictures (built at start-up) |
| `$F000-$F2FF` | scroll buffers | scroll buffers |
| `$F300-$F517` | free (the soak's photographs) | **the buffers that start empty** (`bss.asm`, zeroed at start-up) |
| `$FA00-$FB7F` | row table | row table |
| `$FDFC` down | stack | stack |
| `$FDFD`, `$FE00` | `JP isr`, IM2 table | `JP isr`, IM2 table |

Everything from `$6000` to `$7FFF` is contended: the ULA slows each
access while it draws the picture. Only the spinning wheel's pictures
are read there in play, as before (measured to cost nothing at 50, see
[WHEEL-BOMB.md](WHEEL-BOMB.md)). No code that runs every frame is below
`$8000`.

## Free bytes, before and after

| Area | Before | After |
|---|---|---|
| code (`code_end` to the line) | 348 | **4,689** |
| data (`data_end` to the next thing up) | 1,119 | 341 |
| code and data together (`$8000-$EFFF`) | 1,467 | **5,030** |
| `$6000-$7FFF` | 4,544 (soak only) | 2,234 |
| `$F300-$F9FF` | 1,792 (soak only) | 1,256 |

The code and data share one stretch of fast RAM, and the line only
divides it. At `$C400` the data has 341 bytes to grow. `$C500` would
still fit today, with 85 to spare. If the data grows past `$E5B0`, the
build stops and the line comes down by `$100`.

## The tape

| Block | Before | After |
|---|---|---|
| BASIC | 57 | 62 |
| loading screen | 6,912 | 6,912 |
| cold block, `$6000` | - | 2,310 |
| code, `$8000` | 16,036 | 12,719 |
| data | 11,169 | 8,283 |
| **`.tap` file** | **34,274** | **30,411** |

That's 3,863 bytes shorter, about 20 seconds less loading on a real
Spectrum.

## What each item did

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

## Checks

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

## Not done: ZX0 (item 6)

There is no ZX0 compressor on this machine, and doing it means bringing
in third-party code (the compressor, and Einar Saukas's Z80 unpacker,
BSD-3). The obvious target is the diver's 5,760 bytes of pre-shifted
pictures. They could be loaded packed into the spinning wheel's area
(`$71C0`) and unpacked before `preshift` fills it, which costs no RAM.

The other way is to shift the diver at start-up like the fish, with no
new code from outside. `preshift` would need 3-byte rows for him (he's
24 pixels wide), and he'd come to about 540 bytes on the tape. That
would save more than 5K of tape and cost about 50 bytes of cold code.
