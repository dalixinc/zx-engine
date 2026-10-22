# DIVER ENGINE

A Z80 machine code game engine for the 48K ZX Spectrum, for an underwater
side-scrolling shooter. This is milestones 1 and 2: it loads from tape, clears
the screen, prints a title, runs a 50 Hz IM2 interrupt with a frame counter,
and cycles the border colour every 8 frames.

## Layout

```
src/main.asm        entry point, main loop, output (.tap/.sna) directives
src/constants.asm   memory map, colours, tuning constants
src/interrupts.asm  IM2 vector table at $FE00, JP at $FDFD, frame ISR, wait_frame
src/screen.asm      cls, border, character-cell -> screen/attribute address
src/text.asm        ROM-free print routines (glyphs read from the font at $3D00)
src/loader.asm      tokenised BASIC loader: CLEAR / LOAD ""CODE / RANDOMIZE USR 32768
gfx/                sprite and tile sources (empty for now)
tools/              helper scripts (headless screenshot, ZX0 decompressor)
build/              output: diver.tap, diver.sna, diver.lst, diver.sym
Makefile            Linux / WSL build
build.bat           Windows build
```

Memory: code at `$8000`, stack grows down from `$FDFC`, `JP isr` at `$FDFD`,
257-byte vector table of `$FD` at `$FE00-$FF00`.

## Build on Linux

Requirements: `sjasmplus` 1.24+, optionally `fuse-emulator-sdl` and `zx0`.

```
# sjasmplus from source
curl -LO https://github.com/z00m128/sjasmplus/releases/download/v1.24.0/sjasmplus-1.24.0-src.tar.xz
tar xf sjasmplus-1.24.0-src.tar.xz && cd sjasmplus-1.24.0 && make && sudo make install

sudo apt install fuse-emulator-sdl      # Debian ships without the Sinclair ROMs;
                                        # copy 48.rom into /usr/share/spectrum-roms/

make          # -> build/diver.tap (+ diver.sna snapshot)
make run      # open in Fuse
make shot     # headless screenshot (needs xvfb, xdotool, imagemagick)
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
   - SpecEmu: http://www.specemu.zxe.io/
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

Black screen, "DIVER ENGINE" in yellow on blue, a subtitle, a `FRAMES:` hex
counter rising at 50 per second, and the border changing colour every 8 frames.
See `build/diver-tap-screenshot.png`.
