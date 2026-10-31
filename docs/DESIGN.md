# Atlantis

A game for the 48K ZX Spectrum. The diver is trying to get home.
The Trigon Empire has blockaded Atlantis. The enemies are Trigons.

## The journey

There are 20 levels. Each one has its own border colour. Which colour
goes with which level is still open.

Levels 1 to 10 are colourful. They are the way to Atlantis.

After level 10 there is an interlude. A picture of Atlantis, stored
compressed, scrolls past. The compression is run-length encoding, the
old trick of a 255 byte followed by a count. The picture itself, how
long the scroll takes, and where the bytes live are still open.

Then a test level, where the diver picks up a bomb. What else that
level contains is still open.

Levels 11 to 20 are dark. They lead to the Trigon city. The finale is
getting the bomb through a narrow gap, in the manner of the Death Star
trench. The shape of that gap, and what happens if he misses it, are
still open.

## What is in the game now

The diver swims. A fish crosses the water on its own. The seabed
scrolls in parallax: black ground every frame, yellow sand and green
weed every other frame.

The first Trigon on screen is the pulsar bomb. One is on screen at a
time. It drifts left, bobs, and pulses. It can hit the diver. He has
three lives, shown as hearts. The last life returns to the menu, which
says GAME OVER.

Two more bombs are drawn and stored, and not on screen yet. The
partial wheel rocks part of the way round. The full wheel turns all
the way. The order later is pulsar, then the partial wheel, then the
full wheel. Their pictures are `gfx/wheel-partial.txt` and
`gfx/wheel-full.txt`.

A repeated step does not store the picture again. Each different
shape is kept once, and a short list (`wheel_seq`, and the same for
the other two) says which shape each step shows. The pulsar's eight
steps are two shapes. The two wheels have no repeated frame, so the
list does not shrink them. They stay out of the tape until a level
needs them.

Fire launches one torpedo, along the row he is facing. It destroys a
wheel bomb it touches, and is spent. Another cannot be launched until
`CFG_FIRE_COOLDOWN` television frames have passed (48, about a second).

A hit on a bomb, from the torpedo or from the diver, plays a short
explosion where the bomb was. The bomb is already gone, so the
explosion is drawn instead of it. The fish bursts the same way if it
meets the diver or a torpedo, and the diver does not lose a life for
that. The burst is four pictures, lined up on a byte, and it stays
put while the sea scrolls.

The tape starts at 25 frames a second. The picture frame does the
same draw and the same one tick as 50. The next television frame
moves again and does not draw. Key 2 on the menu switches to 50,
one step every television frame. Symbol Shift + F does the same
during play.
During play, Symbol Shift + S shows the stat line, Symbol Shift + F
switches the speed, and Symbol Shift + P returns to the menu. Each
chord fires once, on the press. The key alone does nothing. S and F
flash the border so the chord can be seen.

The numbers live in `src/atlantis/config.asm`. Change one, rebuild,
and the game uses it.

`make soak` plays a scripted game and checks the picture. A green
border and OK means it passed. `make timing` paints the border in
bands so a frame can be read as a clock.

## What is planned

Not built yet:

- Explosions.
- More collisions. Touching the black ground does not kill him; he is
  only held off it.
- Homing bombs, and smart bombs. The wheel has a kind byte ready for
  a homing routine. The routine is not written.
- Missiles from the silos. The silo picture is still the placeholder.
- Sharks and jellyfish.
- Maybe Trigon divers. Whether they are in is still open.
- A bigger bob on the wheel bomb. The height is `CFG_WHEEL_BOB`.
- Maybe a cap on the diver's speed. Whether to add one is still open.
- Sound effects, and a tune in the manner of Manic Miner. The tune
  itself is still open.
- The level structure above. The game is still one continuous sea.

Later, release it to the retro Spectrum community. After that, a Java
port. The shape of that port is still open.

## Memory

The tape loads two blocks. Figures are from the current build
(`atlantis code_end`, `atlantis data_end`).

| region            | address        | what |
|-------------------|----------------|------|
| instructions      | `$8000-$A3DE`  | `code_end` is `$A3DF` (9,183 bytes) |
| graphics and text | `$C000-$E714`  | `data_end` is `$E715` (10,005 bytes) |
| scroll buffers    | `$F000-$F2FF`  | built at start, not stored on the tape |
| row address table | `$FA00-$FB7F`  | built at start |
| stack             | down from `$FDFC` | |
| `JP isr`          | `$FDFD`        | |
| IM2 vectors       | `$FE00-$FF00`  | |

The soak build ends at `$ABF1`, still under `$C000`. Its two
photographs sit at `$F300`.
