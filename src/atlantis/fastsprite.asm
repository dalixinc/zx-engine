;==============================================================================
; fastsprite.asm - a tighter sprite walker, Atlantis only
;
; The shared routines in src/sprite.asm are written to be clear. Every
; pixel row they look the row address up in the table, save the row
; counter, and then walk the bytes one at a time with a loop. A masked
; byte in that loop is about 57 T-states, and a 16 by 16 wheel pays it
; three times (put the background back, photograph the new background,
; draw). That came to about 60 scanlines. The seabed frame only had 7
; scanlines to spare, so the picture missed the interrupt, the loop ran
; twice per picture, and the bomb flickered.
;
; This file does the same three jobs with less bookkeeping.
;
;   * The next pixel line down, inside one character cell, is one add
;     to the high byte of the screen address. The row-address table is
;     read once per sprite, not once per line. See fast_next_line.
;   * Each width (1, 2, 3 or 4 bytes) is written out in full, so there
;     is no per-byte loop.
;   * The fish and the diver on this build use it too. They are on
;     screen every frame, so the time they give back is what leaves
;     spare scanlines once the wheel is drawn as well.
;
; Engine Demo 1 does not include this file. The fish and the diver
; there still call sprite_save_bg, sprite_restore_bg and sprite_draw,
; and that tape is unchanged.
;
; The background record is the same shape as sprite_save_bg writes:
; valid, y, column, height, bytes, then the visible bytes row by row.
; Restore puts back exactly those bytes. A sprite that is half off the
; screen has already had its column and its byte count reduced to the
; part that is visible, so this walker never writes past column 31.
;
; The interrupt handler only saves the accumulator and HL. These
; routines keep the screen pointer in DE, and they push DE around a
; row, which is safe: the handler does not touch DE or the index
; registers.
;==============================================================================

;------------------------------------------------------------------------------
; fast_next_line - DE = the next pixel row down, same column
;
; The eight pixel lines of a character cell sit 256 bytes apart, so
; adding 1 to D steps to the next line inside the cell. After the
; eighth line that add also bumps the bit that says which third of the
; screen we are in. That bump is only correct when the character row
; wrapped as well (we really have entered the next third).
;
; If the low three bits of D are not zero, we are still inside the
; cell and there is nothing else to do. If they are zero, we wrapped:
; adding 32 to E steps to the next character row. A carry from that add
; means the character row wrapped too, so the bump of D stays. No carry
; means we are still in the same third, and 8 is subtracted from D to
; undo the bump.
;
; E must be the column we started the row on. The byte copy increments
; E, so the caller pushes DE first and pops it before this is called.
; Corrupts: AF. HL and BC are kept.
;------------------------------------------------------------------------------
fast_next_line:
        inc d
        ld a,d
        and 7
        ret nz                  ; still inside this character cell
        ld a,e
        add a,32                ; next character row, same column
        ld e,a
        ret c                   ; wrapped into the next third: D is right
        ld a,d
        sub 8                   ; undo the bump; same third, next row
        ld d,a
        ret

;------------------------------------------------------------------------------
; fast_screen_de - DE = screen address of spr_y, spr_col
; Corrupts: AF, HL, C
;------------------------------------------------------------------------------
fast_screen_de:
        ld a,(spr_y)
        call screen_row_addr    ; HL = leftmost byte of this pixel row
        ld a,(spr_col)
        or l                    ; low five bits are 0; the column fits there
        ld l,a
        ex de,hl
        ret

;------------------------------------------------------------------------------
; fast_buffer_hl - HL = first saved byte of the record IY points at
; Corrupts: DE
;------------------------------------------------------------------------------
fast_buffer_hl:
        push iy
        pop hl
        ld de,BG_DATA
        add hl,de
        ret

;------------------------------------------------------------------------------
; fast_save - photograph the bytes under the sprite
; In:  IY -> background record. spr_y, spr_col, spr_bytes, spr_height
;      already set (sprite_set_pos, or sprite_set_pos_x for a clipped one).
; spr_bytes is the number of bytes actually on screen, not the width of
; the stored picture. A clipped wheel records a shorter row.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
fast_save:
        ld a,(spr_y)
        ld (iy+BG_Y),a
        ld a,(spr_col)
        ld (iy+BG_COL),a
        ld a,(spr_bytes)
        ld (iy+BG_BYTES),a
        ld a,(spr_height)
        ld (iy+BG_HEIGHT),a

        call fast_buffer_hl
        push hl
        call fast_screen_de
        pop hl                  ; HL = record, DE = screen

        ld a,(spr_height)
        ld b,a
        ld a,(spr_bytes)
        cp 2
        jr z,.two
        cp 3
        jr z,.three
        cp 4
        jr z,.four

        ; One byte across. A wheel clipped to a single column.
.one:   push de
        ld a,(de)
        ld (hl),a
        inc hl
        inc e
        pop de
        call fast_next_line
        djnz .one
        jr .done

.two:   push de
        dup 2
        ld a,(de)
        ld (hl),a
        inc hl
        inc e
        edup
        pop de
        call fast_next_line
        djnz .two
        jr .done

.three: push de
        dup 3
        ld a,(de)
        ld (hl),a
        inc hl
        inc e
        edup
        pop de
        call fast_next_line
        djnz .three
        jr .done

.four:  push de
        dup 4
        ld a,(de)
        ld (hl),a
        inc hl
        inc e
        edup
        pop de
        call fast_next_line
        djnz .four

.done:  ld (iy+BG_VALID),1
        ret

;------------------------------------------------------------------------------
; fast_restore - put the photograph back, which erases the sprite
; In:  IY -> background record. Does nothing until the first save.
; The column and the byte count are the ones that were saved, not the
; sprite's new position. Call this before the sprite moves on screen.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
fast_restore:
        ld a,(iy+BG_VALID)
        or a
        ret z

        call fast_buffer_hl
        push hl
        ld a,(iy+BG_Y)
        ld (spr_y),a            ; fast_screen_de reads spr_y and spr_col
        ld a,(iy+BG_COL)
        ld (spr_col),a
        call fast_screen_de
        pop hl                  ; HL = record, DE = screen

        ld b,(iy+BG_HEIGHT)
        ld a,(iy+BG_BYTES)
        cp 2
        jr z,.two
        cp 3
        jr z,.three
        cp 4
        jr z,.four

.one:   push de
        ld a,(hl)
        ld (de),a
        inc hl
        inc e
        pop de
        call fast_next_line
        djnz .one
        ret

.two:   push de
        dup 2
        ld a,(hl)
        ld (de),a
        inc hl
        inc e
        edup
        pop de
        call fast_next_line
        djnz .two
        ret

.three: push de
        dup 3
        ld a,(hl)
        ld (de),a
        inc hl
        inc e
        edup
        pop de
        call fast_next_line
        djnz .three
        ret

.four:  push de
        dup 4
        ld a,(hl)
        ld (de),a
        inc hl
        inc e
        edup
        pop de
        call fast_next_line
        djnz .four
        ret

;------------------------------------------------------------------------------
; fast_pick - HL = the pre-shifted image for spr_shift
; In:  HL -> table of 8 image pointers (from sprite_image)
; Out: HL -> first mask byte of that image
; Corrupts: AF, DE
;------------------------------------------------------------------------------
fast_pick:
        ld a,(spr_shift)
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ret

;------------------------------------------------------------------------------
; fast_draw - draw a masked sprite that is fully stored at spr_bytes
; In:  HL -> first mask byte (shift already chosen). Position from
;      sprite_set_pos. Every stored byte of every row is on screen, so
;      nothing is skipped between rows. The fish and the diver use this.
; Corrupts: AF, BC, DE, HL
;
; A masked byte is: screen = (screen AND mask) OR data. The image has
; to stay in HL because the chip can do AND (HL) and not AND (DE).
;------------------------------------------------------------------------------
fast_draw:
        push hl
        call fast_screen_de
        pop hl
        ld a,(spr_height)
        ld b,a
        ld a,(spr_bytes)
        cp 2
        jr z,.two
        cp 3
        jr z,.three
        cp 4
        jr z,.four

.one:   push de
        ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc e
        pop de
        call fast_next_line
        djnz .one
        ret

.two:   push de
        dup 2
        ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc e
        edup
        pop de
        call fast_next_line
        djnz .two
        ret

.three: push de
        dup 3
        ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc e
        edup
        pop de
        call fast_next_line
        djnz .three
        ret

.four:  push de
        dup 4
        ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc e
        edup
        pop de
        call fast_next_line
        djnz .four
        ret

;------------------------------------------------------------------------------
; fast_draw_gap - fast_draw, for a sprite that is clipped at the edge
; In:  HL -> first on-screen mask byte of row 0 (the caller has already
;      stepped over any pairs hanging off the left). spr_bytes is the
;      visible count. spr_gap2 is how many image bytes to skip after
;      each visible row: the pairs off the right of this row, plus the
;      pairs off the left of the next one. sprite_set_pos_x fills both.
; A fully visible wheel has a gap of 0 and still comes through here,
; because its stored width changes with the shift (2 bytes, or 3).
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
fast_draw_gap:
        push hl
        call fast_screen_de
        pop hl
        ld a,(spr_height)
        ld b,a
        ld a,(spr_bytes)
        cp 2
        jr z,.two
        cp 3
        jr z,.three

.one:   push de
        ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc e
        pop de
        ld a,(spr_gap2)
        add a,l
        ld l,a
        jr nc,.gap1
        inc h
.gap1:  call fast_next_line
        djnz .one
        ret

.two:   push de
        dup 2
        ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc e
        edup
        pop de
        ld a,(spr_gap2)
        add a,l
        ld l,a
        jr nc,.gap2
        inc h
.gap2:  call fast_next_line
        djnz .two
        ret

.three: push de
        dup 3
        ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc e
        edup
        pop de
        ld a,(spr_gap2)
        add a,l
        ld l,a
        jr nc,.gap3
        inc h
.gap3:  call fast_next_line
        djnz .three
        ret

;------------------------------------------------------------------------------
; Atlantis copies of the fish and diver draw. The originals in fish.asm
; and diver.asm are what Engine Demo 1 calls; those files are not edited.
; fast_extra is not used: both sprites stay fully on screen, so the gap
; between rows is zero and fast_draw is the right walker.
;------------------------------------------------------------------------------
fish_restore_fast:
        ld iy,fish_bg
        jp fast_restore

fish_draw_fast:
        ld a,(fish_y)
        ld b,a
        ld a,(fish_x)
        ld c,a
        ld d,FISH_BYTES
        ld e,FISH_HEIGHT
        call sprite_set_pos

        ld iy,fish_bg
        call fast_save

        call fish_image_index
        ld hl,fish_images
        call sprite_image
        call fast_pick
        jp fast_draw

diver_restore_fast:
        ld iy,diver_bg
        jp fast_restore

diver_draw_fast:
        ld a,(diver_y)
        ld b,a
        ld a,(diver_x)
        ld c,a
        ld d,DIVER_BYTES
        ld e,DIVER_HEIGHT
        call sprite_set_pos

        ld iy,diver_bg
        call fast_save

        call diver_image_index
        ld hl,diver_images
        call sprite_image
        call fast_pick
        jp fast_draw
