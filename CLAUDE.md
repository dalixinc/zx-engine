# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Atlantis**, a Z80 assembly game for the 48K ZX Spectrum (sjasmplus 1.24+). It sits on top of a small engine whose earlier parallax demo is frozen as **Engine Demo 1** (git tag `engine-demo-1`, entry `src/main.asm`, tape `build/diver.tap`).

- `src/*.asm` is shared by both programs. `src/atlantis/*.asm` is Atlantis only.
- **The Engine Demo 1 tape must stay byte-identical.** Do not change the bytes the demo assembles from shared files. Atlantis-only additions to a shared file go under `IFDEF ATLANTIS` (main.asm defines it). If not, they go in an Atlantis-only file, the way `src/atlantis/fastsprite.asm` replaces the shared sprite walker and `src/atlantis/scroll.asm` copies the demo's `blit_rows`.

## Build and run

```
make              # build/atlantis.tap + .sna + build/atlantis.lst/.sym
make run          # launch in Fuse (EMU=fuse-sdl by default; EMU=fuse for GTK; EMU="fuse -g 3x" to scale)
make demo         # Engine Demo 1 -> build/diver.tap
make timing       # build/atlantis-timing.sna: border colour bands show where frame time goes
make soak         # build/atlantis-soak.sna: scripted 1024-frame self-check (see below)
make shot         # headless screenshot (xvfb, xdotool, imagemagick)
make input-test   # headless key/Kempston test, DEMO only (reads its row-22 digits)
make sprite-test  # headless sprite test, DEMO only
```

The usual full cycle on this machine (Fuse here is the GTK build, called `fuse`):

```
make -B && make soak && make run EMU="fuse -g 3x"
```

`-B` forces a full rebuild, which also regenerates `gfx/*.asm` (needs Python 3). `make soak` only assembles `build/atlantis-soak.sna`. To see its result, run it with `fuse -g 3x --machine 48 build/atlantis-soak.sna`.

Windows: `build.bat` / `build.bat run` / `build.bat demo`.

`build/atlantis.tap`, `build/diver.tap` and `build/*.png` are **committed**. Rebuilding changes the tracked tape, and PRs here include the rebuilt `.tap`. To check a build without touching the tree, assemble a `git archive HEAD` copy somewhere else. `SAVETAP` paths are relative to the cwd.

Graphics: `gfx/*.txt` (ASCII art: `#` ink, `-` paper, `.` transparent; `mirror off` skips the left-facing copy) is turned into `gfx/*.asm` by `tools/gfx2asm.py`. The generated `.asm` files are committed so Windows builds don't need Python. `make` regenerates them when the `.txt` changes. The tape's loading screen, `gfx/loading.scr` (6912 bytes, committed), is drawn from the same art by `tools/mkloadscreen.py`, which paints at full colour, cuts each 8x8 cell to two colours, and prints any cell that clashed.

## Testing: there is no unit-test framework

Verification means assembling a variant build with `-D` flags and running it in Fuse. Each variant writes its own `.sna` (see the bottom of `src/atlantis/main.asm`), and the tape is only written when none of these flags is set:

| Flag | What it does |
|------|--------------|
| `-DSOAK` | `src/atlantis/soak.asm` plays a scripted dive and checks background restore, colours and the terrain clamp after every frame. **Green border + "OK"** = pass. Red border + reason number + frame = first failure (reasons are listed in soak.asm's header). It takes about 2 minutes. |
| `-DTIMING_BARS` | Border colour per phase. The legend is in main.asm's header. |
| `-DMEASURE` | Runs warmup + 512 steps, then halts and prints hex on row 2: min spare scanlines, late-step count, interrupts, loops. Options: `-DMEAS_DOWN` (hold Down, the heavy seabed case), `-DMEAS_FIRE` (tap fire every other step, so a torpedo is nearly always running), `MEAS_RATE`, `MEAS_WARMUP`, `MEAS_WINDOW`. At 25 fps the late count is high by design; judge it by interrupts = 2 per step. |
| `-DSLACK_LINES=n` | Adds an n-scanline NOP sled. Green/red border shows whether the frame still fits. Optional `SLACK_WARMUP`. |
| `-DSHOT_FRAME=n` | Halts after loop n for a deterministic screenshot. |
| `-DNO_WHEEL` | Leaves the wheel bomb out, for measurement. |

Example: `sjasmplus --nologo --fullpath=off -DMEASURE -DMEAS_DOWN src/atlantis/main.asm`, then `fuse-sdl --machine 48 build/atlantis-measure.sna`.

After a change that touches the frame loop, sprites, scroll, stats or input, run the soak and check spare scanlines in the heavy case (diver on the seabed, wheel on screen). Commit messages here report those numbers.

## Architecture

**The frame budget is the main constraint.** The heavy seabed frame has only a couple of scanlines to spare at 50 fps, so a new instruction in the per-frame path can make the frame miss the interrupt. Comments throughout record T-state counts and measured spare lines. Keep those numbers up to date, and prefer unrolled code in hot paths, as the existing code does.

**Main loop order** (`src/atlantis/main.asm`, `main_loop`). The order follows the raster beam:
1. `chords_poll` (Symbol Shift + P/F/S, edge-triggered via `rising_edge`), then `read_input`, which gives one `000FUDLR` byte in `input_state`
2. Restore sprites in **reverse** draw order: diver, wheel, fish
3. `stats_prepare`. Draw sprites that are still above the seabed (row 21) *before* the seabed copy
4. `scroll_blit` copies the off-screen buffers to rows 21-23 and stamps silo tops. `draw_late` then draws the sprites that overlap the seabed, so they photograph this frame's ground
5. Rotate the ground buffer (1px per 1/50 s) and the slow sand/weed buffer (every other 1/50 s, tracked by `slow_phase`)
6. Stats overlay, then `update_diver` / `update_fish` / `update_wheel`
7. `spare_count` (`src/atlantis/rate.asm`) busy-waits in an exact 224-T-state loop until the interrupt. **This wait is the vsync**, and it also measures spare scanlines

**50/25 fps**: every speed is written per 1/50 s. `step_ticks` is 1 or 2. At 25, the movement updates run twice and the loop waits one more interrupt. The wheel applies `step_ticks` internally, so don't call it twice.

**Sprites**: masked, pre-shifted copies (8 shifts per frame), so drawing involves no run-time bit shifting. Each sprite has a background record (`BG_*` offsets in `src/sprite.asm`) addressed through IY. Save, draw, then restore next frame. `fastsprite.asm` is Atlantis's faster walker, which also clips at the left and right edges. The ISR only preserves AF and HL, and the fast walker relies on that.

**Memory map** (`src/constants.asm`, `src/atlantis/layout.asm`; enforced by `ASSERT`s at the end of main.asm):
- `$8000` code, up to `code_end`, which must be ≤ `$C000`
- `$C000` data: graphics, tables and `data.asm`, loaded as a second tape block
- `$F000` scroll buffers. These are built at run time and must be page-aligned, because the rotate uses `DEC L`
- `$FA00` pixel-row address table (built at start-up)
- the stack grows down from `$FDFC`; `$FDFD` holds `JP isr`; `$FE00` is the 257-byte IM2 vector table of `$FD`

The ROM font at `$3D00` is read directly, and no ROM routines are called.

**Tuning knobs** are in `src/atlantis/config.asm`. That file is numbers only. Several values are pinned by `ASSERT`s, because the soak's frame numbers depend on them.

**Seabed layout**: row 21 is weed and row 22 is sand (together the slow 16px buffer); row 23 is ground (the fast 8px buffer). Silos are 16px tall: their bottom half lives in the ground buffer and their top half is stamped onto the sand. The colour clash this causes is intentional. The diver is clamped one pixel above the black ground (`clamp_to_terrain` in `src/diver.asm`).

## Docs

`docs/SPRITES.md` (screen layout, masking, pre-shifting), `docs/SCROLLING.md` (demo seabed, then Atlantis, with timing measurements), `docs/ENGINE-DEEP-DIVE-V1.md` (long walkthrough, describes tag `doc-v1`). When the README's memory figures and a build disagree, trust the `DISPLAY` output of the build (`atlantis code_end`, `data_end`), and update the README.

## Style

The comments are plain, short English sentences that explain *why*, with cycle counts where timing matters. Each routine's header lists its inputs, outputs and the registers it corrupts (`Corrupts: AF, BC, ...`). Keep that convention. Commit subjects are one plain sentence ending in a period.
