;==============================================================================
; scenery.asm - a static underwater backdrop for testing sprites over
;
; Nothing clever: we fill some character rows with a pixel pattern and an
; attribute colour. It exists so you can see the sprite mask working (the
; fish's see-through pixels show the pattern; its solid pixels hide it) and
; so you can check that save/restore leaves the scenery undamaged.
;
; Remember colour on the Spectrum is per 8x8 cell, not per pixel: when the
; fish swims over the seabed it takes on the seabed's INK/PAPER. That is
; "attribute clash", and the game design will have to live with it.
;==============================================================================

;------------------------------------------------------------------------------
; draw_scenery - water, seabed and a few weeds
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
draw_scenery:
        ; water: rows WATER_TOP_ROW..SEABED_ROW-1, empty pixels, blue paper
        ld b,WATER_TOP_ROW
        ld d,SEABED_ROW - WATER_TOP_ROW
        ld e,WATER_ATTR
        call fill_attr_rows

        ; seabed: a pebbly pattern with yellow paper and black ink
        ld b,SEABED_ROW
        ld d,SEABED_ROWS
        ld e,SEABED_ATTR
        call fill_attr_rows
        ld b,SEABED_ROW
        ld d,SEABED_ROWS
        ld hl,pattern_pebbles
        call fill_pattern_rows

        ; weeds: three columns of a wavy pattern, 4 cells tall, on the seabed
        ld c,4
        call draw_weed
        ld c,13
        call draw_weed
        ld c,24
        call draw_weed
        ret

;------------------------------------------------------------------------------
; fill_attr_rows - In: B = first row, D = number of rows, E = attribute
; Corrupts: AF, BC, D, HL
;------------------------------------------------------------------------------
fill_attr_rows:
        ld c,0
        call attr_addr          ; HL -> first attribute of row B
.row:   ld b,32
.cell:  ld (hl),e
        inc hl                  ; attributes ARE in plain row order
        djnz .cell
        dec d
        jr nz,.row
        ret

;------------------------------------------------------------------------------
; fill_pattern_rows - fill whole character rows with an 8-byte pattern
; In:  B = first row, D = number of rows, HL -> 8 bytes (one per pixel line)
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
fill_pattern_rows:
.row:   ld c,0                  ; C = column, 0..31
.cell:  push de                 ; D = rows left: copy_cell corrupts DE
        push hl                 ; HL = pattern start, needed for every cell
        ex de,hl                ; DE -> pattern
        call char_addr          ; HL -> top pixel line of cell (B,C)
        call copy_cell          ; (corrupts B too, so save it around this)
        pop hl
        pop de
        inc c
        ld a,c
        cp 32
        jr nz,.cell
        inc b                   ; next character row
        dec d
        jr nz,.row
        ret

;------------------------------------------------------------------------------
; draw_weed - In: C = column. Draws 4 cells upward from the seabed.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
draw_weed:
        ld b,SEABED_ROW - 4
.cell:
        call attr_addr
        ld (hl),WEED_ATTR
        call char_addr
        ld de,pattern_weed
        call copy_cell
        inc b
        ld a,b
        cp SEABED_ROW
        jr nz,.cell
        ret

;------------------------------------------------------------------------------
; copy_cell - copy 8 pattern bytes into one character cell
; In: HL -> top pixel line of the cell, DE -> 8 bytes. Corrupts: AF, DE, H
; Inside a cell, each pixel line down is +256, i.e. just INC H.
;------------------------------------------------------------------------------
copy_cell:
        push bc                 ; callers use B as a row counter: keep it
        ld b,8
.line:  ld a,(de)
        ld (hl),a
        inc de
        inc h
        djnz .line
        pop bc
        ret

pattern_pebbles:
        db %00000000
        db %01100010
        db %11110111
        db %01100010
        db %00000000
        db %00011000
        db %10111100
        db %00011001
pattern_weed:
        db %00011000
        db %00110000
        db %00110000
        db %00011000
        db %00001100
        db %00001100
        db %00011000
        db %00110000
