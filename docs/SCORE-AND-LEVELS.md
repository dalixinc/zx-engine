# Scoring and level targets

Branch `claudelet/dev`. Quartus's brief, item by item.

## Where the score goes: row 1, beside the hearts

The brief offered two places: share row 0 with the stat line while it's
hidden, or take row 0 and move the stat line down. I've used a third:
**row 1, beside the hearts.**

```
row 0   (empty in play; the debug stat line when Symbol Shift + S is on)
row 1   SCORE 000000  LEVEL 1                 ♥♥♥
```

Row 1 is cleaner because of how the two rows are drawn:

- **Row 0 is shared with the debug line**, which rewrites its digits
  while sprites cross it. That's why stats.asm has its machinery for
  wiping the columns under a sprite and drawing them again.
- **Row 1 is only drawn at one point in the frame,** straight after the
  sprite restores, when no sprite is on screen. The hearts have always
  worked this way. A sprite that crosses the line photographs the words
  like water and puts them back, so the score needs none of row 0's
  machinery.
- **Nothing else touches row 1.** The explosion and the missiles stop
  at row 2.
- **No clash.** The cells are the water's own white on blue. When the
  bomb crosses the line, the letters under it turn its black for a
  moment, as the hearts always have.

## 1. Score

| Shot | Points on levels 1 to 3 |
|---|---|
| fish | 1 |
| bomb | 2 |
| missile | 10 |

Since the level 2 follow-up these are the last three columns of each
`CFG_LEVELS` row, so a later level can score differently. They were
`CFG_PTS_FISH`, `CFG_PTS_BOMB` and `CFG_PTS_MISSILE`.

Points are only scored from the torpedo, in `torpedo_hit`, `torpedo_fish`
and `missile_shot`. A fish or bomb that runs into the diver goes through
the hit paths, which never score.

## 2. BCD

The score is three bytes of BCD (six digits, low byte first), added with
`ADD` / `ADC` and `DAA`.

- **Drawing** is a nibble per digit, with no division.
- **Comparing** with the level target or the high score goes from the
  top byte down, because BCD sorts the same way as binary.
- **At the top** the score stops at 999999.

## 3. The line on row 1

- **Font:** whole character cells, in the ROM font the menu already
  uses.
- **Only on a change:** `hud_dirty` has one bit each for the hearts, the
  text and the banner's clock. `main_loop` tests that byte once a step,
  in the place where it used to test the hearts' flag, so a step where
  nothing changed costs the same as before.
- **Only the changed cells:** a mirror of the 22 cells means a shot
  redraws one or two digits.
- **Level numbers** show one digit up to 9 and two after that, up to 99.

## 4. Levels

### The table

`CFG_LEVELS` in `config.asm` has one row per level:

```
;          points  gap min  gap max  haste  ...
LEVEL_ROW  n1,     CFG_MISSILE_GAP_MIN, CFG_MISSILE_GAP_MAX, 0, ...
LEVEL_ROW  n2,     70,      185,     24,    ...
LEVEL_ROW  n3,     65,      170,     48,    ...
...
```

(Later briefs added columns: the bomb's kind, how the level looks, and
what a shot scores. `docs/LEVEL-2.md` has the whole row.)

- **Points** are what that level needs, added to the last target, so
  each level is longer than the one before. The numbers are in
  `config.asm` and not repeated here.
- **Gap min, gap max** are that level's missile wait.
- **Haste** makes the bombs slightly faster. It is added to a fraction
  every 1/50 second, and each carry is one more pixel. 64 is a quarter
  faster, 128 half again. That is 2 bytes of state and about 40
  T-states a step.
- **After the last row**, the last row repeats.
- **Level 1 is the old game exactly.** An `ASSERT` holds it there,
  because the soak's frame numbers depend on it.

When the score reaches the target:

- the level goes up;
- the next row's target, missile wait and bomb speed take over;
- the banner goes up and the jingle plays.

A missile worth more than a small level can pass two targets at once, so
the check repeats until the score is below the target.

### The banner

**"LEVEL 2" in big block letters**, three cells wide and five high, in
yellow cells on the blue sea, across rows 7–11 for `CFG_BANNER_TIME`
(two seconds).

- **Drawn in attributes, not pixels.** A sprite's photograph only holds
  pixels, so no save or restore can disturb the banner, and the banner
  can't leave pieces of a sprite behind.
- **Sprites crossing it** show in blue on the yellow for a moment.
- **A bomb flying through it** puts its cells back to water as it
  leaves them, so the banner can be left with gaps. That's cosmetic and
  only lasts the two seconds.
- **The bomb repaints its own colour** after the banner goes up or
  comes down.
- **Cost:** painting it is about 120 attribute writes, once at the
  start and once at the end. That one step can run late at 50.

### The jingle

**G4, C5, E5, G5, a breath of E5, then G5 held**, about a second long.
The sound engine gained a tone mode for it:

- **Same loop, different step.** `snd_tick`'s seven-byte noise step
  (the LFSR, 27 T-states) is swapped for a seven-byte, 27 T-state step
  that flips the value between 0 and $FF. The speaker then makes a
  square wave, a pass is still exactly one scanline, and it still
  stops at the interrupt, so the jingle can't make a frame late.
- **Notes** are a half-period in scanlines and a length in 1/50 s
  (`snd_tune_start`). The tempo is the same at 50 and 25.
- **Recorded** with the SDL disk driver (see the silos write-up): it
  lasts 0.94 s at 50 and 0.97 s at 25. A Goertzel filter on each
  0.1 s finds G4, C5, E5 then G5 in that order at both speeds. It is
  cleaner at 25, where the idle frame has more spare time to sound in.
- **A noise sound started over a tune ends it**, so a shot cuts the
  jingle short.
- **Not heard by me.** The clips are in the scratchpad,
  `m/wav/jingle-50.wav` and `jingle-25.wav`.

## 5. High score

- `hiscore` is kept in memory while the machine is on.
- At game over, `score_game_over` copies the score in if it is higher.
- The menu always shows `HIGH 000000` on row 19.

## 6. Game over

The menu shows GAME OVER (as now), then `SCORE` with the final score on
row 17, then the high score.

**Tested** in a scratch build: three lives, fire tapped automatically, and the
diver held at the fish's depth. The score went 10, 20, 30, 42, 52, 62.
After the third life, the menu read GAME OVER, SCORE 000062 and
HIGH 000062. A second scratch build, with level 1 needing only 4
points, showed the line counting, then "LEVEL 2" and "LEVEL 3" banners
over the water, and the level on row 1 going up with them.

## 7. Timing, soak and memory

The same heaviest case as before, `MEAS_DOWN MEAS_FIRE MEAS_BOOM
MEAS_MISSILE`, 512 steps. `MEAS_FIRE` shoots bombs and fish, so this run
also scores and redraws digits.

| Case | before | now |
|---|---|---|
| 50: heaviest | 9 late / 512 / min 0 | 10 late / 512 / min 0 |
| 50: heaviest, `NO_SOUND` | 7 late / 512 / min 0 | 9 late / 512 / min 0 |
| 50: seabed only | 0 late / 512 / min 8 | 0 late / 512 / min 9 |
| **25: heaviest** | 0 late / 1024 / min 35 | **0 late / 1024 / min 34** |

- **25:** no new late frames, and every step is still 2 interrupts.
- **50:** no frame dropped. The late count moves by 1 or 2, which is
  the usual schedule noise.

**Checks:**

- The soak is green with OK at 50 and 25.
- Its row-1 check now compares the score line, cell by cell, with the
  font, as well as the hearts.
- Engine Demo 1 is byte-identical.
- No tapes are committed.

**Memory:**

- The code ends at `$BB2D`, so the code block has 1,235 bytes left. This
  feature used about 1 KB of the 2.2 KB that was free.
- The data ends at `$E808`. The level table, the banner font and the
  line's words are up there.
- The soak build's code ends at `$BB73`, and its checks are at
  `$6000-$67C6`.

## Files

| File | Change |
|---|---|
| `src/atlantis/score.asm` | new: BCD score, levels, row-1 line, banner, high score |
| `src/atlantis/config.asm` | `CFG_PTS_*` (now columns of `CFG_LEVELS`), `CFG_LEVELS`, `CFG_BANNER_TIME` |
| `src/atlantis/data.asm` | the line's words, the banner font, `level_tab` |
| `src/atlantis/sound.asm` | tone mode (`snd_op_tone`), `snd_tune_start`, the level jingle |
| `src/atlantis/wheel.asm` | `wheel_haste`, `wheel_frac` |
| `src/atlantis/missile.asm` | the gap comes from the level; 10 points a shot |
| `src/atlantis/torpedo.asm`, `boom.asm` | points for a bomb and a fish shot |
| `src/atlantis/hit.asm` | the hearts' flag is a bit of `hud_dirty` |
| `src/atlantis/menu.asm` | `score_reset`, high score at game over, SCORE and HIGH on the menu |
| `src/atlantis/main.asm` | `hud_draw` in the hearts' place; `score.asm` |
| `src/atlantis/soak.asm` | row 1 check includes the score line |
| `src/atlantis/layout.asm` | `BANNER_ATTR` |
| `Makefile`, `README.md`, `CLAUDE.md` | the new file and the line |
