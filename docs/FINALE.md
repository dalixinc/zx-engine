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
- **The world:** a black sea; dark blue hills and ground with yellow seaweed on their
  tops; the silos in front with yellow domes and dark blue towers, their cells
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

## The Trigon divers (chunk 3)

Red Trigon divers come in from the right and swim left in the fish's old
place (`src/finale/ediver.asm`): one at once on levels 1 to 3, two from
level 4. Each comes in one of the level's movements, picked at random:
straight across, drifting to the player's depth, stopping a while to fire
twice as often, or diving at his depth. They fire short dashes to the
left. A shot, or touching one, costs a life. The torpedo, the double
shot and the Lance each take one of a diver's hits (2, 3 or 4 by level);
a hit makes him blink, and the last blows him up for 20 points. The bomb
never comes out with two divers, and a diver waits rather than make a
third big enemy. The silos fire only from level 5; before that a heart
can still fall in their turn. Each level's divers are a row of
`CFG_ED_LEVELS` in `src/finale/config.asm`.

The divers are 16 x 15 (a placeholder cut from Trigon's until Erin's
arrives at that size): at 24 wide, two of them cost a third more to draw
each frame.

**The frame budget.** From level 3 (`CFG_ED_25_LEVEL`), while two big
enemies are out (two divers, or a diver and the bomb), the game drops to
25 frames a second, at the same game speed, and goes back to 50 half a
second after one has gone. Below level 3, 50 holds with them. Measured
with the double shot and the Lance in use, 1,024 steps each, on the
seabed and in mid-water: no level loses a frame; levels 1 and 2 stay at
50 throughout; level 3 is at 25 for about half its steps, levels 4 to 8
for 82 to 97% (two divers are nearly always out there).

## Still to come

The level table (chunk 4), Erin's city and the bomb drop (chunk 5), and,
if room allows, a computer-style font (chunk 6).
