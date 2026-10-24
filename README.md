# ATLANTIS

A Z80 game for the 48K ZX Spectrum, built on the diver engine. The engine's
parallax demo is frozen as **Engine Demo 1** (git tag `engine-demo-1`):
`make demo` still builds it, as `build/diver.tap`, and `make run-demo`
still runs it. `make` and `make run` are the game.

Atlantis is the same diver, the same fish, and the same scroll, with a
different seabed. The bottom row is black ground, 8 pixels tall, one pixel
per frame. Above it is yellow sand, 8 pixels, one pixel every other frame.
Above the sand, now and then, a green seaweed plant that scrolls with the
sand. Everything above that is open water. A silo is still 16 pixels tall,
so it pokes up into the sand and is drawn in the sand's colours there.
That clash is left visible. The diver can sink over the sand and the weed.
He cannot touch the black: his lowest pixel stays one pixel above the
ground, a rock, or a silo, including the part of the silo that stands in
the sand.

**New to the sprite code? Read [docs/SPRITES.md](docs/SPRITES.md).
New to the scrolling ground? Read [docs/SCROLLING.md](docs/SCROLLING.md)**
(the demo's seabed first, then the Atlantis section).

## Controls

| Action | Keys            | Alternative | Kempston |
|--------|-----------------|-------------|----------|
| Up     | Q               | 7           | up       |
| Down   | A               | 6           | down     |
| Left   | O               | 5           | left     |
| Right  | P               | 8           | right    |
| Fire   | SPACE (unused for now) | 0    | fire     |
| Stats  | Symbol Shift + S       |             |          |
| Speed  | Symbol Shift + F       |             |          |
| Menu   | Symbol Shift + P       |             |          |

The tape opens on a start screen: `1` starts the game, `2` swaps between
50 and 25 frames a second. The choice is kept when you come back to the
menu.

The diver has three lives (`CFG_LIVES` in `src/atlantis/config.asm`). A
wheel bomb that touches him costs one: the bomb vanishes and the border
flashes red. The hit boxes are a little smaller than the pictures, so a
graze of the flippers or the rim does not count. After the last life
the game goes back to the menu, which says GAME OVER.

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
src/atlantis/data.asm    menu words, stat-line template, sine table (at $C000)
src/atlantis/menu.asm    the start screen, and Symbol Shift + P back to it
src/atlantis/rate.asm    50 or 25 frames a second, the chords, the spare-scanline count
src/atlantis/scenery.asm water, sand and ground colours
src/atlantis/scroll.asm  the game's seabed: buffers, blit, silo stamp, weed
src/atlantis/stats.asm   the row-0 stat line, Symbol Shift + S
src/atlantis/wheel.asm   the wheel bomb: drift, bob, spin, one at a time
src/atlantis/hit.asm     the bomb against the diver, and the lives
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
src/loader.asm           BASIC loader: CLEAR / LOAD ""CODE / RANDOMIZE USR 32768
gfx/fish.txt             fish art as ASCII (# ink, - paper, . transparent)
gfx/fish.asm             GENERATED from fish.txt: 8 shifts x 2 frames x 2 facings
gfx/diver.txt            diver art, 24 x 15, 3 frames, facing right
gfx/diver.asm            GENERATED from diver.txt: 8 shifts x 3 frames x 2 facings
gfx/wheel.txt            wheel bomb, 12 x 12, 4 frames, mirror off (the T stays a T)
gfx/wheel.asm            GENERATED from wheel.txt: 8 shifts x 4 frames, one facing
docs/SPRITES.md          screen layout, masking, pre-shifting, timing
docs/SCROLLING.md        the demo seabed, then the Atlantis seabed
tools/gfx2asm.py         ASCII art -> pre-shifted masked .asm (Python 3)
tools/read-debug.py      reads the demo's X/Y/IMG hex off a screenshot
tools/make-diver-montage.py  build/montage-diver.png from the art + test shots
tools/                   also: headless screenshot / input / sprite tests
build/                   atlantis.tap, diver.tap, snapshots, listings
Makefile                 Linux / WSL build
build.bat                Windows build (Atlantis; build.bat demo for the demo)
```

Atlantis memory: the tape has two code blocks. The instructions are at
`$8000-$A15D` (`code_end` is `$A15E`, 8,542 bytes) and must stay below
`$C000`. The pictures, menu words and tables are at `$C000-$E668`
(9,833 bytes; the pre-shifted diver alone is 5,760 bytes, the fish 1,728).
A build prints both ends (`atlantis code_end`, `atlantis data_end`), and
the `ASSERT`s at the end of `src/atlantis/main.asm` stop it if a block
runs into the next. The wheel bomb is 12 by 12. A shifted row is 2 bytes for shifts 0 to 4
and 3 bytes for shifts 5 to 7, so the picture is smaller than a 16 by 16
sprite stored at one width.
The scroll buffers are ordinary RAM at `$F000-$F2FF` (768 bytes: 16 slow
rows, then 8 ground rows, built at start-up, not stored on the tape). The
pixel-row address table (also built at start-up) is at `$FA00-$FB7F`. The
stack grows down from `$FDFC`, `JP isr` is at `$FDFD`, and the 257-byte
vector table of `$FD` is at `$FE00-$FF00`. Nothing here may grow into the
next region: the buffers must stop before `$FA00`, and the stack must not
climb down into the row table.

Engine Demo 1 is smaller: `code_end` is `$A928` (10,536 bytes) and its two
buffers are `$F000-$F3FF`.

Graphics: `make` regenerates `gfx/fish.asm`, `gfx/diver.asm` and
`gfx/wheel.asm` from the `.txt` art with Python 3 when the art changes. The
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
then, yellow sand on blue, and a black strip on yellow with rocks and a
missile silo. The silo's top half stands in the sand and is drawn yellow
on blue, because that cell's colours are the sand's. The hatch holes show
blue. That is the colour clash, left visible. The sand and the weed drift
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
