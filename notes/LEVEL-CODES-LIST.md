# Level codes (spoilers)

The list is kept here, outside `docs/`, so it isn't on the GitHub Pages
site with the game. How the codes are made is in
[docs/LEVEL-CODES.md](../docs/LEVEL-CODES.md), and they come from
`src/atlantis/codes.asm`. Each code depends only on its level number, so
the list changes only if that formula does. Level 1 has no code.

| Level | Code | Level | Code | Level | Code |
|---|---|---|---|---|---|
| 2 | TLTTDL | 9 | KKHCKF | 16 | KHJDPU |
| 3 | FDCGGR | 10 | ASEHEC | 17 | BPKDRD |
| 4 | DHSSJU | 11 | UBELAA | 18 | UFPLAG |
| 5 | LDLAGD | 12 | GPGFPP | 19 | GULSTL |
| 6 | CRBRPJ | 13 | SUGJAR | 20 | SDPCET |
| 7 | PFCUKP | 14 | EKKEUH | | |
| 8 | CUELRL | 15 | CDPFFC | | |

## Targets (spoilers too)

The score each level starts at, which is the score a code starts the
game at. Each is the last plus that level's points in `CFG_LEVELS`
(`src/atlantis/config.asm`), so these move if the table does; the codes
above don't.

| Level | Starts at | Level | Starts at |
|---|---|---|---|
| 1 | 0 | 6 | 2,000 |
| 2 | 200 | 7 | 2,700 |
| 3 | 500 | 8 | 3,500 |
| 4 | 900 | 9 | 4,400 |
| 5 | 1,400 | 10 | 5,400 |

From level 10 the last row repeats: 1,000 more for each level.
