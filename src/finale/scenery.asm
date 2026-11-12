;==============================================================================
; scenery.asm - Atlantis backdrop colours
;
; Pixels are drawn by scroll.asm. This file only paints attribute colours,
; then asks scroll_init for the first picture.
;
; A cell is one ink and one paper, shared by every pixel in it, sprites
; included. The pairs that never move are painted once:
;   rows 0-20    white ink, blue paper     open water
;   row 22       yellow ink, blue paper    sand, and any silo top
;   row 23       black ink, yellow paper   ground, rocks, silo bases
; Row 21 starts as water. scroll_init (and every frame after that) repaints
; it, green on blue where a plant is and water everywhere else, because
; those cells have to follow the plant as it scrolls.
;==============================================================================

;------------------------------------------------------------------------------
; draw_scenery - colour the sea and the ground, then build the strips
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
draw_scenery:
        ld b,0                  ; rows 0..20, the whole sky of water
        ld d,BACK_ROW           ; BACK_ROW is 21: twenty-one rows, 0 through 20
        ld e,WATER_ATTR
        call fill_attr_rows

        ld b,SAND_ROW           ; one row, every column, for the whole run
        ld d,1
        ld e,SAND_ATTR
        call fill_attr_rows

        ld b,GROUND_ROW
        ld d,1
        ld e,GROUND_ATTR
        call fill_attr_rows

        jp scroll_init          ; pixels, the seaweed row, the first copy up

;------------------------------------------------------------------------------
; fill_attr_rows - In: B = first row, D = number of rows, E = attribute
; Corrupts: AF, BC, D, HL
;
; Same loop as the one in src/scenery.asm. It is copied rather than shared
; so the demo's scenery file can stay the Engine Demo 1 version.
;------------------------------------------------------------------------------
fill_attr_rows:
        ld c,0
        call attr_addr          ; HL -> first attribute of row B
.row:   ld b,32
.cell:  ld (hl),e
        inc hl                  ; attributes are in plain row order
        djnz .cell
        dec d
        jr nz,.row
        ret
