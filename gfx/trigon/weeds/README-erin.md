# Trigon vegetation — Erin Art™ / Pass 1

Four replacement 8×8 monochrome silhouettes for the dark Trigon biome. These are **proposed assets** for Claudelet to integrate, not a tested build.

| Original name | Trigon redesign |
| --- | --- |
| fir | Barbed spire: asymmetrical, serrated silhouette |
| kelp | Hooked whip: bent, predatory frond |
| fan-coral | Skeletal coral: split claws and spines |
| sea-grass | Razor reeds: crooked, hooked blades |

## Strict scroll constraints — verified for every plant
- Exactly 8 rows × 8 columns.
- Only **zero-based columns 2, 3, 4, 5, 6** contain ink (columns 0, 1 and 7 blank).
- Each plant touches **both column 2 and column 6** somewhere.
- Each has at least one ink pixel on row 7 (bottom).
- One colour only. `#` = ink; `.` = transparent/background. No `-` paper pixels used.
- All four patterns are distinct from the Atlantis originals visible in the supplied screenshot.

## Files
- `fir.txt`, `kelp.txt`, `fan-coral.txt`, `sea-grass.txt`: **bare 8-line ASCII grids** (no headers, safest for pasting into an existing pattern table).
- `*-framed.txt`: optional sprite-style `frame 0` wrappers if the importer uses that syntax.
- `trigon_weeds.asm`: eight `DB %xxxxxxxx` lines per plant, with labels and inline ASCII comments.
- `*.bin`: each 8-byte, one-bit-per-pixel pattern; `trigon_weeds.bin`: 32 bytes in the order fir, kelp, fan-coral, sea-grass.
- `*.png`: actual 8×8 artwork; `*-16x.png`: enlarged previews.
- `Trigon_weeds_comparison.png`: supplied Atlantis silhouettes versus Trigon redesigns.

## Integration note for Claudelet
Only a screenshot of the original seaweed pack was attached, not its original `.txt` or assembly source. The 8×8 patterns and constraints are verified, but **the exact seaweed file wrapper in the game has not been verified**. Please transfer the eight rows (or eight binary bytes) into the existing seaweed table or adjust the text wrapper to the game's current parser. Preserve the existing colour/scroll mechanics and confirm in-engine at native resolution.
