# Testers' switch (spoiler)

Kept here, outside `docs/`, so it isn't on the GitHub Pages site or in
the README.

**Symbol Shift + M**, held together on the menu screen (not during
play), turns on every power-up and the piranha from level 1: the
hearts, the double shot's bubble, the suction and shove bombs, the nuke
(if it is built in) and the piranha, whatever `CFG_POWER_LEVEL`,
`CFG_DOUBLE_LEVEL`, `CFG_SUCTION_LEVEL`, `CFG_SHOVE_LEVEL`,
`CFG_NUKE_LEVEL` and `CFG_PIRANHA_LEVEL` say. A short beep with the border flickering says it
took. It lasts until the machine is reset (the next game, and the one
after, keep it). Nothing on screen shows it.

It is `cheat_poll` in `src/atlantis/missile.asm` (in the cold block,
since only the menu calls it), called by `menu_loop` (`menu.asm`). It
sets every first level in `power_tab` to 1. Builds without power-ups
(the soak, the measurements) don't have it.

## The nuke (testing only)

A third special bomb, kept out of `docs/` and the README. Touch its
starburst to carry it and press B, as for the others:
the bomb and the fish go up as if shot, with no points, and a silo's
missile is taken away. `CFG_NUKE_LEVEL` is 99, so only the testers'
switch brings it in play; set it to 0 to leave its code and its picture
out of the build (for Atlantis), or to a real level to play with it
(for Trigon later). Its share of the roll is `CFG_NUKE_ODDS`.
