;==============================================================================
; scroll.asm - two-layer parallax ground
;
; Replaces the static pebbles, and the flat one-row strips that came after
; them. The full reasoning is in docs/SCROLLING.md. Short version:
;
;   FAR strip  (back)   rows 18-19, 16 pixels. Yellow hills on blue water,
;                       a green seaweed column now and then.
;                       1 pixel every 2 frames.
;   NEAR strip (front)  rows 20-21, 16 pixels. Black hills on yellow,
;                       rocks, missile silos. Everything in it is black.
;                       1 pixel every frame.
;
; The near strip is drawn under the far one, so it reads as "in front".
;
; The world scrolls left on its own the whole time. The diver is still
; moved in screen coordinates. He is not the camera: tying the scroll to
; him would stop the parallax whenever he stopped.
;
; WHY THE FAR STRIP IS NOT SHIFTED ON THE FRAME IT IS COPIED
; Both strips used to be 8 pixels. Copying and rotating 16 was measured to
; finish inside the frame. At 16+16, doing both jobs for both strips on the
; same frame does not (the sums are in SCROLLING.md). The near strip still
; moves one pixel a frame. The far strip moves one pixel every two frames,
; which is the speed it already had, by splitting the work:
;
;   phase 0, SHOW     copy the far buffer to the screen. Do not rotate it.
;                     The screen and the buffer still match.
;   phase 1, PREPARE  do not copy it (the screen already shows it). Rotate
;                     the buffer, off screen, so the next show frame reveals
;                     the new pixel.
;
; The near strip is copied and rotated every frame. It is the lower of the
; two, so the beam reaches it later and there is time.
;
; PER FRAME (see main_loop):
;   1. restore both sprites
;   2. draw anyone still above the far strip (the fish, and the diver if
;      his feet are above it)
;   3. copy the far buffer up, on a show frame only
;   4. copy the near buffer up, every frame
;   5. draw the diver if he overlaps a strip, so he saves THIS ground
;   6. rotate the near buffer, every frame
;   7. rotate the far buffer, on a prepare frame only
;
; Restore has to be first. Copying the new ground down and THEN restoring
; would paint last frame's pixels on top of ground that has already moved.
; Skipping the far copy on a prepare frame is safe: the screen still holds
; the previous show frame's copy, and the buffer was not rotated after it,
; so they are the same bytes. The near copy overwrites the whole near
; strip, including whatever the restore just put back under a sprite.
;
; COLOUR
; A cell is one ink and one paper. The near strip is black ink, yellow
; paper, every cell, set once. Set bits are the black ground.
; The far strip's top row is yellow ink, blue paper, every cell, set once.
; Its bottom row is that same pair, except a seaweed column, which is
; green ink on yellow paper. Those 32 attribute bytes are rewritten when
; a far column finishes arriving (every 8 far pixels, so every 16 frames).
; Between those moments the colour is up to 7 pixels behind the picture.
; That is the clash, written out in SCROLLING.md.
;
; SILOS, FOR LATER (missiles are not in this version)
; front_tiles[i] is the tile in character column i. TILE_SILO is a silo.
; front_h[i] is how many pixels of solid ground that column has, counted
; from the bottom of the strip. A silo is 16, hatch included: the yellow
; slots are not a gap he can swim through.
;
;   screen x of the left edge of column i  =  i*8 - front_fine
;   tile of screen column i               =  front_tiles[(front_head+i) & 31]
;
; front_fine is 0..7. front_head is the slot that is currently the left
; edge: the table is a ring, so a new column does not have to slide the
; other 31 along. The column still entering on the right is front_pending
; (not in the table until front_fine wraps to 0). Its world column is
; front_origin+32, and its height is front_h_pending.
;
; Building that incoming column (the hill shape, the rock or the silo)
; is done a few frames BEFORE it arrives, straight into the spare
; 16-byte buffer. The arrival frame swaps two pointers so the shifter
; reads that buffer next. It does not copy 16 bytes, and it does not
; build the shape: either one, on the frame both strips wrapped, ran
; past the next interrupt. See docs/SCROLLING.md.
;==============================================================================

TILE_FLAT       equ 0
TILE_ROCK       equ 1
TILE_SILO       equ 2
TILE_WEED       equ 1           ; back-strip id; flat is 0 on both strips

; A rock bitmap pokes up this many pixels from the bottom of the strip.
; The bytes are in pat_rock: 16 - ROCK_H zeros, then the mound.
ROCK_H          equ 10

; Columns from one silo to the next. World column N is a silo when
; (N mod gap) = 0. Wider gaps on the early levels. The demo uses level 0;
; poke level_index (0 .. LEVEL_COUNT-1) to try a later one.
LEVEL_COUNT     equ 4
level_silo_gap: db 24, 16, 12, 8
level_index:    db 0

;------------------------------------------------------------------------------
; scroll_init - first 32 columns of each strip, then one copy to the screen
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
        ld (front_column),hl    ; next world column the generators will hand out
        ld (back_column),hl
        ld (front_origin),hl    ; world column of tiles[0]
        ld (back_origin),hl
        xor a
        ld (front_fine),a
        ld (back_fine),a
        ld (back_phase),a       ; first frame is a show frame
        ld (back_attr_pending),a
        ld (front_head),a       ; slot 0 is the left edge, until the first wrap
        ld (back_head),a
        ld (silo_left),a        ; column 0 is a silo (0 mod gap = 0)
        ld a,4
        ld (rock_left),a        ; a rock when the column mod 10 = 4
        ld a,3
        ld (weed_left),a        ; seaweed when the column mod 11 = 3

        xor a
.fillf: ld (init_col),a
        call next_front_tile    ; A = tile, column_h and column_pat filled
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
        ld hl,FRONT_BUF
        ld b,FRONT_PX
        call stamp_column
        ld a,(init_col)
        inc a
        cp 32
        jr nz,.fillf

        call next_front_tile    ; column 32, the one that enters from the right
        ld (front_pending),a
        ld a,(column_h)
        ld (front_h_pending),a
        ld hl,column_pat
        ld de,front_feed
        ld b,FRONT_PX
        call copy_bytes

        xor a
.fillb: ld (init_col),a
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

        call next_back_tile
        ld (back_pending),a
        ld hl,column_pat
        ld de,back_feed
        ld b,BACK_PX
        call copy_bytes

        call paint_back_attrs   ; bottom far row, from the tiles just built
        jp scroll_blit

;------------------------------------------------------------------------------
; scroll_blit - both buffers -> screen. Start-up only.
; The frame loop calls the two halves separately (main_loop), because the
; far half is skipped on a prepare frame.
;------------------------------------------------------------------------------
scroll_blit:
        call scroll_blit_back
        jp scroll_blit_front

; scroll_blit_back - far buffer -> rows 18-19.
; On the frame a new column lines up, also rewrites that row's colours so
; the seaweed green moves with the plant. Corrupts: AF, BC, DE, HL, IX
scroll_blit_back:
        ld a,(back_attr_pending)
        or a
        jr z,.pixels
        xor a
        ld (back_attr_pending),a
        call shift_back_attrs   ; one cell, not a repaint of the row
.pixels:
        ld a,BACK_ROW * 8
        ld b,BACK_PX
        ld hl,BACK_BUF
        jp blit_rows

; scroll_blit_front - near buffer -> rows 20-21. Every frame.
scroll_blit_front:
        ld a,FRONT_ROW * 8
        ld b,FRONT_PX
        ld hl,FRONT_BUF
        jp blit_rows

;------------------------------------------------------------------------------
; blit_rows - copy one buffer row onto one screen row, then the next
; In:  A = first pixel y (multiple of 8), B = rows (multiple of 8),
;      HL = buffer (32 bytes a row)
; Corrupts: AF, BC, DE, HL, IX
;
; LDIR would be the obvious copy (21 T-states a byte). That copy of both
; strips was still running when the raster reached them, so the ground
; tore. LDI is 16 T-states and, unrolled, has no per-byte loop test.
;
; Inside one character cell the next pixel line is just INC D (+256): see
; the address diagram in docs/SPRITES.md. A strip is whole cells, so we look
; the first line up in the row table and then INC D for the other seven.
; LDI also counts down BC, so the line counter is pushed around the copy.
;------------------------------------------------------------------------------
blit_rows:
.cell:  push bc
        push hl
        push af                 ; row_table_entry takes A and destroys it
        call row_table_entry
        ld e,(ix+0)
        ld d,(ix+1)             ; DE = screen address of this cell's top line
        pop af
        pop hl
        ld b,8
.line:  push bc
        push de
        dup 32
        ldi                     ; (HL) -> (DE); HL steps through the buffer
        edup
        pop de
        inc d                   ; next line of the same cell
        pop bc
        djnz .line
        pop bc                  ; pixel-rows still to do, including this cell
        add a,8
        ld c,a                  ; keep y while B is adjusted
        ld a,b
        sub 8
        ld b,a
        ld a,c
        jr nz,.cell
        ret

;------------------------------------------------------------------------------
; shift_rows_left - move a buffer left one pixel; feed bit 7 enters on the right
; In:  HL = buffer, DE = feed (one byte per row), B = rows
; Out: HL = just past the buffer, DE = just past the feed
; Corrupts: AF, BC
;
; Bit 7 of a byte is the leftmost pixel. RL moves bit 6 into bit 7, so the
; picture moves left, and the old bit 7 falls into the carry — ready to
; become bit 0 (the rightmost pixel) of the byte on the left.
; Walking the row from right to left is what joins the bytes up.
;
; Unrolled RL (HL) / DEC L is 15+4 T-states a byte. DEC L is safe because
; every row is 32 bytes on a 32-byte boundary, so it sits inside one
; 256-byte page (SCROLL_BASE is $F000). A DJNZ around the same RL was 34
; T-states and, across both strips, dropped the game to 25 Hz.
; See docs/SCROLLING.md.
;------------------------------------------------------------------------------
shift_rows_left:
.row:   push bc
        call shift_one_row
        pop bc
        djnz .row
        ret

; In:  HL = leftmost byte of one row, DE = that row's feed byte
; Out: HL = leftmost byte of the next row, DE = next feed byte
shift_one_row:
        push hl                 ; the left edge, so we can find the next row
        ld a,l
        add a,31
        ld l,a                  ; rightmost byte. The carry this ADD sets is
                                ; discarded by RLCA, which writes its own.
        ld a,(de)
        rlca                    ; feed bit 7 -> carry, and into bit 0 of the
        ld (de),a               ; feed, so next frame the next pixel is in bit 7
        inc de                  ; LD and INC DE do not touch the flags
        dup 31
        rl (hl)                 ; carry comes in as bit 0, bit 7 leaves
        dec l                   ; byte to the left. Same page: see the note above.
        edup
        rl (hl)                 ; leftmost byte. No DEC after it.
        pop hl
        ld a,l                  ; next row is 32 bytes on. ADD A,32 sets carry
        add a,32                ; when the row crosses a 256-byte page.
        ld l,a
        ret nc
        inc h
        ret

; --- one strip ----------------------------------------------------------------
; scroll_front - rotate the near buffer one pixel. Every frame.
; Does not touch the screen. Corrupts: AF, BC, DE, HL
scroll_front:
        ld hl,FRONT_BUF
        ld de,(front_feed_ptr)  ; the buffer the shifter consumes in place
        ld b,FRONT_PX
        call shift_rows_left

        ld a,(front_fine)
        inc a
        cp 8
        jr z,.column            ; this pixel was the 8th: a whole column is in
        ld (front_fine),a
        cp 3                    ; a show frame, four shifts before the wrap
        call z,build_front_ahead
        jp maybe_back_ahead     ; far build, if the previous prepare asked
.column:
        xor a
        ld (front_fine),a
        ld hl,(front_origin)
        inc hl
        ld (front_origin),hl

        ; The slot scrolling off the left becomes the new right-hand column.
        ; No copy of the other 31 entries: front_head says which slot is the
        ; left edge. The pixels for the new column were built on an earlier
        ; frame (front_ahead_*) so this frame only stores two bytes and
        ; points the shifter at that buffer.
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

        ld a,(front_ahead_id)   ; that pre-built column is now the one entering
        ld (front_pending),a
        ld a,(front_ahead_h)
        ld (front_h_pending),a
        ; Its pixels are already in the ahead buffer. Swap, so the shifter
        ; reads them and the next build overwrites the buffer we just
        ; finished with. No 16-byte copy on this frame: two of those, on
        ; the frame both strips wrap, missed the interrupt.
        ld hl,(front_feed_ptr)
        ld de,(front_ahead_ptr)
        ld (front_feed_ptr),de
        ld (front_ahead_ptr),hl
        jp maybe_back_ahead

; scroll_back - rotate the far buffer one pixel. Prepare frames only.
; The matching attribute update is deferred to the next show frame
; (back_attr_pending), so the green cell and the plant move together.
scroll_back:
        ld hl,BACK_BUF
        ld de,(back_feed_ptr)
        ld b,BACK_PX
        call shift_rows_left

        ld a,(back_fine)
        inc a
        cp 8
        jr z,.column
        ld (back_fine),a
        cp 2                    ; ask for the far build on the next (show) frame
        ret nz
        ld a,1
        ld (back_build_req),a
        ret
.column:
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
        ld (hl),a               ; old left slot is now the right-hand column
        ld a,e
        inc a
        and 31
        ld (back_head),a

        ld a,(back_ahead_id)
        ld (back_pending),a
        ld a,1
        ld (back_attr_pending),a ; next show frame recolours the bottom row
        ld hl,(back_feed_ptr)
        ld de,(back_ahead_ptr)
        ld (back_feed_ptr),de
        ld (back_ahead_ptr),hl
        ret

; The near column-after-next is built when front_fine becomes 3, which is a
; show frame. The far one is requested when back_fine becomes 2 (a prepare
; frame) and built on the show frame after that, so it never shares a frame
; with the near build or with a column actually arriving. See SCROLLING.md.
maybe_back_ahead:
        ld a,(back_build_req)
        or a
        ret z
        xor a
        ld (back_build_req),a
        jp build_back_ahead

build_front_ahead:
        ld hl,(front_ahead_ptr) ; generate straight into the spare buffer
        ld (pat_dest),hl
        call next_front_tile
        ld (front_ahead_id),a
        ld a,(column_h)
        ld (front_ahead_h),a
        ret

build_back_ahead:
        ld hl,(back_ahead_ptr)
        ld (pat_dest),hl
        call next_back_tile
        ld (back_ahead_id),a
        ret

; --- which tile is the next world column? ------------------------------------
; Both routines consume one column and return the tile id in A.
; They also fill the 16 bytes at (pat_dest), top byte first, and
; column_h (solid pixels from the bottom; the diver's clamp reads the
; near ones back out of front_h). pat_dest is column_pat while the
; first screenful is stamped in, and the spare ahead buffer after that.
;
; A silo every `silo_gap` columns, a rock every 10 (when that column is not
; already a silo), seaweed every 11. Counting down is the same rule as
; "column mod N = k". Dividing the column number on the frame a new column
; arrives was enough, together with everything else that frame, to miss
; the next interrupt. See docs/SCROLLING.md.
;
; The counters are "columns still to go". Zero means this column is the one.
; They are set in scroll_init so that column 0 behaves: silo immediately,
; first rock at column 4, first weed at column 3.
;
; The undulation is separate from those counters. near_profile / far_profile
; repeat every 16 world columns, so the hills keep their shape however the
; silo gap changes.

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

        ; Rock phase advances on every column, silos included, so the rocks
        ; stay on columns 4, 14, 24, ... even when a silo takes one of them.
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
        inc a                   ; A was 9, now non-zero
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

        ld a,(weed_left)
        or a
        jr z,.weed_now
        dec a
        ld (weed_left),a
        xor a
        jp build_back_pat
.weed_now:
        ld a,10                 ; next weed is 11 columns after this one
        ld (weed_left),a
        ld a,TILE_WEED
        jp build_back_pat

; --- pixels for one column ----------------------------------------------------
; column_h is the hill height. A rock is OR-ed on top of that and may raise
; the height. A silo replaces the column; its height is the full strip so
; the hatch (clear bits, yellow showing through) is not a hole. Seaweed
; replaces only the bottom 8 pixels, which is one attribute cell, so the
; plant never shares a cell with the top row's yellow-on-blue.

build_front_pat:
        ld (build_tile),a       ; returned in A at the end. The fill and the
        cp TILE_SILO            ; copy both leave A holding a pixel, not the id.
        jr z,.silo
        cp TILE_ROCK
        jr z,.rock
        call fill_column        ; flat hill. column_h is already the profile.
        jr .id
.rock:  call fill_column
        ld hl,pat_rock
        ld de,(pat_dest)
        ld b,FRONT_PX
.or:    ld a,(de)
        or (hl)                 ; rock outline over the solid hill
        ld (de),a
        inc hl
        inc de
        djnz .or
        ld a,(column_h)
        cp ROCK_H
        jr nc,.id               ; the hill was already taller than the rock
        ld a,ROCK_H
        ld (column_h),a
        jr .id
.silo:  ld hl,pat_silo
        ld de,(pat_dest)
        ld b,FRONT_PX
        call copy_bytes
        ld a,FRONT_PX           ; solid for collision, hatch included
        ld (column_h),a
.id:    ld a,(build_tile)
        ret

build_back_pat:
        ld (build_tile),a
        call fill_column
        ld a,(build_tile)
        cp TILE_WEED
        jr nz,.id
        ld hl,(pat_dest)
        ld de,8                 ; the plant stays in the bottom character cell
        add hl,de
        ex de,hl
        ld hl,pat_weed
        ld b,8
        call copy_bytes
.id:    ld a,(build_tile)
        ret

; Fill (pat_dest) from column_h: that many $FF bytes at the bottom, zeros
; above. Top byte is the first byte. Both strips are 16 pixels (asserted).
; A straight store is quicker than the compare-per-row version, which on the
; frame a column is built was enough to push the frame past the interrupt.
; Corrupts: AF, BC, HL
fill_column:
        ld hl,(pat_dest)
        ld a,(column_h)
        ld c,a                  ; solid rows
        ld a,FRONT_PX
        sub c                   ; zero rows above the skyline
        jr z,.solid
        ld b,a
        xor a
.z:     ld (hl),a
        inc hl
        djnz .z
.solid: ld a,c
        or a
        ret z
        ld b,a
        ld a,$FF
.f:     ld (hl),a
        inc hl
        djnz .f
        ret

; Stamp column_pat down one buffer column.
; In:  HL = buffer, A = column 0..31, B = pixel rows. Corrupts: AF, BC, DE, HL
stamp_column:
        ld e,a
        ld d,0
        add hl,de               ; first row, this column
        ld de,column_pat
.row:   ld a,(de)
        ld (hl),a
        inc de
        push bc
        ld bc,32
        add hl,bc               ; next pixel row, same column
        pop bc
        djnz .row
        ret

; The seaweed colour has to move with the plant. One cell is exactly 8
; pixels, and a far column arrives every 8 far pixels, so the bottom row
; of attributes shifts left one cell at the same moment the pixels do.
; A 32-cell repaint was enough, on that show frame, to miss the interrupt.
; Shifting the 32 bytes that are already on screen is a short copy, then
; one new cell on the right. The top far row never changes.
; Called on the show frame after a far column lines up (the pixels are
; copied up in the same call). Corrupts: AF, BC, DE, HL
shift_back_attrs:
        ld b,BACK_ROW + 1
        ld c,0
        call attr_addr          ; HL = leftmost cell of the bottom far row
        ld d,h
        ld e,l
        inc hl                  ; source is one cell to the right of dest
        ld bc,31
        ldir                    ; cells 1..31 slide into 0..30. DE = cell 31
        push de
        ld a,(back_head)
        dec a                   ; the slot just filled in is the new right edge
        and 31
        ld e,a
        ld d,0
        ld hl,back_tiles
        add hl,de
        ld a,(hl)
        cp TILE_WEED
        ld a,BACK_HILL_ATTR     ; LD does not disturb the flags from CP
        jr nz,.store
        ld a,BACK_WEED_ATTR
.store: pop de
        ld (de),a
        ret

; Full paint of that row. Start-up only (back_head is 0, so screen order
; and table order match). The scrolling update is shift_back_attrs.
paint_back_attrs:
        ld b,BACK_ROW + 1       ; the bottom of the two far rows
        ld c,0
        call attr_addr          ; HL -> first attribute of that row
        ld a,(back_head)
        ld e,a
        ld d,0
        ld ix,back_tiles
        add ix,de               ; screen column 0
        ld a,32
        sub e                   ; slots from the head to the end of the ring
        ld b,a
        call .span
        ld a,(back_head)
        or a
        ret z                   ; head was 0: that span was the whole row
        ld b,a                  ; then the slots that wrapped to the front
        ld ix,back_tiles
        ; fall through into .span
.span:  ld a,(ix+0)
        cp TILE_WEED
        ld a,BACK_HILL_ATTR     ; LD does not disturb the flags from CP
        jr nz,.store
        ld a,BACK_WEED_ATTR
.store: ld (hl),a
        inc hl
        inc ix
        djnz .span
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
; Pixels of solid ground from the bottom of the strip, repeating every
; 16 columns. 16 would fill the strip. The two tables are different shapes
; so the far hills do not trace the near ones.
;
; Near, columns 0..15. A silo (height 16) stands above the highest step.
;
;         . . . . . # # . . . . . . . . .
;         . . . . # # # # . . . . . . . .
;         . . . # # # # # # . . . . . . .
;         . . # # # # # # # # . . . . . .
;         . # # # # # # # # # # . . . . .
;         # # # # # # # # # # # # . . . .
;         # # # # # # # # # # # # # # . .
;         # # # # # # # # # # # # # # # #
; col     0 1 2 3 4 5 6 7 8 9 a b c d e f
near_profile:
        db 4, 5, 7, 9, 11, 13, 14, 14, 13, 11, 9, 7, 5, 4, 3, 4

; Far. Peaks of 10 cross into the top character row, so the skyline is
; not stuck on the bottom row's attribute boundary.
far_profile:
        db 2, 3, 4, 6, 8, 10, 10, 8, 6, 5, 4, 3, 2, 2, 3, 4

; --- fixed shapes ------------------------------------------------------------
; Bit 7 is the leftmost pixel. Top byte is the top pixel row.
; Clear bits show the paper colour (yellow behind the near strip, blue
; behind the far hills, yellow inside a seaweed cell).

pat_rock:
        db %00000000            ; 6 empty rows, then a mound ROCK_H tall
        db %00000000
        db %00000000
        db %00000000
        db %00000000
        db %00000000
        db %00011000
        db %00111100
        db %01111110
        db %11111111
        db %11111111
        db %11111111
        db %11111111
        db %11111111
        db %11111111
        db %11111111
pat_silo:
        db %00011000            ; tip
        db %00011000
        db %00111100            ; cap
        db %00100100            ; hatch: the clear bits are yellow, not a gap
        db %00100100
        db %00111100
        db %01111110
        db %01000010
        db %11111111
        db %11100111            ; two slots. Art to be replaced later.
        db %11100111
        db %11111111
        db %11111111
        db %11111111
        db %11111111
        db %11111111
pat_weed:
        db %00001000            ; bottom 8 pixels only. The top 8 of a weed
        db %00011100            ; column stay as the hill, so this plant does
        db %00001000            ; not cross into the yellow-on-blue row.
        db %00111110
        db %00001000
        db %00011100
        db %00001000
        db %00111110

; --- state --------------------------------------------------------------------
silo_gap:       db 0            ; copy of level_silo_gap[level_index]
silo_left:      db 0            ; columns until the next silo (0 = this one)
rock_left:      db 0            ; columns until the next rock
rock_hit:       db 0            ; non-zero if this column's rock phase fired
weed_left:      db 0            ; columns until the next seaweed

front_column:   dw 0            ; next world column next_front_tile will issue
back_column:    dw 0
front_origin:   dw 0            ; world column currently in front_tiles[0]
back_origin:    dw 0
front_fine:     db 0            ; 0..7 pixels scrolled since columns lined up
back_fine:      db 0
; 0 = show (copy the far strip, do not rotate it)
; 1 = prepare (rotate it, do not copy it). main_loop flips this.
back_phase:     db 0
; Set when a far column lines up. The next show frame rewrites the bottom
; far attribute row, then clears it. Keeps the green cell with the plant.
back_attr_pending: db 0

front_head:     db 0            ; slot index of the leftmost near column
back_head:      db 0
front_pending:  db 0            ; tile id of the column entering on the right
back_pending:   db 0
front_h_pending: db 0           ; its solid height (diver clamp, right edge)
front_ahead_id: db 0
front_ahead_h:  db 0
back_ahead_id:  db 0
back_build_req: db 0            ; 1 = build the far ahead column this frame
front_tiles:    ds 32
front_h:        ds 32           ; solid pixels from the bottom, one per column
back_tiles:     ds 32
; Two 16-byte buffers per strip. The shifter reads *feed_ptr and rotates
; those bytes in place. A build writes *ahead_ptr. On a column wrap the
; two pointers swap, so the arrival frame does not copy 16 bytes.
front_feed_ptr: dw front_feed   ; shifter reads this; wrap swaps it
front_ahead_ptr: dw front_ahead_pat
back_feed_ptr:  dw back_feed
back_ahead_ptr: dw back_ahead_pat
front_feed:     ds FRONT_PX     ; pixels still to shift in, bit 7 next
front_ahead_pat: ds FRONT_PX
back_feed:      ds BACK_PX
back_ahead_pat: ds BACK_PX

column_h:       db 0            ; height of the column just generated
pat_dest:       dw column_pat   ; where build_*_pat writes (ahead, or this)
column_pat:     ds FRONT_PX     ; its pixels, top byte first
build_tile:     db 0
init_col:       db 0
init_tile:      db 0
