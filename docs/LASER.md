# The torpedo's laser sound

Branch `claudelet/dev`. When the diver fires, the torpedo leaves with a
short, high zap.

## What it is

It's a two-note tune, played through the same player as the level
jingle:

| Note | Half-period (scanlines) | Pitch | Length |
|---|---|---|---|
| 1 | 2 | 3.9 kHz | 2/50 s |
| 2 | 5 | 1.6 kHz | 1/50 s |

That is 60 ms at 50 fps. At 25 a step is two ticks and plays one note
whatever its length, so it is 80 ms. The notes are the `CFG_LASER` list
in `config.asm`, each a half-period in scanlines (the pitch is
7812 / half-period Hz) and a length in 1/50 s.

## Choosing it

The first version was a six-note falling sweep, 2-3-4-5-7-9, two ticks
a note: 240 ms. It was chosen from four sweeps recorded headless from
Fuse, as it sounds at 25, because it stands out from the game's other
sounds, which are all noise. In play it was too long, so it was cut to
its first and fourth notes, a quarter of the length.

## How it sounds at 50 and at 25

All the game's sounds play only in the spare time at the end of each
frame (see sound.asm), so they can never make a frame late. The laser
gets whatever time is left:

| Rate | Tone per frame, measured in open water |
|---|---|
| 50 | about 0.5-2 ms of every 20 ms |
| 25 | about 10 ms of every 40 ms (the idle frame) |

So the laser is fuller at 25 and thinner and buzzier at 50, more so on
the seabed. The pitches are right at both rates: each frame's tone was
measured from the recordings.

## Priority

The laser **starts on the step that fires, but only into silence**. It
never cuts off a sound that is playing: an explosion, a missile's
whoosh or the level jingle plays to its end, and that shot is silent.
(It was once the other way round, and the laser cut off a fish's
explosion when the diver fired during it.)

- An explosion that starts after it (including the torpedo's own hit)
  still cuts it short, so hits are always heard.
- From key to sound is at most one frame (fire is read at the start of
  a step, and the first note plays at the end of the same step), plus
  the emulator's own audio buffer, which every sound has.

A tune counts a note down before playing it, so a one-tick first note
would never be heard. The table starts with a one-tick lead-in that is
used up on the step that fires.

## Checks

- **Timing.** MEASURE with MEAS_DOWN + MEAS_FIRE (the laser restarts
  every other step):
  - at 50: 8 spare lines minimum, 0 late, 512 interrupts, the same as
    before the laser;
  - at 25: 0 late, 1024 interrupts.
  Starting the tune costs about a scanline on the step that fires.
- **Soak** at 50: green, OK.
- **Memory:** 23 bytes of code. `code_end` is `$BE9E`, leaving 354
  bytes free.
- **Engine Demo 1:** untouched. The change is in Atlantis-only files.
