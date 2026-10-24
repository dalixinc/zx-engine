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
; Corrupts: AF, DE, HL. C advances by 2 (or 4 for print_hex16).
;
; This does not go through print_char. print_char also writes the attribute
; byte, and the debug line prints 16 digits every frame. That extra work,
; on top of the sprites and the scrolling ground, ran past the next
; interrupt, so the game dropped to 25 frames a second (see
; docs/SCROLLING.md). The digit cells are already the right colour: cls
; paints the screen white-on-black, which is the same pen these digits use.
; Writing the picture is enough. The copy is unrolled for the same reason
; the ground copy is: DJNZ was costing more than the byte it copied.
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
        jr c,.glyph
        add a,'A'-'9'-1
.glyph:
        push bc
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl               ; *8, bytes per glyph
        ld de,FONT_BASE
        add hl,de
        ex de,hl                ; DE -> glyph
        call char_addr          ; HL -> top pixel row of the cell
        dup 8
        ld a,(de)
        ld (hl),a
        inc de
        inc h                   ; next pixel row inside this cell
        edup
        pop bc
        inc c
        ret

text_attr:      db WHITE | (BLACK << 3)
