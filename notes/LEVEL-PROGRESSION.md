# Level progression (spoilers)

What changes level by level, from `CFG_LEVELS` and the stage settings in
`src/atlantis/config.asm`. It is kept here, outside `docs/`, because it
gives the targets. If the table in `config.asm` changes, update this.

| Level | Points to finish (total at end) | Bomb | Colour | Bomb movement | Bomb speed | Missile wait | Fish | Border | New from this level |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 200 (200) | pulsar | black | small bob | 50 px/s | 1.5–4.0 s | round, straight | heartbeat | — |
| 2 | 300 (500) | pulsar | yellow | wave (±16 px) | 55 px/s | 1.4–3.7 s | round, wave, a bit faster | cyan | **hearts**; "starts now" panel |
| 3 | 400 (900) | spinning wheel | red | wave | 59 px/s | 1.3–3.4 s | round, straight | red | "stay tuned" panel |
| 4 | 500 (1,400) | spinning wheel | magenta | hunts, 48 | 64 px/s | 1.2–3.1 s | round | heartbeat | **double-shot bubble** |
| 5 | 600 (2,000) | spinning wheel | green | wave | 69 px/s | 1.1–2.8 s | round | heartbeat | — |
| 6 | 700 (2,700) | spinning wheel | cyan | hunts, 88 | 73 px/s | 1.0–2.5 s | round, **1 in 4 piranha** | heartbeat | **piranhas** |
| 7 | 800 (3,500) | spinning wheel | yellow | wave | 78 px/s | 0.9–2.2 s | as 6 | heartbeat | — |
| 8 | 900 (4,400) | spinning wheel | black | hunts, 128 (max) | 83 px/s | 0.8–1.9 s | as 6 | heartbeat | — |
| 9+ | 1,000 each | spinning wheel | red | hunts, 128 | 88 px/s | 0.7–1.6 s | as 6 | heartbeat | **homing silo missiles** |

## Notes

- **Hunt** is how hard the bomb drifts to the diver's depth: 48 is about
  9 px/s, 128 about 25 px/s (half the diver's speed).
- **Points on every level:** a fish 1 (a piranha 2), a bomb 2, a
  missile 10.
- **Power-ups** sink at about 31 px/s, slower than the diver. A heart
  turns up about one missile turn in 8, a bubble about one in 21 (the
  double shot lasts 30 seconds). Lives top out at 5.
- **After level 9** its row repeats.
- **The testers' switch** (see [CHEATS.md](CHEATS.md)) brings hearts,
  bubbles and piranhas in from level 1. It doesn't touch the bombs or the
  missiles.
- **A bomb's look and movement** change with the next bomb, not in
  mid-flight. The fish and the border change at once.
