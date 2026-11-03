# The diver's death

Branch `claudelet/dev`. A hit used to cost a life and put the diver
back at the left edge on the same step. Now the game stops while he
dies (`src/atlantis/death.asm`).

## What you see

| 1/50 s after the hit | |
|---|---|
| 0 | Everything stops: the seabed, the bomb, the fish, the missile, the torpedo. A burst already going (the bomb's or the fish's) plays out. The border flashes red as before. A long, deep rumble starts. |
| 6 | His cells flash through red, yellow, magenta and cyan inks, 4/50 s each. |
| 31 | His colours come back, he is taken off the screen, and a burst goes off where he was. |
| 90 | The life is taken. With lives left he comes back one column in from the left edge (at the starting depth if he had sunk onto the black ground) and the game goes on. With none, the knell and GAME OVER, as before. |

`CFG_DEATH_FLASH` (25) and `CFG_DEATH_TIME` (90) are in `config.asm`.
The rumble is `CFG_DIVER_SND_*`: 85 bursts, falling from 255 lines and
density 128, pitch 6.

The first six steps let the colours that were already changing finish:
a bomb that hit him clears its cells on the next step, and a fish he
touched flashes its own for four (`FISH_FLASHES`). Saving his cells at
the hit kept the bomb's black ink, and the restore painted it back on
him.

## How

- `diver_hurt` no longer takes the life. It returns carry, and the step
  stops at the first hit: `main_loop` jumps to `death_hit` (at 50) and
  `idle_tick` to `death_begin` (at 25), instead of `game_over`.
- `death_freeze` points `step_jp_shift` at `step_skip` and
  `step_jp_move` at `death_step`, with `step_ticks` 1 and the sound gate
  open. Each frozen step only restores, draws and copies the seabed,
  like the 25 picture frame, so it is never late, and a death runs at
  50 at either speed. `rate_apply` freezes again if Symbol Shift + F is
  pressed during one. `death_end` and `game_reset` call `death_reset`,
  which puts the speed's own jumps back.
- He is taken off by writing `JP diver_draw_none` over the first
  instruction of `diver_draw_fast`. The restore before it takes him off
  the screen with the other sprites. `diver_draw_none` then clears his
  photograph, so later restores don't paint him over the burst.
- The LEVEL banner's clock stops during a death and goes on afterwards
  for the time it had left. Level 2's message waits for the banner, so
  it never opens over a death.
- It is all in the cold block (442 bytes). The hot code is 24 bytes
  shorter.

## Checks

- Ground deaths at 50 and 25, recorded from Fuse: the flash, the burst,
  the hearts, the respawn. The two speeds look and sound the same.
- The rumble: bursts of 3-4 ms a frame while he is still drawn, then
  5-7 ms, fading out over 1.4-1.7 s.
- Three deaths: the knell, then the menu with GAME OVER.
- Symbol Shift + P after he had been taken off, then a new game: he is
  drawn and everything moves.
- A scratch build that reaches level 2 on the step of the hit: the
  banner stays up through the death, then the level 2 message, then
  play.
- Score and play: the SHOT_FRAME build (no input, so bombs kill him)
  at loop 1380 is pixel-identical to the old build at loop 1200 (two
  deaths, 90 loops each).
- MEASURE at 50 and 25 (MEAS_DOWN, MEAS_FIRE, MEAS_SPIN, MEAS_BOOM,
  MEAS_MISSILE) and SHOT_FRAME 300: pixel-identical to before. Soak at
  50 and 25: green, OK. Engine Demo 1: byte-identical.
