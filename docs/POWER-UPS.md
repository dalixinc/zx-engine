# Power-ups

Branch `claudelet/dev`. Two power-ups: a heart for an extra life, and a
rarer bubble that gives the double shot for a while: two torpedoes out
at once.

## In play

- **Where they come from.** Each time a missile ends, the next turn is
  rolled: a heart `CFG_HEART_ODDS` times in 256 (32, about one turn in
  8), a bubble `CFG_DOUBLE_ODDS` times in 256 (12, about one in 21),
  otherwise a missile. Only from level `CFG_POWER_LEVEL` (1, so they can
  be seen from the start).
- **How they move.** A power-up appears below the hearts, in a column
  near the diver (his middle, give or take 32 pixels), and sinks
  `CFG_POWER_SPEED` pixels a 1/50 second. It is gone just above the
  weed, about three seconds later.
- **Taking one.** Touch it. Torpedoes pass through it.
  - **The heart** is one more life, up to `CFG_LIVES_MAX` (5). Row 1
    has room for 5 hearts. At 5 it is still used up.
  - **The bubble** gives the double shot for `CFG_DOUBLE_TIME` seconds
    (30): he can fire again while a torpedo is still running, so two
    can be out at once, each moving, hitting and scoring on its own.
    Each launch is still a fresh press, with the usual cooldown.
  - Either plays a short rising jingle.

## How it costs so little

**The missile's slot.** A power-up is the missile slot holding something
else (`msl_kind`). It uses the missile's draw, its restore, and its test
against the diver. While one is up, no missile is, so it adds no frame
that the missile does not already cost. It sinks in a column that is a
multiple of 8, and the water does not scroll, so the 8 by 8 picture is
always one byte a row with no shifted copies: 16 bytes a picture. It
stays above the weed, so it is always drawn before the seabed copy.

**The double shot.** The torpedo's draw is a tight, hand-unrolled
two-row routine with one block of state (`torp_on` to `torp_vcol`). The
second torpedo has the same block, `T2_OFF` bytes on (`t2_*`), and four
more save bytes.

- **Firing again** while one runs hands the running one to the second
  slot (`double_hand`: its block and save bytes copied, as it is on the
  screen) and a fresh one leaves the gun as the first.
- **Drawing and putting back:** the draw and the restore are macros
  taking the block's offset, so `t2_draw` and `t2_restore` are the same
  code.
- **Moving and hitting:** the second uses the first's own routines.
  `t2_swap` exchanges the bytes they read (`torp_on` to `torp_dir`) for
  the call, 216 T-states each way.
- **A single torpedo pays nothing.** Nothing tests for a second one on
  the frame. While one exists, `torp_two_set` patches main_loop: its
  three restores, two draws and two hit calls (`.torp_rc1-3`,
  `.torp_dc1-2`, `.torp_hc1-2`) are made unconditional (the opcode
  patched, `CALL C` to `CALL`, `RET NC` to `NOP` and so on) and go to the
  "both" routines, which test each torpedo. When the second has gone and
  been put back, `hit_both` patches them back. Asserts check every
  patched opcode and operand as built.

A label inside `main_loop` (even an `equ`) starts a new scope for its
local labels, which is why the call sites are local labels and why
`SLACK_WARMUP`'s default moved above `main_loop`.

## Which builds have them

`POWERUPS` is defined except in the soak (its script counts its
missiles) and in a measurement (which holds its own cases steady).
`-DMEAS_DOUBLE` gives a measurement the double shot all the time: with
`MEAS_FIRE` two torpedoes are out nearly always, the worst case.
Without `POWERUPS` the hearts are `CFG_LIVES` cells, as before, so the
soak's check of row 1 is unchanged.

## Timing

While the double shot lasts, the gun's cooldown is `CFG_DOUBLE_COOLDOWN`
(10 1/50 seconds) instead of `CFG_FIRE_COOLDOWN` (48): a torpedo takes
less than 48 to cross from most places, so with the usual wait two
would never be out. 10 puts them about 40 pixels apart.

The worst case: diver on the seabed, the bomb on screen, and
`MEAS_DOUBLE` with `MEAS_FIRE`, so two torpedoes are out nearly all the
time. Spare scanlines (the lowest of 512 steps), late steps, interrupts:

| | Spare | Late steps | Interrupts |
|---|---|---|---|
| level 1, one torpedo | 2 | 0 | 512 |
| level 1, double shot | 0 | 13 | 512 |
| level 2, double shot | 0 | 16 | 512 |
| level 4, double shot | 0 | 19 | 512 |
| level 9, double shot | 0 | 31 | 512 |
| level 1, open water, double shot | 0 | 9 | 512 |
| level 1 at 25, double shot | 47 | | 1,024 |

The interrupts are 1 a step in every row: no interrupt is missed, so
the game stays at 50. A late step runs a little past the interrupt and
the next step catches up; at worst (level 9, both always out) that is 1
step in 16, a little jitter, only while two are out during a bubble's
30 seconds. A single torpedo's numbers are main's.

The power-up's own draw is the missile's, plus about 20 T-states to
pick its picture, and the missile cases had 3 to 5 lines to spare.

## Memory

| | Now | Free |
|---|---|---|
| hot code (with the pictures and the patch tables) | `code_end` `$B6D1` | 591, below the round fish |
| data | `data_end` `$CE9B` | 101 before the packed tape moves up a page |
| cold block | `cold_end` `$7162` | 94 |
| packed tape | `$CF00-$FF48` | 16 below the ROM's UDGs |

To make room, the round fish's pictures are split: the left-facing pair
below the jet's (`RFISH_BUF`, `$B920`), the right-facing pair at the top
of the room above the run-time buffers (`RFISH_HI`, `$F5A0`). The tape
is 14,258 bytes. The packed tape is now the limit: it loads from the
page after `data_end` and must end below `$FF58`, so the next big thing
needs room made first (the spinning wheel down to 4 pictures, or the
loader rearranged).

## Checks

- **Soak:** green at 50 and 25.
- **Engine Demo 1:** byte-identical.
- **Every build assembles:** the tape, `STATS`, the soak, the measures
  (with and without `MEAS_DOUBLE`, `MEAS_BOOM`, `MEAS_MISSILE`),
  `TIMING_BARS`, `SHOT_FRAME`, `SLACK_LINES`.
- **In Fuse,** on scratch copies with the diver made unhittable:
  - with both power-ups made very likely, both appear and sink, and a
    heart took him from 3 hearts to 4;
  - with every power-up a bubble dropped onto him, he took it, fired
    twice a third of a second apart, and two torpedoes were out at
    once, with nothing left behind on the screen.
