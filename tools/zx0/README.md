# ZX0 compressor

Einar Saukas's ZX0 compressor, the C source of
<https://github.com/einar-saukas/ZX0> (`src/`, commit `ecde3a2`, December
2021), unchanged apart from line endings. BSD 3-Clause, see `LICENSE`.
The matching Z80 decoder is `tools/dzx0_standard.asm`, from the same
commit.

`make` builds it as `build/zx0` (any C compiler: `cc -O2`) and uses it
to pack the tape (`src/atlantis/tape.asm`, `docs/MEMORY.md`). On Windows,
`build.bat` uses `zx0.exe` from `windows-tools\zx0\` or the PATH if it is
there, and otherwise writes the unpacked tape.
