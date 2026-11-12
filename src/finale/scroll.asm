;==============================================================================
; scroll.asm - Atlantis seabed
;
; Two speeds, three bands. The picture is in docs/SCROLLING.md. Short
; version, because the "why" is mostly "the demo's strips were taller
; than this, and the tall version did not fit in one frame":
;
;   SLOW  rows 21-22, one buffer. Weed on top of sand. 1 pixel every
;         2 frames. The plant is only drawn on a column whose sand is
;         the full 8 pixels, so it sits on the dune instead of floating.
;   FAST  row 23, its own buffer. Black ground, rocks, the bottom half
;         of a silo. 1 pixel every frame.
;   SILO  16 wide, 24 tall, one character row in each band. The base
;         is two columns of the fast buffer, so it stays nailed to the
;         ground. The tower (row 22) and the dome (row 21) are stamped
;         on after the copy, at the same fine scroll, from pictures
;         already shifted (gfx/silo.txt), so the three parts stay
;         joined. Each part is drawn in its own row's colours: black on
;         yellow, yellow on blue, and green on blue for the dome, whose
;         cells are painted the seaweed's colour (silo_cells). Nothing
;         clashes, even where a plant and a dome share a cell.

; Every frame copies all three bands, then rotates the fast buffer, and
; rotates the slow buffer on every other frame. The demo could not copy
; and rotate both of its 16-pixel strips in one frame, so it split the
; far strip into a show frame and a prepare frame. These strips are 8
; pixels of ground plus 16 of the slow layer, and the silo's upper
; parts are not a strip, so the split is not used. The numbers are in
; SCROLLING.md.
;
; PER FRAME (see main_loop):
;   1. restore both sprites
;   2. draw anyone still above row 21
;   3. copy the slow buffer (weed, then sand)
;   4. stamp the silo towers and domes onto the sand and the weed
;   5. copy the ground
;   6. draw the diver if his feet are on the seabed, so he saves THIS ground
;   7. rotate the ground buffer
;   8. rotate the slow buffer, every other frame
;
; Restore is first for the same reason as the demo. The copy replaces
; the seabed completely, so a photograph taken before the copy is last
; frame's ground.
;
; SILOS
; The fast strip is a ring of 32 tile ids, plus the column still sliding
; in from the right.
;
;   screen x of the left edge of aligned column i  =  i*8 - front_fine
;   tile of aligned column i                        =  front_tiles[(front_head+i) & 31]
;   solid height of that column                     =  front_h[(front_head+i) & 31]
;   world column of screen column i                 =  front_origin + i
;
; front_fine is 0..7. front_head is the slot under the left edge of the
; screen. Aligned column 32 is front_pending / front_h_pending: it is not
; in the ring until front_fine wraps, and its world column is
; front_origin+32. A silo is two columns: TILE_SILO (2), the left half,
; then TILE_SILO_R (3). Both are SILO_H (24) tall, dome included, so the
; diver touches the top of the dome, pixel y = NEAR_BOTTOM - 24 = 168,
; the top of row 21.
;
; level_silo_gap and level_index are the demo's table. Poke level_index
; (0 .. LEVEL_COUNT-1) before scroll_init. Column N is a silo when
; N mod gap = 0, and N+1 is its right half. Rocks are column mod 10 = 4,
; unless that column was already part of a silo.
;==============================================================================

TILE_FLAT       equ 0
TILE_ROCK       equ 1
TILE_SILO       equ 2           ; the left half
TILE_SILO_R     equ 3           ; the right half
TILE_WEED       equ 1           ; slow-strip id. Flat is 0 on both strips.
                                ; Same number as TILE_ROCK, different strip.

; Columns from one silo to the next. The demo's table, including level 0.
LEVEL_COUNT     equ 4
level_silo_gap: db 24, 16, 12, 8
level_index:    db 0

; A weed graphic's set pixels are inset from the cell: 2 clear pixels on
; the left, 1 on the right (see pat_weed). While the cell is scrolling,
; the plant only spills into the next cell once the scroll passes that
; padding. The attribute update uses these so it does not paint a green
; cell the plant has not reached, and does not leave a set pixel in a
; water-coloured cell.
WEED_SPILL_AT   equ 3           ; fine >= this: the plant enters the left cell
WEED_LEAVE_AT   equ 7           ; fine >= this: no set pixel remains in its own cell

        COLD
;------------------------------------------------------------------------------
; slope_build - the sloped tops of the ground and the sand, at start-up
; Each of a profile's 16 columns gets 8 bytes, top row first. Its height
; runs from its own (h0) at its left pixel to the next column's (h1) at
; its right on an S-curve (slope_curve), and a pixel is solid where the
; curve is at least that row, to the nearest half pixel. The curve is
; flat at both ends, so where a rise meets a fall the top is rounded,
; not a point, and a step becomes a smooth bank. A flat column (h0 = h1)
; is exactly the old block. The columns are built from these tables as
; they scroll in (slope_copy), so the frame does no more than before.
; v(x) = 16 h0 + (h1 - h0) w(x) is the height at pixel x's middle, in
; 16ths; row L is solid where v >= 16 L - 8.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
; w(x) out of 16 at each pixel's middle: smoothstep, 3t^2 - 2t^3, at
; t = (2x + 1) / 16, rounded, then the end mark. A straight line would
; be 1, 3, 5 ... 15.
slope_curve:    db 0, 1, 4, 7, 9, 12, 15, 16, $FF

slope_build:
        ld hl,near_profile
        ld de,SLOPE_GROUND
        call .prof
        ld hl,far_profile
        ld de,SLOPE_SAND
.prof:  ld c,0                  ; the column
.col:   ld a,c
        call .at
        ld b,a                  ; h0
        ld a,c
        inc a
        and 15
        call .at                ; h1
        sub b                   ; d
        push hl
        push de
        ld l,a
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        ld h,a                  ; 16 h0
        ld de,slope_curve
        ld ix,preshift_row      ; 8 bytes of start-up scratch
.v:     ld a,(de)
        inc de
        ld b,a
        inc b
        jr z,.vdone             ; the end mark
        ld a,h
        jr .wn
.w:     add a,l                 ; d, w times
.wn:    djnz .w
        ld (ix+0),a
        inc ix
        jr .v
.vdone: pop de
        ld h,8 * 16 - 8         ; the top row's threshold
.row:   ld ix,preshift_row
        ld b,0
        ld l,8
.px:    ld a,(ix+0)
        inc ix
        cp h
        ccf                     ; carry: solid
        rl b
        dec l
        jr nz,.px
        ld a,b
        ld (de),a
        inc de
        ld a,h
        sub 16
        ld h,a
        jr nc,.row              ; 120 down to 8: eight rows
        pop hl
        inc c
        ld a,c
        cp 16
        jr c,.col
        ret
; A = the profile's byte A, HL = the profile. Preserves HL.
.at:    push hl
        add a,l
        ld l,a
        jr nc,.in
        inc h
.in:    ld a,(hl)
        pop hl
        ret

;------------------------------------------------------------------------------
; scroll_init - first 32 columns, the column waiting off the right, one copy
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
scroll_init:
        ld a,(level_index)
        ld e,a
        ld d,0
        ld hl,level_silo_gap
        add hl,de
        ld a,(hl)
        ld (silo_gap),a

        ld hl,0
        ld (front_column),hl
        ld (back_column),hl
        ld (front_origin),hl    ; world column of the left edge
        ld (back_origin),hl
        xor a
        ld (front_fine),a
        ld (back_fine),a
        ld (front_head),a
        ld (back_head),a
        ld (slow_phase),a
        ld (silo_left),a        ; column 0 is a silo (0 mod gap = 0)
        ld (silo_right),a
        ld (silo_rest_n),a      ; nothing stamped on the weed row yet
        ld (silo_cells_n),a     ; and no dome cells painted
        dec a
        ld (silo_sig_s),a       ; $FF matches no ink pattern: the first stamp paints
        ld (weed_wait),a
        ld a,4
        ld (rock_left),a        ; a rock when the column mod 10 = 4
        ld a,3
        ld (weed_left),a        ; first weed *try* at column 3, as the demo

        xor a
.fillf: ld (init_col),a
        ld hl,column_pat
        ld (pat_dest),hl
        call next_front_tile
        ld (init_tile),a
        ld a,(init_col)
        ld e,a
        ld d,0
        ld hl,front_tiles
        add hl,de
        ld a,(init_tile)
        ld (hl),a
        ld hl,front_h
        add hl,de
        ld a,(column_h)
        ld (hl),a
        ld a,(init_col)
        ld hl,GROUND_BUF
        ld b,GROUND_PX
        call stamp_column
        ld a,(init_col)
        inc a
        cp 32
        jr nz,.fillf

        ld hl,ground_feed
        ld (pat_dest),hl
        call next_front_tile    ; column 32, the one that enters from the right
        ld (front_pending),a
        ld a,(column_h)
        ld (front_h_pending),a

        xor a
.fillb: ld (init_col),a
        ld hl,column_pat
        ld (pat_dest),hl
        call next_back_tile
        ld (init_tile),a
        ld a,(init_col)
        ld e,a
        ld d,0
        ld hl,back_tiles
        add hl,de
        ld a,(init_tile)
        ld (hl),a
        ld a,(init_col)
        ld hl,BACK_BUF
        ld b,BACK_PX
        call stamp_column
        ld a,(init_col)
        inc a
        cp 32
        jr nz,.fillb

        ld hl,slow_feed
        ld (pat_dest),hl
        call next_back_tile
        ld (back_pending),a

        call silo_build         ; the short list stamp_silos walks
        ; Phase 1 makes scroll_blit copy the weed as well as the sand,
        ; and paint the weed colours. The loop leaves phase at 0 for a
        ; frame that only has to repair the sand, so put it back before
        ; returning to the loop.
        ld a,1
        ld (slow_phase),a
        call scroll_blit
        xor a
        ld (slow_phase),a
        ret

;------------------------------------------------------------------------------
; scroll_blit - put the buffers on screen, then the silo towers and domes.
;
; The slow buffer only changes every other frame (main_loop rotates it
; after this, when slow_phase is 0). On that frame the picture already
; on screen is this buffer: the sprites have been restored, so the weed
; does not need copying again. The sand row does, because last frame's
; silo towers are still drawn on it and the ground has moved. Copying
; just those 8 rows wipes them. The domes on the weed row are wiped by
; copying back only the bytes they covered (silo_unstamp), which is
; still the buffer's picture on this frame. The other frame
; (slow_phase != 0) is the one that shows the buffer the rotate just
; produced, so it copies all 16 and repaints the weed colours while it
; is there. The sand-only frame does not: the colours already match the
; pixels still on screen.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
; The sand is the bottom 8 rows of the slow buffer. The weed is the top 8.
SAND_BUF        equ BACK_BUF + 8 * 32

        HOT

scroll_blit:
        ; At 25 the idle frame shifts the slow buffer and sets the phase
        ; to 1, so every picture frame there takes this full copy.
        ld a,(slow_phase)
        or a
        jr z,.sand_only
        ld a,BACK_ROW * 8       ; weed, then the sand falls out in row 22
        ld b,BACK_PX
        ld hl,BACK_BUF
        call blit_rows
        ; Colours in the same breath as the pixels. The beam reaches row
        ; 21 while the rest of this frame is still copying sand and ground,
        ; so painting later would let it draw the new pixels with the old
        ; cell colour for one frame.
        call paint_weed_attrs
        jr .tops
.sand_only:
        call silo_unstamp
        ld a,SAND_ROW * 8
        ld b,8
        ld hl,SAND_BUF
        call blit_rows
.tops:  call stamp_silos
        ld a,GROUND_ROW * 8
        ld b,GROUND_PX
        ld hl,GROUND_BUF
        call blit_rows
        ret

;------------------------------------------------------------------------------
; scroll_shift_ground - rotate the ground one pixel. Every frame.
; Does not touch the screen. A new column is built on the wrap, into the
; feed the shifter has just finished with. 8 bytes, so it fits on that
; frame; the demo built its 16-byte column early because the wrap frame
; was already out of time.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
scroll_shift_ground:
        ld hl,GROUND_BUF
        ld de,ground_feed
        ld b,GROUND_PX
        call shift_rows_left

        ld a,(front_fine)
        inc a
        cp 8
        jr z,.wrap
        ld (front_fine),a
        ret
.wrap:
        xor a
        ld (front_fine),a
        ld hl,(front_origin)
        inc hl
        ld (front_origin),hl

        ; The slot that just left the screen becomes the new right-hand
        ; column. The pixels are already in the buffer (the shift put
        ; them there). This only files the id and the height.
        ld a,(front_head)
        ld e,a
        ld d,0
        ld hl,front_tiles
        add hl,de
        ld a,(front_pending)
        ld (hl),a
        ld hl,front_h
        add hl,de
        ld a,(front_h_pending)
        ld (hl),a
        ld a,e
        inc a
        and 31
        ld (front_head),a

        ld hl,ground_feed
        ld (pat_dest),hl
        call next_front_tile
        ld (front_pending),a
        ld a,(column_h)
        ld (front_h_pending),a
        jp silo_after_wrap      ; the list, now that the new pending exists

;------------------------------------------------------------------------------
; scroll_shift_slow - rotate weed and sand one pixel.
; Call on every other frame (main_loop flips slow_phase).
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
scroll_shift_slow:
        ld hl,BACK_BUF
        ld de,slow_feed
        ld b,BACK_PX
        call shift_rows_left

        ld a,(back_fine)
        inc a
        cp 8
        jr z,.wrap
        ld (back_fine),a
        ret
.wrap:
        xor a
        ld (back_fine),a
        ld hl,(back_origin)
        inc hl
        ld (back_origin),hl

        ld a,(back_head)
        ld e,a
        ld d,0
        ld hl,back_tiles
        add hl,de
        ld a,(back_pending)
        ld (hl),a
        ld a,e
        inc a
        and 31
        ld (back_head),a

        ld hl,slow_feed
        ld (pat_dest),hl
        call next_back_tile
        ld (back_pending),a
        ret

;------------------------------------------------------------------------------
; blit_rows - copy buffer rows onto screen rows
; In:  A = first pixel y (multiple of 8), B = rows (multiple of 8),
;      HL = buffer (32 bytes a row)
; Corrupts: AF, BC, DE, HL, IX
;
; This is the demo's blit_rows (src/scroll.asm), copied so that file can
; stay the Engine Demo 1 seabed. LDI unrolled, and INC D between the
; lines of one character cell, because that is what made the copy finish
; before the beam. LDIR was still running when the raster arrived.
;------------------------------------------------------------------------------
blit_rows:
.cell:  push bc
        push hl
        push af
        call row_table_entry
        ld e,(ix+0)
        ld d,(ix+1)
        pop af
        pop hl
        ld b,8
.line:  push bc
        push de
        dup 32
        ldi
        edup
        pop de
        inc d
        pop bc
        djnz .line
        pop bc
        add a,8
        ld c,a
        ld a,b
        sub 8
        ld b,a
        ld a,c
        jr nz,.cell
        ret

;------------------------------------------------------------------------------
; shift_rows_left - move a buffer left one pixel; the feed's bit 7 enters
; on the right.
; In:  HL = buffer, DE = feed (one byte per row), B = rows
; Out: HL = just past the buffer, DE = just past the feed
; Corrupts: AF, B
;
; The rotate itself is the demo's: RL (HL) then DEC L is 19 T-states a
; byte, and it is written out 32 times because a loop around one RL
; dropped the demo to 25 Hz. DEC L stays on the page because every row
; is 32 bytes on a 32-byte boundary and SCROLL_BASE is $F000.
;
; The demo calls a one-row block and saves the row count around that
; call. Nothing in the row uses the row count, so the save was only
; there to protect it from the call. Putting the row in line with the
; count removes the call, the return, and that save: 42 T-states a row
; on the common row (one less on the row that steps into the next page).
; The ground is 8 rows, every frame: 336 T-states, a scanline and a
; half. The weed and the sand are 16 more rows, every other frame:
; another 672 T-states. Both are after the screen copy, so the copy
; starts at the same moment as before. The seabed frame that draws the
; bomb while it is two bytes wide and half off the left was the one
; frame with no scanline to spare. This is where that time went.
;------------------------------------------------------------------------------
shift_rows_left:
.row:   push hl
        ld a,l
        add a,31
        ld l,a
        ld a,(de)
        rlca                    ; feed bit 7 -> carry, and into bit 0 of the feed
        ld (de),a
        inc de
        dup 31
        rl (hl)
        dec l
        edup
        rl (hl)
        pop hl
        ld a,l
        add a,32
        ld l,a
        jr c,.page              ; the next row starts on the next page
        djnz .row
        ret
.page:  inc h
        djnz .row
        ret

;------------------------------------------------------------------------------
; stamp_silos - draw every silo's dome (row 21) and tower (row 22)
;
; The ground buffer holds the base, already moved by front_fine. The
; dome and the tower are in no buffer. They are drawn here at the same
; fine scroll, from gfx/silo.asm, which holds the picture already
; shifted to each of the 8 pixel positions, so nothing is shifted at
; run time and the parts cannot come apart.
;
; A silo whose left half is aligned column n has its left pixel at
; x = n*8 - front_fine. Its picture is shift x & 7, three bytes a row,
; from column x >> 3: n when front_fine is 0, n-1 otherwise. A silo
; wholly on screen is drawn by that shift's own code (silo.asm), about
; 5 scanlines. One hanging off an edge goes through SILO_ROWS, the
; masked loop over the same picture as data, which leaves out the bytes
; that are off the screen.
;
; The old stamp shifted each row of an 8 x 8 top a bit at a time and
; wrote each byte through a call. With two silos on screen it cost up
; to 49 scanlines of the heavy seabed frame. The masked loop alone,
; on every silo, still left 11 of 512 seabed steps late at 50.
;
; silo_at lists the silos on screen, as the aligned column of the left
; half: -1 (only the right half is left) to 32 (the left half is still
; sliding in). The closest silos are 8 columns apart, so it holds at
; most five. silo_build fills it once at start-up, and silo_after_wrap
; keeps it when a column scrolls off.
;
; Each draw notes the weed-row bytes it covered (silo_rest) for
; silo_unstamp, and the cells its dome has ink in (silo_cells).
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
SILO_SCR21      equ $50A0       ; screen byte of row 21, top line, column 0
SILO_ATTR21     equ ATTRS + BACK_ROW * 32
SILO_ATTR22     equ SILO_ATTR21 + 32    ; Finale: the towers' row too
        ASSERT high SILO_ATTR22 == high (SILO_ATTR22 + 31)
        ASSERT (SILO_SCR21 & 31) == 0 && (SILO_ATTR21 & 31) == 0
        ASSERT (BACK_BUF & 255) == 0, "silo_unstamp walks the weed rows with L alone"

; Draw cnt bytes of every row, from byte j0 of the picture, at DE (row
; 21, top line). The dome's 8 lines, then the tower's 8, one character
; row down. Each byte: screen = (screen AND mask) OR data.
; 153 T-states a line for three bytes.
        MACRO SILO_ROWS j0, cnt
        IF j0 > 0
        ld bc,2 * j0
        add hl,bc
        ENDIF
        ld c,2                  ; the dome's row, then the tower's
1:      ld b,8
2:
        IF cnt > 1
        DUP cnt - 1
        ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc e
        EDUP
        ENDIF
        ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        IF cnt > 1
        DUP cnt - 1
        dec e
        EDUP
        ENDIF
        IF cnt < 3
        DUP SILO_ROW_BYTES - 2 * cnt
        inc hl                  ; the bytes this edge leaves out
        EDUP
        ENDIF
        inc d
        djnz 2B
        ld a,e
        add a,32                ; the next character row: rows 21 and 22
        ld e,a                  ; are in the same third, so no carry
        ld a,d
        sub 8
        ld d,a
        dec c
        jp nz,1B
        ENDM

stamp_silos:
        xor a
        ld (silo_rest_n),a
        ld a,(front_fine)
        neg
        and 7
        ld (silo_shift),a       ; one shift for every silo this frame
        ld c,a
        add a,a
        ld e,a
        ld d,0
        ld hl,silo_code_tab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (silo_code),de       ; the code that draws that shift
        ld l,c
        ld h,0
        add hl,hl               ; *2
        ld e,l
        ld d,h
        add hl,hl               ; *4
        add hl,de               ; *6
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; *96, SILO_PIC_BYTES
        ld de,silo_pics
        add hl,de
        ld (silo_pic),hl        ; and the same picture as data, for the edges
        ; The dome cells only change when the column origin does, or
        ; the shift moves the ink into another byte (2 or 3 frames in
        ; 8). Otherwise the cells painted last time still hold.
        ld hl,silo_cellbits
        ld a,c
        add a,l
        ld l,a
        ld a,0
        adc a,h
        ld h,a
        ld c,(hl)               ; which picture bytes have dome ink
        ld a,(front_origin)
        ld b,a
        ld hl,silo_sig_o
        xor (hl)
        ld (hl),b
        ld b,a                  ; 0 if the origin is the same
        ld a,c
        ld hl,silo_sig_s
        xor (hl)
        ld (hl),c
        or b
        ld (silo_cells_new),a   ; 0: the same cells as last time
        xor a
        ld (silo_new_n),a

        ld a,(silo_n)
        or a
        jr z,.done
        ld b,a
        ld hl,silo_at
.one:   push bc
        push hl
        ld a,(front_fine)
        or a
        ld a,(hl)               ; n
        jr z,.aligned
        dec a                   ; shifted: the first byte is one column left
.aligned:
        call silo_draw
        pop hl
        pop bc
        inc hl
        djnz .one
.done:  ld a,(silo_cells_new)
        or a
        ret z
        jp silo_cells_update

; Draw one silo. In: A = its first column, -2..32 (signed).
; Corrupts: AF, BC, DE, HL
silo_draw:
        cp 30
        jr nc,.edge             ; 30, 31, 32, and the negatives
        ld c,a
        ld b,3
        ld e,0
        call silo_note
        ld a,low SILO_SCR21
        or c
        ld l,a
        ld h,high SILO_SCR21
        ld de,(silo_code)
        push de
        ret                     ; into this shift's code, which returns
.edge:  cp 30
        jp z,.c30
        cp 31
        jp z,.c31
        cp -1
        jp z,.cm1
        cp -2
        ret nz                  ; 32: nothing on screen yet
        ld c,0                  ; -2: only the third byte, in column 0
        ld b,1
        ld e,2
        call silo_note
        call silo_screen
        ld hl,(silo_pic)
        SILO_ROWS 2, 1
        ret
.cm1:   ld c,0                  ; -1: the second and third bytes
        ld b,2
        ld e,1
        call silo_note
        call silo_screen
        ld hl,(silo_pic)
        SILO_ROWS 1, 2
        ret
.c30:   ld c,a                  ; the first two bytes
        ld b,2
        ld e,0
        call silo_note
        call silo_screen
        ld hl,(silo_pic)
        SILO_ROWS 0, 2
        ret
.c31:   ld c,a                  ; the first byte
        ld b,1
        ld e,0
        call silo_note
        call silo_screen
        ld hl,(silo_pic)
        SILO_ROWS 0, 1
        ret

; In: C = screen column. Out: DE = row 21's top line at that column.
silo_screen:
        ld a,low SILO_SCR21
        or c
        ld e,a
        ld d,high SILO_SCR21
        ret

; Note one silo's drawn place. In: C = first screen column, B = bytes,
; E = the first picture byte drawn (0..2). Preserves C.
; Corrupts: AF, B, DE, HL
silo_note:
        ld hl,silo_rest_n       ; the weed-row bytes, for silo_unstamp
        ld a,(hl)
        inc (hl)
        add a,a
        add a,low silo_rest
        ld l,a
        ld a,0
        adc a,high silo_rest
        ld h,a
        ld (hl),c
        inc hl
        ld (hl),b
        ld a,(silo_cells_new)
        or a
        ret z                   ; the dome cells have not changed
        ; The cells this dome has ink in: bit j of silo_cellbits is
        ; picture byte j. Start at byte E.
        ld hl,silo_cellbits
        ld a,(silo_shift)
        add a,l
        ld l,a
        ld a,0
        adc a,h
        ld h,a
        ld a,(hl)
        inc e
        jr .shift
.drop:  rrca                    ; the bytes left of the screen
.shift: dec e
        jr nz,.drop
        ld e,a
        ld a,c
        push bc
        ld c,a                  ; the column of this byte
.cell:  rr e
        jr nc,.next
        ld hl,silo_new_n
        ld a,(hl)
        inc (hl)
        add a,low silo_new
        ld l,a
        ld a,0
        adc a,high silo_new
        ld h,a
        ld (hl),c
.next:  inc c
        djnz .cell
        pop bc
        ret

;------------------------------------------------------------------------------
; silo_unstamp - wipe last frame's domes off the weed row
; Only on the frame that does not copy the weed. That frame's picture
; on screen is still the slow buffer (the rotate comes after it), so the
; bytes are copied back from there, and nothing had to be saved. The
; frame that copies the weed wipes them with the copy.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
silo_unstamp:
        ld a,(silo_rest_n)
        or a
        ret z
        ld ix,silo_rest
.one:   push af
        ld a,(ix+0)             ; first column
        ld l,a                  ; HL = the weed's top line in the buffer
        ld h,high BACK_BUF
        or low SILO_SCR21
        ld e,a
        ld d,high SILO_SCR21    ; DE = the same byte on the screen
        ld a,(ix+1)
        cp 3
        jr nz,.edge
        ld bc,$08FF             ; B = lines. C only keeps LDI off B.
.line3: ldi
        ldi
        ldi
        ld a,l
        add a,32 - 3            ; the next buffer line: rows 0-7 of the
        ld l,a                  ; buffer are one page, so no carry
        ld a,e
        sub 3
        ld e,a
        inc d
        djnz .line3
        jr .next
.edge:  ld c,a                  ; one or two bytes, at an edge
        ld b,8
.line:  push bc
        push de
        push hl
        ld b,0
        ldir
        pop hl
        pop de
        pop bc
        ld a,l
        add a,32
        ld l,a
        inc d
        djnz .line
.next:  inc ix
        inc ix
        pop af
        dec a
        jr nz,.one
        ret

;------------------------------------------------------------------------------
; The dome's colour. The dome is drawn in row 21, which is painted per
; cell: green on blue where a plant is, water elsewhere. Every cell a
; dome has ink in is painted green on blue as well, the seaweed's own
; colour, so a plant and a dome in one cell cannot clash. When the dome
; moves on, the cell gets back the colour paint_weed_attrs would give it.
;
; silo_cells is the list painted now. stamp_silos builds silo_new only
; when the origin has changed, or the shift has moved the ink into
; another byte (most frames the cells are the same), then silo_cells_update puts the old cells back and paints
; the new. paint_weed_attrs repaints the whole row, so it ends with
; silo_paint_cells.
;------------------------------------------------------------------------------
; Corrupts: AF, BC, DE, HL
silo_cells_update:
        ld a,(silo_cells_n)
        or a
        jr z,.paint
        ld b,a
        ld de,silo_cells
.old:   ld a,(de)
        ld c,a
        call weed_cell_attr     ; A = the colour without the dome
        ld l,c
        ld h,0
        push de
        ld de,SILO_ATTR21
        add hl,de
        pop de
        ld (hl),a
        ld a,l
        add a,32
        ld l,a
        ld (hl),SAND_ATTR       ; the tower's cell below: the hills' again
        inc de
        djnz .old
.paint: ld a,(silo_new_n)
        ld (silo_cells_n),a
        or a
        ret z
        ld c,a
        ld b,0
        ld hl,silo_new
        ld de,silo_cells
        ldir
        ; fall through

; Finale: the silo's colour on every cell in silo_cells, the dome's in
; row 21 and the tower's below it. Corrupts: AF, B, DE, HL
silo_paint_cells:
        ld a,(silo_cells_n)
        or a
        ret z
        ld b,a
        ld de,silo_cells
        ld h,high SILO_ATTR21
.cell:  ld a,(de)
        or low SILO_ATTR21
        ld l,a
        ld (hl),SILO_ATTR
        add a,32
        ld l,a
        ld (hl),SILO_ATTR
        inc de
        djnz .cell
        ret

; The colour paint_weed_attrs gives column C of row 21. It reads the
; same paint_tiles that routine filled, which still match the screen:
; the slow layer only moves on the frame that repaints them.
; In: C = column. Out: A = attribute. Preserves BC, DE.
weed_cell_attr:
        ld hl,paint_tiles
        ld a,l
        add a,c
        ld l,a
        jr nc,.got
        inc h
.got:   ld a,(back_fine)
        cp WEED_LEAVE_AT
        jr nc,.spill            ; fine >= 7: nothing of its own plant is left
        ld a,(hl)
        cp TILE_WEED
        jr z,.green
.spill: ld a,(back_fine)
        cp WEED_SPILL_AT
        jr c,.water
        inc hl
        ld a,(hl)               ; the next column (pending, for column 31)
        cp TILE_WEED
        jr z,.green
.water: ld a,WATER_ATTR
        ret
.green: ld a,WEED_ATTR
        ret

; Fill silo_at from the ring and the pending column. Init only.
; Corrupts: AF, BC, DE, HL
silo_build:
        xor a
        ld (silo_n),a
        ld b,0                  ; aligned column 0..32
.next:  ld a,b
        push bc
        call front_tile
        pop bc
        cp TILE_SILO
        call z,silo_append      ; appends B, and gives B back
        inc b
        ld a,b
        cp 33
        jr nz,.next
        ret

; In: B = aligned column. Preserves B. Ignores the call if the list is full.
silo_append:
        ld a,(silo_n)
        cp 8
        ret nc
        push bc
        ld e,a
        ld d,0
        ld hl,silo_at
        add hl,de
        pop bc
        ld a,b
        ld (hl),a
        ld hl,silo_n
        inc (hl)
        ret

; Called at the end of a ground wrap, after front_pending is the new one.
; Every silo moves one column left. One whose left half was already at
; -1 has gone: its right half was column 0, which has just left.
; Corrupts: AF, BC, DE, HL
silo_after_wrap:
        ld a,(silo_n)
        or a
        jr z,.maybe
        ld b,a
        ld hl,silo_at
        ld de,silo_at           ; compact back into the same list
        ld c,0
.one:   ld a,(hl)
        inc hl
        dec a                   ; one column to the left
        cp -2
        jr z,.skip              ; it was -1: the whole silo is off the left
        ld (de),a
        inc de
        inc c
.skip:  djnz .one
        ld a,c
        ld (silo_n),a
.maybe: ld a,(front_pending)
        cp TILE_SILO
        ret nz
        ld b,32                 ; the new pending is aligned column 32
        jp silo_append

; In: A = aligned column 0..32. Out: A = tile id. Corrupts: DE, HL.
front_tile:
        cp 32
        jr z,.pend
        ld hl,front_head
        add a,(hl)
        and 31
        ld e,a
        ld d,0
        ld hl,front_tiles
        add hl,de
        ld a,(hl)
        ret
.pend:  ld a,(front_pending)
        ret

; Same, for the slow strip. In: A = aligned column 0..32.
back_tile:
        cp 32
        jr z,.pend
        ld hl,back_head
        add a,(hl)
        and 31
        ld e,a
        ld d,0
        ld hl,back_tiles
        add hl,de
        ld a,(hl)
        ret
.pend:  ld a,(back_pending)
        ret

;------------------------------------------------------------------------------
; paint_weed_attrs - row 21, one cell per column, matching the pixels
; just copied.
;
; Green ink on blue paper where the plant has a set pixel, water
; everywhere else. Green on blue means a clear pixel is still the blue
; water, so a cell the plant only partly fills does not turn into a
; coloured block. The cell is green when:
;
;   back_fine <= 6 and this column's tile is a weed
;        (a set pixel of the plant is still inside the cell; the graphic
;         is clear on its rightmost pixel, so at fine 7 it has gone), or
;   back_fine >= 3 and the next column's tile is a weed
;        (the inset on the left of the graphic is 2 pixels, so the first
;         two steps of the scroll do not bring a set pixel across).
;
; Both can be true at once. That is one plant occupying two cells, which
; is the scroll, not a second plant. The spare cell has blue paper, so
; it looks like water until a sprite swims into it and turns green.
;
; The tiles live in a ring that starts at back_head, and the column still
; off the right is back_pending. Calling into that ring twice a cell did
; not leave enough of the frame. This copies the 32 tiles into column
; order, with the pending column in the extra byte, and then walks that
; list once. paint_tiles[i+1] is exactly "the next column".
; Every cell a silo's dome has ink in is then painted green as well.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
paint_weed_attrs:
        ld a,(back_head)
        ld e,a
        ld d,0
        ld hl,back_tiles
        add hl,de               ; column 0's tile
        ld a,32
        sub e                   ; bytes from here to the end of the ring
        ld c,a
        ld b,0
        ld de,paint_tiles
        ldir                    ; columns 0 .. (31-head)
        ld a,(back_head)
        or a
        jr z,.pend              ; head was 0: those 32 bytes were the lot
        ld c,a
        ld b,0
        ld hl,back_tiles
        ldir                    ; the wrapped columns, through column 31
.pend:  ld a,(back_pending)
        ld (de),a               ; column 32, so column 31 can see its neighbour

        ld b,BACK_ROW
        ld c,0
        call attr_addr
        ex de,hl                ; DE walks the attribute row
        ld hl,paint_tiles
        ld a,(back_fine)
        ld c,a
        ld b,32
.cell:  ld a,c
        cp WEED_LEAVE_AT
        jr nc,.spill            ; fine >= 7: nothing of our plant remains
        ld a,(hl)
        cp TILE_WEED
        jr nz,.spill
        ld a,WEED_ATTR
        jr .store               ; already green; the spill cannot change that
.spill: ld a,c
        cp WEED_SPILL_AT
        jr c,.water             ; fine <= 2: the next plant has not entered
        inc hl
        ld a,(hl)               ; the next column (pending, for column 31)
        dec hl
        cp TILE_WEED
        jr nz,.water
        ld a,WEED_ATTR
        jr .store
.water: ld a,WATER_ATTR
.store: ld (de),a
        inc de
        inc hl
        djnz .cell
        jp silo_paint_cells     ; the domes are green too

; --- which tile is the next world column? ------------------------------------
; Both routines consume one column and return the tile id in A.
; They fill the bytes at (pat_dest), top byte first.
;   fast column: 8 bytes, the ground row. column_h is the solid height
;                from the bottom of the screen (8 for a full ground row,
;                24 for either half of a silo: the tower and the dome are
;                stamped above it).
;   slow column: 16 bytes. Top 8 are the weed or zeros. Bottom 8 are the
;                sand. column_h is the sand height, 1..8, and is not stored:
;                the diver does not collide with sand.
;
; A silo every `silo_gap` columns, and its right half in the column after
; it. A rock every 10, when that column is not already part of a silo. Counting down is the demo's rule. Dividing on the
; frame a column arrives was part of what used to miss the interrupt.
;
; Seaweed tries on the same countdown the demo used (first try at column
; 3, then every 11). A try only plants when the sand in THAT column is
; the full 8 pixels. Otherwise it waits for the next full column, so the
; plant is never drawn with water between it and the dune. With this
; profile those columns are 4, 20, 36, ... — the peaks, 16 apart.

next_front_tile:
        ld hl,(front_column)
        ld a,l
        and 15
        ld (front_prof_i),a     ; build_front_pat's slope (slope_build)
        ld e,a
        ld d,0
        ld hl,near_profile
        add hl,de
        ld a,(hl)
        ld (column_h),a

        ld hl,(front_column)
        inc hl
        ld (front_column),hl

        ; The rock countdown advances on silo columns too, so the rocks
        ; stay on 4, 14, 24, ... even when a silo takes one of them.
        xor a
        ld (rock_hit),a
        ld a,(rock_left)
        or a
        jr z,.rock_now
        dec a
        ld (rock_left),a
        jr .silo
.rock_now:
        ld a,9                  ; the next rock is 10 columns after this one
        ld (rock_left),a
        inc a
        ld (rock_hit),a
.silo:  ld a,(silo_right)
        or a
        jr nz,.silo_r           ; the column after a silo is its right half
        ld a,(silo_left)
        or a
        jr z,.silo_now
        dec a
        ld (silo_left),a
        ld a,(rock_hit)
        or a
        jr nz,.rock
        xor a                   ; TILE_FLAT
        jp build_front_pat
.rock:  ld a,TILE_ROCK
        jp build_front_pat
.silo_now:
        ld a,(silo_gap)
        dec a
        ld (silo_left),a
        ld a,1
        ld (silo_right),a
        ld a,TILE_SILO
        jp build_front_pat
.silo_r:
        xor a
        ld (silo_right),a
        ld hl,silo_left         ; it counts towards the next silo, as any
        dec (hl)                ; column does. The gap is at least 8.
        ld a,TILE_SILO_R
        jp build_front_pat

next_back_tile:
        ld hl,(back_column)
        ld a,l
        and 15
        ld (back_prof_i),a
        ld e,a
        ld d,0
        ld hl,far_profile
        add hl,de
        ld a,(hl)
        ld (column_h),a

        ld hl,(back_column)
        inc hl
        ld (back_column),hl

        ; Top 8 zeros (no plant yet), then the sand in the bottom 8.
        ld de,(pat_dest)
        xor a
        ld b,8
.zw:    ld (de),a
        inc de
        djnz .zw
        ld a,(back_prof_i)      ; the sand, its top sloped towards the
        ld hl,SLOPE_SAND        ; next column's (slope_build)
        call slope_copy         ; DE is the sand half. Advances past it.

        ld a,(weed_wait)
        or a
        jr nz,.try
        ld a,(weed_left)
        or a
        jr z,.try
        dec a
        ld (weed_left),a
        xor a                   ; TILE_FLAT
        ret
.try:           ld a,(column_h)
        cp 8                    ; a plant only on a dune that fills the sand row
        jr nz,.wait
        ; One of the four plants (udg.asm), from weed_seed: 0 the fir,
        ; 1 the kelp, 2 the fan coral, 3 the sea grass.
        ld a,(weed_seed)
        srl a                   ; the same Galois step as wheel_rng
        jr nc,.keep
        xor $B8
.keep:  ld (weed_seed),a
        and 3
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,weed_pics
        add hl,de
        ld de,(pat_dest)        ; plant into the top 8, on top of the dune
        REPT 8
        ldi
        ENDR
        ld a,10                 ; next TRY is 11 columns on
        ld (weed_left),a
        xor a
        ld (weed_wait),a
        ld a,TILE_WEED
        ret
.wait:  ld a,1                  ; remember, and plant on the next full dune
        ld (weed_wait),a
        xor a
        ld (weed_left),a
        ret                     ; TILE_FLAT

; --- pixels for one fast column ----------------------------------------------
; A flat column is column_h solid bytes at the bottom of the 8, zeros
; above. A rock is OR-ed on top of that and may raise the height to
; ROCK_H. A silo half REPLACES the 8 bytes with its half of the base,
; rows 16-23 of gfx/silo.txt, and reports height SILO_H. The tower and
; the dome are not stored here; stamp_silos draws them.

build_front_pat:
        ld (build_tile),a
        cp TILE_SILO
        jr nc,.silo             ; either half
        cp TILE_ROCK
        jr z,.rock
        ld de,(pat_dest)
        ld a,(front_prof_i)
        ld hl,SLOPE_GROUND
        call slope_copy
        jr .id
.rock:  ld de,(pat_dest)
        ld a,(front_prof_i)
        ld hl,SLOPE_GROUND
        call slope_copy
        ld hl,pat_rock
        ld de,(pat_dest)
        ld b,GROUND_PX
.or:    ld a,(de)
        or (hl)
        ld (de),a
        inc hl
        inc de
        djnz .or
        ld a,(column_h)
        cp ROCK_H
        jr nc,.id
        ld a,ROCK_H
        ld (column_h),a
        jr .id
.silo:  ld hl,silo_base_l       ; the base, silo.asm
        jr z,.half
        ld hl,silo_base_r
.half:  ld de,(pat_dest)
        ld b,GROUND_PX
        call copy_bytes
        ld a,SILO_H
        ld (column_h),a
.id:    ld a,(build_tile)
        ret

; The column's 8 bytes from a slope table: HL = SLOPE_GROUND or
; SLOPE_SAND, A = its profile index (0..15), DE = where. Advances DE
; past them. Corrupts: AF, BC, HL
slope_copy:
        add a,a
        add a,a
        add a,a
        add a,l
        ld l,a                  ; neither table crosses a page (layout.asm)
        REPT 8                  ; 128 T-states: no slower than the old fill
        ldi
        ENDR
        ret

; Stamp column_pat down one buffer column.
; In:  HL = buffer, A = column 0..31, B = pixel rows. Corrupts: AF, BC, DE, HL
stamp_column:
        ld e,a
        ld d,0
        add hl,de
        ld de,column_pat
.row:   ld a,(de)
        ld (hl),a
        inc de
        push bc
        ld bc,32
        add hl,bc
        pop bc
        djnz .row
        ret

; HL -> src, DE -> dest, B = count. Corrupts AF, BC, DE, HL.
copy_bytes:
        ld a,(hl)
        inc hl
        ld (de),a
        inc de
        djnz copy_bytes
        ret

; --- profiles ----------------------------------------------------------------
; Pixels of solid colour from the bottom of that row, repeating every
; 16 columns. 8 fills the row. The two shapes are different so the sand
; does not trace the ground.
;
; Sand is low at indexes 0 and 8. Silos land on those columns (gap 24
; hits 0, 24, 48, 72, ... which is index 0, 8, 0, 8, ...), so the yellow
; top of a silo stands up out of the dune instead of disappearing into
; an 8-pixel sand fill. Indexes 4, 5 and 6 are the full 8: that is where
; the seaweed countdown finds a dune to sit on.
;
;        0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
far_profile:
        db 2, 3, 4, 6, 8, 8, 8, 5, 2, 3, 4, 5, 6, 4, 3, 3

; Ground. A silo (height 16) replaces its column, so the profile value
; under a silo is never drawn. Index 4 is a rock column and is shorter
; than ROCK_H, so the first rock stands proud of the hill.
near_profile:
        db 3, 4, 5, 6, 4, 7, 8, 7, 5, 4, 3, 2, 2, 3, 4, 5

; --- fixed shapes ------------------------------------------------------------
; Bit 7 is the leftmost pixel. Top byte is the top pixel row.
; The silo is gfx/silo.txt.

; pat_rock and the seaweed (weed_pics) are in the UDG area: udg.asm.

; --- state -------------------------------------------------------------------
silo_gap:       db 0
silo_left:      db 0            ; columns until the next silo (0 = this one)
rock_left:      db 0
rock_hit:       db 0
weed_left:      db 0            ; columns until the next weed try
weed_wait:      db 0            ; 1 = a try missed its dune; plant on the next full one
; paint_tiles: in bss.asm (zeroed at start-up, not on the tape)  ; columns 0..31 in order, then the pending column
silo_right:     db 0            ; 1 = the next column is a silo's right half
silo_n:         db 0            ; how many silos are in silo_at (0..8)
; silo_at: in bss.asm (zeroed at start-up, not on the tape)  ; their left halves' aligned columns, -1..32
silo_shift:     db 0            ; the picture's shift this frame
silo_pic:       dw 0            ; row 0 of the picture at that shift
silo_code:      dw 0            ; the code that draws that shift
silo_rest_n:    db 0            ; domes drawn on the weed row
; silo_rest: in bss.asm (zeroed at start-up, not on the tape)  ; their first column and byte count
silo_sig_o:     db 0            ; front_origin and the dome's ink bytes,
silo_sig_s:     db 0            ; when its cells were last worked out
silo_cells_new: db 0            ; 0 = the same cells as last frame
silo_cells_n:   db 0            ; dome cells painted green now
; silo_cells: in bss.asm (zeroed at start-up, not on the tape)
silo_new_n:     db 0            ; this frame's cells, while they are built
; silo_new: in bss.asm (zeroed at start-up, not on the tape)

front_column:   dw 0            ; next world column next_front_tile will issue
back_column:    dw 0
front_origin:   dw 0            ; world column of the left edge (the head slot)
back_origin:    dw 0
front_fine:     db 0            ; 0..7 pixels scrolled since columns lined up
back_fine:      db 0
slow_phase:     db 0            ; flipped by main_loop; 1 = shift the slow layer

front_head:     db 0            ; slot index of the leftmost column
back_head:      db 0
front_pending:  db 0            ; tile id of the column entering on the right
back_pending:   db 0
front_h_pending: db 0           ; its solid height (the diver's clamp, right edge)
; front_tiles: in bss.asm (zeroed at start-up, not on the tape)
; front_h: in bss.asm (zeroed at start-up, not on the tape)  ; solid pixels from the bottom of the screen
; back_tiles: in bss.asm (zeroed at start-up, not on the tape)

; ground_feed: in bss.asm (zeroed at start-up, not on the tape)  ; pixels still to shift in, bit 7 next
; slow_feed: in bss.asm (zeroed at start-up, not on the tape)

column_h:       db 0
front_prof_i:   db 0            ; the new column's profile index (its slope)
back_prof_i:    db 0
weed_seed:      db $5A          ; which plant: its own shift register. Never 0.
pat_dest:       dw column_pat
; column_pat: in bss.asm (zeroed at start-up, not on the tape)  ; top byte first. The ground uses the first 8.
build_tile:     db 0
init_col:       db 0
init_tile:      db 0
