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
;   SILO  16 pixels. The bottom 8 travel in the fast buffer, so they
;         stay nailed to the column. The top 8 are stamped onto row 22
;         after the sand is copied, using the same fine-scroll, so the
;         two halves stay joined. Stamping is a few columns, not another
;         full-width rotate. A fourth strip did not leave enough of the
;         frame. Row 22 keeps its sand colours, so the top half is drawn
;         yellow on blue. That is the clash, on purpose.
;
; Every frame copies all three bands, then rotates the fast buffer, and
; rotates the slow buffer on every other frame. The demo could not copy
; and rotate both of its 16-pixel strips in one frame, so it split the
; far strip into a show frame and a prepare frame. These strips are 8
; pixels of ground plus 16 of the slow layer, and the silo top is not a
; strip, so the split is not used. The numbers are in SCROLLING.md.
;
; PER FRAME (see main_loop):
;   1. restore both sprites
;   2. draw anyone still above row 21
;   3. copy the slow buffer (weed, then sand)
;   4. stamp silo tops onto the sand
;   5. copy the ground
;   6. draw the diver if his feet are on the seabed, so he saves THIS ground
;   7. rotate the ground buffer
;   8. rotate the slow buffer, every other frame
;
; Restore is first for the same reason as the demo. The copy replaces
; the seabed completely, so a photograph taken before the copy is last
; frame's ground.
;
; SILOS, FOR LATER (missiles are not in this version)
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
; front_origin+32. TILE_SILO (2) is a silo. Its height is 16, hatch
; included: the clear bits in the picture are not a gap. The top of that
; column on screen is pixel y = NEAR_BOTTOM - 16 = 176, the top of row 22.
; The bytes are pat_silo, top byte first. The art is a placeholder.
;
; level_silo_gap and level_index are the demo's table. Poke level_index
; (0 .. LEVEL_COUNT-1) before scroll_init. Column N is a silo when
; N mod gap = 0. Rocks are column mod 10 = 4, unless that column was
; already a silo.
;==============================================================================

TILE_FLAT       equ 0
TILE_ROCK       equ 1
TILE_SILO       equ 2
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
; scroll_blit - put the buffers on screen, then the silo tops.
;
; The slow buffer only changes every other frame (main_loop rotates it
; after this, when slow_phase is 0). On that frame the picture already
; on screen is this buffer: the sprites have been restored, so the weed
; does not need copying again. The sand row does, because last frame's
; silo tops are still drawn on it and the ground has moved. Copying just
; those 8 rows wipes them. The other frame (slow_phase != 0) is the one
; that shows the buffer the rotate just produced, so it copies all 16
; and repaints the weed colours while it is there. The sand-only frame
; does not: the colours already match the pixels still on screen.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
; The sand is the bottom 8 rows of the slow buffer. The weed is the top 8.
SAND_BUF        equ BACK_BUF + 8 * 32

scroll_blit:
        ; At 25 the picture is drawn every other television frame, and
        ; the slow shift lands on the frame that is not drawn. A sand-only
        ; copy would move the dune and leave the plant where it was.
        ld a,(step_ticks)
        cp 2
        jr z,.both
        ld a,(slow_phase)
        or a
        jr z,.sand_only
.both:
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
; stamp_silos - OR every silo's top 8 pixels onto row 22
;
; The ground buffer holds the BOTTOM 8 bytes of pat_silo, and the shift
; has already moved them by front_fine. The top 8 bytes are not in that
; buffer. This draws them at the same fine-scroll so the picture is one
; column, not two.
;
; Aligned column n (the column the silo occupies when front_fine is 0)
; is slot (front_head + n) & 31, or front_pending when n is 32. After k
; pixels of left scroll its screen x is n*8 - k. An 8-pixel column
; shifted left by k lands in column n-1 (the bits that fell off) and
; column n (the rest). k = 0 stays entirely in column n. n = 32 is the
; column still entering: only its spill, in column 31, is on screen.
;
; Worked example, hatch byte %00100100, k = 4:
;   bits that fall off the left  ->  %00000010  in column n-1
;   bits that remain             ->  %01000000  in column n
; The routine builds those two bytes with the same RL the buffer uses,
; so it cannot disagree with the half that is already on row 23.
;
; Walking all 33 columns every frame, and calling front_tile for each,
; did not fit. The closest silos are 8 columns apart, so at most five of
; them (plus the one still off the right) are in this window. silo_at is
; that list. silo_build fills it once at start-up. silo_after_wrap keeps
; it when a column scrolls off: every entry moves one column left, a 0
; falls off, and the new pending column is appended if it is a silo.
;
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
stamp_silos:
        ld a,(silo_n)
        or a
        ret z
        ld b,a
        ld hl,silo_at
.one:   push bc
        push hl
        ld a,(hl)
        ld (stamp_n),a
        call stamp_one_silo
        pop hl
        pop bc
        inc hl
        djnz .one
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
        or a
        jr z,.skip              ; aligned column 0 has left the screen
        dec a                   ; every other column moves one to the left
        ld (de),a               ; (32, the old pending, becomes 31)
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

stamp_one_silo:
        ld a,SAND_ROW * 8
        call row_table_entry
        ld e,(ix+0)
        ld d,(ix+1)             ; DE = leftmost byte of the top sand line
        ld hl,pat_silo
        ld b,8
.row:   push bc
        push de
        push hl
        ld a,(hl)               ; this row of the silo top
        call silo_split         ; stamp_hi = column n, stamp_lo = column n-1
        ld a,(front_fine)
        or a
        jr z,.aligned

        ld a,(stamp_n)
        or a
        jr z,.main              ; n = 0: the spill is off the left edge
        dec a
        ld c,a
        ld a,(stamp_lo)
        call or_col
.main:  ld a,(stamp_n)
        cp 32
        jr nc,.done             ; n = 32: the unspilled half is off the right
        ld c,a
        ld a,(stamp_hi)
        call or_col
        jr .done

.aligned:
        ld a,(stamp_n)
        cp 32
        jr nc,.done
        ld c,a
        ld a,(stamp_hi)
        call or_col
.done:  pop hl
        pop de
        pop bc
        inc hl
        inc d                   ; next line of this same character cell
        djnz .row
        ret

; In: A = pattern byte. front_fine = k.
; Out: stamp_hi / stamp_lo set. Corrupts: AF, BC.
silo_split:
        ld c,a
        ld a,(front_fine)
        or a
        jr z,.zero
        ld b,a
        ld a,c
        ld c,0
.sl:    add a,a                 ; bit 7 falls into the carry: it has left this column
        rl c                    ; and joins the spill, leftmost bit first
        djnz .sl
        ld (stamp_hi),a
        ld a,c
        ld (stamp_lo),a
        ret
.zero:  ld a,c
        ld (stamp_hi),a
        xor a
        ld (stamp_lo),a
        ret

; OR A onto the screen row at DE, column C. C >= 32 is off screen: skip.
; Corrupts: AF, B. Preserves C, DE, HL.
or_col:
        ld b,a
        ld a,c
        cp 32
        ret nc
        push de
        add a,e                 ; low 5 bits of a row address are 0, and
        ld e,a                  ; the column fits in them, so this cannot carry
        ld a,(de)
        or b
        ld (de),a
        pop de
        ret

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
        ret

; --- which tile is the next world column? ------------------------------------
; Both routines consume one column and return the tile id in A.
; They fill the bytes at (pat_dest), top byte first.
;   fast column: 8 bytes, the ground row. column_h is the solid height
;                from the bottom of the screen (8 for a full ground row,
;                16 for a silo — the extra 8 are the stamped top).
;   slow column: 16 bytes. Top 8 are the weed or zeros. Bottom 8 are the
;                sand. column_h is the sand height, 1..8, and is not stored:
;                the diver does not collide with sand.
;
; A silo every `silo_gap` columns, a rock every 10 (when that column is
; not already a silo). Counting down is the demo's rule. Dividing on the
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
.silo:  ld a,(silo_left)
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
        ld a,TILE_SILO
        jp build_front_pat

next_back_tile:
        ld hl,(back_column)
        ld a,l
        and 15
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
        ld a,(column_h)
        call fill_bottom        ; DE is the sand half. Advances past it.

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
        ld de,(pat_dest)        ; plant into the top 8, on top of the dune
        ld hl,pat_weed
        ld b,8
        call copy_bytes
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
; ROCK_H. A silo REPLACES the 8 bytes with the bottom half of pat_silo
; and reports height 16. The top half is not stored here; stamp_silos
; reads it from pat_silo when it sees TILE_SILO.

build_front_pat:
        ld (build_tile),a
        cp TILE_SILO
        jr z,.silo
        cp TILE_ROCK
        jr z,.rock
        ld de,(pat_dest)
        ld a,(column_h)
        call fill_bottom
        jr .id
.rock:  ld de,(pat_dest)
        ld a,(column_h)
        call fill_bottom
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
.silo:  ld hl,pat_silo + GROUND_PX
        ld de,(pat_dest)
        ld b,GROUND_PX
        call copy_bytes
        ld a,SILO_H
        ld (column_h),a
.id:    ld a,(build_tile)
        ret

; Fill DE, 8 bytes: A solid rows at the bottom ($FF), zeros above.
; A is 0..8. Corrupts: AF, BC, DE.
fill_bottom:
        ld c,a
        ld a,8
        sub c                   ; zero rows. SUB sets the flags; LD would not.
        jr z,.solid
        ld b,a
        xor a
.z:     ld (de),a
        inc de
        djnz .z
.solid: ld a,c
        or a
        ret z
        ld b,a
        ld a,$FF
.f:     ld (de),a
        inc de
        djnz .f
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
; pat_silo is the demo's placeholder, unchanged. Top 8 bytes are stamped
; onto row 22 (yellow ink, blue paper). Bottom 8 go in the ground buffer
; (black ink, yellow paper). The hatch is in the top half, so its holes
; show the blue water, not the yellow the art was drawn against.

pat_rock:
        db %00000000            ; two clear rows, then a mound ROCK_H tall
        db %00000000
        db %00011000
        db %00111100
        db %01111110
        db %11111111
        db %11111111
        db %11111111
pat_silo:
        db %00011000            ; tip
        db %00011000
        db %00111100            ; cap
        db %00100100            ; hatch. Clear bits are paper, not a gap.
        db %00100100
        db %00111100
        db %01111110
        db %01000010
        db %11111111            ; row 23 starts here
        db %11100111
        db %11100111
        db %11111111
        db %11111111
        db %11111111
        db %11111111
        db %11111111
pat_weed:
        db %00001000            ; sits in row 21. The bottom row has pixels,
        db %00011100            ; so a full-height dune touches the plant.
        db %00001000            ; Leftmost set pixel is bit 5 (2 from the
        db %00111110            ; left). Rightmost is bit 1 (1 from the right).
        db %00001000            ; paint_weed_attrs's 3 and 7 come from that.
        db %00011100
        db %00001000
        db %00111110

; --- state -------------------------------------------------------------------
silo_gap:       db 0
silo_left:      db 0            ; columns until the next silo (0 = this one)
rock_left:      db 0
rock_hit:       db 0
weed_left:      db 0            ; columns until the next weed try
weed_wait:      db 0            ; 1 = a try missed its dune; plant on the next full one
paint_tiles:    ds 33           ; columns 0..31 in order, then the pending column
silo_n:         db 0            ; how many silos are in silo_at (0..8)
silo_at:        ds 8            ; their aligned columns, 0..32

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
front_tiles:    ds 32
front_h:        ds 32           ; solid pixels from the bottom of the screen
back_tiles:     ds 32

ground_feed:    ds GROUND_PX    ; pixels still to shift in, bit 7 next
slow_feed:      ds BACK_PX

column_h:       db 0
pat_dest:       dw column_pat
column_pat:     ds BACK_PX      ; top byte first. The ground uses the first 8.
build_tile:     db 0
init_col:       db 0
init_tile:      db 0
stamp_n:        db 0            ; aligned column currently being stamped
stamp_hi:       db 0            ; silo byte that stays in column n
stamp_lo:       db 0            ; silo byte that spilled into column n-1
