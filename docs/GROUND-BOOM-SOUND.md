# The ground kills, a cheaper explosion, and the beeper crunch

Branch `claudelet/dev`. The brief came from Quartus; the replies to it
are below, item by item.

## 1. Touching the black ground kills the diver

**What happens now:** if he sinks onto the black ground, a rock or a
silo top, he explodes, loses a heart, and starts again at x = 8. It
goes through the same `diver_hurt` path and the same explosion as a
bomb or a fish, so the clean-up is the same.

**How it works:**
- `clamp_to_terrain` (`src/diver.asm`, shared) already holds him one
  pixel above the black. Under `IFDEF ATLANTIS` it now also sets
  `diver_touch` whenever it has to hold him up. Engine Demo 1's bytes
  don't change, and a byte-for-byte check against the committed tape
  confirms it.
- The step checks `diver_touch` after `hit_check`, in both the 50 fps
  tick and `idle_move` at 25. If it is set, `ground_hit` starts the
  explosion over him (`boom_at_diver`) and calls `diver_hurt`.
- **He also goes back up, to y = 110, the depth a game starts at.**
  This goes slightly beyond the brief, which only said x = 8. If he
  stayed at the bottom with Down still held, he would touch again on
  the very next step and lose all three lives in three steps.
- `diver_hurt` clears `diver_touch`, so a bomb and the ground in the
  same step cost one life, not two.
- The soak and MEASURE builds skip the ground kill, the same way they
  already skip `hit_check`. `MEAS_DOWN` has to sit on the seabed to
  measure the heavy case.

**Tested at 50 and 25:** I held Down from the start of a game. Each
touch shows the explosion, takes a heart, and puts him back at the
left at his starting depth. The third touch gives GAME OVER. A bomb
was on screen during these explosions.

## 2. The explosion while a bomb is on screen

### Measured first: too heavy

A new MEASURE switch, `-DMEAS_BOOM`, keeps an explosion running over
the diver all the time: a new one starts as soon as the last ends,
while bombs keep flying. With the diver held on the seabed
(`MEAS_DOWN`), that is the heaviest frame possible.

With the explosion as it was, which erased, photographed and redrew
12 rows through the row table on every step (about 10 scanlines):

| 50 fps, 512 steps | late | interrupts | min spare |
|---|---|---|---|
| seabed, no explosion | 5 | 512 | 0 |
| seabed + explosion every step | **187** | 512 | 0 |
| seabed + explosion + firing | **206** | **514** (2 dropped) | 0 |

### The fix: draw it only when the shape changes

Each of the four shapes is shown for two steps. So now:

- **New burst, or moved:** restore the old one, photograph the screen
  under it, then draw it.
- **Same place, new shape:** write the new shape over the old one. The
  photograph is still the background, because the explosion is the
  bottom layer.
- **Same place, same shape:** nothing at all.

It is also snapped to a whole character row, so it walks down the
cell with `INC H` instead of looking up every row. A shape change
costs about 3 scanlines, on every other step.

This is the "every other step" option. Neither enemy becomes immune:
the bomb, fish, torpedo and ground checks still run on every step.
Only the redraw skips.

| 50 fps, 512 steps, explosion every step | late | interrupts | min spare |
|---|---|---|---|
| seabed | 28 | 512 | 0 |
| seabed + firing | 60 | 512 | 0 |
| open water | 18 | 512 | 0 |
| open water + firing | 44 | 512 | 0 |

No frames are dropped: every run is exactly 1 interrupt per step. The
late steps run a few scanlines past the interrupt and catch up on the
next frame.

These numbers are a worst case. They come from an explosion that
never stops, over a diver who stays on the seabed. In play there is
one explosion per hit, and after a ground hit he goes back up to
y = 110, out of the heavy seabed case.

**A fish shot while a bomb is showing** doesn't explode. It already
used the flash (`torpedo_fish` → `fish_flash_begin`), which is a few
attribute writes. The `MEAS_FIRE` runs above include those shots.

## 3. The explosion's crunch on the beeper

**`src/atlantis/sound.asm`**, with `snd_boom_start` and `snd_tick`.

- **The noise:** white noise from an 8-bit Galois LFSR, done without a
  branch so every pass takes the same time. On each pass the speaker
  bit (bit 4 of port 254) is set when the new LFSR value is below the
  density. That pass also writes the border colour main_loop last set
  (`snd_border`, bits 0-2) and keeps MIC (bit 3) at 0. The border
  doesn't change, and nothing else on screen is touched.
- **It only plays in the spare time.** A step ends by waiting for the
  interrupt in `spare_count`, one scanline (224 T-states) per pass.
  `snd_tick` plays its burst *inside that wait*, in passes that are
  also exactly 224 T-states and count lines the same way. **It stops
  the moment the interrupt arrives**, so a burst can't make a frame
  late: a heavy frame just gets a shorter burst. The spare-line count
  stays correct. OUT can be held up a few T-states while the screen is
  being drawn, so it can only read slightly low.
- **It fades out.** There are 10 bursts, one per step. The first is 60
  scanlines (3.8 ms) at density 128/256, which is the loudest hiss.
  Each burst after it is a tenth shorter and a tenth sparser.
- **Tune it by ear** in `config.asm`: `CFG_BOOM_SND_FRAMES`,
  `CFG_BOOM_SND_LINES`, `CFG_BOOM_SND_DENSITY`.
- **At 25** only the idle frame's wait plays. `snd_gate` is shut for
  the picture frame.
- **For other sounds later:** a sound is a run of bursts (count,
  length, density, and how much the length and density drop each
  burst). A shot or a silo missile only needs its own `snd_*_start`
  that fills in those five bytes.
- **On/off switch:** `-DNO_SOUND` leaves the beeper out of any build:
  the tape, the soak and MEASURE.

### Measured with sound on (heaviest case: seabed + explosion every step)

| Build | late | interrupts | min spare (picture) |
|---|---|---|---|
| 50, sound | 30 | 512 | 0 |
| 50, `NO_SOUND` | 28 | 512 | 0 |
| 50 + firing, sound | 63 | 512 | 0 |
| 50, no explosion, sound | 0 | 512 | 0 |
| 50, no explosion, `NO_SOUND` | 4 | 512 | 0 |
| 25, sound | 0 | 1024 | 23 lines |
| 25, `NO_SOUND` | 0 | 1024 | 24 lines |
| 25 + firing, sound | 0 | 1024 | 22 lines |

The sound adds no late frames. The 50 fps differences of 2 or 3, in
both directions, are the same schedule noise measured last time:
padding the frame start with a few NOPs moves this count by 2. At 25
every step is still exactly 2 frames, and the idle frame, where the
crunch plays, has more than 99 lines spare.

**I couldn't listen to it.** This Fuse build can't record audio, so
the crunch's sound and its tuning need checking by ear.

## Checks

- `make`, `make timing`, `make soak` and a `-DNO_SOUND` build assemble
  with 0 errors.
- The soak ends on a green border with OK at 50 and at 25.
- Engine Demo 1 is byte-identical.
- No `build/*.tap` is committed.

## Files

| File | Change |
|---|---|
| `src/diver.asm` | `IFDEF ATLANTIS`: the clamp sets `diver_touch` |
| `src/atlantis/hit.asm` | `diver_touch`, `ground_hit`, `DIVER_START_Y`; `diver_hurt` clears the touch |
| `src/atlantis/boom.asm` | `boom_at_diver`; cell-aligned explosion; redraw only on a shape change; starts the sound |
| `src/atlantis/sound.asm` | new: `snd_boom_start`, `snd_tick`, `snd_reset` |
| `src/atlantis/rate.asm` | `spare_count` plays the burst in its wait; `rate_apply` sets `snd_gate` |
| `src/atlantis/main.asm` | `GROUND_CHECK` in both ticks; `MEAS_BOOM`; border colour kept for the beeper; 25's idle gate |
| `src/atlantis/menu.asm` | start depth from `DIVER_START_Y`; clears the touch and the sound |
| `src/atlantis/config.asm` | `CFG_BOOM_SND_FRAMES`, `_LINES`, `_DENSITY` |
| `README.md`, `CLAUDE.md` | the ground kill, the sound, `MEAS_BOOM`, `NO_SOUND` |
