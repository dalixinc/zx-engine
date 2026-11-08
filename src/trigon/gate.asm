;==============================================================================
; trigon/gate.asm - the code on Trigon's menu (cold block)
;
; Trigon is played on from Atlantis: its menu has no "Start game", only
; option 1, a code (menu_code, menu.asm, on CODE_ROW). The Trigon code
; that the Atlantis ending gives (GATE_WORD, codes.asm) starts level 1,
; with the story first; a Trigon level code starts that level, as
; Atlantis's do. A wrong code buzzes, says BAD CODE, and asks again;
; Space gives up. The attract demo still plays level 1 by itself.
;==============================================================================

;------------------------------------------------------------------------------
; gate_level - menu_code, after the sixth letter, in place of code_level
; Out: A = the level the letters in code_buf start, or 0 for none.
; Corrupts: AF, B, DE, HL
;------------------------------------------------------------------------------
gate_level:
        ld hl,code_buf
        ld de,gate_code
        ld b,CODE_LEN
.cmp:   ld a,(de)
        cp (hl)
        jp nz,code_level        ; not it: perhaps a level's code
        inc hl
        inc de
        djnz .cmp
        ld a,1
        ret
gate_code:      GATE_WORD
        ASSERT $ - gate_code == CODE_LEN

;------------------------------------------------------------------------------
; gate_buzz - a wrong code: a low square wave, about a third of a second,
; played straight away (blocking, as the knell is). The menu's border
; stays. GATE_HALF loops of 51 T-states make a half wave of about 11,700
; T-states, 150 Hz.
; Corrupts: AF, BC
;------------------------------------------------------------------------------
MENU_BORDER     equ BLUE        ; enter_menu's
GATE_HALF       equ 230
GATE_HALVES     equ 100
gate_buzz:
        ld c,GATE_HALVES
        ld a,MENU_BORDER
.half:  xor %00010000           ; the speaker
        out (ULA_PORT),a
        ld b,GATE_HALF
.wait:  ex (sp),hl
        ex (sp),hl
        djnz .wait
        dec c
        jr nz,.half
        ld a,MENU_BORDER
        out (ULA_PORT),a        ; the speaker in
        ret
