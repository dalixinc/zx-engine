# 25 fps that keeps time, and clean hits

Branch `claudelet/dev`, commit `1e22ee4`. It was not pushed or merged.

## The task

1. **Bug:** when the diver is hit, by a bomb or a fish, he jumps back
   to x = 8. Sometimes a piece of him, or of the explosion, was left on
   the screen.
2. **Main task:** make 25 fps run properly. Each step should be one
   frame that draws the picture and one frame that does no drawing.
   There should be few or no late picture frames, the same real game
   speed as 50 fps, no flicker, and seaweed that stays on the sand.
   50 fps must be no worse than before.
3. **Checks:** `make`, `make timing` and `make soak` must assemble
   with no errors, and the soak must end on a green border with OK at
   both 50 and 25.

---

## 1. Pieces left behind after a hit

### What was wrong

Every sprite saves a picture of the screen underneath it before it is
drawn. On the next frame that saved picture is copied back, which
erases the sprite. These copies must go back in the **reverse order**
of the draws. If they don't, one sprite's saved picture can hold
another sprite, and copying it back paints that other sprite again
in its old place.

There were two places that broke this order.

- **The explosion** (`boom.asm`) was drawn from inside `wheel_draw`'s
  "no bomb" path, in among the sprites. When the diver was drawn first,
  the explosion's saved picture held part of him. The next frame erased
  the diver, and then the explosion copied back its saved picture,
  diver piece included. Because a hit had just moved him to x = 8, that
  piece was left floating where he had been.
  `boom_arm` also copied the old explosion's saved picture back in the
  movement phase, while sprites were still drawn on the screen. That
  left bits of explosion in their saved pictures.
- **The flashing fish** stopped being drawn while it flashed. At the
  end it copied back its saved picture, taken several steps earlier.
  The fish is drawn after the diver, so that saved picture held the
  diver as he was when the fish touched him.

### What changed

- **The explosion is now the bottom layer.** While an explosion is
  showing, the `call stats_prepare` straight after the sprite erases
  (`boom_hook` in `main.asm`) is patched to call `boom_step` instead.
  At that point no sprite is on the screen. So the explosion's saved
  picture is only background, the sprites drawn after it save the
  explosion in their own pictures, and the reverse-order erases put
  everything back correctly. When no explosion is showing, this costs
  nothing.
- **The explosion erases itself from where it was drawn.** It now
  remembers the drawn position (`boom_dcol`, `boom_dy`). A new
  explosion started by `boom_arm` doesn't copy anything back
  straight away. The next `boom_step` erases the old one and then
  draws the new one.
- **The explosion stays between rows 2 and 20.** Row 0 holds the score
  digits and row 1 the hearts, and both are redrawn underneath it. The
  seabed rows are recopied every frame, so an explosion there would
  have copied back an old seabed.
- **The fish stays still and keeps being drawn while it flashes**
  (`fish_flash_draw`). When the flashing ends, the normal erase removes
  it and it isn't drawn again. Nothing is copied back out of turn.
- `wheel_draw` no longer calls the explosion.

### Checked

I played up to a bomb hit at 50 and at 25 fps and took screenshots
before and after. The water where he was hit is clean, the explosion
shows, and he restarts at x = 8. That test didn't include a fish hit,
so the fish change hasn't been seen in play yet.

---

## 2. 25 fps

### What was wrong

- **The picture frame did a full 50 fps frame's work.** That meant
  erasing and drawing, copying the seabed, shifting the ground,
  sometimes shifting the slow buffer, and one round of movement.
  The seaweed fix (`6f151bd`) made it worse: it made every 25 fps
  picture copy the weed as well as the sand, which is the most
  expensive copy. The heavy frame couldn't fit all of that. It ran
  late on 453 of 512 steps, and each late step waited an extra
  interrupt, so the game ran at about 17 fps.
- **The idle frame's "1 spare line" was a display bug.** In
  `spare_count`, when more than 255 lines were left, the code loaded
  `L` with 255, but the value stored was `A`, which still held `H`
  (1). A nearly empty idle frame therefore showed as 1 spare line, or
  224 T-states.

### What changed

**The picture frame only draws.** At 25 fps it restores, draws, copies
the seabed (`scroll_blit`, `draw_late`), sets the border and refreshes
the digits. Then it stops.

**The idle frame (`idle_tick`) does the step's other work:**

- shifts the ground twice (1 px per 1/50 s, so 2 px per step)
- shifts the slow weed and sand buffer once (1 px per step)
- sets `slow_phase = 1`, so the next picture copies weed and sand
  together. This keeps the seaweed on the sand.
- runs the movement twice (`idle_move`): the diver, the fish, the
  torpedo, the fire button, the wheel bomb, torpedo hits and hit
  checks. Each run uses the fast one-pixel paths (`step_ticks` = 1).

This gives the same results as before. Each step still moves
everything by 2 × 1/50 s, just in a different frame.

**50 fps keeps its old order.** There are two patched jumps in
`main_loop`:

```
step_jp_shift:  jp step_shift     ; step_skip at 25
...
step_jp_move:   jp step_move      ; step_moved at 25
```

`rate_apply` sets both jumps whenever the speed changes, at the menu,
with Symbol Shift + F, and at start-up. At 50 fps they cost 20
T-states in all. That replaced the old `step_ticks` / `step_saved`
juggling, which cost about 70.

An earlier version moved the border and the digits ahead of the shifts
to save a test. It was dropped because it changed where in the frame
screen and port accesses happen, and those accesses run more slowly
while the screen is being drawn (contention).

**`scroll_blit` no longer tests `step_ticks`.** `slow_phase` already
says whether the weed must be copied, at both speeds. That saves
27 T-states on every 50 fps frame. Switching speed during play still
works, because the phase means the same thing at both rates.

**`spare_count`:** `ld l,255` became `ld a,255`, so a frame with more
than 255 spare lines now shows the 99 cap.

`step_saved` is gone. `idle_tick` sets `step_ticks` back to 2 itself.

---

## Results

`-DMEASURE` builds, 512 measured steps after a 40-step warmup. Each
cell shows late steps / interrupts / minimum spare lines.

| Case | main (before) | claudelet/dev (after) |
|---|---|---|
| 50 fps, diver on the seabed (`MEAS_DOWN`) | 5 / 512 / 0 | 6 / 512 / 0 |
| 50 fps, seabed + firing (`MEAS_FIRE`) | 23 / 512 / 0 | 22 / 512 / 0 |
| 50 fps, open water | 3 / 512 / 0 | 0 / 512 / 1 |
| 25 fps, diver on the seabed | **453** / 1477 / 0 | **0** / 1024 / 35 |
| 25 fps, seabed + firing | 456 / 1480 / 0 | 0 / 1024 / 35 |
| 25 fps, open water | 454 / 1478 / 0 | 0 / 1024 / 39 |

- **25 fps:** no picture frame is late, and every step takes exactly 2
  interrupts (1024 for 512 steps), so the game runs at the same real
  speed as 50. The idle frame shows the 99 cap: it has far more time
  than it needs.
- **50 fps:** every run took exactly 1 interrupt per step, so no frame
  is dropped. The few "late" steps overrun by a few T-states and catch
  up on the next frame. That count is noise: padding the start of the
  frame with 4 to 52 T-states of NOPs, and changing nothing else, gave
  6, 6, 6, 6, 4, 6. Main's 5 sits inside that range.

## Checks

- `make`, `make timing` and `make soak` assemble with 0 errors and
  0 warnings.
- The soak ends on a **green border with OK** at 50 and at 25 (built
  with `-DSOAK -DCFG_START_RATE=25`).
- Engine Demo 1 is byte-identical:
  `git show fc5fe34^:build/diver.tap | cmp - build/diver.tap`.
- No `build/*.tap` is committed.

## Files

| File | Change |
|---|---|
| `src/atlantis/main.asm` | `boom_hook`; picture/idle split; `step_jp_shift` / `step_jp_move`; new `idle_tick` and `idle_move` |
| `src/atlantis/rate.asm` | `rate_apply` sets the two jumps; `spare_count` cap fix; `step_saved` removed |
| `src/atlantis/scroll.asm` | `scroll_blit` uses `slow_phase` alone |
| `src/atlantis/boom.asm` | `boom_step`; drawn position kept; rows 2-20 limit; fish flash redraws the fish |
| `src/atlantis/wheel.asm` | `wheel_draw` no longer calls the explosion |
| `CLAUDE.md` | 25 fps notes and how to read the MEASURE output |
