;==============================================================================
; loader.asm - tokenised BASIC loader, assembled into scratch memory only
;
;   10 CLEAR VAL "32767": LOAD ""CODE : RANDOMIZE USR VAL "32768"
;
; Atlantis loads its loading screen first, stops the ROM printing
; "Bytes:" over it, and has two CODE blocks:
;
;   10 CLEAR VAL "32767": LOAD ""SCREEN$ : POKE VAL "23739",VAL "111":
;      LOAD ""CODE : LOAD ""CODE : RANDOMIZE USR VAL "32768"
;
; POKE 23739,111 is the old trick: it points the low byte of the
; current channel's output address at a RET in the ROM, so the messages
; the tape headers would print go nowhere.
; VAL "..." avoids having to emit the hidden 5-byte floating point numbers.
; This block is only used by SAVETAP; it is not part of the CODE block.
;==============================================================================

T_CLEAR     equ $FD
T_VAL       equ $B0
T_LOAD      equ $EF
T_CODE      equ $AF
T_RANDOMIZE equ $F9
T_USR       equ $C0
T_SCREEN    equ $AA
T_POKE      equ $F4

        ; Scratch only: SAVETAP copies these bytes into the BASIC header.
        ; They are not part of either CODE block. The demo keeps the
        ; loader at $E000. Atlantis has its pictures at $C000, so the
        ; same scratch would sit on top of them; $F900 is the first
        ; free byte after the soak photographs and still below the row
        ; table.
        IFDEF ATLANTIS
        ORG $F900
        IFDEF SOAK
        ASSERT $ >= SOAK_BUF_END, "the BASIC loader overlaps a soak photograph"
        ENDIF
        ELSE
        ORG $E000
        ENDIF
basic_start:
        db 0, 10                ; line number 10 (big-endian)
        dw .line_end - .line    ; line length (little-endian)
.line:
        db T_CLEAR, T_VAL, '"32767"', ':'
        IFDEF ATLANTIS
        db T_LOAD, '""', T_SCREEN, ':'
        db T_POKE, T_VAL, '"23739"', ',', T_VAL, '"111"', ':'
        ENDIF
        db T_LOAD, '""', T_CODE, ':'
        ; Atlantis loads a second block: the pictures and the tables
        ; that live at DATA_START. The demo has one block, and this
        ; second LOAD is not assembled into its BASIC.
        IFDEF ATLANTIS
        db T_LOAD, '""', T_CODE, ':'
        ENDIF
        db T_RANDOMIZE, T_USR, T_VAL, '"', "32768", '"'
        db $0D
.line_end:
BASIC_LENGTH equ $ - basic_start
        IFDEF ATLANTIS
        ASSERT basic_start + BASIC_LENGTH <= ROW_TABLE, "the BASIC loader runs into the row table"
        ENDIF
