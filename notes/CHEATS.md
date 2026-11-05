# Testers' switch (spoiler)

Kept here, outside `docs/`, so it isn't on the GitHub Pages site or in
the README.

**Symbol Shift + M**, held together on the menu screen (not during
play), turns on the hearts, the double shot's bubble and the piranha
from level 1, whatever `CFG_POWER_LEVEL`, `CFG_DOUBLE_LEVEL` and
`CFG_PIRANHA_LEVEL` say. A short beep with the border flickering says it
took. It lasts until the machine is reset (the next game, and the one
after, keep it). Nothing on screen shows it.

It is `cheat_poll` in `src/atlantis/missile.asm`, called by
`menu_loop` (`menu.asm`). It sets the three bytes at `power_levels` to
1. Builds without power-ups (the soak, the measurements) don't have it.
