;==============================================================================
; scroll.asm - two-layer parallax ground
;
; Replaces the static pebbles. The full reasoning (why a buffer, why this
; order, what the timing bar is showing) is in docs/SCROLLING.md.
;
;   FAR strip  (back)   character row 18, 8 pixels. Yellow paper, green ink,
;                       a seaweed column now and then. 1 pixel every 2 frames.
;   NEAR strip (front)  character row 19, 8 pixels. Black paper, white
;                       ink. Mostly flat, occasional rocks, missile silos on
;                       a spacing that depends on the level. 1 pixel a frame.
;   Floor               character row 21, solid black, not scrolled.
;
; The world scrolls left on its own the whole time. The diver is still
; moved in screen coordinates, exactly as in v0.4. He is not the camera:
; tying the scroll to him would stop the parallax whenever he stopped, so
; the demo would not show the two speeds.
;
; PER FRAME (see main_loop):
;   1. restore both sprites     screen matches what their records saved
;   2. draw anyone still in the water (the fish, and the diver if his feet
;      are above the far strip). The copy below does not touch that water.
;   3. scroll_blit              copy both buffers onto the strips
;   4. draw the diver if he overlaps a strip, so he saves THIS ground
;   5. scroll_world             shift the buffers, off screen, for next time
;
; Restore has to be first. The record is a snapshot of the screen. Copying
; the new ground down and THEN restoring would paint last frame's pixels
; on top of ground that has already moved — a smear of "pixels left behind".
; The copy overwrites the whole strip, including whatever the restore just
; put back under a sprite. Water above the strips is not copied, so a sprite
; drawn there stays. A sprite drawn before the copy must not overlap it.
;
; SILOS, FOR LATER (Trigon missiles are not in this version)
; front_tiles[i] is the tile in character column i. TILE_SILO is a silo.
; The strip is also scrolled by a fraction of a column:
;
;   screen x of the left edge of column i  =  i*8 - front_fine
;
; front_fine is 0..7. Negative means those pixels have gone off the left.
; The column still entering on the right is front_pending (not in the table
; until front_fine wraps back to 0). Its world column is front_origin+32.
;==============================================================================

TILE_FLAT       equ 0
TILE_ROCK       equ 1
TILE_SILO       equ 2
TILE_WEED       equ 1           ; back-strip id; flat is 0 on both strips

; Columns from one silo to the next. World column N is a silo when
; (N mod gap) = 0. Wider gaps on the early levels. The demo uses level 0;
; poke level_index (0 .. LEVEL_COUNT-1) to try a later one.
LEVEL_COUNT     equ 4
level_silo_gap: db 24, 16, 12, 8
level_index:    db 0

;------------------------------------------------------------------------------
; scroll_init - first 32 columns, copied up once so the title shows ground
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
        ld (back_phase),a
        ld (silo_left),a        ; column 0 is a silo (0 mod gap = 0)
        ld a,4
        ld (rock_left),a        ; a rock when the column mod 10 = 4
        ld a,3
        ld (weed_left),a        ; seaweed when the column mod 11 = 3

        ld hl,front_tiles
        ld b,32
.fillf: push bc
        push hl
        call next_front_tile
        pop hl
        ld (hl),a
        inc hl
        pop bc
        djnz .fillf
        call next_front_tile    ; column 32, the one that enters from the right
        ld (front_pending),a
        ld hl,(pattern_ptr)
        ld de,front_feed
        ld b,FRONT_PX
        call copy_bytes

        ld hl,back_tiles
        ld b,32
.fillb: push bc
        push hl
        call next_back_tile
        pop hl
        ld (hl),a
        inc hl
        pop bc
        djnz .fillb
        call next_back_tile
        ld (back_pending),a
        ld hl,(pattern_ptr)
        ld de,back_feed
        ld b,BACK_PX
        call copy_bytes

        call paint_front
        call paint_back
        jp scroll_blit

;------------------------------------------------------------------------------
; scroll_blit - buffers -> screen.
; Call AFTER the sprites are restored and BEFORE they are saved and drawn,
; so the save grabs this frame's ground and not last frame's, and not the
; sprite itself. Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
scroll_blit:
        ld a,BACK_ROW * 8
        ld b,BACK_PX
        ld hl,BACK_BUF
        call blit_rows
        ld a,FRONT_ROW * 8
        ld b,FRONT_PX
        ld hl,FRONT_BUF
        jp blit_rows

;------------------------------------------------------------------------------
; scroll_world - move the buffers on for next frame. Does not touch the screen.
; Front every frame, back every other frame (half the speed).
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
scroll_world:
        call scroll_front
        ld a,(back_phase)       ; 0,1,0,1... the far strip moves on the 0s
        xor 1
        ld (back_phase),a
        ret nz
        jp scroll_back

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
; The first version of this was a DJNZ loop: RL (HL) / DEC HL / DJNZ is
; 15+6+13 = 34 T-states a byte. Twenty-four rows of that, on top of the
; sprite drawing and the copy to the screen, ran past the next interrupt,
; so the whole game dropped from 50 frames a second to 25. The loop test
; was the expensive part. Unrolled, it is RL (HL) / DEC L = 15+4, and DEC L
; is safe because every row is 32 bytes on a 32-byte boundary, so it sits
; inside one 256-byte page (SCROLL_BASE is $F000). See docs/SCROLLING.md.
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
scroll_front:
        ld hl,FRONT_BUF
        ld de,front_feed
        ld b,FRONT_PX
        call shift_rows_left

        ld a,(front_fine)
        inc a
        cp 8
        jr z,.column            ; this pixel was the 8th: a whole column is in
        ld (front_fine),a
        ret
.column:
        xor a
        ld (front_fine),a
        ld hl,(front_origin)
        inc hl
        ld (front_origin),hl

        ld hl,front_tiles+1
        ld de,front_tiles
        ld bc,31
        ldir                    ; DE left pointing at front_tiles+31
        ld a,(front_pending)
        ld (de),a               ; that column has now fully arrived

        call next_front_tile
        ld (front_pending),a
        ld hl,(pattern_ptr)
        ld de,front_feed
        ld b,FRONT_PX
        jp copy_bytes

scroll_back:
        ld hl,BACK_BUF
        ld de,back_feed
        ld b,BACK_PX
        call shift_rows_left

        ld a,(back_fine)
        inc a
        cp 8
        jr z,.column
        ld (back_fine),a
        ret
.column:
        xor a
        ld (back_fine),a
        ld hl,(back_origin)
        inc hl
        ld (back_origin),hl

        ld hl,back_tiles+1
        ld de,back_tiles
        ld bc,31
        ldir
        ld a,(back_pending)
        ld (de),a

        call next_back_tile
        ld (back_pending),a
        ld hl,(pattern_ptr)
        ld de,back_feed
        ld b,BACK_PX
        jp copy_bytes

; --- which tile is the next world column? ------------------------------------
; Both routines consume one column, return the tile id in A, and point
; (pattern_ptr) at its pixels.
;
; A silo every `silo_gap` columns, a rock every 10 (when that column is not
; already a silo), seaweed every 11. Counting down is the same rule as
; "column mod N = k", and it stays a few instructions. Dividing the column
; number (16 trips around a loop) on the frame a new column arrives was
; enough, together with everything else that frame, to miss the next
; interrupt. See docs/SCROLLING.md.
;
; The counters are "columns still to go". Zero means this column is the one.
; They are set in scroll_init so that column 0 behaves: silo immediately,
; first rock at column 4, first weed at column 3.

next_front_tile:
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
        xor a
        ld hl,pat_front_flat
        jr .keep
.rock:  ld a,TILE_ROCK
        ld hl,pat_front_rock
        jr .keep
.silo_now:
        ld a,(silo_gap)
        dec a
        ld (silo_left),a
        ld a,TILE_SILO
        ld hl,pat_front_silo
.keep:  ld (pattern_ptr),hl
        ret

next_back_tile:
        ld hl,(back_column)
        inc hl
        ld (back_column),hl
        ld a,(weed_left)
        or a
        jr z,.weed_now
        dec a
        ld (weed_left),a
        xor a
        ld hl,pat_back_flat
        jr .keep
.weed_now:
        ld a,10                 ; next weed is 11 columns after this one
        ld (weed_left),a
        ld a,TILE_WEED
        ld hl,pat_back_weed
.keep:  ld (pattern_ptr),hl
        ret

; --- turn the id tables into pixels (start-up only) --------------------------
; At fine-scroll 0 a tile is exactly one character column, so its bytes are
; copied in at stride 32. Later frames only shift; they do not repaint.

paint_front:
        ld hl,front_tiles
        ld de,FRONT_BUF
        ld b,FRONT_PX
        ld ix,pat_front_flat
        jp paint_columns

paint_back:
        ld hl,back_tiles
        ld de,BACK_BUF
        ld b,BACK_PX
        ld ix,pat_back_flat
        ; fall through

; In:  HL -> 32 tile ids, DE -> buffer, B = pixel height, IX -> packed
;      patterns (tile id 0 first, each tile B bytes).
; Temps below are ordinary memory on purpose: the address arithmetic is
; "buffer + row*32 + column" and a pile of stack traffic made it harder
; to check than it was worth. This runs once, before the first frame.
paint_columns:
        ld (paint_tiles),hl
        ld (paint_buf),de
        ld a,b
        ld (paint_height),a
        push ix
        pop hl
        ld (paint_pats),hl

        xor a
.column:
        ld (paint_col),a
        push af

        ld hl,(paint_tiles)
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)               ; tile id
        ld l,a
        ld h,0
        ld a,(paint_height)
        ld e,l
        ld d,h                  ; DE = id
        ld hl,0
.mul:   add hl,de               ; HL = id * height
        dec a
        jr nz,.mul
        ld de,(paint_pats)
        add hl,de
        ld (paint_src),hl       ; first byte of this tile

        xor a                   ; row
.row:   ld (paint_row),a
        push af

        ld hl,(paint_src)
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)               ; pattern byte for this row
        ld (paint_byte),a

        ld hl,(paint_buf)
        ld a,(paint_row)
        or a
        jr z,.col_only
        ld b,a
.stride:
        ld de,32
        add hl,de
        djnz .stride
.col_only:
        ld a,(paint_col)
        ld e,a
        ld d,0
        add hl,de
        ld a,(paint_byte)
        ld (hl),a

        pop af
        inc a
        ld hl,paint_height
        cp (hl)
        jr nz,.row

        pop af
        inc a
        cp 32
        jr nz,.column
        ret

; HL -> src, DE -> dest, B = count. Corrupts AF, BC, DE, HL.
copy_bytes:
        ld a,(hl)
        inc hl
        ld (de),a
        inc de
        djnz copy_bytes
        ret

; --- patterns -----------------------------------------------------------------
; Packed: paint_columns indexes them as base + id*height. Bit 7 is the
; leftmost pixel. Flat tiles are zeros so the paper colour shows through
; (yellow sand, black rock-bed).

pat_front_flat:
        ds FRONT_PX, 0
pat_front_rock:
        db %00000000
        db %00000000
        db %00011000
        db %00111100
        db %01111110
        db %01111110
        db %11111111
        db %11111111
pat_front_silo:
        db %00111100
        db %00100100                ; dark slit: the hatch missiles will use
        db %00100100
        db %00111100
        db %01000010
        db %01000010
        db %11111111                ; footing
        db %11111111
pat_back_flat:
        ds BACK_PX, 0
pat_back_weed:
        db %00010000
        db %00111000
        db %00010000
        db %01111100
        db %00010000
        db %00111000
        db %00010000
        db %00111000

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
back_phase:     db 0            ; toggles; far strip moves when this becomes 0

front_pending:  db 0            ; tile id of the column entering on the right
back_pending:   db 0
front_tiles:    ds 32
back_tiles:     ds 32
front_feed:     ds FRONT_PX     ; pixels still to shift in, bit 7 next
back_feed:      ds BACK_PX
pattern_ptr:    dw 0

paint_tiles:    dw 0
paint_buf:      dw 0
paint_pats:     dw 0
paint_src:      dw 0
paint_height:   db 0
paint_col:      db 0
paint_row:      db 0
paint_byte:     db 0
