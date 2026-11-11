;==============================================================================
; main.asm - TRIGON
;
; The second game. Atlantis ends at the city, where its last screen gives
; the player the Trigon code; this is the game that code opens, loaded
; from its own tape. It is the Atlantis game, frame loop and all
; (src/atlantis/main.asm and the files it includes), assembled with
; TRIGON defined, which changes:
;   - the numbers: src/trigon/config.asm in place of Atlantis's, with
;     Trigon's own levels, colours and sea (CFG_SEA)
;   - the art: Erin's sprites (gfx/trigon/), the same sizes and names as
;     the Atlantis ones, so the same draws and buffers take them
;   - the colours: every cell on the water is an ink on the sea's paper
;     (SEA, layout.asm); the fish and a flying missile get their cells
;     painted each step (theme.asm); a death flashes CFG_HIT_INK
;   - the menu: TRIGON in the tall letters, and the code first: the
;     Trigon code starts level 1, a level code a later level (gate.asm)
;   - the words: the story, and the codes' keys (codes.asm)
; and leaves out the city (CITY_SHOW): Trigon has no interlude.
;
; Nothing Atlantis assembles changes: each TRIGON switch keeps the
; Atlantis bytes in its other half, and the Makefile's trigon target
; checks that build/atlantis.sna does not move.
;
; Build:  make trigon     (build/trigon.tap and build/trigon.sna)
;         make trigon-seas (build/trigon-sea-black.sna, -dark.sna)
;         make trigon-ediver (build/trigon-ediver.sna: the enemy diver
;                         experiment, -DENEMY_DIVER, src/trigon/ediver.asm)
; The same -D test flags as Atlantis (SOAK, MEASURE, SHOT_FRAME ...) give
; build/trigon-*.sna.
;==============================================================================

        DEFINE TRIGON
        INCLUDE "../atlantis/main.asm"

    IFNDEF TIMING_BARS
    IFNDEF SOAK
    IFNDEF SLACK_LINES
    IFNDEF SHOT_FRAME
    IFNDEF MEASURE
        ; As Atlantis's: the loading screen into screen memory, a plain
        ; tape that needs nothing but sjasmplus, the blocks for the
        ; packed tape (src/atlantis/tape.asm with -DTRIGON), and the
        ; snapshot. -DSEA_SNA writes only a snapshot, named by the sea
        ; (the comparison: make trigon-seas, with -DCFG_SEA=0 or 1).
        ORG SCREEN
loading_screen:
        INCBIN "../../gfx/trigon/loading.scr"
        ASSERT $ - loading_screen == 6912, "a Spectrum screen is 6912 bytes"
    IFDEF ENEMY_DIVER
        ; The enemy diver experiment (ediver.asm): a snapshot only.
        SAVESNA  "build/trigon-ediver.sna", entry
    ELSE
    IFDEF SEA_SNA
        IF CFG_SEA == BLACK
        SAVESNA  "build/trigon-sea-black.sna", entry
        ELSE
        SAVESNA  "build/trigon-sea-dark.sna", entry
        ENDIF
    ELSE
        EMPTYTAP "build/trigon-plain.tap"
        SAVETAP  "build/trigon-plain.tap", BASIC, "trigon", basic_start, BASIC_LENGTH, 10
        SAVETAP  "build/trigon-plain.tap", CODE, "trigon", loading_screen, 6912
        SAVETAP  "build/trigon-plain.tap", CODE, "trigonm", COLD_START, COLD_LENGTH
        SAVETAP  "build/trigon-plain.tap", CODE, "trigonc", code_start, CODE_LENGTH
        SAVETAP  "build/trigon-plain.tap", CODE, "trigond", data_start, DATA_LENGTH
        SAVETAP  "build/trigon-plain.tap", CODE, "trigonu", udg_start, UDG_LENGTH
        SAVEBIN  "build/trigon-cold.bin", COLD_START, COLD_LENGTH
        SAVEBIN  "build/trigon-code.bin", code_start, CODE_LENGTH
        SAVEBIN  "build/trigon-data.bin", data_start, DATA_LENGTH
        SAVEBIN  "build/trigon-udg.bin", udg_start, UDG_LENGTH
        ; What tape.asm needs to know: --exp=build/trigon.exp
        EXPORT hot_top
        EXPORT data_top
        EXPORT cold_top
        EXPORT cold_end
        EXPORT code_end
        EXPORT data_end
        EXPORT udg_start
        EXPORT udg_end
        EXPORT entry
        SAVESNA  "build/trigon.sna", entry
    ENDIF
    ENDIF
    ENDIF
    ENDIF
    ENDIF
    ENDIF
    ENDIF

    IFDEF TIMING_BARS
        SAVESNA "build/trigon-timing.sna", entry
    ENDIF
    IFDEF SOAK
        SAVESNA "build/trigon-soak.sna", entry
    ENDIF
    IFDEF SLACK_LINES
        SAVESNA "build/trigon-slack.sna", entry
    ENDIF
    IFDEF SHOT_FRAME
        SAVESNA "build/trigon-shot.sna", entry
    ENDIF
    IFDEF MEASURE
        SAVESNA "build/trigon-measure.sna", entry
    ENDIF
