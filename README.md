# DIVER ENGINE

A Z80 machine code game engine for the 48K ZX Spectrum, for an underwater
side-scrolling shooter. Milestones 1-3 are done: it loads from tape, prints a
title, runs a 50 Hz IM2 interrupt with a frame counter, cycles the border
colour every 8 frames, and moves a 16x16 block with the keyboard or a Kempston
joystick.

## Controls

| Action | Keys            | Alternative | Kempston |
|--------|-----------------|-------------|----------|
| Up     | Q               | 7           | up       |
| Down   | A               | 6           | down     |
| Left   | O               | 5           | left     |
| Right  | P               | 8           | right    |
| Fire   | SPACE (colour)  | 0           | fire     |

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
src/screen.asm      cls, border, character-cell -> screen/attribute address
src/text.asm        ROM-free print routines (glyphs read from the font at $3D00)
src/input.asm       keyboard half-row tables + Kempston -> one flags byte
src/block.asm       milestone 3 test object: 2x2-cell attribute block
src/loader.asm      tokenised BASIC loader: CLEAR / LOAD ""CODE / RANDOMIZE USR 32768
gfx/                sprite and tile sources (empty for now)
tools/              helper scripts (headless screenshot + input test, ZX0 decompressor)
build/              output: diver.tap, diver.sna, diver.lst, diver.sym
Makefile            Linux / WSL build
build.bat           Windows build
```

Memory: code at `$8000`, stack grows down from `$FDFC`, `JP isr` at `$FDFD`,
257-byte vector table of `$FD` at `$FE00-$FF00`.

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

"DIVER ENGINE" in yellow on blue, a help line, a `FRAMES:` hex counter rising
at 50 per second, the border changing colour every 8 frames, and a red 16x16
block in the middle that moves with QAOP / 5678 / Kempston and changes colour
on each FIRE press. See `build/diver-tap-screenshot.png` and the
`build/montage-*.png` test strips.

Emulator tip: Fuse maps the PC arrow keys to the Spectrum cursor keys (CAPS +
5-8), so they work too. To test Kempston in Fuse, enable Options >
Peripherals > Kempston joystick and set Options > Joysticks > Keyboard to
Kempston (or `--kempston --joystick-keyboard-output 2`), then QAOP/SPACE drive
the joystick. Load the `.tap` for this; loading the `.sna` resets the
peripheral settings in Fuse.
