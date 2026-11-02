# The torpedo's laser sound

Branch `claudelet/dev`. When the diver fires, the torpedo leaves with a
high, falling "pew".

## What it is

It's a short tune, played through the same player as the level jingle:

| Note | Half-period (scanlines) | Pitch |
|---|---|---|
| 1 | 2 | 3.9 kHz |
| 2 | 3 | 2.6 kHz |
| 3 | 4 | 2.0 kHz |
| 4 | 5 | 1.6 kHz |
| 5 | 7 | 1.1 kHz |
| 6 | 9 | 870 Hz |

Each note lasts 2/50 s (`CFG_LASER_TICKS`), so the sweep takes 240 ms
at both 50 and 25 fps. The notes are the `CFG_LASER` list in
`config.asm`. A note is its half-period in scanlines, and the pitch is
7812 / half-period Hz.

## Choosing it

Four sweeps were recorded headless from Fuse (sound to a file) and
compared: 2-3-4-5-7-9; 1 to 8; 3-4-5-6-8-10-13; and 2-3-5-8, one note per
1/50 s. The first was chosen **as it sounds at 25 fps**, because it
stands out from the game's other sounds, which are all noise. At 25 each
note lasts a two-tick step, so the notes were made two ticks long at 50
too.

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

A new sound normally replaces the last. The laser is the lowest:

- It starts only into silence, or over the laser before it (a quick
  second shot restarts it).
- An explosion, or the level jingle, playing is left alone, and any
  explosion that starts while the laser plays cuts it off. A torpedo
  that hits something straight away ends its own laser with the crunch.
- The missile launch whoosh only plays into silence too, so it is
  skipped while a laser is playing. Both are short, so this is rare.

`snd_laser_start` tells the laser from the jingle by where `snd_tune`
points: inside `snd_laser` means the laser. The jingle's notes are
below it, and an `ASSERT` keeps them there.

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
- **Memory:** 45 bytes of code. `code_end` is `$BEB4`, leaving 332
  bytes free.
- **Engine Demo 1:** untouched. The change is in Atlantis-only files.
