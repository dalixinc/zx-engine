;==============================================================================
; tape.asm - the packed tape, build/atlantis.tap
;
; Assembled after main.asm, by the Makefile: main.asm writes the cold
; block, the code and the data as they are in memory (build/*.bin) and
; their ends (--exp=build/atlantis.exp), build/zx0 packs them and the
; loading screen, and this file puts them on the tape behind a small
; unpacker. Nothing here is part of the game: once it has jumped to
; entry, memory from COLD_START to data_end and the screen are byte for
; byte what main.asm assembled, and what build/atlantis.sna holds.
;
; The tape:
;   BASIC   10 CLEAR VAL "24575": LOAD ""CODE : RANDOMIZE USR VAL "<show>":
;              POKE VAL "23739",VAL "111": LOAD ""CODE : RANDOMIZE USR VAL "<go>"
;   CODE    "atlantis"  the unpacker, dzx0 and the packed loading screen
;   CODE    "atlantc"   the packed cold block, code and data
;
; WHERE. The unpacker must stay out of what it unpacks, and the packed
; game must not be overwritten before it has been read:
;   - the first block goes in the free room above the cold block, from
;     the page after cold_end, and must end below $8000. At start-up
;     the spinning wheel's pictures are built over its top half.
;   - the second goes from the page after data_end, above everything the
;     unpacker writes. The diver's copies and the scroll buffers are
;     built over it at start-up.
; The cold block is unpacked first, then the code, then the data, each
; into memory below the packed bytes still to be read.
;
; show returns to BASIC (it keeps IY and the alternate registers, as the
; ROM needs); go jumps to entry and never returns. POKE 23739,111 stops
; the ROM printing the second block's name over the picture.
;
; -DUNPACK_CHECK: a test tape. go prints the Fletcher sums of the screen
; and the three blocks, and the frames each unpack took, instead of
; starting the game (docs/MEMORY.md).
;==============================================================================

        DEVICE ZXSPECTRUM48

        INCLUDE "../constants.asm"
        INCLUDE "../../build/atlantis.exp"

COLD_START      equ $6000
UDG_START       equ $FF58       ; the ROM's user-defined graphics
FRAMES          equ 23672       ; the ROM counts interrupts here

UNPACK_ORG      equ (cold_end + $FF) & $FF00
PACKED_ORG      equ (data_end + $FF) & $FF00

;------------------------------------------------------------------------------
; The first block: the unpacker and the packed loading screen.
;------------------------------------------------------------------------------
        ORG UNPACK_ORG
unpack_start:
        jp show                 ; USR UNPACK_ORG
        jp go                   ; USR UNPACK_ORG + 3

; show - the loading screen, while the rest of the tape loads.
show:
    IFDEF UNPACK_CHECK
        ld hl,(FRAMES)
        ld (t_screen),hl
    ENDIF
        ld hl,packed_screen
        ld de,SCREEN
        call dzx0_standard
    IFDEF UNPACK_CHECK
        ld hl,(FRAMES)
        ld de,(t_screen)
        or a
        sbc hl,de
        ld (t_screen),hl
    ENDIF
        ret

; go - the cold block, the code and the data, then the game.
go:
        di
    IFDEF UNPACK_CHECK
        ei                      ; the ROM's interrupt counts the frames
        ld hl,(FRAMES)
        ld (t_game),hl
    ENDIF
        ld hl,packed_cold
        ld de,COLD_START
        call dzx0_standard
        ld hl,packed_code
        ld de,entry
        call dzx0_standard
        ld hl,packed_data
        ld de,DATA_START
        call dzx0_standard
    IFDEF UNPACK_CHECK
        ld hl,(FRAMES)
        ld de,(t_game)
        or a
        sbc hl,de
        ld (t_game),hl
        jp check
    ELSE
        jp entry
    ENDIF

        INCLUDE "../../tools/dzx0_standard.asm"

    IFDEF UNPACK_CHECK
        INCLUDE "tapecheck.asm"
    ELSE
t_screen        equ 0           ; only the check build counts frames
t_game          equ 0
    ENDIF

packed_screen:
        INCBIN "../../build/loading.zx0"
unpack_end:
        ASSERT UNPACK_ORG >= cold_end, "the unpacker would sit on the cold block"
        ASSERT unpack_end <= CODE_START, "the unpacker and the packed screen run into the code"

;------------------------------------------------------------------------------
; The second block: the packed game.
;------------------------------------------------------------------------------
        ORG PACKED_ORG
packed_start:
packed_cold:
        INCBIN "../../build/atlantis-cold.zx0"
packed_code:
        INCBIN "../../build/atlantis-code.zx0"
packed_data:
        INCBIN "../../build/atlantis-data.zx0"
packed_end:
        ASSERT PACKED_ORG >= data_end, "the packed game would sit on the data"
        ASSERT packed_end <= UDG_START, "the packed game runs into the ROM's UDGs"

        DISPLAY "tape unpacker ", unpack_start, " to ", unpack_end
        DISPLAY "tape packed game ", packed_start, " to ", packed_end

;------------------------------------------------------------------------------
; The BASIC. Scratch: SAVETAP copies these bytes into the BASIC block.
; Numbers are written as VAL "....." so there are no hidden 5-byte forms.
;------------------------------------------------------------------------------
T_CLEAR     equ $FD
T_VAL       equ $B0
T_LOAD      equ $EF
T_CODE      equ $AF
T_RANDOMIZE equ $F9
T_USR       equ $C0
T_POKE      equ $F4

        ; The five decimal digits of a number, as text.
        MACRO DIGITS5 n?
        db '0' + ((n?) / 10000) % 10, '0' + ((n?) / 1000) % 10
        db '0' + ((n?) / 100) % 10, '0' + ((n?) / 10) % 10, '0' + (n?) % 10
        ENDM

        ORG SCREEN              ; scratch: nothing is saved from here but the BASIC
basic_start:
        db 0, 10                ; line 10 (big-endian)
        dw .line_end - .line
.line:
        db T_CLEAR, T_VAL, '"24575"', ':'
        db T_LOAD, '""', T_CODE, ':'
        db T_RANDOMIZE, T_USR, T_VAL, '"'
        DIGITS5 show
        db '"', ':'
        db T_POKE, T_VAL, '"23739"', ',', T_VAL, '"111"', ':'
        db T_LOAD, '""', T_CODE, ':'
        db T_RANDOMIZE, T_USR, T_VAL, '"'
        DIGITS5 go
        db '"', $0D
.line_end:
BASIC_LENGTH equ $ - basic_start
        ASSERT COLD_START - 1 == 24575, "the BASIC's CLEAR 24575 must sit just below the cold block"

    IFNDEF UNPACK_CHECK
        EMPTYTAP "build/atlantis.tap"
        SAVETAP  "build/atlantis.tap", BASIC, "atlantis", basic_start, BASIC_LENGTH, 10
        SAVETAP  "build/atlantis.tap", CODE, "atlantis", unpack_start, unpack_end - unpack_start
        SAVETAP  "build/atlantis.tap", CODE, "atlantc", packed_start, packed_end - packed_start
    ELSE
        EMPTYTAP "build/atlantis-unpack-check.tap"
        SAVETAP  "build/atlantis-unpack-check.tap", BASIC, "atlantis", basic_start, BASIC_LENGTH, 10
        SAVETAP  "build/atlantis-unpack-check.tap", CODE, "atlantis", unpack_start, unpack_end - unpack_start
        SAVETAP  "build/atlantis-unpack-check.tap", CODE, "atlantc", packed_start, packed_end - packed_start
    ENDIF
