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

## The nuke

A third special bomb, kept out of `docs/` and the README. Since
2026-11-08 it is a real power-up: from level 12 in Atlantis, from
level 6 in Trigon (`CFG_NUKE_LEVEL`); before that, only the testers' switch brought it. Touch its
starburst to carry it and press B, as for the others:
the bomb and the fish go up as if shot, and a silo's missile is taken
away, each for `CFG_PTS_NUKE` (50) points, shown as for the other two.
The testers' switch still brings it from level 1. Set `CFG_NUKE_LEVEL`
to 0 to leave its code and its picture out of a game's build. Its share
of the roll is `CFG_NUKE_ODDS` (8 in 256).

## Straight to the city interlude

With the testers' switch on (Symbol Shift + M on the menu), start a game
with the code of the last Atlantis level, `CFG_INTERLUDE_LEVEL` (level
20: SDPCET, see LEVEL-CODES-LIST.md). Its target is then the score it
starts with, so the first point scored finishes the level and the city
comes up. It is in `score_reset` (`score.asm`), under `CITY_SHOW` and
`POWERUPS`.

**Just the picture, from the menu:** option 3, then **SUNKEN**. The
city shows (with its chime) as it would after level 20, and a key, or
five seconds, brings the menu back; no game is started. It has an N,
which no level's code can have, so it never clashes with one. It is
`il_menu_code` in `src/atlantis/interlude.asm`, called by `menu_code`.


## Trigon

The testers' switch (Symbol Shift + M on the menu) works in Trigon as
in Atlantis. Trigon's menu wants a code before anything starts: the
Trigon code (KRAKEN, from the Atlantis ending) for level 1, or a Trigon
level code (LEVEL-CODES-LIST.md) for a later level.

In Trigon the testers' switch also makes the diver unhurt: bombs,
the fish, missiles and the black ground cost no life (a bomb that
touches him still blows up), so the levels can be played through.
`CFG_GOD_MODE` in `src/trigon/config.asm`: 0 leaves it out of the
build altogether (it is in `diver_hurt`, `hit.asm`).

The testers' switch also gives the Lance laser from level 1 (it is
Trigon's from `CFG_LANCE_LEVEL`, 4), with its picture on the score line
at once and no level 4 message.
