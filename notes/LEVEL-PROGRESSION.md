# Level progression (spoilers)

What changes level by level, from `CFG_LEVELS` and the stage settings in
`src/atlantis/config.asm`. It is kept here, outside `docs/`, because it
gives the targets. If the table in `config.asm` changes, update this.

| Level | Points to finish (total at end) | Bomb | Colour | Bomb movement | Bomb speed | Missile wait | Fish | Border | New from this level |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 200 (200) | pulsar | black | small bob | 50 px/s | 1.5–4.0 s | round, straight | cyan | — |
| 2 | 300 (500) | pulsar | yellow | wave (±16 px) | 55 px/s | 1.4–3.7 s | round, wave, a bit faster | green | **hearts**; "starts now" panel |
| 3 | 450 (950) | spinning wheel | red | wave | 59 px/s | 1.3–3.4 s | round, straight | yellow | "stay tuned" panel |
| 4 | 550 (1,500) | spinning wheel | magenta | hunts, 48 | 64 px/s | 1.2–3.1 s | round, wave, 61 px/s | white | **double-shot bubble** |
| 5 | 650 (2,150) | spinning wheel | green | wave | 69 px/s | 1.1–2.8 s | round, straight | cyan | **suction bomb** |
| 6 | 750 (2,900) | spinning wheel | cyan | hunts, 88 | 73 px/s | 1.0–2.5 s | wave, 63 px/s; **1 in 4 piranha** | green | **piranhas** |
| 7 | 850 (3,750) | spinning wheel | yellow | wave | 78 px/s | 0.9–2.2 s | straight; piranhas | yellow | **shove bomb** |
| 8 | 950 (4,700) | spinning wheel | black | hunts, 128 (max) | 83 px/s | 0.8–1.9 s | wave, 64 px/s; piranhas | white | — |
| 9 | 1,100 (5,800) | spinning wheel | red | hunts, 128 | 88 px/s | 0.7–1.6 s | wave, 66 px/s; piranhas | cyan | — |
| 10+ | 1,400 each (7,200 at the end of 10) | spinning wheel | red | hunts, 128 | 88 px/s | 0.7–1.6 s | wave, 66 px/s; piranhas | green | **homing silo missiles** |

## Notes

- **Hunt** is how hard the bomb drifts to the diver's depth: 48 is about
  9 px/s, 128 about 25 px/s (half the diver's speed).
- **Points:** a fish 1 (a piranha 2); a bomb 2 on levels 1-2 (the
  pulsar) and 3 from level 3 (the spinning wheel); a missile 10, and a
  homing missile (level 10 on) 15 (`CFG_MSL_HOME_PTS`).
- **Targets after the higher scores (Atlantis 1.0 brief, part A):** the
  bomb's extra point is worth roughly a tenth more per level (missiles
  are most of a level's points), so levels 3-8 need 50 more each (400 ->
  450 ... 900 -> 950). Level 9 lost its homing missiles, which made it
  easier, so it goes from 1,000 to 1,100. Level 10 is a row of its own:
  homing missiles at 15 put about 40% more on each missile, so 1,400.
- **Power-ups** sink at about 31 px/s, slower than the diver. A heart
  turns up about one missile turn in 8, a bubble about one in 21 (the
  double shot lasts 30 seconds), a suction bomb about one in 23 and a
  shove bomb about one in 51. Lives top out at 5.
- **Each new level** brings him back up to 3 lives if he has fewer
  (`CFG_LEVEL_LIVES`); not a death, and not a start from a level code.
- **Special bombs** are carried, one at a time (a new one replaces the
  old), shown on row 1 left of the bubble's cell, and set off with
  B. Suction, the escape, pulls the bomb and the fish down towards the
  seabed and leaves them there alive, scoring nothing. Shove throws them
  right; each blows up at the edge, or when the half second is up, and
  scores what a torpedo would. Shove blows up a silo missile at once (a
  torpedo's points); suction takes it away silently. Both stop a hunting
  bomb hunting. The nuke scores
  nothing. The nuke (testing only, `CFG_NUKE_LEVEL` 99) is in
  [CHEATS.md](CHEATS.md).
- **After level 10** its row repeats, up to 20, the last of Atlantis.
  Finishing level 20 (`CFG_INTERLUDE_LEVEL`) shows the city interlude,
  then level 21 goes on with the same row until Trigon has its own.
- **The testers' switch** (see [CHEATS.md](CHEATS.md)) brings every
  power-up (the special bombs and the nuke too) and the piranha in from
  level 1. It doesn't touch the enemy bombs or the missiles.
- **A bomb's look and movement** change with the next bomb, not in
  mid-flight, and the fish's movement with the next fish (the one
  swimming keeps its way until it is shot or bumps him). The border
  changes at once. Each level's border is one steady light colour; it
  flashes only for a death, a new level (white), a special bomb or a
  chord.

## Trigon, levels 11 to 20 (0.7.x, chunk 3)

Each bomb takes one of two movements at random (`CFG_MOVES`); the
second bomb of a pair keeps bob, wave or hunt (`TB_TABLE`). Wave h×s is
the height and speed for the wave and the zigzag; 68×½ is level 20's
full-height swing (`MV_HALF`).

| Level | Target (start) | First bomb | Wave h×s | Second bomb (pairs /256) | Haste | Missile gap | Belt |
|---|---|---|---|---|---|---|---|
| 11 | 1,500 (8,450) | zigzag or wave | 24×1 | wave (160) | 196 | 30–75 | blue |
| 12 | 1,600 (9,950) | stop-start or hunt | 16×2 | bob (176) | 200 | 30–70 | blue |
| 13 | 1,700 (11,550) | pulsar: wave or zigzag | 40×1 | hunt (192) | 204 | 28–70 | red |
| 14 | 1,800 (13,250) | hunt or stop-start | 20×2 | wave (200) | 208 | 28–65 | red |
| 15 | 1,900 (15,050) | zinger or wave | 32×1 | bob (176) | 212 | 26–65 | brown |
| 16 | 2,000 (16,950) | zigzag or zinger | 32×1 | hunt (208) | 216 | 26–60 | brown |
| 17 | 2,100 (18,950) | wave or zigzag | 40×1 | wave (208) | 220 | 24–60 | brown |
| 18 | 2,200 (21,050) | stop-start or zinger | 20×2 | hunt (224) | 224 | 24–55 | brown |
| 19 | 2,300 (23,250) | zinger or zigzag | 32×1 | hunt (232) | 232 | 22–50 | black (flashing white) |
| 20 | 2,400 (25,550) | zinger or wave | 68×½ | hunt (240) | 240 | 20–50 | black (flashing white) |

Finishing level 20 (27,950) shows the ending and the Finale code. The
fish waves on odd levels (worth 2) and swims straight on even ones.
