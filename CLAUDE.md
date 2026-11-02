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

`make web` (or `build.bat web`) copies `build/atlantis.sna` and `.tap` into `docs/play/`, the GitHub Pages version (JSSpeccy 3, `docs/WEB.md`). Those two copies are committed on purpose; `build/` is not.

`-B` forces a full rebuild, which also regenerates `gfx/*.asm` (needs Python 3). `make soak` only assembles `build/atlantis-soak.sna`. To see its result, run it with `fuse -g 3x --machine 48 build/atlantis-soak.sna`.

Windows: `build.bat` / `build.bat run` / `build.bat demo`.

The tapes (`build/atlantis.tap`, `build/diver.tap`) are **not tracked** any more: `make` builds them, and `.gitignore` ignores them. `build/*.png` is still committed. To check that Engine Demo 1 is unchanged, compare a fresh `make demo` with the last committed copy: `git show fc5fe34^:build/diver.tap | cmp - build/diver.tap`. `SAVETAP` paths are relative to the cwd.

Graphics: `gfx/wheel_spin.asm` is the exception: `tools/gfx2raw.py` writes every other frame of `gfx/wheel-full.txt` unshifted, and the game shifts it at start-up. Otherwise `gfx/*.txt` (ASCII art: `#` ink, `-` paper, `.` transparent; `mirror off` skips the left-facing copy) is turned into `gfx/*.asm` by `tools/gfx2asm.py`. The generated `.asm` files are committed so Windows builds don't need Python. `make` regenerates them when the `.txt` changes. The tape's loading screen, `gfx/loading.scr` (6912 bytes, committed), is drawn from the same art by `tools/mkloadscreen.py`, which paints at full colour, cuts each 8x8 cell to two colours, and prints any cell that clashed.

## Testing: there is no unit-test framework

Verification means assembling a variant build with `-D` flags and running it in Fuse. Each variant writes its own `.sna` (see the bottom of `src/atlantis/main.asm`), and the tape is only written when none of these flags is set:

| Flag | What it does |
|------|--------------|
| `-DSOAK` | `src/atlantis/soak.asm` plays a scripted dive and checks background restore, colours and the terrain clamp after every frame. **Green border + "OK"** = pass. Red border + reason number + frame = first failure (reasons are listed in soak.asm's header). It takes about 2 minutes at 50 and 3 at 25. |
| `-DTIMING_BARS` | Border colour per phase. The legend is in main.asm's header. |
| `-DMEASURE` | Runs warmup + 512 steps, then halts and prints hex on row 2: min spare scanlines, late-step count, max spare, interrupts. Row 3 is the same for the 25 fps idle frame (ending in loops). Options: `-DMEAS_DOWN` (hold Down, the heavy seabed case), `-DMEAS_FIRE` (tap fire every other step, so a torpedo is nearly always running), `MEAS_RATE`, `MEAS_WARMUP`, `MEAS_WINDOW`. Judge the speed by interrupts: 1 per step at 50, 2 at 25. At 50 the heavy case shows a handful of late steps that overrun by a few T-states and catch up; that count moves by 1-2 with schedule alignment alone. |
| `-DSLACK_LINES=n` | Adds an n-scanline NOP sled. Green/red border shows whether the frame still fits. Optional `SLACK_WARMUP`. |
| `-DSHOT_FRAME=n` | Halts after loop n for a deterministic screenshot. |
| `-DNO_WHEEL` | Leaves the wheel bomb out, for measurement. |
| `-DMEAS_BOOM` | With `-DMEASURE`: an explosion over the diver all the time (a new one as soon as the last ends), with its sound. The worst case for the explosion's cost. |
| `-DMEAS_SPIN` | With `-DMEASURE`: every bomb is the spinning wheel (level 3's bomb), whose pictures are read from contended RAM at `$7000`. Compare with the same build without it. |
| `-DMEAS_MISSILE` | With `-DMEASURE`: a silo missile armed or flying all the time (no gap). A missile that reaches the measuring diver passes through him. |
| `-DNO_SOUND` | Leaves the beeper out of any build, so timing can be compared with and without sound. |

Example: `sjasmplus --nologo --fullpath=off -DMEASURE -DMEAS_DOWN src/atlantis/main.asm`, then `fuse-sdl --machine 48 build/atlantis-measure.sna`.

After a change that touches the frame loop, sprites, scroll, stats or input, run the soak and check spare scanlines in the heavy case (diver on the seabed, wheel on screen). Commit messages here report those numbers.

## Architecture

**The frame budget is the main constraint.** The heavy seabed frame has only a couple of scanlines to spare at 50 fps, so a new instruction in the per-frame path can make the frame miss the interrupt. Comments throughout record T-state counts and measured spare lines. Keep those numbers up to date, and prefer unrolled code in hot paths, as the existing code does.

**Main loop order** (`src/atlantis/main.asm`, `main_loop`). The order follows the raster beam:
1. `chords_poll` (Symbol Shift + P/F/S, edge-triggered via `rising_edge`), then `read_input`, which gives one `000FUDLR` byte in `input_state`
2. Restore sprites in **reverse** draw order: diver, wheel, fish
3. `stats_prepare`. Draw sprites that are still above the seabed (row 21) *before* the seabed copy
4. `scroll_blit` copies the off-screen buffers to rows 21-23 and stamps the silo towers and domes. `draw_late` then draws the sprites that overlap the seabed, so they photograph this frame's ground
5. Rotate the ground buffer (1px per 1/50 s) and the slow sand/weed buffer (every other 1/50 s, tracked by `slow_phase`)
6. Stats overlay, then `update_diver` / `update_fish` / `update_wheel`
7. `spare_count` (`src/atlantis/rate.asm`) busy-waits in an exact 224-T-state loop until the interrupt. **This wait is the vsync**, and it also measures spare scanlines

**50/25 fps**: every speed is written per 1/50 s. `step_ticks` is 1 or 2. At 25 each step is two television frames: the picture frame only restores, draws and copies the seabed, and `idle_tick` (the next frame) shifts the ground twice and the slow buffer once, then runs the movement twice on the one-pixel paths. `rate_apply` patches the two jumps in `main_loop` (`step_jp_shift`, `step_jp_move`) that skip the shifts and the moves on the picture frame. The wheel applies `step_ticks` internally, so don't call it twice.

**Missiles** (`missile.asm`): one at a time, armed after a random gap in a silo on screen whose missile will leave within `CFG_MISSILE_RANGE` of the diver (`msl_near`), then straight up. It leaves only at a ground shift that puts it in one byte, so in flight it is one byte a row. Up in the water it is the first sprite drawn after the explosion and the last restored; in the hatch it is the first late sprite. `msl_vn` records which, like `torp_vn`.

**Score and row 1** (`score.asm`): BCD score (3 bytes, low first), levels from `CFG_LEVELS` (target, missile gap, bomb haste, bomb kind: the pulsar or, from level 3, the spinning wheel, switched per bomb by `wheel_type`; level 1 must stay the old game). Level codes: `codes.asm`, high score. Row 1 holds the score line and the hearts. It is drawn by `hud_draw` straight after the restores, when no sprite is on screen, and only when a bit of `hud_dirty` is set, so sprites photograph it like water. Row 0 stays the debug line's. The "LEVEL n" banner is attribute cells only (rows 7-11), so no sprite photograph is involved.

**Hits and sound**: a bomb, a fish, a missile, or sinking onto the black (`clamp_to_terrain` sets `diver_touch` under `IFDEF ATLANTIS`) all go through `diver_hurt` and an explosion (`boom.asm`). A MEASURE build only clears `diver_touch`, so `MEAS_DOWN` can sit on the seabed. The explosion is the bottom layer: `boom_hook` (the `call stats_prepare` after the restores) is patched to `boom_step` while one is up. Sound (`sound.asm`) plays only inside `spare_count`'s wait for the interrupt, one scanline per pass, so it cannot make a frame late; at 25 only the idle frame's wait plays it (`snd_gate`). Each sound is a six-byte `SND_DEF` (bursts, length, density, pitch); a new one replaces the last. A tune (`snd_tune_start`, the level jingle) swaps the 7-byte noise step in `snd_tick` for an equal-time tone step (`snd_op_tone`). The game-over knell (`snd_knell`) is the one blocking sound.

**Sprites**: masked, pre-shifted copies (8 shifts per frame), so drawing involves no run-time bit shifting. Each sprite has a background record (`BG_*` offsets in `src/sprite.asm`) addressed through IY. Save, draw, then restore next frame. `fastsprite.asm` is Atlantis's faster walker, which also clips at the left and right edges. The ISR only preserves AF and HL, and the fast walker relies on that.

**Memory map** (`src/constants.asm`, `src/atlantis/layout.asm`; enforced by `ASSERT`s at the end of main.asm):
- `$6000` the soak's own code and variables, soak build only (contended RAM; it checks pictures, not time)
- `$7000` the spinning wheel's shifted pictures (`$7000-$7E3F`), built at start-up by `wspin_build` from `gfx/wheel_spin.asm` (contended, but measured to cost nothing at 50; see `docs/WHEEL-BOMB.md`)
- `$8000` code, up to `code_end`, which must be ≤ `$C000`
- `$C000` data: graphics, tables and `data.asm`, loaded as a second tape block
- `$F000` scroll buffers. These are built at run time and must be page-aligned, because the rotate uses `DEC L`
- `$FA00` pixel-row address table (built at start-up)
- the stack grows down from `$FDFC`; `$FDFD` holds `JP isr`; `$FE00` is the 257-byte IM2 vector table of `$FD`

The ROM font at `$3D00` is read directly, and no ROM routines are called.

**Tuning knobs** are in `src/atlantis/config.asm`. That file is numbers only. Several values are pinned by `ASSERT`s, because the soak's frame numbers depend on them.

**Seabed layout**: row 21 is weed and row 22 is sand (together the slow 16px buffer); row 23 is ground (the fast 8px buffer). A silo is two tile columns (`TILE_SILO`, `TILE_SILO_R`), 16 wide and 24 tall: its base lives in the ground buffer, and its tower (row 22) and dome (row 21) are drawn every frame by code that `src/atlantis/silo.asm` builds at assembly time from the art there, one straight run per shift. The dome's cells are painted the weed's green (`silo_cells` in scroll.asm), so nothing clashes. On the frame that does not copy the weed, the domes are wiped by copying their bytes back from the slow buffer (`silo_unstamp`). The diver is clamped one pixel above the black ground (`clamp_to_terrain` in `src/diver.asm`).

## Docs

`docs/SPRITES.md` (screen layout, masking, pre-shifting), `docs/SCROLLING.md` (demo seabed, then Atlantis, with timing measurements), `docs/ENGINE-DEEP-DIVE-V1.md` (long walkthrough, describes tag `doc-v1`). When the README's memory figures and a build disagree, trust the `DISPLAY` output of the build (`atlantis code_end`, `data_end`), and update the README.

## Style

The comments are plain, short English sentences that explain *why*, with cycle counts where timing matters. Each routine's header lists its inputs, outputs and the registers it corrupts (`Corrupts: AF, BC, ...`). Keep that convention. Commit subjects are one plain sentence ending in a period.
