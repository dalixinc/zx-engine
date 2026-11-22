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
- **Levels:** see [the levels (chunk 4)](#the-levels-chunk-4). The
  banner freezes the action while it is up. Finishing the last level
  shows a placeholder ending.

## Room and timing

| | Hot | Cold | Data |
|---|---|---|---|
| Trigon 0.8.0 | 1 | 5 | 8 |
| Finale base | 1,705 | 1,381 | 2,400 |
| Finale, chunk 4 | 213 | 886 | 368 |

Free while the game runs as well: `$78E0-$7FFF` (the spinning wheel's
pictures, 1,824 bytes) and the round fish's 1,728.

Measured with power-ups and the Lance on and fire held, 1,024 steps:
levels 3, 6 and 8, on the seabed and in mid-water, show no late steps,
at least 10 scanlines to spare, and 1,024 interrupts.

## The Trigon divers (chunk 3)

Trigon divers come in from the right and swim left in the fish's old
place (`src/finale/ediver.asm`), drawn by Erin: the blue standard diver
and the red, tougher one, 16 x 15, facing left, kicking through four
pictures (apart, halfway, glide, halfway) and turning to a firing pose as
they shoot. One at once on levels 1 to 3 (blue, then red on level 3),
two from level 4, one of each (the levels, below). Each comes in one of the level's movements, picked at random:
weaving across on a wave (16 pixels up and down, from a random point on
it), drifting to the player's depth, stopping a while to fire twice as
often, or diving at his depth. They fire short dashes to the left
(Erin's 6 x 2 shot) at the level's speed, in their own colour once clear of the diver. A shot, or touching one, costs a life. The
torpedo, the double shot and the Lance each take one of a diver's hits:
a blue diver takes 2 to 4 by level, a red one 3 or 4. A hit makes him
blink, and the last blows him up for 20 points. The bomb
never comes out with two divers, and a diver waits rather than make a
third big enemy. The silos fire only from level 6; before that a heart
can still fall in their turn. Each level's divers are a row of
`CFG_ED_LEVELS` in `src/finale/config.asm`.

Their shifted pictures (1,440 bytes a colour) are made at start-up: the
blue's in the fish's old room, the red's at the top of the code's room,
both in uncontended memory.

Their colours are painted with their moves, not their draws, so at 25
they fall in the idle frame, and painted again every 8 frames: the bomb,
a heart, missiles and the Lance give cells back to the water as they
pass, and a diver over one would show white.

**The frame budget.** On every level (`CFG_ED_25_LEVEL` 1), while two big
enemies are out (two divers, or a diver and the bomb), the game drops to
25 frames a second, at the same game speed, and goes back to 50 half a
second after one has gone. Measured with the double shot and the Lance
in use, 1,024 steps each, on the seabed and in mid-water: no level loses
a frame; levels are at 25 for 55 to 97% of their steps.

## The levels (chunk 4)

Ten levels, each a little harder than the last, in two tables in
`src/finale/config.asm` that go together row by row: `CFG_LEVELS` (the
bomb's movement and haste, the silos' wait, the border) and
`CFG_ED_LEVELS` (the divers: how many, how tough, their movements, how
often they fire and how fast their shots fly).

| Level | What it brings |
|---|---|
| 1 | The opening fight: one blue diver, crossing or drifting to you; the pulsar on a quicker bob |
| 2 | The double shot. The diver may stop to fire; the bomb on the wave |
| 3 | The Lance. A red diver alone, quicker shots; the bomb hunting |
| 4 | Two divers at once, a blue and a red |
| 5 | The divers dive at you; the bomb hunts harder |
| 6 | The silos open fire from below; blue divers take 3 hits |
| 7 | Red divers take 4; every movement |
| 8 | Faster shots, quicker fire, closer missiles |
| 9 | The guard: the bomb hunting hardest |
| 10 | The last fight, short: the toughest divers, diving and drifting at you; then the ending |

Measured with fire held, 1,024 steps a level, on the seabed and in
mid-water: no level loses a frame and none has more than 2 late steps.
The game is at 25 frames a second (two big enemies out) for about half
to 60% of levels 1 to 3, and 77 to 97% from level 4, where two divers
come at once.

## Still to come

Erin's city and the bomb drop (chunk 5), and, if room allows, a
computer-style font (chunk 6). Losing the bomb drop, the final
sequence, will send the diver back to the start of level 9, the level
before the last (it was level 7 when Finale had eight levels).
