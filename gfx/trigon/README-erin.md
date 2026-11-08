# Trigon Sprite Redesign — Erin, Pass 1

Drop-in text sprites using the original engine format. Each asset preserves its exact width, height, frame count, and mirror flag. The original pack has not been overwritten.

| Sprite | Dimensions | Frames | Concept |
|---|---|---|---|
| piranha | 16x9 | 2 | Predatory piranha, two-frame jaw snap |
| round-fish | 16x9 | 2 | Armored deep-sea angler with flashing lure |
| pulsar | 12x12 | 8 | Trigon T held upright; alternating burst and containment ring |
| spinning-wheel | 12x12 | 16 | Four bladed rotational states at engine-selected frames 0/4/8/12 |
| missile | 6x8 | 2 | Angular missile with long and short exhaust |

`#` = INK; `-` = opaque PAPER; `.` = transparent. Fish face right; the engine mirrors them. Bombs and missile have `mirror off`.

The PNG files show every frame at 12x enlargement. GIF files are animated visual previews. These are experimental silhouettes; inspect at native 1x scale in-game before adoption.

**Wheel note:** The current build selects frames 0, 4, 8 and 12, so the wheel has four distinct quarter-turn states repeated across 16 frames. If the engine is later changed to display all 16 frames, we can generate smoother intermediate states.
