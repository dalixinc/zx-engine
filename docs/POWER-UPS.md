# Power-ups

Branch `claudelet/dev`. Two power-ups: a heart for an extra life, and a
rarer bubble that gives twin torpedoes for a while.

## In play

- **Where they come from.** Each time a missile ends, the next turn is
  rolled: a heart `CFG_HEART_ODDS` times in 256 (32, about one turn in
  8), a bubble `CFG_TWIN_ODDS` times in 256 (12, about one in 21),
  otherwise a missile. Only from level `CFG_POWER_LEVEL` (1, so they can
  be seen from the start).
- **How they move.** A power-up appears below the hearts, in a column
  near the diver (his middle, give or take 32 pixels), and sinks
  `CFG_POWER_SPEED` pixels a 1/50 second. It is gone just above the
  weed, about three seconds later.
- **Taking one.** Touch it. Torpedoes pass through it.
  - **The heart** is one more life, up to `CFG_LIVES_MAX` (5). Row 1
    has room for 5 hearts. At 5 it is still used up.
  - **The bubble** gives twin torpedoes for `CFG_TWIN_TIME` seconds
    (15): each shot is two torpedoes, one 4 pixels below the other,
    moving as one. A hit anywhere in that band counts, the gap included.
  - Either plays a short rising jingle.

## How it costs so little

**The missile's slot.** A power-up is the missile slot holding something
else (`msl_kind`). It uses the missile's draw, its restore, and its test
against the diver. While one is up, no missile is, so it adds no frame
that the missile does not already cost. It sinks in a column that is a
multiple of 8, and the water does not scroll, so the 8 by 8 picture is
always one byte a row with no shifted copies: 16 bytes a picture. It
stays above the weed, so it is always drawn before the seabed copy.

**The twin.** The torpedo's draw is a tight, hand-unrolled two-row
routine. A twin is a second pair of rows `TWIN_DY` (4) below, drawn from
the same picture into four more save bytes (`torp_r2`, `torp_r3`). The
draw and the restore are now macros, so the second pair is the same
code. A plain torpedo must not pay for any of it, so nothing tests for a
twin on the frame. A launch patches instead (`torp_twin_set`, in the
cold block, only when it changes between one and two):

- main_loop's three calls to `torpedo_restore` and two to `torpedo_draw`
  (`.torp_rc1-3`, `.torp_dc1-2`) go to `torpedo_restore_twin` and
  `torpedo_draw_twin`. Asserts check that each label is on the call it
  should be.
- The hit tests' heights grow by `TWIN_DY`: the bomb's, a missile's,
  the fish's, and the test that decides whether it runs in the weed.

A label inside `main_loop` (even an `equ`) starts a new scope for its
local labels, which is why the call sites are local labels and why
`SLACK_WARMUP`'s default moved above `main_loop`.

## Which builds have them

`POWERUPS` is defined except in the soak (its script counts its
missiles) and in a measurement (which holds its own cases steady).
`-DMEAS_TWIN` makes every shot in a measurement a twin, to measure it.
Without `POWERUPS` the hearts are `CFG_LIVES` cells, as before, so the
soak's check of row 1 is unchanged.

## Timing

The heavy case: diver on the seabed, the bomb on screen, a torpedo
nearly always running (`MEAS_DOWN`, `MEAS_FIRE`). Spare scanlines and
late steps in 512, one torpedo against a twin on every shot:

| | One torpedo | Twin |
|---|---|---|
| level 1 | 2 | 0, no late step |
| level 2 | 1 | 0, no late step |
| level 4 | 0, 1 late | 0, 3 late |
| level 9 | 0, no late step | 0, 4 late |
| level 1 at 25 | 47 | 47 |
| level 1, open water | | 1 |

The interrupts are 1 a step in every row: the game stays at 50. A twin
costs about two scanlines while it runs, so on the heaviest frames a few
steps overrun by a few T-states and catch up, the same kind as
`MEAS_BOOM`'s. That only happens during the 15 seconds of a bubble.
The one-torpedo column is the same as before the power-ups.

The power-up's own draw is the missile's, plus about 20 T-states to
pick its picture, and the missile cases had 3 to 5 lines to spare.

## Memory

| | Bytes | Now |
|---|---|---|
| hot code | 510 | `code_end` `$B57C`, 68 free below the round fish |
| data | 94 (the two pictures, the twin's patch tables) | `data_end` `$CEF9`, 55 free |
| cold block | 67 (`torp_twin_set`, resets) | `cold_end` `$718C`, 52 free |

The tape is 14,104 bytes. The packed game ends at `$FEAE`, 170 bytes
below the ROM's UDGs at `$FF58`, which is its limit. Uncontended code,
data and the packed tape are now all close to full: the next big thing
will need room made first (for example, the spinning wheel down to 4
pictures).

## Checks

- **Soak:** green at 50 and 25.
- **Engine Demo 1:** byte-identical.
- **Every build assembles:** the tape, `STATS`, the soak, the measures
  (with and without `MEAS_TWIN`, `MEAS_BOOM`), `TIMING_BARS`,
  `SHOT_FRAME`, `SLACK_LINES`.
- **In Fuse,** on scratch copies with the diver made unhittable:
  - with both power-ups made very likely, both appear and sink, and a
    heart took him from 3 hearts to 4;
  - with every power-up a bubble dropped onto him, he took it and fired
    twins, which scored on the fish and left nothing behind on the
    screen.
