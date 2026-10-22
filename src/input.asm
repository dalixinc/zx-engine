;==============================================================================
; input.asm - keyboard (redefinable) + Kempston joystick -> one flags byte
;
; Result bits (see constants.asm): 000FUDLR, 1 = pressed, same as Kempston.
;
; A key table has 5 entries in the order FIRE, UP, DOWN, LEFT, RIGHT, each
; 2 bytes: half-row high byte, key bit mask. Reading them in that order and
; shifting each result into E builds the flags byte with FIRE in bit 4 and
; RIGHT in bit 0. The tables live in RAM so a "define keys" screen can simply
; overwrite keys_primary later.
;==============================================================================

;------------------------------------------------------------------------------
; read_input - sample everything once; call once per frame
; Out: A = (input_state) = combined flags, also input_keys / input_joy set
;      (input_prev) = last frame's flags, for edge detection
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
read_input:
        ld a,(input_state)
        ld (input_prev),a

        ld hl,keys_primary
        call read_key_table
        ld d,e                  ; D = primary keys
        ld hl,keys_alt
        call read_key_table     ; E = alternative keys (D untouched)
        ld a,d
        or e
        ld (input_keys),a

        call read_kempston
        ld (input_joy),a
        ld hl,input_keys
        or (hl)
        ld (input_state),a
        ret

;------------------------------------------------------------------------------
; read_key_table - In: HL -> 5-entry key table. Out: E = flags. Corrupts: AF,BC,HL
;------------------------------------------------------------------------------
read_key_table:
        ld e,0
        ld b,5
.key:   push bc
        ld b,(hl)               ; half-row select on A8-A15
        inc hl
        ld c,ULA_PORT
        in a,(c)                ; 0 = pressed
        cpl
        and (hl)                ; isolate this key -> non-zero if pressed
        inc hl
        add a,$FF               ; carry = (a != 0)
        rl e
        pop bc
        djnz .key
        ret

;------------------------------------------------------------------------------
; read_kempston - Out: A = joystick flags, or 0 if no interface.
; With nothing on port $1F the bus floats (often $FF); a real Kempston
; always returns bits 5-7 clear, so any of them set means "not fitted".
; Corrupts: AF
;------------------------------------------------------------------------------
read_kempston:
        in a,(KEMPSTON_PORT)
        bit 7,a
        jr nz,.none
        bit 6,a
        jr nz,.none
        bit 5,a
        jr nz,.none
        and IN_MASK
        ret
.none:  xor a
        ret

; --- Key tables (order: FIRE, UP, DOWN, LEFT, RIGHT) ------------------------
keys_primary:                   ; defaults: SPACE, Q, A, O, P
        db ROW_SPC_B, %00001    ; SPACE
        db ROW_Q_T,   %00001    ; Q
        db ROW_A_G,   %00001    ; A
        db ROW_P_Y,   %00010    ; O
        db ROW_P_Y,   %00001    ; P
keys_alt:                       ; cursor keys / Sinclair-ish: 0, 7, 6, 5, 8
        db ROW_0_6,   %00001    ; 0
        db ROW_0_6,   %01000    ; 7
        db ROW_0_6,   %10000    ; 6
        db ROW_1_5,   %10000    ; 5
        db ROW_0_6,   %00100    ; 8

; --- Input state -------------------------------------------------------------
input_state:    db 0            ; combined flags this frame
input_prev:     db 0            ; combined flags last frame
input_keys:     db 0            ; keyboard only (debug)
input_joy:      db 0            ; Kempston only (debug)
