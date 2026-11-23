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
  brings up [Trigon City and the bomb drop](#trigon-city-and-the-bomb-drop-chunk-5).

## Room and timing

| | Hot | Cold | Data |
|---|---|---|---|
| Trigon 0.8.0 | 1 | 5 | 8 |
| Finale base | 1,705 | 1,381 | 2,400 |
| Finale, chunk 4 | 213 | 886 | 368 |
| Finale, chunk 5 | 330 | 63 | 176 |

Chunk 5 also uses the two rooms that were free while the game runs: the
packed city fills `$781D-$7FFF` (the spinning wheel's old pictures, and
the top of the cold block's room), and the busier half of the ending
sits above the run-time buffers, where Atlantis keeps the round fish's
pictures (`$F65A-$F8A1`, 30 bytes left there). See
[Trigon City and the bomb drop](#trigon-city-and-the-bomb-drop-chunk-5).

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
third big enemy. On the levels of one diver (1 to 3), he and the bomb
take turns: one big enemy at a time. The silos fire only from level 6; before that a heart
can still fall in their turn. Each level's divers are a row of
`CFG_ED_LEVELS` in `src/finale/config.asm`.

Their shifted pictures (1,440 bytes a colour) are made at start-up: the
blue's in the fish's old room, the red's at the top of the code's room,
both in uncontended memory.

Their colours are painted with their moves, not their draws, so at 25
they fall in the idle frame. When a diver moves into new cells, the new
ones are painted at once, but the ones he leaves go back to the water
only after he has been drawn in his new place, so no part of him shows
white for a frame. They are painted again every 8 frames: the bomb,
a heart, missiles and the Lance give cells back to the water as they
pass, and a diver over one would show white.

**The frame budget.** On every level (`CFG_ED_25_LEVEL` 1), while two big
enemies are out (two divers, or a diver and the bomb), the game drops to
25 frames a second, at the same game speed, and goes back to 50 half a
second after one has gone. Levels 1 to 3 never have two, as the diver
and the bomb take turns, so they stay at 50. At 50 a diver and the bomb
together leave no time to spare, and over a third of the steps run
late, which would tear; the turns cost about 12 bytes.

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
| 10 | The last fight, short: the toughest divers, diving and drifting at you; then Trigon City and the bomb drop |

Measured with fire held, 1,024 steps a level, on the seabed and in
mid-water (chunk 5: levels 1, 2, 3, 4, 6 and 10): no level loses a
frame and none has more than 6 late steps (steps that overrun a little
and catch up). Levels 1 to 3 are at 50 frames a second all the time
(until chunk 5 they were at 25 for about half to 60% of it); from level
4, where two divers come at once, the game is at 25 for 77 to 93%.

## Trigon City and the bomb drop (chunk 5)

Finishing level 10 stops the fight. The screen goes black, and the city
comes on in a circle from the middle, with TRIGON CITY over it, the
level's jingle, and the power generator flashing at its foot. A second
later a fresh key, or five seconds, starts the drop.

The diver swims left and right above the city, the bomb under him, and
fire lets it go. It falls through the shields, three bars that slide
across the city at their own speeds, into the generator. A shield stops
it (a red flash), and so does the bottom of the city. There are five
bombs, counted under the city.

- **Into the generator:** a white blast grows from it over the whole
  screen, then the dark, then "TRIGON CITY FALLS / THE BLOCKADE IS
  BROKEN / ATLANTIS IS FREE" until a key, the high score, and the menu.
- **No bombs left:** "The bombs are spent. Back to level 9", then the
  game starts again at the start of level 9, as its code would (with
  that level's score and full lives). The high score counts first.

Everything is a setting in `src/finale/config.asm`: the city's time,
the bombs, their speed, the level to go back to, the generator's place
and colours, and each shield's row, length, speed and direction.

**The picture.** It is the Atlantis city for now, with Finale's black
sea round it (`tools/mkcity.py --finale`, `gfx/finale/city.scr`): Erin's
Trigon City drops in the same way when it comes, at 192 x 128 or
smaller. Packed, it is 2,019 bytes. It is not in the cold block: it
sits at the top of that room, `$781D-$7FFF`, which nothing uses while
the game runs. On the tape it rides at the end of the second block, and
the game copies it up as it starts, before anything can write there. A
Trigon City of up to about 2,080 bytes packed fits as things stand.

**The code** runs once a game, so its main part is in the cold block
(`src/finale/city.asm`). The circle, the shields, the bomb's drawing,
the words and the picture's unpacker are above the run-time buffers
(`src/finale/cityhi.asm`), copied there from the tape the same way. The
picture's colours wait in the seabed's buffers while it is up; the next
game draws them again.

## Still to come

If room allows, a computer-style font (chunk 6), and Erin's Trigon City
and bomb-carrying diver when they come.
