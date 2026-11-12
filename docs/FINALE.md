# Finale

The third and last game of the trilogy. The diver carries the bomb
through Trigon's waters, drops it into the Trigon power generator,
destroys the city and breaks the blockade on Atlantis.

Finale is built in chunks (the Director's brief). This page describes
what is built so far.

## How it is made

Finale is a copy of the Atlantis and Trigon sources, in `src/finale/`.
Its first commit assembled to Trigon's bytes exactly; everything since
is Finale's own. Atlantis and Trigon are not touched, so their tapes,
snapshots and test builds stay byte-identical, as does Engine Demo 1.
The shared engine files in `src/` (sprites, input, screen, text) are
read, not changed.

```
make finale        # build/finale.tap and build/finale.sna
make run-finale    # load the tape in Fuse
make finale-soak   # build/finale-soak.sna, the background-restore soak
make finale-measure
make unpack-check-finale
```

Its loading screen is drawn by `tools/mkloadscreen.py --finale`
(`gfx/finale/loading.scr`, FINALE in two tones, no fish), and its
version is `src/finale/VERSION`.

## The base (chunk 2)

- **What came out of Trigon:** the fish (its place is kept empty for
  the enemy divers), the second bomb, the spinning wheel (the pulsar is
  the one bomb), the bombs' newer movements, the belts and "+BELT", the
  special bombs and the bubble, and the level 2 and 4 messages.
- **The world:** a black sea; dark magenta hills and ground with yellow seaweed on their
  tops; the silos in front with yellow domes and dark red towers, their cells
  painted as they pass. Every colour is a setting in
  `src/finale/config.asm`, to tune in play.
- **The menu:** FINALE in the tall letters, yellow over red. It asks for
  the code Trigon's ending gives before level 1.
- **The story:** a short intro typed before the game.
- **The diver:** white, no belts (placeholder art until Erin's
  bomb-carrying diver arrives, inside his present 24 x 15 box).
- **Weapons:** the torpedo; the double shot from level 2 and the Lance
  from level 3, given, not caught. The heart is the only power-up.
- **Levels:** eight placeholder levels, the pulsar on the bob, the wave
  or hunting, a little faster each time. The banner still freezes the
  action while it is up. Finishing level 8 shows a placeholder ending.

## Room and timing

| | Hot | Cold | Data |
|---|---|---|---|
| Trigon 0.8.0 | 1 | 5 | 8 |
| Finale base | 1,705 | 1,381 | 2,400 |

Free while the game runs as well: `$78E0-$7FFF` (the spinning wheel's
pictures, 1,824 bytes) and the round fish's 1,728.

Measured with power-ups and the Lance on and fire held, 1,024 steps:
levels 3, 6 and 8, on the seabed and in mid-water, show no late steps,
at least 10 scanlines to spare, and 1,024 interrupts.

## Still to come

Enemy divers (chunk 3), the level table (chunk 4), Erin's city and the
bomb drop (chunk 5), and, if room allows, a computer-style font (chunk 6).
