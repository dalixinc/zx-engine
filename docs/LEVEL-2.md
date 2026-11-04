# Level 2

Branch `claudelet/dev`. Quartus's brief: make level 2 a real level,
and set the pattern for the levels after it.

![Level 2](images/level-2.png)

## What changes at level 2

| | Level 1 (unchanged) | Level 2 |
|---|---|---|
| bomb | the black pulsar, small bob | the same pulsar, **yellow**, on a **wave** 16 pixels up and down |
| fish | straight across at row 76 | a **wave** 12 pixels up and down about row 76, about a fifth faster |
| border | the heartbeat (a slow round of colours) | **cyan** |
| points | bomb 2, fish 1, missile 10 | the same |

Level 2's target and length are as before. Its bomb was already a
little faster (haste 24). The targets and the level codes are not
published here: the codes are in `notes/LEVEL-CODES-LIST.md` in the
repository, and the targets are the first column of `CFG_LEVELS`.

**The panel.** Reaching level 2 shows the "LEVEL 2" banner, then the
panel: "WELL DONE, YOU REACHED LEVEL 2." / "LEVEL 2 STARTS NOW", the
code, and "PRESS A KEY". The "STAY TUNED, MORE IS COMING" panel has
moved to the end of level 2: it follows the "LEVEL 3" banner, with level
3's code, and level 3 (the spinning wheel) carries on behind it. The
code is no longer under level 3's banner. From level 4 it is under the
banner as before.

## The table

The look is five more columns of `CFG_LEVELS` in `config.asm`, and
what a shot scores is three more after them:

```
;          ...  bomb    ink            bmove      fmove          fspeed border        fish bomb missile
LEVEL_ROW  ...  BOMB_P, CFG_WHEEL_INK, MOVE_BOB,  MOVE_STRAIGHT, 0,     BORDER_BEAT,  1,   2,   10   ; 1
LEVEL_ROW  ...  BOMB_P, CFG_L2_INK,    MOVE_WAVE, MOVE_WAVE,     48,    CYAN,         1,   2,   10   ; 2
LEVEL_ROW  ...  BOMB_W, CFG_SPIN_INK,  MOVE_BOB,  MOVE_STRAIGHT, 0,     BORDER_BEAT,  1,   2,   10   ; 3 to 9
```

- **ink**: the bomb's cell colour. `CFG_L2_INK` is bright yellow on blue.
- **bmove**: `MOVE_BOB` (the old bomb) or `MOVE_WAVE`.
- **fmove**: `MOVE_STRAIGHT` (the old fish) or `MOVE_WAVE`.
- **fspeed**: the fish's haste, like the bomb's: 0 is a pixel per 1/50 s,
  48 adds a pixel about one 1/50 s in five. It only applies to
  `MOVE_WAVE`; a straight fish must have 0, and an assert checks that.
- **border**: a colour (`BLACK` to `WHITE`), or `BORDER_BEAT` for the
  heartbeat.
- **fish, bomb, missile**: what a torpedo scores for each on this level,
  0 to 99. They replace `CFG_PTS_FISH`, `CFG_PTS_BOMB` and
  `CFG_PTS_MISSILE`. Level 1 must stay 1, 2 and 10.

**Changing a level's target, or any other column, changes no level
code.** A code depends only on the level's number (`codes.asm`).

Asserts keep level 1's row exactly the old game. A later level is one
more row; a new kind of movement is one more `MOVE_*` value and one
more routine in `level.asm`.

The waves' sizes and speeds (`config.asm`, with Dalix's tuning in mind):

| Setting | Value | Meaning |
|---|---|---|
| `CFG_BOMB_WAVE_AMP` | 16 | pixels above and below the bomb's middle |
| `CFG_BOMB_WAVE_SPEED` | 2 | one wave every 128/50 s (2.6 s) |
| `CFG_FISH_WAVE_AMP` | 12 | pixels above and below row 76 |
| `CFG_FISH_WAVE_SPEED` | 3 | one wave every 85/50 s (1.7 s) |
| level 2 `fspeed` | 48 | the fish about a fifth faster |
| `CFG_L2_INK` | `BRIGHT \| YELLOW \| (BLUE << 3)` | the bomb's colour |
| level 2 border | `CYAN` | |

A wave climbs at most `AMP * 6.3 * SPEED / 256` pixels a 1/50 s. Above
1, the bomb's colour is repainted whole on those steps, which costs
time; the fish doesn't mind. An assert in `level.asm` stops the build
if the bomb's `AMP * SPEED` is over 40. Other asserts keep both waves in
open water: the bomb's middle stays `AMP` clear of the score row and the
seaweed, and the fish stays below row 1 and above the seabed.

## How it works

- `level.asm` is new. `level_style` (cold) takes a row's five bytes when
  a level starts, by score or by code. The two movers are hot.
- **The bomb.** `wheel_type` gives each new bomb the level's ink and
  movement. `update_wheel` sends kind 1 to `wheel_wave`, after the kind
  0 test, so level 1's bomb costs exactly what it did. The wave sets the
  height from a 128-entry table, then joins the drift's own spin and
  move code (`wheel_drift.spin1` at 50, `.spin2` at 25). A height more
  than a pixel from the last sets `wheel_odd`, so the colour is painted
  whole, as a wobble does.
- **The fish.** `fish_wave` replaces `update_fish` in the two move calls
  (`fish_mv`, `fish_mv2`), and `fish_unhold` now puts back the level's
  mover (`fish_mover`). The three hit tests that used the fixed depth
  (`fish_touch`, `fish_aside`, `torpedo_fish`) keep `FISH_SWIM_Y` as
  their operand, and `fish_wave` writes the fish's height into it as it
  moves. So level 1 runs the same instructions as before. The shared
  `fish.asm` is untouched.
- **The border.** A fixed colour is written over the heartbeat's first
  four bytes (`LD A,colour : JR .border`). `BORDER_BEAT` puts them back.
- **The tables.** `data.asm` makes both waves from one table of sines
  when the game is assembled, so any amplitude works.
- **Measuring.** `-DMEAS_LEVEL=n` starts a MEASURE build at level n.

## Bytes

| | Before | After | Used |
|---|---|---|---|
| hot code (`code_end`) | `$B1A8` | `$B28C` | 228 |
| data (`data_end`) | `$CB6B` | `$CC98` | 301 (256 of it the two wave tables) |
| cold block (`cold_end`) | `$6FBB` | `$7036` | 123 |
| tape | 12,697 | 13,116 | 419 |

Free afterwards: code 4,468, data 664, cold block 394.

## Checks

- **Level 1 is unchanged.** All ten timing and screenshot builds
  (MEASURE at 50 and 25 with MEAS_DOWN, MEAS_FIRE, MEAS_SPIN, MEAS_BOOM,
  MEAS_MISSILE; SHOT_FRAME 300 and 1200) are pixel-identical to the
  build before this brief. The soak is green at 50 and 25. Engine Demo
  1 is byte-identical.
- **Timing**, minimum spare scanlines and late steps, interrupts right
  throughout (512 at 50, 1024 at 25):

| Build | Level 1 | Level 2 |
|---|---|---|
| 50 MEAS_DOWN | 9, 0 late | 9, 0 late |
| 50 MEAS_DOWN + MEAS_FIRE | 2, 0 | 1, 0 |
| 50 MEAS_DOWN + MEAS_MISSILE | 4, 0 | 5, 0 |
| 50 MEAS_BOOM | 0, 1 late | 0, 2 late |
| 50, diver in open water | – | 10, 0 |
| 25 MEAS_DOWN | 48, 0 | 47, 0 |
| 25 MEAS_DOWN + MEAS_FIRE | 47, 0 | 47, 0 |

  MEAS_BOOM's late steps overrun by a few T-states and catch up; that
  count moves by one or two with schedule alignment alone.
- **Codes.** Level 2's code starts level 2 with the cyan border, the
  yellow wave bomb and the wave fish. Level 3's starts level 3 with the
  red spinning wheel, the straight fish and the heartbeat.
- **Panels**, in a scratch build scoring 50 or 99 a shot: level 2's
  panel says it starts now, and play goes on in level 2. Level 3's says
  more is coming, with level 3's code, and play goes on in level 3.
- **A death on level 2**: the same freeze, flash, burst and respawn as
  on level 1. The fish keeps its wave and the bomb its colour.
- That scratch build, scoring every step fire was held, ran up to level
  16 and showed level 2's message there as "LEVEL @". A message still
  due from level 2 or 3 is now dropped when a later level arrives. Real
  play can't skip levels like that.

## Follow-up after review

- **No codes or targets in `docs/`.** This page, the README,
  `LEVEL-CODES.md` and `SCORE-AND-LEVELS.md` no longer give a level code
  or a point target, and the scores are painted out of the four
  screenshots that showed one. The codes, and now the score each level
  starts at, are in `notes/LEVEL-CODES-LIST.md`, outside the web site.
- **The wave's limit is an assert.** `level.asm` stops the build if
  `CFG_BOMB_WAVE_AMP * CFG_BOMB_WAVE_SPEED` is over 40.
- **Points per level.** `CFG_LEVELS` ends with what a fish, a bomb and a
  missile score on that level (1, 2 and 10 everywhere for now).
  `CFG_PTS_*` are gone. Changing any column, the targets included,
  changes no level code.
- **The bomb stays below the score line.** Its top never goes above
  pixel row 16 (`WHEEL_TOP_Y`). The surface height in `wheel_heights`
  is one swing below row 1 instead of below row 0, `wheel_clamp_base`
  keeps a wobbled bomb there, and the wave's middle is kept `AMP` below
  it. The soak build keeps the old top: its script parks the surface
  bomb on row 0 to test it against the stat digits.
- **Yellow cells left behind.** With haste, the bomb sometimes moves two
  pixels in a step at 50. Its colour's fast path finds the column to
  paint or give back from the shift it lands on (7 or 4), so a step
  from 5 to 3 or from 0 to 6 missed a column, and a cell kept the
  bomb's ink until something repainted it. The diver turned yellow
  there. Those two landings now repaint the whole rectangle
  (`wheel_drift.moved`). Level 1 has no haste, so it never happened
  there; level 3's red wheel had it too.

**Bytes:** hot code 24 (`code_end` `$B2A4`, 4,444 free; 14 of them the
fix), data 27 (the points columns; `data_end` `$CCB3`, 637 free), cold
block 0. The tape is 13,150 bytes.

**Checks:**

- **Level 1 plays identically.** All ten timing and screenshot builds
  are pixel-identical to `main`, and so they are with the top forced
  back to 0, which isolates the other changes. None of those runs met a
  surface bomb, so the new top didn't show in them. The soak is green
  at 50 and 25. Engine Demo 1 is byte-identical.
- **The codes are unchanged:** the assembled code table is
  byte-identical to `main`'s.
- **Timing** with `-DMEAS_LEVEL`, identical to `main` on every build:
  level 2 at 50, 9 / 1 / 5 / 0 spare with MEAS_DOWN / + MEAS_FIRE /
  + MEAS_MISSILE / MEAS_BOOM (late steps 0, 0, 0, 2) and 10 in open
  water; at 25, 47 and 47. Level 9 (haste 192, the most two-pixel
  steps) at 50: 8 and 1, no late steps.
- **The yellow cells.** A scratch build played level 2 shooting, with
  the diver sweeping up and down and unable to die, and checked one
  row of cells a step: rows 2 to 20 had to be water, the banner, the
  bomb's own rectangle or a flashing fish. Without the fix it stopped
  in under 3 seconds of play on a cell of the bomb's yellow, one column
  right of the bomb. With it, 10 minutes at 50 (about 29,000 steps,
  score 200 to 423) and 10 minutes at 25 found none.
- **The asserts fire:** a wave of 16 by 3, and level 1 scoring 3 for a
  bomb, both stop the build.
