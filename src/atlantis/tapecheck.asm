;==============================================================================
; tapecheck.asm - tape.asm's -DUNPACK_CHECK: prove the unpacked memory
;
; After go has unpacked everything, print on the top rows, as hex:
;   row 0   the screen's sums      (Fletcher: sum, sum of sums, 16 bits)
;   row 1   the cold block's
;   row 2   the code's
;   row 3   the data's
;   row 4   frames to unpack the screen, frames to unpack the game
;   row 5   the UDG block's
; then stop. The screen is summed before anything is printed on it.
; The sums of build/*.bin and gfx/loading.scr must match (docs/MEMORY.md).
;==============================================================================

check:
        di
        ld hl,SCREEN
        ld bc,6912
        call sum
        push de
        push hl
        ld hl,COLD_START
        ld bc,cold_end - COLD_START
        call sum
        push de
        push hl
        ld hl,entry
        ld bc,code_end - entry
        call sum
        push de
        push hl
        ld hl,DATA_START
        ld bc,data_end - DATA_START
        call sum
        ; Now the screen may be written on: white on black for rows 0-4,
        ; then print, bottom-up from the stack.
        push hl
        push de
        ld hl,ATTRS
        ld de,ATTRS + 1
        ld bc,6 * 32 - 1
        ld (hl),$47
        ldir
        pop de
        pop hl
        ld b,3
        call print_pair
        pop hl
        pop de
        ld b,2
        call print_pair
        pop hl
        pop de
        ld b,1
        call print_pair
        pop hl
        pop de
        ld b,0
        call print_pair
        ld de,(t_screen)
        ld hl,(t_game)
        ld b,4
        call print_pair
        ld hl,udg_start
        ld bc,udg_end - udg_start
        call sum
        ld b,5
        call print_pair
        ld a,4                  ; green border: done
        out ($FE),a
.stop:  halt
        jr .stop

; In: HL = start, BC = length. Out: DE = sum, HL = sum of sums.
sum:    ld de,0
        ld (.s2),de
.byte:  ld a,(hl)
        inc hl
        add a,e
        ld e,a
        jr nc,.n
        inc d
.n:     push hl
        ld hl,(.s2)
        add hl,de
        ld (.s2),hl
        pop hl
        dec bc
        ld a,b
        or c
        jr nz,.byte
        ld hl,(.s2)
        ret
.s2:    dw 0

; Print DE at column 0 and HL at column 5 of character row B (0-7).
print_pair:
        push hl
        ld c,0
        ex de,hl
        call hex16
        pop hl
        ld c,5
; HL as four hex digits at row B, column C.
hex16:  ld a,h
        call hex8
        ld a,l
hex8:   push af
        rrca
        rrca
        rrca
        rrca
        call digit
        pop af
digit:  and 15
        add a,'0'
        cp '9' + 1
        jr c,.ch
        add a,'A' - '9' - 1
.ch:    push hl
        push bc
        ; The ROM's glyph for A, onto row B (0-7: the top third), column C.
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,$3C00             ; the ROM font, from character 0
        add hl,de
        ex de,hl
        ld a,b
        rrca
        rrca
        rrca
        and $E0
        or c
        ld l,a
        ld h,SCREEN >> 8
        ld b,8
.line:  ld a,(de)
        ld (hl),a
        inc de
        inc h
        djnz .line
        pop bc
        pop hl
        inc c
        ret

t_screen:       dw 0
t_game:         dw 0
