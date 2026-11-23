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
  suction and the bubble, and the level 2 and 4 messages.
- **The world:** a black sea; dark blue hills and ground with yellow seaweed on their
  tops; the silos in front with yellow domes and dark blue towers, their cells
  painted as they pass. Every colour is a setting in
  `src/finale/config.asm`, to tune in play.
- **The menu:** FINALE in the tall letters, yellow over red. It asks for
  the code Trigon's ending gives before level 1. The last code (typed,
  or the one GAME OVER showed) is offered on the code's line: Enter
  takes it, a letter starts a new one.
- **Row 1:** the score, the level, the Lance's gauge, then a yellow
  bomb (the one he carries for the generator), the speed (50 or 25
  frames a second, as it changes), the special bomb he carries, if any,
  and the hearts.
- **The letters:** Finale's own computer-style font, capitals, digits
  and the few signs its words use (`src/finale/font.asm`, two looks:
  `CFG_FONT_LOOK` 1 bold, 2 thin), for every word and number but the
  title's tall letters, the banner's blocks and the points' small
  figures. Lowercase prints as capitals. See [the letters](#the-letters).
- **The story:** a short intro typed before the game.
- **The diver:** white, no belts (placeholder art until Erin's
  bomb-carrying diver arrives, inside his present 24 x 15 box).
- **Weapons:** the torpedo; the double shot from level 2 and the Lance
  from level 3, given, not caught. The Lance's beam also burns up the
  Trigon divers' shots it touches, and from level 4 a torpedo that
  meets one takes it out (`CFG_TORP_SHOT_LEVEL`; within two rows above
  or below counts, `CFG_TORP_SHOT_SLACK`).
- **Power-ups:** the heart, and from level 4 the special bombs
  (`src/finale/special.asm`), rarer, in the silo missile's place. He
  carries one at a time, shown on row 1 left of the hearts, and B sets
  it off: the screen shakes and the divers' shots are gone. Shove (green
  chevrons) throws the bomb and the divers to the right edge, where they
  blow up for 20 points each, and blows up a silo's missile. Their
  levels and shares are settings in `src/finale/config.asm`.
- **Levels:** see [the levels (chunk 4)](#the-levels-chunk-4). The
  banner freezes the action while it is up. Finishing the last level
  brings up [Trigon City and the bomb drop](#trigon-city-and-the-bomb-drop-chunk-5).

## Room and timing

| | Hot | Cold | Data |
|---|---|---|---|
| Trigon 0.8.0 | 1 | 5 | 8 |
| Finale base | 1,705 | 1,381 | 2,400 |
| Finale, chunk 4 | 213 | 886 | 368 |
| Finale 0.1.3, chunk 5 | 158 | 119 | 176 |
| Finale 0.1.4 | 117 | 66 | 56 |
| Finale, after the squeeze | 653 | 440 | 184 |
| Finale, the special bombs | 211 | 150 | 184 |
| Finale, the letters | 188 | 152 | 184 |

**The squeeze** (Quartus's brief after 0.1.4) freed, item by item:

| Item | Hot | Cold | Data |
|---|---|---|---|
| The fish's wave table (the game has no fish) | | | 128 |
| The fish's picture tables | | | 64 |
| The fish's raw art | | 144 | |
| The spinning wheel's settings (`enemy_spin`, 5 bytes: an alignment gap took them) | | | 0 |
| Suction's and shove's tunes | 46 | | |
| The fish's code: flash, wait, hits, wave, the Lance's fish test | 453 | 8 | 64 |
| `trigon_paint`'s fish part (also a little time each step) | 37 | | |
| The printer buffer: the drop (`ct_try`) and its records, 248 bytes | | 222 | |

The soak, written round a fish, keeps all of the fish. Then the
torpedo against the divers' shots took 128 of the data block's, and the
special bombs 442 of the hot code's and 290 of the cold block's (the
shake is in the hot code, as the cold block was too small for it).

The printer buffer (`$5B00`, 8 bytes left) cannot be loaded from tape:
a 128 in 128 BASIC keeps its paging code there while it loads. Its
routines are assembled to run there with their bytes in the scroll
buffers, which are built later, and start-up copies them up once it
has taken the interrupts. The packed tape brings them at the end of the
second block, before cityhi.asm.

Chunk 5 also uses the two rooms that were free while the game runs: the
packed city fills `$77A9-$7FFF` (the spinning wheel's old pictures, and
the top of the cold block's room), and the busier half of the ending
sits above the run-time buffers, where Atlantis keeps the round fish's
pictures (`$F65A-$F8A1`, 30 bytes left there). The ending's words are
in the hot code, as the cold block is full. See
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

They swim no higher than pixel row 40 (`CFG_ED_TOP`), three rows under
the score. Each step erases every sprite and draws it again while the
beam runs down the picture; a sprite the beam reaches between the two
is not on that picture. The divers are drawn just after ours and his
torpedo, or first when one of them is above him (`ed_order`), and erased
in the reverse order. Drawn last, as they were, a diver in the top third
was missing from every picture at 50, and higher than row 40 he still
is when ours is at the top (measured: 16 to 32 vanished, 40 and 48
never did, firing or not).

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
| 4 | Two divers at once, a blue and a red; the special bombs may fall |
| 5 | The divers dive at you; the bomb hunts harder |
| 6 | The silos open fire from below; blue divers take 3 hits |
| 7 | Red divers take 4; every movement |
| 8 | Faster shots, quicker fire, closer missiles |
| 9 | The guard: the bomb hunting hardest |
| 10 | The last fight, short: the toughest divers, diving and drifting at you; then Trigon City and the bomb drop |

Measured with fire held, 1,024 steps a level, on the seabed and in
mid-water (after the squeeze: levels 1, 2, 3, 4, 6 and 10): no level
loses a frame and none has more than 6 late steps (steps that overrun a
little and catch up). Levels 1 to 3 are at 50 frames a second all the
time (until chunk 5 they were at 25 for about half to 60% of it); from
level 4, where two divers come at once, the game is at 25 for 78 to
94%. The torpedo's test against the shots tests their rows inline
first: called for both shots each time, it gave level 10 in mid-water
16 late steps.

The special bombs, measured the same way with shove set off every 64
steps (16 times in 1,024, its points off so the level stays the same):
levels 4, 7 and 10, on the seabed and in mid-water, lose no frame while
a throw lasts or as it ends, and show at most one late step. The step
that sets one off loses a frame 2 to 4 times in 16, but that step holds
the second-long shake, while the game stands still anyway. Holding one
costs about 60 T-states a step (B is read only then).
## Trigon City and the bomb drop (chunk 5)

Finishing level 10 stops the fight. The screen goes black, and the city
comes on in a circle from the middle, with TRIGON CITY over it and the
level's jingle: Erin's city, the great red T over its gate. The gate is
the power generator, flashing yellow and red. A second
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

**The picture** is Erin's Trigon City, 192 x 128, from her Trigo art
pack (`gfx/finale/trigo_city_bitmap.bin` and `_attrs.bin`), with
Finale's black sea round it (`tools/mkcity.py --finale`,
`gfx/finale/city.scr`). Packed, it is 2,135 bytes. It is not in the cold
block: it sits at the top of that room, `$77A9-$7FFF`, which nothing uses
while the game runs. On the tape it rides at the end of the second
block, and the game copies it up as it starts, before anything can
write there. Her 256 x 128 panorama would pack to about 3,470 bytes,
some 1,300 more than there is room for.

**The code** runs once a game, so its main part is in the cold block
(`src/finale/city.asm`). The circle, the shields, the bomb's drawing,
the words and the picture's unpacker are above the run-time buffers
(`src/finale/cityhi.asm`), copied there from the tape the same way. The
picture's colours wait in the seabed's buffers while it is up; the next
game draws them again.

## The letters

48 letters, `+` to `Z` in ASCII order, six rows each: the middle six
lines of the cell, as the ROM's capitals use (the top and bottom lines
are drawn empty). The space and the apostrophe take two slots no word
uses. They cost no block room: they live in the end of the fish's old
picture room that the blue diver's 1,440 bytes leave free (`$EB50`,
288 bytes, exactly 48 letters), where the plain tape's data block and
the snapshot already reach, and the packed tape's `city_go` copies them
up. The code that draws them (`font_glyph`, `glyph_put`) took 23 bytes
of the hot code; `print_char` got shorter, so the cold block gained 2.
The test builds' hex readouts and the soak keep the ROM's font.

Row 1's letters are drawn only when they change, as before. Measured as
above, levels 1, 4 and 10, seabed and mid-water: the same late steps
and interrupts as 0.1.5, and the least spare at most a scanline less.

## Still to come

Erin's bomb-carrying diver when it comes.
