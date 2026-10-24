# DIVER ENGINE

A Z80 machine code game engine for the 48K ZX Spectrum, for an underwater
side-scrolling shooter. Milestones 1-5 are done (v0.4): it loads from tape,
prints a title, runs a 50 Hz IM2 interrupt with a frame counter, cycles the
border colour every 8 frames, reads keyboard/Kempston input, and steers a
masked, pre-shifted, animated 24-pixel diver (with a jet unit) pixel by
pixel, while a 16-pixel fish swims back and forth by itself.

**v0.5** replaces the static seabed with two parallax silhouettes. The far
one is yellow sand on the blue water, with a green seaweed column now and
then, 16 pixels tall, scrolling a pixel every other frame. The near one is
a black landscape on yellow, rocks and missile silos included, also 16
pixels tall, scrolling a pixel every frame, and it sits directly under the
far one. The diver is still steered in screen coordinates; the world
scrolls on its own, and he can swim down until his feet are one pixel
above the black ground. **New to the sprite code? Read [docs/SPRITES.md](docs/SPRITES.md).
New to the scrolling ground? Read [docs/SCROLLING.md](docs/SCROLLING.md).**

## Controls

| Action | Keys            | Alternative | Kempston |
|--------|-----------------|-------------|----------|
| Up     | Q               | 7           | up       |
| Down   | A               | 6           | down     |
| Left   | O               | 5           | left     |
| Right  | P               | 8           | right    |
| Fire   | SPACE (unused for now) | 0    | fire     |

All sources are merged into one byte, `000FUDLR` (same layout as Kempston),
with `IN_*` constants in `src/constants.asm`. Row 23 shows it in hex for
debugging: `KEY` (keyboard only), `JOY` (Kempston only), `IN` (combined).
Keys are redefinable: overwrite the `keys_primary` table in `src/input.asm`
(5 entries of half-row byte + bit mask, order FIRE, UP, DOWN, LEFT, RIGHT).
A Kempston read with any of bits 5-7 set is treated as "no joystick", which
guards against the floating bus when no interface is fitted.

## Layout

```
src/main.asm        entry point, main loop, output (.tap/.sna) directives
src/constants.asm   memory map, colours, tuning constants
src/interrupts.asm  IM2 vector table at $FE00, JP at $FDFD, frame ISR, wait_frame
src/screen.asm      cls, border, cell -> screen/attribute address, pixel-row table
src/text.asm        ROM-free print routines (glyphs read from the font at $3D00)
src/input.asm       keyboard half-row tables + Kempston -> one flags byte
src/sprite.asm      masked pre-shifted sprites of any width: set position,
                    save/restore background (one record per sprite), draw
src/scenery.asm     water and strip colours, then asks scroll_init to draw the ground
src/scroll.asm      two parallax silhouettes: buffers, blit, shift, silo ring
src/diver.asm       the player: movement, clamping, facing, kick animation
src/fish.asm        the fish: swims left/right on its own (second sprite)
src/loader.asm      tokenised BASIC loader: CLEAR / LOAD ""CODE / RANDOMIZE USR 32768
gfx/fish.txt        fish art as ASCII (# ink, - paper, . transparent), 2 frames
gfx/fish.asm        GENERATED from fish.txt: 8 shifts x 2 frames x 2 facings
gfx/diver.txt       diver art, 24 x 15, 3 frames, facing right
gfx/diver.asm       GENERATED from diver.txt: 8 shifts x 3 frames x 2 facings
docs/SPRITES.md     how the screen layout, masking, pre-shifting and timing work
docs/SCROLLING.md   the two strips: why a buffer, the draw order, the timing
tools/gfx2asm.py    ASCII art -> pre-shifted masked .asm (Python 3)
tools/read-debug.py reads the X/Y/IMG hex values off a screenshot
tools/make-diver-montage.py  build/montage-diver.png from the art + test shots
tools/              also: headless screenshot / input / sprite tests, ZX0 decompressor
build/              output: diver.tap, diver.sna, diver.lst, diver.sym
Makefile            Linux / WSL build
build.bat           Windows build
```

Memory: code and data at `$8000-$A927` (`code_end` is `$A928`, 10,536 bytes;
the pre-shifted diver alone is 5,760 bytes, the fish 1,728). The two scroll
buffers are ordinary RAM at `$F000-$F3FF` (1,024 bytes, 16 rows each, built
at start-up, not stored on the tape). The pixel-row address table (also
built at start-up) is at `$FA00-$FB7F`. The stack grows down from `$FDFC`,
`JP isr` is at `$FDFD`, and the 257-byte vector table of `$FD` is at
`$FE00-$FF00`. Nothing here may grow into the next region: the buffers must
stop before `$FA00`, and the stack must not climb down into the row table.

Graphics: `make` regenerates `gfx/fish.asm` and `gfx/diver.asm` from the
`.txt` art with Python 3 when the art changes. The generated files are
committed, so Windows users can build with `build.bat` without Python. After
editing the art, run e.g.
`python tools\gfx2asm.py gfx\diver.txt gfx\diver.asm diver` first.

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

make          # -> build/diver.tap (+ diver.sna snapshot)
make run      # open in Fuse
make shot     # headless screenshot (needs xvfb, xdotool, imagemagick)
make input-test   # headless key presses + Kempston, screenshots in build/
make sprite-test  # headless diver + fish test, shots build/diver-*.png;
                  # then python3 tools/make-diver-montage.py
make timing       # build/diver-timing.sna: border colour shows the frame's time
```

## Set up on Windows

1. **Assembler.** Download `sjasmplus-1.24.0.win.zip` from
   https://github.com/z00m128/sjasmplus/releases, unzip to e.g.
   `C:\zx\sjasmplus`, and add that folder to your PATH
   (Start > "Edit the system environment variables" > Environment Variables > Path).
   Check with `sjasmplus --version` in a new terminal.
2. **Emulator.** Any of these will open `build\diver.tap`:
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

"DIVER ENGINE" in yellow on blue, a help line, a blue sea, and along the
bottom two moving silhouettes: yellow sand dunes with a green seaweed
column now and then, and under them a black landscape on yellow with rocks
and the occasional missile silo. A white fish swims to and fro, and the
white diver holds his jet unit out in front. QAOP / 5678 / Kempston swim
him one pixel per frame; he kicks his flippers only while moving (legs
apart, then half way, then crossed, then half way) and glides with his
legs together when you let go. He turns to face the way he's going, passes
in front of the fish, and can swim down until his feet are one pixel above
the black ground (a hill lifts him). Over the strips he takes on their
colours: attribute clash, including turning black-on-yellow over the near
strip, where he vanishes into a black hill. The strips keep scrolling
whether or not he moves. Row 22 shows `FRAMES:` plus the diver's `X`, `Y`
(pixels, hex) and `IMG` (0-2 facing right, 3-5 facing left: 0 legs apart,
1 half way, 2 together). Row 23 shows the input bytes. See
`build/scroll-a.png`, `build/scroll-b.png`, `build/scroll-c.png` and
`build/montage-diver.png` (`montage-sprites.png` is from the fish-only
milestone 4).

Emulator tip: Fuse maps the PC arrow keys to the Spectrum cursor keys (CAPS +
5-8), so they work too. To test Kempston in Fuse, enable Options >
Peripherals > Kempston joystick and set Options > Joysticks > Keyboard to
Kempston (or `--kempston --joystick-keyboard-output 2`), then QAOP/SPACE drive
the joystick. Load the `.tap` for this: in testing, loading the `.sna` left the
Kempston reading 00, apparently because the snapshot overrides the peripheral settings.
