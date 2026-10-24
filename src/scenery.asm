;==============================================================================
; scenery.asm - the backdrop colours, and the attribute-row filler
;
; The moving ground itself is in scroll.asm (two parallax silhouettes).
; This file paints the attribute colours that do not change as the world
; scrolls, then asks scroll_init to build the pixels and the seaweed row.
;
; Colour is one byte per 8x8 cell, shared by every pixel in that cell,
; sprites included:
;   water            white ink, blue paper
;   far hills        yellow ink, blue paper (both far rows, to start)
;   near hills       black ink, yellow paper (both near rows, forever)
; scroll_init then recolours the bottom far row per column, because a
; seaweed cell is green on yellow instead of yellow on blue. That row is
; the only one whose attributes move, and only when a column lines up.
; A sprite picks up whatever pair it is standing on. docs/SCROLLING.md.
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

        ; Both far rows start as yellow-on-blue. The bottom row's seaweed
        ; columns are repainted by scroll_init (and again each time a far
        ; column scrolls fully on).
        ld b,BACK_ROW
        ld d,BACK_PX / 8
        ld e,BACK_HILL_ATTR
        call fill_attr_rows

        ; Both near rows, every column, for the whole run. Black ink on
        ; yellow paper: the silhouette pixels are the ink, the background
        ; is the paper. Nothing in this strip is any other colour.
        ld b,FRONT_ROW
        ld d,FRONT_PX / 8
        ld e,FRONT_ATTR
        call fill_attr_rows

        jp scroll_init          ; pixels, seaweed colours, first copy up

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

