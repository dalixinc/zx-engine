# ATLANTIS

A Z80 game for the 48K ZX Spectrum, built on the diver engine. The engine's
parallax demo is frozen as **Engine Demo 1** (git tag `engine-demo-1`):
`make demo` still builds it, as `build/diver.tap`, and `make run-demo`
still runs it. `make` and `make run` are the game.

Atlantis is the same diver, the same fish, and the same scroll, with a
different seabed. The bottom row is black ground, 8 pixels tall, one pixel
per frame. Above it is yellow sand, 8 pixels, one pixel every other frame.
Above the sand, now and then, a green seaweed plant that scrolls with the
sand. Everything above that is open water. A missile silo is 16 pixels
wide and stands up through all three bands: a black base in the ground,
a yellow tower in the sand, and a green dome in the weed row. Each part
uses its own row's colours, so it does not clash with the sand or a
plant. The diver can sink over the sand and the weed, but touching the
black ground, a rock or a silo costs a life.

**New to the sprite code? Read [docs/SPRITES.md](docs/SPRITES.md).
New to the scrolling ground? Read [docs/SCROLLING.md](docs/SCROLLING.md)**
(the demo's seabed first, then the Atlantis section).

## Play in the browser

Once GitHub Pages is switched on for this repository (Settings, then
Pages, deploying from `main`, folder `/docs`), Atlantis plays at
**https://dalixinc.github.io/zx-engine/play/** in JSSpeccy 3. Click to
play, then `1`. Ctrl is Symbol Shift there. `make web` (or
`build.bat web`) copies a fresh build into `docs/play/`; commit and push
it to update the site. See [docs/WEB.md](docs/WEB.md).

## Controls

| Action | Keys            | Alternative | Kempston |
|--------|-----------------|-------------|----------|
| Up     | Q               | 7           | up       |
| Down   | A               | 6           | down     |
| Left   | O               | 5           | left     |
| Right  | P               | 8           | right    |
| Fire   | SPACE                  | 0           | fire     |
| Stats  | Symbol Shift + S (test builds only) | |          |
| Speed  | Symbol Shift + F       |             |          |
| Menu   | Symbol Shift + P       |             |          |

The tape shows a loading screen while the game loads (it is drawn from
the game's own sprites by `tools/mkloadscreen.py`). The game then opens
on a start screen: `1` starts the game, `2` swaps between
50 and 25 frames a second, and `3` takes a six-letter level code
(`0` rubs out a letter, Space gives up). The choice is kept when you come back to the
menu.

The diver has three lives (`CFG_LIVES` in `src/atlantis/config.asm`),
shown as hearts at the top right of the screen. A wheel bomb that
touches him costs one: the bomb vanishes, a heart goes, and the border
flashes red. The hit boxes are a little smaller than the pictures, so a
graze of the flippers or the rim does not count. Sinking onto the black
ground, a rock or a silo is a hit too: he explodes, loses a heart, and
starts again at the left edge at his starting depth. Each torpedo leaves with a falling laser
"pew" (`CFG_LASER`). Explosions crunch
on the beeper: high for a fish, middle for a bomb, long and low for a
lost life (tune them in `config.asm`, `CFG_*_SND_*`). The last life
plays a death knell, then the game goes back to the menu, which says
GAME OVER with your score. The menu always shows the high score, kept
until the machine is switched off.

Shooting scores: 1 for a fish, 2 for a bomb, 10 for a missile on the
first levels (each level's row of `CFG_LEVELS` in `config.asm` says).
Something that runs into him scores nothing. The score and the level
are on row 1, beside the hearts. Each level has a target, and each is
longer than the last. Reaching it puts up a big "LEVEL n" banner, plays
a jingle, and the next level's missiles come more often and its bombs
fly a little faster. Level 2 has a yellow bomb on a wave, a faster fish
on a wave and a cyan border (`docs/LEVEL-2.md`). From level 3 the bomb
is a red spinning wheel instead of the pulsar.

Level 2 and level 3 each open with a message and the level's code, up
until a key is pressed; from level 4 the code is under the banner. The
game-over screen shows the code of the highest level reached. Typing a
code on the menu starts a game at that level, with the score that level
starts at. The codes aren't published: they're in
`notes/LEVEL-CODES-LIST.md` in the repository, outside the web site.
See `docs/LEVEL-CODES.md`.

Now and then a silo near the diver arms a missile: it sits in the hatch
for half a second, scrolling with the ground, then flies straight up and
is gone below the hearts. Only a silo whose missile will leave within
`CFG_MISSILE_RANGE` pixels of him fires, so they come up close. Touching it is a hit, the same as a bomb. One is up
at a time; the wait between them, the warning and the speed are
`CFG_MISSILE_*` in `config.asm`.

Fire launches a torpedo from the nose of his jet unit, the way he is
facing. It runs along that row until it leaves the screen, and a bomb or
a missile it touches blows up. One at a time: a new press fires again once the last one
has gone. It does not follow him up or down.

The three Symbol Shift chords fire once, the moment both keys go down.
Holding them does not repeat, and the letter on its own does nothing.

Symbol Shift + S toggles the stat line on row 0. It is off at the start.
While it is hidden, that row is water again. It reads

```
scan 12 50/s x160 y090 L3 f65535
```

`scan` is the number of scanlines left over after the last step (99 at
most), `50/s` the speed, `x` and `y` the diver in pixels, `L` the lives
left, and `f` the television frames since the game started. The digits are reprinted every
eight steps.

All sources are merged into one byte, `000FUDLR` (same layout as Kempston),
with `IN_*` constants in `src/constants.asm`. Keys are redefinable: overwrite the `keys_primary` table in `src/input.asm`
(5 entries of half-row byte + bit mask, order FIRE, UP, DOWN, LEFT, RIGHT).
A Kempston read with any of bits 5-7 set is treated as "no joystick", which
guards against the floating bus when no interface is fitted.

The demo still prints its digits on rows 22 and 23. It has no overlay.

## Layout

```
src/atlantis/main.asm    Atlantis entry, main loop, output directives
src/atlantis/config.asm  the numbers you change: diver range, start speed, bomb bob
src/atlantis/layout.asm  the game's rows, colours, buffer addresses
src/atlantis/data.asm    menu words, stat-line template, sine table (at $C400)
src/atlantis/menu.asm    the start screen, and Symbol Shift + P back to it
src/atlantis/rate.asm    50 or 25 frames a second, the chords, the spare-scanline count
src/atlantis/scenery.asm water, sand and ground colours
src/atlantis/scroll.asm  the game's seabed: buffers, blit, silo stamp, weed
src/atlantis/silo.asm    the silo picture, and the code built from it that draws it
src/atlantis/missile.asm the silos' missiles: arm, fly, hit, their own draw
src/atlantis/score.asm   the score, the levels, the line on row 1, the banner
src/atlantis/codes.asm   the level codes: table, showing one, checking one typed
src/atlantis/preshift.asm the fish's and both bombs' pictures, shifted at start-up
src/atlantis/bss.asm     the buffers that start empty, at $F300, not on the tape
docs/play/               the browser version: page, JSSpeccy 3, snapshot, tape
src/atlantis/stats.asm   the row-0 stat line, Symbol Shift + S (test builds only)
src/atlantis/wheel.asm   the wheel bomb: drift, bob, spin, one at a time
src/atlantis/hit.asm     the bomb and the ground against the diver, and the lives
src/atlantis/sound.asm   beeper noise, played in each frame's spare time
src/atlantis/torpedo.asm the diver's torpedo: fire, run, hit a bomb, its own draw
src/atlantis/fastsprite.asm  the faster sprite walker the game uses (not the demo)
src/atlantis/soak.asm    the background-restore check, only with -DSOAK
src/main.asm             Engine Demo 1 entry and loop
src/layout.asm           the demo's rows and buffer addresses
src/constants.asm        memory map, colours, tuning constants
src/interrupts.asm       IM2 vector table at $FE00, JP at $FDFD, frame ISR
src/screen.asm           cls, border, cell address, pixel-row table
src/text.asm             ROM-free print routines (glyphs from the font at $3D00)
src/input.asm            keyboard half-row tables + Kempston -> one flags byte
src/sprite.asm           masked pre-shifted sprites; Atlantis adds edge clipping
src/scenery.asm          the demo's water and strip colours
src/scroll.asm           the demo's two 16-pixel silhouettes
src/diver.asm            the player: movement, clamping, facing, kick animation
src/fish.asm             the fish: swims left/right on its own (second sprite)
src/loader.asm           BASIC loader: CLEAR / LOAD ""SCREEN$ / LOAD ""CODE x2 / RANDOMIZE USR 32768
gfx/fish.txt             fish art as ASCII (# ink, - paper, . transparent)
gfx/fish.asm             GENERATED from fish.txt: 8 shifts x 2 frames x 2 facings
gfx/diver.txt            diver art, 24 x 15, 3 frames, facing right
gfx/diver.asm            GENERATED from diver.txt: 8 shifts x 3 frames x 2 facings
gfx/wheel.txt            wheel bomb, 12 x 12, 4 frames, mirror off (the T stays a T)
gfx/wheel.asm            GENERATED from wheel.txt: 8 shifts x 4 frames, one facing
gfx/torpedo.txt          torpedo, 7 x 2, one frame
gfx/torpedo.asm          GENERATED from torpedo.txt: 8 shifts x 1 frame x 2 facings
gfx/missile.txt          silo missile, 6 x 8, one frame, mirror off
gfx/missile.asm          GENERATED from missile.txt: 8 shifts x 1 frame
gfx/loading.scr          GENERATED loading screen, 6912 bytes (tools/mkloadscreen.py)
docs/SPRITES.md          screen layout, masking, pre-shifting, timing
docs/SCROLLING.md        the demo seabed, then the Atlantis seabed
tools/gfx2asm.py         ASCII art -> pre-shifted masked .asm (Python 3)
tools/mkloadscreen.py    draws gfx/loading.scr from the sprites (Python 3)
tools/read-debug.py      reads the demo's X/Y/IMG hex off a screenshot
tools/make-diver-montage.py  build/montage-diver.png from the art + test shots
tools/                   also: headless screenshot / input / sprite tests
build/                   atlantis.tap, diver.tap, snapshots, listings
Makefile                 Linux / WSL build
build.bat                Windows build (Atlantis; build.bat demo for the demo)
```

Atlantis memory (the full map is in [docs/MEMORY.md](docs/MEMORY.md)):
the tape is packed with ZX0. After the BASIC come two blocks: a small
unpacker with the packed loading screen, which it shows at once, then
the packed game (13,150 bytes in all). The unpacker writes three
blocks. The cold block at `$6000-$7035` (4,150 bytes) is the menu, the
level codes, start-up, the diver's death, each level's look and anything else that runs
once in a while, with the raw art that start-up shifts. It is
contended RAM, so nothing that runs every frame goes there. The
instructions are at `$8000-$B2A3` (`code_end` is `$B2A4`) and must stay
below `$C400`. The pictures and tables are at `$C400-$CCB2`. The four
sprites' shifted copies are built at start-up: the diver's, the
fish's and the pulsar's at `$CF30-$EFFF`, the spinning wheel's at
`$71C0-$7FFF`. The buffers that start empty are at `$F300-$F517`,
zeroed at start-up. The tape build has no stat line.
The soak build puts its checks after the cold block and its photographs
after the game's code.
A build prints the ends (`atlantis code_end`, `data_end`, `cold_end`,
`bss`), and the `ASSERT`s at the end of `src/atlantis/main.asm` stop it
if a block runs into the next. The wheel bomb is 12 by 12. A shifted row
is 2 bytes for shifts 0 to 4 and 3 bytes for shifts 5 to 7, so the
picture is smaller than a 16 by 16 sprite stored at one width.
The scroll buffers are ordinary RAM at `$F000-$F2FF` (768 bytes: 16 slow
rows, then 8 ground rows, built at start-up, not stored on the tape). The
pixel-row address table (also built at start-up) is at `$FA00-$FB7F`. The
stack grows down from `$FDFC`, `JP isr` is at `$FDFD`, and the 257-byte
vector table of `$FD` is at `$FE00-$FF00`. Nothing here may grow into the
next region: the buffers must stop before `$FA00`, and the stack must not
climb down into the row table.

Engine Demo 1 is smaller: `code_end` is `$A928` (10,536 bytes) and its two
buffers are `$F000-$F3FF`.

Graphics: `make` regenerates `gfx/fish.asm`, `gfx/diver.asm`,
`gfx/wheel.asm`, `gfx/torpedo.asm` and `gfx/missile.asm` from the `.txt` art with Python 3 when the art changes,
and redraws `gfx/loading.scr` when the art or `tools/mkloadscreen.py` changes. The
generated files are committed, so Windows users can build with `build.bat`
without Python. After editing the art, run e.g.
`python tools\gfx2asm.py gfx\wheel.txt gfx\wheel.asm wheel` first. A line
`mirror off` in the text file skips the left-facing copy.

## Build on Ubuntu-based Linux (Zorin OS, Ubuntu, Mint, Pop!_OS)

```
sudo add-apt-repository universe multiverse     # Zorin usually has these on already
sudo apt update
sudo apt install build-essential cmake git curl xz-utils make
sudo apt install fuse-emulator-gtk spectrum-roms  # or fuse-emulator-sdl
```

`spectrum-roms` (the Sinclair/Amstrad ROMs Fuse needs) lives in Ubuntu's
**multiverse** repo; without it Fuse cannot boot a 48K. Then build sjasmplus
and the project as below. With the GTK build, run `make run EMU=fuse-gtk`
(or just `fuse`, whichever your package installed).

## Build on Debian / other Linux

Requirements: `sjasmplus` 1.24+, optionally `fuse-emulator-sdl` and `zx0`.

```
# sjasmplus from source
curl -LO https://github.com/z00m128/sjasmplus/releases/download/v1.24.0/sjasmplus-1.24.0-src.tar.xz
tar xf sjasmplus-1.24.0-src.tar.xz && cd sjasmplus-1.24.0 && make && sudo make install

sudo apt install fuse-emulator-sdl      # Debian has no spectrum-roms package;
                                        # copy 48.rom (from the Fuse source
                                        # tarball's roms/ folder) into
                                        # /usr/share/spectrum-roms/

make          # -> build/atlantis.tap (+ atlantis.sna snapshot)
make run      # open Atlantis in Fuse. EMU=fuse if you use the GTK front end's name
make demo     # -> build/diver.tap, Engine Demo 1, unchanged
make run-demo # open that tape
make shot     # headless screenshot of Atlantis (needs xvfb, xdotool, imagemagick)
make timing   # build/atlantis-timing.sna: border colour shows the frame's time
make input-test   # headless key presses of the DEMO (it reads row 22)
make sprite-test  # headless diver + fish test of the DEMO, shots build/diver-*.png
```

Fuse opens in a small window. Scale it with a graphics filter, for example
`make run EMU="fuse -g 3x"`. `-g` is short for `--graphics-filter`, and the
choices include 2x, 3x, 4x, hq3x and advmame3x. To make that permanent, add
`export EMU="fuse -g 3x"` to `~/.bashrc`, or set the filter in Fuse's Options
menu and choose Options > Save, which writes `~/.fuserc`. `--full-screen`
works only with the SDL build (`fuse-sdl`).

`make run` loads the tape in a moment, so the loading screen only flashes
past. To load it at real tape speed, turn off Fuse's tape traps and fast
loading. The loading screen appears as soon as the first, short block is
in, and stays up while the game loads behind it:

```
# Linux
fuse --machine 48 --no-traps --no-fastload -g 3x build/atlantis.tap

# Windows
windows-tools/fuse/fuse.exe --machine 48 --no-traps --no-fastload --graphics-filter 3x build/atlantis.tap
```

## Set up on Windows

1. **Assembler.** Download `sjasmplus-1.24.0.win.zip` from
   https://github.com/z00m128/sjasmplus/releases, unzip to e.g.
   `C:\zx\sjasmplus`, and add that folder to your PATH
   (Start > "Edit the system environment variables" > Environment Variables > Path).
   Check with `sjasmplus --version` in a new terminal.
2. **Emulator.** Any of these will open `build\atlantis.tap`:
   - Fuse for Windows: https://sourceforge.net/projects/fuse-emulator/files/fuse/
   - ZEsarUX: https://github.com/chernandezba/zesarux/releases
   - SpecEmu (Windows-only, very accurate; search "SpecEmu")
   Set it to a 48K machine. Dragging the `.tap` onto the window usually auto-loads it.
3. **Editor.** VS Code with the "Z80 Macro-Assembler" extension (mborik) for
   syntax highlighting. Add "DeZog" (maziac) later for source-level debugging
   with breakpoints; it works with sjasmplus `.sld` output and ZEsarUX.
4. **Build.** In the project folder run `build.bat`, or `build.bat run` to
   build and launch. If `fuse.exe` isn't on PATH, set it first:
   `set EMU=C:\zx\fuse\fuse.exe`.
   Prefer `make`? Install WSL (`wsl --install`), then follow the Linux steps.
5. **Compression (later).** ZX0 Windows builds: https://github.com/einar-saukas/ZX0

## What you should see

**Atlantis** (`make run`). First the start screen: "ATLANTIS" in yellow on
blue, the controls, and the numbered options over the seabed. Press `1`.
The play screen has no words on it. Open water from the top of the screen
down to three thin bands at the bottom: a green seaweed plant now and
then, yellow sand on blue, and a black strip on yellow with rocks and
missile silos. A silo is a black base, a yellow tower cut out of the
sand, and a green dome (see `docs/images/silo-before.png`,
`docs/images/silo-after.png` and `docs/images/silo-zoom.png`). The sand and the weed drift
at half the speed of the black strip. A white fish swims to and fro at the
old depth. A wheel bomb slides in from the right, one pixel a frame,
bobbing as it goes, and leaves through the left edge. Its legs spin and
the T in the hub stays upright. One is on screen at a time; the next
appears about a second after the last one has gone. The bomb does not
fit in one frame: while it is on screen the loop misses the interrupt
and the picture updates at 25 Hz, with the scroll and the sprites
stepping twice per picture. The speeds were not changed to hide that.
`docs/SCROLLING.md` has the measurement and the options. The diver holds his
jet unit out in front, kicks while you hold
a direction, and glides with his legs together when you let go. He can
swim up to the top row, and down over the weed and the sand, until his
feet are one pixel above the black under him. A silo or a rising hill
lifts him. Over a coloured cell he takes on its colours. The strips keep
scrolling whether or not he moves. The stat line is hidden until
Symbol Shift + S; the border cycles every 8 frames so the loop is still
obvious. See `build/atlantis-seabed.png`, `build/atlantis-low.png`,
`build/atlantis-stats.png` and `build/atlantis-stats-off.png`. The
timing border is `build/atlantis-timing-water.png` (he is up in the
water) and `build/atlantis-timing-low.png` (he is down on the seabed).

**Engine Demo 1** (`make run-demo`) is the previous picture: "DIVER ENGINE",
two 16-pixel strips (yellow sand, then black ground), and the debug digits
fixed on rows 22 and 23. See `build/scroll-a.png`, `build/scroll-b.png`,
`build/scroll-c.png` and `build/montage-diver.png`.

Emulator tip: Fuse maps the PC arrow keys to the Spectrum cursor keys (CAPS +
5-8), so they work too. To test Kempston in Fuse, enable Options >
Peripherals > Kempston joystick and set Options > Joysticks > Keyboard to
Kempston (or `--kempston --joystick-keyboard-output 2`), then QAOP/SPACE drive
the joystick. Load the `.tap` for this: in testing, loading the `.sna` left the
Kempston reading 00, apparently because the snapshot overrides the peripheral settings.
