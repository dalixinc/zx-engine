;==============================================================================
; scenery.asm - the backdrop colours, and the attribute-row filler
;
; The moving ground itself is in scroll.asm (two parallax strips). This file
; only paints the attribute colours and then asks scroll_init to build the
; first screen of pixels. Colour is per 8x8 cell: a sprite over the front
; strip becomes white-on-black, over the back strip green-on-yellow, over
; the water white-on-blue. That is attribute clash, and the strips are each
; one colour pair so it stays predictable.
;==============================================================================

;------------------------------------------------------------------------------
; draw_scenery - colour the water and the ground, then build the strips
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
draw_scenery:
        ; open water: from the title down to the row above the far strip.
        ; Pixels stay 0 (cls). Paper is blue.
        ld b,WATER_TOP_ROW
        ld d,BACK_ROW - WATER_TOP_ROW
        ld e,WATER_ATTR
        call fill_attr_rows

        ld b,BACK_ROW
        ld d,BACK_PX / 8
        ld e,BACK_ATTR
        call fill_attr_rows

        ld b,FRONT_ROW
        ld d,FRONT_PX / 8
        ld e,FRONT_ATTR
        call fill_attr_rows

        ; Rows 20 and 21. The front strip is only row 19; this black band
        ; is what the diver sits in when he swims down, and it keeps the
        ; debug text (rows 22-23) off the ground.
        ld b,FLOOR_ROW
        ld d,2
        ld e,FLOOR_ATTR
        call fill_attr_rows

        jp scroll_init          ; paint both strips and copy them up once

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

