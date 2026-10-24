;==============================================================================
; wheel.asm - the first Trigon enemy, the wheel bomb
;
; One at a time. It slides in from the right edge, a pixel a frame, bobs
; up and down, and leaves through the left edge. After a short pause
; another one appears at a different height.
;
; The legs spin. The T does not: that mark is on every Trigon enemy,
; and it stays upright. The art is gfx/wheel.txt, 12 by 12, four frames,
; the wide leg stepping a quarter turn counter-clockwise (the way a
; wheel rolls when it travels left). There is a one-pixel gap of water
; between the T and the rim. The picture is a placeholder.
;
; It is drawn by the walker in fastsprite.asm, not by the shared sprite
; loop. A 16 by 16 wheel on that loop cost about 60 scanlines, and the
; frame only had 7 to spare, so the picture missed the interrupt and
; flickered. Twelve pixels is the size asked for. Shifted by 0 to 4 it
; is two bytes wide; shifted by 5 to 7 it is three. The walker writes
; the row in a straight line, and the fish and the diver on this build
; use the same walker, which is where the spare scanlines come from.
;
; Each bomb has its own ink colour. The paper stays the blue of the
; water. wheel_colour is an index into wheel_palette, so a later level
; can point a bomb at another entry, and a homing bomb can use a
; different index from a drifting one. The default is bright red.
; White is the diver, the fish and the water ink, so a white bomb
; would not read.
;
; Colour clash: an 8 by 8 cell has one ink. Any cell the bomb covers
; (the title, the diver, the fish, the stat digits) is drawn in the
; bomb's ink until the bomb moves on and the old attribute byte is put
; back. The sand and the seaweed are not recoloured. The lowest pixel
; of the lowest bob is pixel 167, the last pixel of character row 20,
; and the attribute walk stops there. Row 21 is the seaweed.
;
; Movement is a type byte and a table of routines, so a later bomb that
; homes in on the diver is another entry in the table and another
; routine. That routine is not written here.
;
; It stays in the open water. The top of the bob is pixel row 0 (the stat
; digits may sit on it). The bottom of the bob is the last pixel of row
; 20, one above the seaweed.
;==============================================================================

; Kind values. wheel_kind picks a row of wheel_kind_tab.
WHEEL_KIND_DRIFT equ 0          ; the only kind so far: straight left

; --- Tuning. Names are the knobs. -------------------------------------------
; One pixel a frame, the same speed as the diver, so this first bomb is
; something he can swim away from and something the eye can follow while
; it clips at the edge. 50 pixels a second.
WHEEL_SPEED     equ 1

; Half the height of the bob, in pixels. The table below is a rounded
; sine of this size, not a triangle: a triangle is a couple of adds and
; no table, but it turns around in one frame at the top and looks like a
; bounce. The sine slows down as it reaches the top. 6 pixels is enough
; to read as a bob and small enough that a spawn near the surface still
; fits under the seaweed.
WHEEL_BOB       equ 6

; How many video frames each rotation frame is held. Four frames make one
; turn, so a turn takes 4*8 = 32 frames. In that time the bomb travels 32
; pixels. The rim sits about 5 pixels from the centre, and a wheel of that
; radius rolls one turn in about 31 pixels, so the spin is about right.
; Lower it to slow the spin; it does not have to match the roll.
WHEEL_SPIN      equ 8

; Frames to wait after one bomb has gone, before the next appears.
; 48 frames is just under a second.
WHEEL_GAP       equ 48

; Legal bases. The bob is added to the base, so the base itself stays this
; far from the top and from the seaweed:
;   top:    base - WHEEL_BOB >= 0
;   bottom: base + WHEEL_BOB + WHEEL_HEIGHT <= row 21
WHEEL_TOP_BASE  equ WHEEL_BOB
WHEEL_LOW_BASE  equ BACK_ROW * 8 - WHEEL_HEIGHT - WHEEL_BOB

; Phase of the one bomb. Not the same thing as the kind: drifting covers
; both the flight and the pause between flights.
WHEEL_FLY       equ 1
WHEEL_WAIT      equ 0

;------------------------------------------------------------------------------
; update_wheel - one frame of movement, via the kind table
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
update_wheel:
        ld a,(wheel_kind)
        add a,a                 ; entries are words
        ld e,a
        ld d,0
        ld hl,wheel_kind_tab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        jp (hl)

; One entry today. A homing bomb is a second dw, and wheel_kind = 1.
; Nothing here jumps to a routine that has not been written.
wheel_kind_tab:
        dw wheel_drift

;------------------------------------------------------------------------------
; wheel_drift - the straight-left bomb
; Flying: bob, spin, move left, and when it has gone past the left edge,
; start the pause. Waiting: count down, then spawn the next one.
;------------------------------------------------------------------------------
wheel_drift:
        ld a,(wheel_phase)
        or a
        jr z,.waiting

        ; Bob index steps every frame, round a 32-entry table.
        ld a,(wheel_bob_i)
        inc a
        and 31
        ld (wheel_bob_i),a
        ld hl,wheel_bob
        ld e,a
        ld d,0
        add hl,de
        ld a,(wheel_base)
        add a,(hl)              ; the table entry is a signed offset
        ld (wheel_y),a

        ; Spin. WHEEL_FRAMES is 4, so the frame number is two bits.
        ld hl,wheel_spin_n
        inc (hl)
        ld a,(hl)
        cp WHEEL_SPIN
        jr c,.moved
        ld (hl),0
        ld a,(wheel_frame)
        inc a
        and WHEEL_FRAMES - 1
        ld (wheel_frame),a

.moved: ld hl,(wheel_x)
        ld de,-WHEEL_SPEED
        add hl,de
        ld (wheel_x),hl

        ; Gone once the right-hand pixel is off the screen too:
        ; x + width <= 0.
        ld de,WHEEL_WIDTH
        add hl,de
        bit 7,h
        jr nz,.leave            ; x + width is negative
        ld a,h
        or l
        ret nz                  ; still a pixel on the screen, or more
.leave: xor a
        ld (wheel_phase),a
        ld a,WHEEL_GAP
        ld (wheel_delay),a
        ret

.waiting:
        ld hl,wheel_delay
        dec (hl)
        ret nz
        call wheel_next_height  ; a new base, from the LFSR
        ld hl,256               ; left pixel just past the right edge
        ld (wheel_x),hl
        xor a
        ld (wheel_bob_i),a
        ld (wheel_spin_n),a
        ld (wheel_frame),a
        ld a,(wheel_base)       ; bob[0] is 0, so y starts at the base
        ld (wheel_y),a
        ld a,WHEEL_FLY
        ld (wheel_phase),a
        ret

;------------------------------------------------------------------------------
; wheel_next_height - step the LFSR and take a base from the table
; The low 3 bits pick one of 8 heights. Every entry is between
; WHEEL_TOP_BASE and WHEEL_LOW_BASE, so the bob cannot leave the water.
; Corrupts: AF, DE, HL
;------------------------------------------------------------------------------
wheel_next_height:
        call wheel_rng
        and 7
        ld e,a
        ld d,0
        ld hl,wheel_heights
        add hl,de
        ld a,(hl)
        ld (wheel_base),a
        ret

;------------------------------------------------------------------------------
; wheel_rng - one step of an 8-bit LFSR. A is the new value.
;
; The other cheap source is the R register. R counts instructions, so it
; changes when a frame runs long, and a soak test could not know which
; height was coming. This sequence is the same every time the game is
; switched on.
;
; Galois form, polynomial x^8 + x^6 + x^5 + x^4 + 1. The shifted-out bit
; selects the xor with $B8. Period 255. Seed 0 would stay 0, so the seed
; below is not 0, and the xor keeps it off 0.
;
; Seed 42. The first step is 21 (index 5, the fish's depth). The second
; is 178 (index 2, the surface). The soak counts on that order.
; Corrupts: AF
;------------------------------------------------------------------------------
wheel_rng:
        ld a,(wheel_seed)
        srl a                   ; bit 0 into carry, a zero into bit 7
        jr nc,.keep
        xor $B8
.keep:  ld (wheel_seed),a
        ret

;------------------------------------------------------------------------------
; wheel_restore - put back the pixels and the attribute bytes from last
;                 frame
; wheel_draw    - photograph the new position, draw, and colour the cells,
;                 or do none of that when it is fully off the screen
; Drawn after the fish and before the diver, so the fish is behind it
; and the diver is in front. It never reaches the seaweed, so it is
; always drawn before the seabed copy. Both of these run at the start
; of the frame, while the beam is still up in the border on a frame
; that finishes on time. That is what keeps the erase from flickering.
; Corrupts: AF, BC, DE, HL, IX, IY
;------------------------------------------------------------------------------
wheel_restore:
        ld iy,wheel_bg
        jp fast_restore

wheel_draw:
        ld a,(wheel_phase)
        or a
        jr z,.off               ; the pause: nothing on screen

        ; Stored width depends on the shift. The low 3 bits of x pick
        ; it, including when x is negative: -1 has low bits 7, and that
        ; copy is 3 bytes. sprite_set_pos_x then clips that width.
        ld hl,(wheel_x)
        ld a,l
        and 7
        ld e,a
        ld d,0
        ld hl,wheel_shift_bytes
        add hl,de
        ld d,(hl)               ; stored bytes for this shift
        ld a,(wheel_y)
        ld b,a
        ld e,WHEEL_HEIGHT
        ld hl,(wheel_x)
        call sprite_set_pos_x
        ld a,(spr_hidden)
        or a
        jr nz,.off

        ; Resolve the ink every draw, so a store to wheel_colour shows
        ; up on the next frame without any other setup.
        ld a,(wheel_colour)
        ld e,a
        ld d,0
        ld hl,wheel_palette
        add hl,de
        ld a,(hl)
        ld (wheel_ink),a

        ld iy,wheel_bg
        call fast_save

        ld a,(wheel_frame)      ; one facing, so the index is the frame
        ld hl,wheel_images
        call sprite_image
        call fast_pick          ; HL -> image for this shift

        ; Fully on screen: every stored byte is drawn, and the gap
        ; between rows is zero. That is the slow case (a shift of 5, 6
        ; or 7 is three bytes, and all three are on the screen). Skip
        ; the "add the gap" step, which would be adding zero.
        ; Clipped: step over the pairs hanging off the left, then
        ; fast_draw_gap skips the hidden pairs after each row.
        ld a,(spr_skip2)
        or a
        jr nz,.clipped
        ld a,(spr_gap2)
        or a
        jr nz,.clipped
        call fast_draw
        ret
.clipped:
        ld a,(spr_skip2)
        add a,l
        ld l,a
        jr nc,.noskip
        inc h
.noskip:
        call fast_draw_gap
        ret

.off:   ; Fully off, or waiting. wheel_colours, which runs next and
        ; still before the seabed copy, puts the water colour back on
        ; the rectangle. Drop the pixel record so the next restore
        ; does not paint the old photograph.

        ld iy,wheel_bg
        ld (iy+BG_VALID),0
        ret


;------------------------------------------------------------------------------
; wheel_colours - keep the bomb's ink on its rectangle
;
; The bomb moves one pixel a frame, so it usually stays inside the same
; character cells. Those cells are already the right colour. Writing
; them again, and putting the old bytes back first, was a few scanlines
; on every frame, and the frames where the rectangle was three cells
; tall missed the interrupt.
;
; The common frame finds the same rectangle as last time and returns.
; While the whole bomb is on the screen, the column that changed is
; read from the shift instead of from a second compare: shift 7 paints
; the new left column, shift 4 puts the old right column back. A frame
; that is clipped compares the rectangle and updates the strip that
; moved. The strip is written in the bomb's ink, or back to the water
; colour. It does not read the old bytes. Everything above the seaweed
; is the water colour, apart from the title word, which is put back
; when a strip that covered it is given back to the sea.
;
; A store to wheel_colour is picked up on this frame even when the
; rectangle has not moved: the byte last written is wheel_shown.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
wheel_colours:
    IFDEF NO_INK
        ; Measurement only. The tape does not define this. It leaves the
        ; ink out so the spare-scanline count can be taken without the
        ; attribute fill.
        ret
    ENDIF
        call wheel_attr_box
        jp z,wheel_colours_clear
        ld a,(wheel_attr_n)
        or a
        jp z,wheel_paint_attrs
        ld a,(wheel_ink)
        ld hl,wheel_shown
        cp (hl)
        jp nz,wheel_full_recolour

        ; Partly or wholly on the screen. The box already returned
        ; otherwise, and that case was the clear above. Past the left
        ; edge the right-hand column shrinks; the shift is not used
        ; there (wheel_colours_fast.column). Repainting the whole
        ; rectangle on the way out was the seabed frame that missed.
        jp wheel_colours_fast

;------------------------------------------------------------------------------
; wheel_colours_fast - the bomb is wholly on screen and the ink is the
; same as last frame
; A one-pixel slide to the left changes a column only on two shifts.
; Shift 7: the left pixel has entered a new cell, so that column is
; painted. Shift 4: the right pixel has left a cell, so the old column
; is put back to the water colour. Any other shift is the same columns.
; The bob moves one pixel up, one down, or not at all, so at most one
; row edge changes, and only by one cell.
; Working out which edge from the two column numbers, then checking the
; difference was exactly one, was most of the time on the frame that
; also draws the three-byte picture.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
wheel_colours_fast:
        ; The row test comes first. Most frames do not cross a row, and
        ; then only the shift is looked at. The accumulator holds the
        ; new row while HL points at the old one, so a difference of one
        ; does not have to be loaded again.
        ld a,(wheel_r0)
        ld hl,wheel_pr0
        cp (hl)
        jr nz,.top
        inc hl                      ; the old bottom row sits next to it
        ld a,(wheel_r1)
        cp (hl)
        jr nz,.bottom
        call .column
        ret z                       ; same rectangle: nothing to write
        jp wheel_remember_edges

.top:   sub (hl)                    ; new top minus the old top
        cp 1
        jr z,.drop_top              ; moved down: the old top row is left
        cp $FF
        jr nz,.odd                  ; not a one-cell step
        ld a,(wheel_r0)
        ld b,a
        ld a,(wheel_ink)
        ld d,a
        call wheel_paint_row        ; the new top row, current columns
        jr .both
.drop_top:
        ld a,(wheel_pr0)
        ld b,a
        call wheel_water_row
        jr .both

.bottom:sub (hl)
        cp 1
        jr z,.add_bot
        cp $FF
        jr nz,.odd
        ld a,(wheel_pr1)
        ld b,a
        call wheel_water_row
        jr .both
.add_bot:
        ld a,(wheel_r1)
        ld b,a
        ld a,(wheel_ink)
        ld d,a
        call wheel_paint_row

.both:  call .column
        jp wheel_remember_edges

.odd:   ; The bob only ever steps one pixel, so this is a safety net
        ; (a height change that is not a single cell). Repaint. Nothing
        ; has been written yet on this path.
        jp wheel_full_recolour

; Shift 7 paints the new left column. Shift 4 puts the old right column
; back. Anything else leaves the columns alone and returns with the zero
; flag set. A column that is written returns with the zero flag clear.
.column:
        ; Off the left, a pixel is still showing (the box said so). The
        ; left edge stays column 0, so only the right edge can move, and
        ; a one-pixel step moves it by one cell. The low byte of a
        ; negative x is not a shift we can trust.
        ld a,(wheel_x+1)
        or a
        jr z,.by_shift
        ld a,(wheel_c0)
        ld hl,wheel_pc0
        cp (hl)
        jr nz,.odd_col
        ld a,(wheel_c1)
        inc hl                      ; the old right column
        cp (hl)
        jr z,.none
        ld b,a
        ld a,(hl)
        sub b
        cp 1
        jr nz,.odd_col
        ld c,(hl)
        ld a,(wheel_pr0)
        ld b,a
        ld a,(wheel_pr1)
        sub b
        inc a
        ld e,a
        call wheel_water_cells_col
        or 1
        ret
.odd_col:
        pop af                      ; drop the return from call .column
        jp wheel_full_recolour
.by_shift:
        ld a,(wheel_x)
        and 7
        cp 7
        jr z,.add_left
        cp 4
        jr nz,.none
        ; Shift 4 is a right-hand column left behind only once the right
        ; pixel is on the screen (x <= 243). While the bomb is still
        ; clipped on the right, that column was never painted: x = 244
        ; is shift 4 and the old right edge is still column 31.
        ld a,(wheel_x)
        cp 244
        jr c,.drop_right
.none:  xor a
        ret
.add_left:
        ld a,(wheel_c0)
        ld c,a
        ld a,(wheel_ink)
        ld d,a
        ld a,(wheel_r0)
        ld b,a
        ld a,(wheel_r1)
        sub b
        inc a
        ld e,a                      ; how many rows the new column covers
        call wheel_solid_col
        or 1
        ret
.drop_right:
        ld a,(wheel_pc1)            ; the column just left behind
        ld c,a
        ld a,(wheel_pr0)
        ld b,a
        ld a,(wheel_pr1)
        sub b
        inc a
        ld e,a
        call wheel_water_cells_col
        or 1
        ret

wheel_colours_clear:
    IFDEF NO_INK
        ret
    ENDIF
        ld a,(wheel_attr_n)
        or a
        ret z
        call wheel_restore_attrs
        ret

;------------------------------------------------------------------------------
; wheel_restore_attrs - water colour back on the rectangle from last frame
; The address and the size were saved when it was painted, so this does
; not work them out again. The title word is yellow, so any cell of it
; inside that rectangle is put back afterwards. The count is cleared.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
wheel_restore_attrs:
        ld a,(wheel_attr_n)
        or a
        ret z
        ; The rectangle last painted. The fast path does not keep a
        ; second copy of its address: rebuilding it here happens once,
        ; when the bomb has left, not on the frame that draws it.
        ld a,(wheel_pr0)
        ld b,a
        ld a,(wheel_pc0)
        ld c,a
        call attr_addr
        ld a,(wheel_pc1)
        sub c
        inc a
        ld c,a                      ; width in cells
        ld a,(wheel_pr1)
        sub b
        inc a
        ld b,a                      ; height in cells
        ld d,WATER_ATTR
        call wheel_fill_hl
        call wheel_fix_title
        xor a
        ld (wheel_attr_n),a
        ld (wheel_shown),a
        ret

;------------------------------------------------------------------------------
; wheel_attr_box - the character cells this bomb covers
; Out: Z if it is waiting, or fully off the screen.
;      NZ, and wheel_c0..wheel_c1, wheel_r0..wheel_r1 are inclusive.
;      The bottom row is never the seaweed. Pixel 168 is the first
;      pixel of character row 21, and the box stops at row 20.
; x between 0 and 255 is the short path. That is every frame where the
; whole bomb is on the screen, which is the slow frame. Hanging off
; the left or the right is the longer path under it.
; Corrupts: AF, DE, HL
;------------------------------------------------------------------------------
wheel_attr_box:
        ld a,(wheel_phase)
        or a
        ret z

        ld hl,(wheel_x)
        bit 7,h
        jr nz,.negative
        ld a,h
        or a
        jr z,.on_screen
        xor a                   ; x >= 256, still off the right
        ret

.on_screen:
        ld a,l
        rrca
        rrca
        rrca
        and 31
        ld (wheel_c0),a
        ld a,l
        add a,WHEEL_WIDTH - 1
        jr nc,.last_ok
        ld a,255
.last_ok:
        rrca
        rrca
        rrca
        and 31
        ld (wheel_c1),a
        jr .rows

.negative:
        ld de,WHEEL_WIDTH
        add hl,de               ; x + width. Positive: a pixel is on.
        bit 7,h
        jr z,.some_left
        xor a
        ret
.some_left:
        ld a,h
        or l
        ret z
        xor a
        ld (wheel_c0),a
        ld hl,(wheel_x)
        ld de,WHEEL_WIDTH - 1
        add hl,de
        ld a,l
        rrca
        rrca
        rrca
        and 31
        ld (wheel_c1),a

.rows:  ld a,(wheel_y)
        rrca
        rrca
        rrca
        and 31
        ld (wheel_r0),a
        ld a,(wheel_y)
        add a,WHEEL_HEIGHT - 1
        cp BACK_ROW * 8
        jr c,.bottom_ok
        ld a,BACK_ROW * 8 - 1
.bottom_ok:
        rrca
        rrca
        rrca
        and 31
        ld (wheel_r1),a
        or 1                    ; NZ. Row 0 alone would leave A = 0.
        ret

;------------------------------------------------------------------------------
; wheel_paint_attrs - ink across the rectangle worked out just above
; The rectangle is already in wheel_c0..wheel_r1. Paper stays blue,
; because that is what the palette entries use. The title word is
; covered in the same ink for as long as the bomb sits on it, and
; wheel_fix_title brings the yellow back when the bomb moves off.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
wheel_paint_attrs:
        ; Attribute address of the top-left cell. Same arithmetic as
        ; attr_addr, written here so the repaint does not pay for a call.
        ld a,(wheel_r0)
        rrca
        rrca
        rrca
        ld l,a
        and %00000011
        or high ATTRS
        ld h,a
        ld a,l
        and %11100000
        ld c,a
        ld a,(wheel_c0)
        or c
        ld l,a
        ld (wheel_pat),hl

        ld a,(wheel_c1)
        ld c,a
        ld a,(wheel_c0)
        ld b,a
        ld a,c
        sub b
        inc a
        ld (wheel_pcols),a
        ld c,a                  ; C = columns

        ld a,(wheel_r1)
        ld b,a
        ld a,(wheel_r0)
        ld e,a
        ld a,b
        sub e
        inc a
        ld (wheel_prows),a
        ld b,a                  ; B = rows

        ld hl,(wheel_pat)       ; the width math used A, not HL, but be sure
        ld a,(wheel_ink)
        ld d,a
        call wheel_fill_hl
        jp wheel_remember

; Colour changed: the whole old rectangle goes back to water, then the
; whole new one is painted. This is rare (the drifting bomb does not
; change colour mid-flight). A one-pixel move uses wheel_delta instead.
wheel_full_recolour:
        call wheel_restore_attrs
        jp wheel_paint_attrs

;------------------------------------------------------------------------------
; wheel_remember - the rectangle just painted is the one to compare next
; Corrupts: AF, HL
;------------------------------------------------------------------------------
wheel_remember_fast:
        ld a,(wheel_ink)
        ld (wheel_shown),a
        ld a,1
        ld (wheel_attr_n),a
        ; Fall through. The fast path, which already knows the ink has
        ; not changed and a rectangle is on screen, enters here.
wheel_remember_edges:
        ; The new rectangle is four bytes in a row, and so is the copy
        ; kept for next frame, in the same order. Two word stores move
        ; all four. The order of the bytes inside the word does not
        ; matter: the same pair is written back.
        ld hl,(wheel_c0)
        ld (wheel_pc0),hl
        ld hl,(wheel_r0)
        ld (wheel_pr0),hl
        ret

wheel_remember:
        call wheel_remember_fast
        ; Address and size, for a later full restore.
        ld a,(wheel_r0)
        rrca
        rrca
        rrca
        ld l,a
        and %00000011
        or high ATTRS
        ld h,a
        ld a,l
        and %11100000
        ld c,a
        ld a,(wheel_c0)
        or c
        ld l,a
        ld (wheel_pat),hl
        ld a,(wheel_c1)
        ld c,a
        ld a,(wheel_c0)
        ld b,a
        ld a,c
        sub b
        inc a
        ld (wheel_pcols),a
        ld a,(wheel_r1)
        ld b,a
        ld a,(wheel_r0)
        ld c,a
        ld a,b
        sub c
        inc a
        ld (wheel_prows),a
        ret

; Paint one new row. B = row, D = ink.
wheel_paint_row:
        ld a,(wheel_c0)
        ld c,a
        ld a,(wheel_c1)
        sub c
        inc a
        ld e,a
        call wheel_solid_row
        ret

; Water back one old row. B = row.
wheel_water_row:
        ld a,(wheel_pc0)
        ld c,a
        ld a,(wheel_pc1)
        sub c
        inc a
        ld e,a
        call wheel_water_cells_row
        ret

; B = top row, C = column, E = number of rows, D = byte.
wheel_solid_col:
        call attr_addr
.cell:  ld (hl),d
        dec e
        ret z
        ld a,l
        add a,32
        ld l,a
        jr nc,.cell
        inc h
        jr .cell

; B = top row, C = column, E = number of rows. Water, or the title colour.
; The title word is the only cell above the seaweed that is not the
; water colour, so a strip that misses row 2 is a plain fill.
wheel_water_cells_col:
        ld a,b
        cp 3
        jr nc,.plain
        add a,e
        dec a                   ; bottom row
        cp 2
        jr c,.plain
        call attr_addr
        jr .titled
.plain: ld d,WATER_ATTR
        jp wheel_solid_col
.titled:
.cell:  ld a,b
        cp 2
        jr nz,.sea
        ld a,c
        cp TITLE_COL
        jr c,.sea
        cp TITLE_COL + TITLE_LEN
        jr nc,.sea
        ld (hl),TITLE_ATTR
        jr .step
.sea:   ld (hl),WATER_ATTR
.step:  dec e
        ret z
        inc b
        ld a,l
        add a,32
        ld l,a
        jr nc,.cell
        inc h
        jr .cell

; B = row, C = left column, E = number of columns, D = byte.
wheel_solid_row:
        call attr_addr
.cell:  ld (hl),d
        dec e
        ret z
        inc c
        inc l
        jr .cell

; B = row, C = left column, E = number of columns.
wheel_water_cells_row:
        ld a,b
        cp 2
        jr nz,.plain
        ld d,WATER_ATTR
        ; Fall into the titled loop only for row 2. Any other row is water.
        call attr_addr
        jr .titled
.plain: ld d,WATER_ATTR
        jp wheel_solid_row
.titled:
.cell:  ld a,b
        cp 2
        jr nz,.sea
        ld a,c
        cp TITLE_COL
        jr c,.sea
        cp TITLE_COL + TITLE_LEN
        jr nc,.sea
        ld (hl),TITLE_ATTR
        jr .step
.sea:   ld (hl),WATER_ATTR
.step:  dec e
        ret z
        inc c
        inc l
        jr .cell

;------------------------------------------------------------------------------
; wheel_fill_hl - write D across the rectangle
; In:  HL = first cell, B = rows, C = columns, D = the byte.
; Used for the first paint and for a colour change. A one-pixel move
; does not come here: it recolours the strip that changed, which is
; wheel_delta. A counted loop is fine on this rare path.
; A row of attributes can cross into the next page, so the carry is kept.
; Corrupts: AF, BC, HL
;------------------------------------------------------------------------------
wheel_fill_hl:
.row:   push bc
        push hl
.col:   ld (hl),d
        inc l
        dec c
        jr nz,.col
        pop hl
        ld a,l
        add a,32
        ld l,a
        jr nc,.next
        inc h
.next:  pop bc
        djnz .row
        ret

;------------------------------------------------------------------------------
; wheel_fix_title - the title word's colour, if the old rectangle covered it
; The word is row 2, columns 12 to 19 ("ATLANTIS" printed at column 12).
; The water fill has already run, so those cells are blue-and-white
; until this puts the yellow back. No other cell above the seaweed
; has a different colour: the help line and the hint are the water
; colour, and the digits do not change attributes.
; Corrupts: AF, BC, HL
;------------------------------------------------------------------------------
wheel_fix_title:
        ld a,(wheel_pr0)
        cp 3
        ret nc                  ; old rectangle starts below the title
        ld a,(wheel_pr1)
        cp 2
        ret c                   ; old rectangle ends above the title
        ld a,(wheel_pc1)
        cp TITLE_COL
        ret c                   ; entirely to the left of the word
        ld a,(wheel_pc0)
        cp TITLE_COL + TITLE_LEN
        ret nc                  ; entirely to the right of the word
        ld b,2
        ld a,(wheel_pc0)
        cp TITLE_COL
        jr nc,.colok
        ld a,TITLE_COL
.colok: ld c,a
        call attr_addr          ; HL = first title cell we overwrote
        ld a,(wheel_pc1)
        cp TITLE_COL + TITLE_LEN
        jr c,.endok
        ld a,TITLE_COL + TITLE_LEN - 1
.endok: sub c
        inc a
        ld b,a
        ld a,TITLE_ATTR
.cell:  ld (hl),a
        inc l
        djnz .cell
        ret

TITLE_COL       equ 12          ; column where "ATLANTIS" is printed
TITLE_LEN       equ 8

;------------------------------------------------------------------------------
wheel_on_row0:
        ld a,(wheel_phase)
        or a
        ret z
        ld a,(wheel_y)
        cp 8
        jr c,.xchk
        xor a
        ret
.xchk:  ld hl,(wheel_x)
        ld a,h
        or a
        jr z,.on                ; x is 0..255, so at least one pixel shows
        bit 7,h
        jr z,.off               ; x >= 256: still off the right
        ld de,WHEEL_WIDTH
        add hl,de               ; x + width. Positive means a pixel is on.
        bit 7,h
        jr nz,.off
        ld a,h
        or l
        jr z,.off               ; x + width = 0: the last pixel just left
.on:    ld a,1
        or a
        ret
.off:   xor a
        ret

; --- State -------------------------------------------------------------------
wheel_kind:     db WHEEL_KIND_DRIFT
wheel_phase:    db WHEEL_FLY
; Starts just off the right, so the first thing the player sees is it
; sliding in, not popping into existence. The first height is fixed
; (table entry 0). Later heights come from the LFSR.
wheel_x:        dw 256
wheel_y:        db 36           ; matches the base; bob[0] is 0
wheel_base:     db 36
wheel_bob_i:    db 0
wheel_frame:    db 0
wheel_spin_n:   db 0
wheel_delay:    db 0
wheel_seed:     db 42

; Eight bases. Entry 0 is the first bomb (no LFSR yet): deep enough to
; meet the diver as he drops back from the surface, not so high that it
; sits on row 0 while the soak is checking his photograph.
; Entry 5 is the first LFSR height (seed 42 -> 21, low 3 bits = 5): the
; fish swims at pixel 76, and a bomb at 70 overlaps him at every point
; of the bob.
; Entry 2 is the second LFSR height: the surface. The bob reaches y = 0,
; so the stat digits can sit on top of it.
wheel_heights:
        db 36                   ; 0  diver's depth on the way down
        db 100                  ; 1
        db WHEEL_TOP_BASE       ; 2  surface
        db 120                  ; 3
        db 50                   ; 4
        db 70                   ; 5  fish
        db 24                   ; 6
        db WHEEL_LOW_BASE       ; 7  one pixel of bob above the seaweed

; Rounded sine, amplitude WHEEL_BOB, 32 steps. It holds at the top and
; the bottom for two frames, which is the shape of a sine and not of a
; straight up-and-down. Stored as signed offsets from the base.
wheel_bob:
        db 0, 1, 2, 3, 4, 5, 5, 6
        db 6, 5, 5, 4, 3, 2, 1, 0
        db 0,-1,-2,-3,-4,-5,-5,-6
        db -6,-5,-5,-4,-3,-2,-1, 0

; Ink for this bomb. An index into the table, not the attribute byte
; itself, so another bomb can use another entry without a second copy
; of the drawing code. 0 is the drifting bomb on screen today.
wheel_colour:   db 0

; Bright red on the blue of the water. White is the diver, the fish and
; the open water, so a white bomb would disappear into them. Paper is
; blue in every entry: the sea does not change colour. To recolour the
; bomb, change the byte below. For a second colour, add another db and
; store 1 in wheel_colour (a homing bomb would do that).
wheel_palette:
        db BRIGHT | RED | (BLUE << 3)

; The attribute byte last chosen from the table. The soak reads this
; when the bomb is on row 0. It matches the palette until a draw
; resolves a new index.
wheel_ink:      db BRIGHT | RED | (BLUE << 3)

; Non-zero once a rectangle has been painted. The bytes on screen are
; not stored: open water is put back as the water colour, and the title
; word is put back as TITLE_ATTR. wheel_pc0..wheel_pr1 is that rectangle.
; wheel_shown is the ink byte last written, so a change of wheel_colour
; is seen on the next frame even when the rectangle stays put.
wheel_attr_n:   db 0
wheel_shown:    db 0
wheel_pc0:      db 0
wheel_pc1:      db 0
wheel_pr0:      db 0
wheel_pr1:      db 0
; Address and size of that rectangle, so putting the water back does
; not work the address out a second time.
wheel_pat:      dw 0
wheel_prows:    db 0
wheel_pcols:    db 0

; Scratch for the attribute box of the bomb as it is this frame.
wheel_c0:       db 0
wheel_c1:       db 0
wheel_r0:       db 0
wheel_r1:       db 0

wheel_bg:       ds BG_DATA + WHEEL_BYTES * WHEEL_HEIGHT
