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
;   CODE    "atlantis"  the packed loading screen, then the unpacker
;                         and dzx0, ending just below $8000
;   CODE    "atlantc"   the packed code, cold block, data and UDG block,
;                         ending at the ROM's UDGs ($FF48)
;
; WHERE. The unpacker must stay out of what it unpacks, and nothing
; packed may be overwritten before it has been read. go unpacks in the
; order the second block holds them, so each write lands only on bytes
; already read:
;   - the code, to $8000: between the two blocks.
;   - the cold block, to $6000: over the first block's packed screen,
;     which show has already unpacked, but below the unpacker itself,
;     which sits at the first block's top (asserted above cold_end, and
;     the cold block may grow to the spinning wheel's pictures).
;   - the data, to DATA_START: over the second block's packed code and
;     cold block, already read. Its own packed bytes are further up
;     (asserted past data_end).
; The second block is loaded as high as it goes, ending at $FF48, so the
; only things below it are the code's destination (asserted: it starts
; at or above code_end) and nothing else that matters while the tape
; loads. Its room is from code_end to $FF48, not from DATA_START: the
; round fish's and the jet's pictures, between the code and the data,
; are built at start-up, after it has been read. (Until 0.9.4 it loaded
; at DATA_START, about 3,280 bytes higher, which was all the room lost.)
;   - the UDG block, last, above everything else.
; At start-up the spinning wheel's pictures are built over the first
; block, and the diver's copies and the scroll buffers over the second.
; (Until November 2026 the first block sat on the page after cold_end
; and carried the data, and the second loaded on the page after
; data_end: that left the cold block 79 bytes and the packed game
; 1,005, docs/MEMORY.md.)
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
    IFDEF TRIGON                ; -DTRIGON: Trigon's tape, from build/trigon-*
        INCLUDE "../../build/trigon.exp"
    ELSE
        INCLUDE "../../build/atlantis.exp"
    ENDIF

COLD_START      equ $6000
UDG_START       equ $FF48       ; the ROM's user-defined graphics, and 16 bytes below
FRAMES          equ 23672       ; the ROM counts interrupts here

; The first block ends at $8000: its length is fixed by the INCBIN and
; the code, so the assembler settles this in its first passes.
UNPACK_ORG      equ CODE_START - (unpack_end - unpack_start)
; The second block ends at the ROM's UDGs; its length is fixed by the
; INCBINs, so the assembler settles this as it does UNPACK_ORG.
PACKED_ORG      equ UDG_START - (packed_end - packed_start)

;------------------------------------------------------------------------------
; The first block: the packed loading screen, then the unpacker.
;------------------------------------------------------------------------------
        ORG UNPACK_ORG
unpack_start:
packed_screen:
    IFDEF TRIGON
        INCBIN "../../build/trigon-loading.zx0"
    ELSE
        INCBIN "../../build/loading.zx0"
    ENDIF
unpack_code:

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
        ; In the order the second block holds them (WHERE, above).
        ld hl,packed_code
        ld de,entry
        call dzx0_standard
        ld hl,packed_cold
        ld de,COLD_START
        call dzx0_standard
        ld hl,packed_data
        ld de,DATA_START
        call dzx0_standard
        ld hl,packed_udg
        ld de,udg_start
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

unpack_end:
        ASSERT unpack_end == CODE_START, "the first block does not end at the code"
        ASSERT unpack_code >= cold_end, "the cold block would be unpacked over the unpacker"
        ASSERT UNPACK_ORG >= COLD_START, "the first block runs below the cold block"

;------------------------------------------------------------------------------
; The second block: the packed game.
;------------------------------------------------------------------------------
        ORG PACKED_ORG
packed_start:
    IFDEF TRIGON
packed_code:
        INCBIN "../../build/trigon-code.zx0"
packed_cold:
        INCBIN "../../build/trigon-cold.zx0"
packed_data:
        INCBIN "../../build/trigon-data.zx0"
packed_udg:
        INCBIN "../../build/trigon-udg.zx0"
    ELSE
packed_code:
        INCBIN "../../build/atlantis-code.zx0"
packed_cold:
        INCBIN "../../build/atlantis-cold.zx0"
packed_data:
        INCBIN "../../build/atlantis-data.zx0"
packed_udg:
        INCBIN "../../build/atlantis-udg.zx0"
    ENDIF
packed_end:
        ASSERT PACKED_ORG >= code_end, "the packed game would sit on the code"
        ASSERT packed_data >= data_end, "the data would be unpacked over its own packed bytes"
        ASSERT packed_end <= UDG_START, "the packed game runs into the ROM's UDGs"
        ASSERT udg_start == UDG_START, "the UDG block is not at the ROM's UDGs"

        DISPLAY "tape unpacker ", unpack_start, " to ", unpack_end
        DISPLAY "tape packed game ", packed_start, " to ", packed_end
        DISPLAY "tape room below the packed game ", /D, packed_start - code_end

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

    IFDEF TRIGON
    IFNDEF UNPACK_CHECK
        EMPTYTAP "build/trigon.tap"
        SAVETAP  "build/trigon.tap", BASIC, "trigon", basic_start, BASIC_LENGTH, 10
        SAVETAP  "build/trigon.tap", CODE, "trigon", unpack_start, unpack_end - unpack_start
        SAVETAP  "build/trigon.tap", CODE, "trigonc", packed_start, packed_end - packed_start
    ELSE
        EMPTYTAP "build/trigon-unpack-check.tap"
        SAVETAP  "build/trigon-unpack-check.tap", BASIC, "trigon", basic_start, BASIC_LENGTH, 10
        SAVETAP  "build/trigon-unpack-check.tap", CODE, "trigon", unpack_start, unpack_end - unpack_start
        SAVETAP  "build/trigon-unpack-check.tap", CODE, "trigonc", packed_start, packed_end - packed_start
    ENDIF
    ELSE
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
    ENDIF
