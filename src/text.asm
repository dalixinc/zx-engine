;==============================================================================
; text.asm - ROM-free text printing (reads glyphs from FONT_BASE only)
;==============================================================================

;------------------------------------------------------------------------------
; print_char - draw one character
; In:  A = ASCII code (32-127), B = row, C = column, (text_attr) = colour
; Out: C advanced by one column
; Corrupts: AF, DE, HL
;------------------------------------------------------------------------------
print_char:
        push bc
        ; DE = FONT_BASE + A*8
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,FONT_BASE
        add hl,de
        ex de,hl                ; DE -> glyph

        call char_addr          ; HL -> screen
        ld b,8
.row:   ld a,(de)
        ld (hl),a
        inc de
        inc h                   ; next pixel row inside a cell is +256
        djnz .row
        pop bc

        push bc
        call attr_addr
        ld a,(text_attr)
        ld (hl),a
        pop bc
        inc c
        ret

;------------------------------------------------------------------------------
; print_string - draw a zero-terminated string
; In:  HL -> string, B = row, C = column
; Corrupts: AF, DE, HL, C
;------------------------------------------------------------------------------
print_string:
.next:  ld a,(hl)
        or a
        ret z
        inc hl
        push hl
        call print_char
        pop hl
        jr .next

;------------------------------------------------------------------------------
; print_hex8 / print_hex16 - print A or HL as hex at B,C
; Corrupts: AF, DE, HL (print_hex16 preserves nothing else either)
;------------------------------------------------------------------------------
print_hex16:
        push hl
        ld a,h
        call print_hex8
        pop hl
        ld a,l
        ; fall through
print_hex8:
        push af
        rrca
        rrca
        rrca
        rrca
        call .nibble
        pop af
.nibble:
        and $0F
        add a,'0'
        cp '9'+1
        jr c,.out
        add a,'A'-'9'-1
.out:   jp print_char

text_attr:      db WHITE | (BLACK << 3)
