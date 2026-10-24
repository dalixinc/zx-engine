;==============================================================================
; sprite.asm - masked, pre-shifted software sprites of any width
;
; TECHNIQUE (full walk-through in docs/SPRITES.md)
;
; 1. Pre-shifted images. A sprite at pixel x starts in screen column x/8 and
;    is offset x AND 7 pixels into that byte. tools/gfx2asm.py stores 8 copies
;    of every frame, already shifted by 0..7. Drawing is then a plain byte
;    copy: no bit-shifting at run time.
;
;    Width: a sprite W pixels wide is W/8 + 1 bytes wide in every copy.
;    The extra byte is there because shifting right by 1..7 pushes the
;    rightmost pixels into the next byte along. (At shift 0 that byte is
;    empty, but every copy is kept the same size so the loops below don't
;    care which shift they are drawing.) The fish: 16 px -> 3 bytes. The
;    diver: 24 px -> 4 bytes. The routines here take that byte count as a
;    parameter ("bytes per row"), so one set of routines serves both.
;
; 2. Masking. Each image byte comes as a pair (mask, data):
;        screen = (screen AND mask) OR data
;    Mask bits are 1 where the background must survive, 0 where the sprite
;    is solid.
;
; 3. Save / restore background. Before drawing we copy the screen bytes the
;    sprite is about to cover into that sprite's own "background record"
;    (see below). Next frame we copy them back, which erases the sprite and
;    repairs the scenery in one go.
;
; PER FRAME, for one sprite, straight after HALT:
;        sprite_restore_bg  -> sprite_set_pos -> sprite_save_bg -> sprite_draw
; With several sprites: restore ALL of them first, in the REVERSE order they
; were drawn, then save+draw each in turn (see main_loop). Reverse order
; matters when they overlap: the one drawn last saved a background that
; contained the earlier sprites, so it must be put back first.
;
; The scrolling strips are copied onto the screen after every restore
; (main_loop). A sprite that overlaps a strip is saved and drawn AFTER the
; copy, so the record holds this frame's ground and not the sprite itself
; (saving while it is still drawn would put its own pixels back next frame).
; A sprite that stays in the water is drawn BEFORE the copy: the copy does
; not touch those rows, and drawing it earlier keeps the beam from catching
; it. The demo skips the far strip's copy on a prepare frame, because that
; buffer was not rotated after the previous copy and the screen already
; matches it. Atlantis copies its (shorter) strips every frame. Either way
; the save is after the copy when the sprite overlaps a strip.
; docs/SCROLLING.md has both orders.
;
; BACKGROUND RECORD - one per sprite, pointed to by IY:
;        IY+BG_VALID   0 until the first save (so the first restore is skipped)
;        IY+BG_Y       pixel row it was saved from
;        IY+BG_COL     screen column (0-31)
;        IY+BG_HEIGHT  rows saved
;        IY+BG_BYTES   bytes per row saved
;        IY+BG_DATA... the saved screen bytes, BG_BYTES x BG_HEIGHT of them
; Declare one with   my_bg: ds BG_DATA + bytes * height   (ds fills with 0,
; so BG_VALID starts at 0). IY is used because (iy+n) lets us reach each
; field by name without disturbing HL/DE, which do the copying.
;
; LIMITS: sprite_set_pos / sprite_draw still require the sprite fully on
; screen. x no more than 256 - bytes*8 + 7, so every byte of a shifted row
; stays on that screen line, and y within 0..192-height. The diver and the
; fish use that path, and it is the path Engine Demo 1 ships.
;
; Horizontal clipping (a sprite sliding off the left or the right edge) is
; sprite_set_pos_x / sprite_draw_clip, further down. Those two are assembled
; for Atlantis only. The demo never places a sprite past the edge, and its
; tape is frozen, so the bytes above this comment are the demo's bytes.
; Vertical clipping is not done: callers keep y on screen.
;==============================================================================

BG_VALID        equ 0
BG_Y            equ 1
BG_COL          equ 2
BG_HEIGHT       equ 3
BG_BYTES        equ 4
BG_DATA         equ 5           ; size of the header; saved bytes follow

;------------------------------------------------------------------------------
; sprite_set_pos - work out where the next sprite goes
; In:  B = y (top pixel row), C = x, D = bytes per row (e.g. FISH_BYTES),
;      E = height in pixel rows
; Out: spr_y, spr_col (x / 8), spr_shift (x AND 7), spr_bytes, spr_height
; Corrupts: AF
;------------------------------------------------------------------------------
sprite_set_pos:
        ld a,b
        ld (spr_y),a
        ld a,d
        ld (spr_bytes),a
        ld a,e
        ld (spr_height),a

        ld a,c
        and %00000111           ; pixel offset inside the byte -> which copy
        ld (spr_shift),a

        ld a,c
        rrca                    ; x / 8 = screen column. RRCA x3 then mask
        rrca                    ; off the 3 bits that rotated round to the
        rrca                    ; top (Z80 has no single "shift by 3").
        and %00011111
        ld (spr_col),a
        ret

;------------------------------------------------------------------------------
; sprite_save_bg - copy the screen bytes under the sprite into a record
; In:  IY -> this sprite's background record; position from sprite_set_pos
; Corrupts: AF, BC, DE, HL, IX
;
; Loop shape (also used by restore and draw):
;   outer loop: one pass per pixel row, B counts rows, C = column
;   inner loop: one pass per byte across, B counts bytes
; Both loops want B for DJNZ, so the outer B/C are PUSHed at the start of
; each row and POPped at the end. That is the standard Z80 way to nest two
; DJNZ loops; it costs 21 T-states per row.
;------------------------------------------------------------------------------
sprite_save_bg:
        ; note where this background came from, for the restore
        ld a,(spr_y)
        ld (iy+BG_Y),a
        call row_table_entry    ; IX -> address of the top row
        ld a,(spr_col)
        ld (iy+BG_COL),a
        ld c,a                  ; C = column, added to every row address
        ld a,(spr_bytes)
        ld (iy+BG_BYTES),a
        ld a,(spr_height)
        ld (iy+BG_HEIGHT),a
        ld b,a                  ; B = rows to do

        push iy                 ; DE = IY + BG_DATA, where the bytes go.
        pop de                  ; (no "LD DE,IY": go via the stack)
        ld hl,BG_DATA
        add hl,de
        ex de,hl

.row:   ld a,(ix+0)             ; HL = row address + column
        add a,c                 ; (can't carry: low 5 bits of a row address
        ld l,a                  ;  are 0 and the column fits in them)
        ld h,(ix+1)

        push bc                 ; keep row count + column
        ld a,(iy+BG_BYTES)
        ld b,a
.byte:  ld a,(hl)               ; screen -> buffer
        ld (de),a
        inc de
        inc l                   ; next byte along (same row: L never wraps
        djnz .byte              ;  because the sprite stays on screen)
        pop bc

        inc ix                  ; next table entry = next pixel row
        inc ix
        djnz .row

        ld (iy+BG_VALID),1
        ret

;------------------------------------------------------------------------------
; sprite_restore_bg - put back what sprite_save_bg saved (erases the sprite)
; In:  IY -> this sprite's background record
; Does nothing until the record has been saved once.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
sprite_restore_bg:
        ld a,(iy+BG_VALID)
        or a
        ret z

        ld a,(iy+BG_Y)
        call row_table_entry    ; IX -> table entry for the saved top row
        ld c,(iy+BG_COL)
        ld b,(iy+BG_HEIGHT)

        push iy                 ; HL = IY + BG_DATA, where the bytes are
        pop de
        ld hl,BG_DATA
        add hl,de

.row:   ld a,(ix+0)             ; DE = row address + column
        add a,c
        ld e,a
        ld d,(ix+1)

        push bc
        ld b,(iy+BG_BYTES)
.byte:  ld a,(hl)               ; buffer -> screen
        ld (de),a
        inc hl
        inc e
        djnz .byte
        pop bc

        inc ix
        inc ix
        djnz .row
        ret

;------------------------------------------------------------------------------
; sprite_image - pick an image from a sprite's image table
; In:  HL -> images table (e.g. diver_images), A = index into it
;      (gfx2asm.py orders it facing*FRAMES + frame)
; Out: HL -> that image's table of 8 shift pointers, ready for sprite_draw
; Corrupts: AF, DE
;------------------------------------------------------------------------------
sprite_image:
        add a,a                 ; entries are 16-bit words
        ld e,a
        ld d,0
        add hl,de
        ld e,(hl)               ; read the word (low byte first)
        inc hl
        ld d,(hl)
        ex de,hl
        ret

;------------------------------------------------------------------------------
; sprite_draw - draw a masked sprite at the position from sprite_set_pos
; In:  HL -> table of 8 image pointers (one per shift), from sprite_image
; Corrupts: AF, BC, DE, HL, IX
;
; Register plan inside the loop:
;   HL -> image bytes (mask, data, mask, data, ...)
;   DE -> screen byte being drawn
;   IX -> row table entry,  B = rows left (outer) / bytes left (inner),
;   C = column
; The screen pointer is in DE (not HL) because the Z80 can only do
; AND (HL) / OR (HL), not AND (DE): the image is what we AND and OR with.
;------------------------------------------------------------------------------
sprite_draw:
        ; pick the copy for this shift: HL = word at HL + shift*2
        ld a,(spr_shift)
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl                ; HL -> image for this shift

        ld a,(spr_y)
        push hl
        call row_table_entry    ; (corrupts HL and DE, so keep HL safe)
        pop hl
        ld a,(spr_col)
        ld c,a
        ld a,(spr_height)
        ld b,a

.row:   ld a,(ix+0)             ; DE = row address + column
        add a,c
        ld e,a
        ld d,(ix+1)

        push bc
        ld a,(spr_bytes)
        ld b,a
.byte:  ld a,(de)               ; background
        and (hl)                ; mask: clear where the sprite is solid
        inc hl
        or (hl)                 ; data: set the ink pixels
        inc hl
        ld (de),a
        inc e
        djnz .byte
        pop bc

        inc ix
        inc ix
        djnz .row
        ret

; --- Where the next sprite goes (set by sprite_set_pos) -----------------------
spr_y:          db 0
spr_col:        db 0
spr_shift:      db 0
spr_bytes:      db 0
spr_height:     db 0

;------------------------------------------------------------------------------
; Horizontal edge clipping. Atlantis only.
;
; Engine Demo 1 does not DEFINE ATLANTIS, so none of this is in diver.tap.
; The routines above are untouched, which is what keeps that tape identical.
;
; A sprite's x may now be negative (hanging off the left) or 256 and above
; (hanging off the right). The pre-shifted copies are unchanged. The same
; rule as a positive x still picks the copy:
;
;   shift  = the low 3 bits of x          (x AND 7, which is right for a
;                                          negative x too: -1 has low bits 7)
;   column = floor(x / 8), signed         (so -1 is column -1, shift 7)
;
; Bytes that would land in column -1 or column 32 are not written. The
; background record then holds only the columns that were actually on
; screen, because sprite_save_bg stores spr_col and spr_bytes and those
; two are set to the VISIBLE column and the VISIBLE count. Restore is the
; ordinary sprite_restore_bg: it puts back exactly what was saved, so a
; half-off-screen sprite does not smear into the line above or below, and
; it does not leave a copy of itself in the margin.
;
; When nothing at all is on screen, spr_hidden is 1. The caller must not
; save or draw, and must clear BG_VALID. The restore at the start of the
; frame has already erased the previous position. Leaving VALID set would
; paint that old photograph a second time, on top of whatever is there now.
;
; Drawing. If the sprite is fully on screen, sprite_draw_clip jumps to
; sprite_draw. The test costs about 70 T-states (a third of a scanline)
; and the byte loop is the original one. While it is clipped, each row
; adds the hidden image bytes onto HL so the next row starts in the right
; place. That add is:
;
;   ld a,(spr_gap2)   ; 13
;   add a,l           ;  4
;   ld l,a            ;  4
;   jr nc             ; 12 when it does not cross a page, 7 when it does
;   inc h             ;  4 only on the cross
;
; 33 T-states on the usual row, 32 when HL crosses a 256-byte boundary.
; A 16-row sprite pays 16*33 = 528 T-states, which is 528/224 = 2.4
; scanlines, and the byte loop is shorter by every byte that is off
; screen (the masked byte is about 57 T-states, so two skipped bytes
; over 16 rows is about 8 scanlines saved). An off-screen margin (draw
; the whole sprite into a wider buffer, then copy the visible part) would
; draw the hidden bytes as well, so it costs more than skipping them.
;
; Not handled: a sprite wider than the screen, clipped on the left AND the
; right at once. Nothing here is that wide. The widest is the diver, 4
; stored bytes, and he does not use this path.
;------------------------------------------------------------------------------
        IFDEF ATLANTIS

spr_skip2:      db 0            ; image bytes to skip at the left of row 0
spr_gap2:       db 0            ; image bytes to skip after each visible row
spr_hidden:     db 0            ; 1 = nothing to save or draw

;------------------------------------------------------------------------------
; sprite_set_pos_x - position, allowing x off the left or the right
; In:  HL = pixel x, signed (negative, or 256 and up, are off screen)
;      B = y, D = stored bytes per row, E = height
; Out: spr_y, spr_shift, spr_height as sprite_set_pos
;      spr_col, spr_bytes = the visible column and the visible byte count
;      spr_skip2, spr_gap2, spr_hidden as above
; Corrupts: AF, C, HL
;------------------------------------------------------------------------------
sprite_set_pos_x:
        ld a,b
        ld (spr_y),a
        ld a,e
        ld (spr_height),a

        ld a,l
        and %00000111           ; shift, correct for a negative x as well
        ld (spr_shift),a

        ; column = floor(x / 8). SRA brings the sign down with it, so a
        ; negative x stays negative. Three of them is a divide by 8.
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l                    ; L = column, H = $00 or $FF

        bit 7,h
        jr nz,.off_left

        ; column >= 0. Column 32 and beyond is completely off the right.
        ld a,l
        cp 32
        jr nc,.hide
        ld (spr_col),a
        xor a
        ld (spr_skip2),a        ; the left edge of the image is on screen

        ; The last byte sits in column (column + bytes - 1). That is still
        ; column 31 when column + bytes <= 32.
        ld a,d
        add a,l
        cp 33
        jr c,.all_on            ; column + bytes <= 32

        ld a,32
        sub l                   ; visible = how many columns are left
        ld (spr_bytes),a
        ld c,a
        ld a,d
        sub c                   ; hidden on the right = full width - visible
        jr .gap

.all_on:
        ld a,d                  ; every stored byte lands on the screen
        ld (spr_bytes),a
        xor a                   ; nothing hidden on the right
        jr .gap

.off_left:
        ; skip = -column. The bytes that fell off the left are dropped
        ; and drawing starts at column 0.
        ld a,l
        neg
        cp d
        jr nc,.hide             ; the whole row is off the left
        ld c,a                  ; pairs to skip
        ld a,d
        sub c
        ld (spr_bytes),a        ; the rest of the row. A 3 or 4 byte sprite
        xor a                   ; starting at column 0 cannot also hang off
        ld (spr_col),a          ; the right, so the right-hand tail is 0.
        ld a,c
        add a,a                 ; pairs -> image bytes (mask, data)
        ld (spr_skip2),a
        xor a
        ; fall into .gap

.gap:   ; A = pairs hidden on the right. The gap between one visible row
        ; and the next is those pairs plus the pairs hidden on the left.
        ld c,a
        ld a,(spr_skip2)
        srl a                   ; back to pairs; spr_skip2 is always even
        add a,c
        add a,a                 ; and back to image bytes
        ld (spr_gap2),a
        xor a
        ld (spr_hidden),a
        ret

.hide:  ld a,1
        ld (spr_hidden),a
        ret

;------------------------------------------------------------------------------
; sprite_draw_clip - sprite_draw, skipping bytes that are off the edge
; In:  HL -> table of 8 image pointers, as for sprite_draw
;      position from sprite_set_pos_x
; Does nothing when spr_hidden is set.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
sprite_draw_clip:
        ld a,(spr_hidden)
        or a
        ret nz
        ; Fully on screen: spr_bytes is the full width and spr_col is the
        ; real column, which is exactly what sprite_draw wants.
        ld a,(spr_skip2)
        or a
        jr nz,.clipped
        ld a,(spr_gap2)
        or a
        jp z,sprite_draw

.clipped:
        ld a,(spr_shift)        ; same copy-picking as sprite_draw
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl                ; HL -> image for this shift

        ; Row 0: step over the pairs that hang off the left. Later rows
        ; get the same step from spr_gap2, after the previous row.
        ld a,(spr_skip2)
        add a,l
        ld l,a
        jr nc,.skip0
        inc h
.skip0:
        ld a,(spr_y)
        push hl
        call row_table_entry
        pop hl
        ld a,(spr_col)
        ld c,a
        ld a,(spr_height)
        ld b,a

.row:   ld a,(ix+0)             ; DE = first on-screen byte of this row
        add a,c
        ld e,a
        ld d,(ix+1)

        push bc
        ld a,(spr_bytes)        ; visible bytes only. At least one: a count
        ld b,a                  ; of 0 is spr_hidden, and we returned.
.byte:  ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc e                   ; stays on this screen line: the visible
        djnz .byte              ; bytes end at column 31 or before
        pop bc

        ld a,(spr_gap2)         ; skip the hidden pairs, then the left-hand
        add a,l                 ; pairs of the next row. 33 T-states.
        ld l,a
        jr nc,.gap_nc
        inc h
.gap_nc:
        inc ix
        inc ix
        djnz .row
        ret

        ENDIF
