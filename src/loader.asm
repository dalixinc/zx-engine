;==============================================================================
; loader.asm - tokenised BASIC loader, assembled into scratch memory only
;
;   10 CLEAR VAL "32767": LOAD ""CODE : RANDOMIZE USR VAL "32768"
;
; VAL "..." avoids having to emit the hidden 5-byte floating point numbers.
; This block is only used by SAVETAP; it is not part of the CODE block.
;==============================================================================

T_CLEAR     equ $FD
T_VAL       equ $B0
T_LOAD      equ $EF
T_CODE      equ $AF
T_RANDOMIZE equ $F9
T_USR       equ $C0

        ORG $E000               ; scratch; never loaded at runtime
basic_start:
        db 0, 10                ; line number 10 (big-endian)
        dw .line_end - .line    ; line length (little-endian)
.line:
        db T_CLEAR, T_VAL, '"32767"', ':'
        db T_LOAD, '""', T_CODE, ':'
        db T_RANDOMIZE, T_USR, T_VAL, '"', "32768", '"'
        db $0D
.line_end:
BASIC_LENGTH equ $ - basic_start
