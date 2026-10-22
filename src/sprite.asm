;==============================================================================
; sprite.asm - masked, pre-shifted 16-pixel-wide software sprites
;
; TECHNIQUE (full walk-through in docs/SPRITES.md)
;
; 1. Pre-shifted images. A sprite at pixel x starts in screen column x/8 and
;    is offset x AND 7 pixels into that byte. tools/gfx2asm.py stores 8 copies
;    of every frame, already shifted by 0..7, each 3 bytes wide. Drawing is
;    then a plain byte copy: no bit-shifting at run time.
;
; 2. Masking. Each image byte comes as a pair (mask, data):
;        screen = (screen AND mask) OR data
;    Mask bits are 1 where the background must survive and 0 where the
;    sprite is solid, so the sprite gets a clean shape instead of being
;    XOR-ed or OR-ed into the scenery.
;
; 3. Save / restore background. Before drawing we copy the screen bytes the
;    sprite is about to cover into bg_buffer. Next frame we put them back
;    (erasing the sprite and repairing the scenery in one go), then save and
;    draw at the new position.
;
; Per frame, call in this order, straight after HALT:
;        sprite_restore_bg  -> sprite_set_pos -> sprite_save_bg -> sprite_draw
;
; Limits for now (one sprite, simple bounds): only ONE sprite uses bg_buffer;
; the caller must keep x in 0..239 (so all 3 bytes stay on the same pixel
; row) and the sprite fully on screen vertically. Proper clipping and a
; buffer per sprite come with the entities milestone.
;==============================================================================

;------------------------------------------------------------------------------
; sprite_set_pos - work out where the sprite goes
; In:  B = y (top pixel row), C = x (0-239), E = height in pixel rows
; Out: spr_y, spr_col (x / 8), spr_shift (x AND 7), spr_height set
; Corrupts: AF
;------------------------------------------------------------------------------
sprite_set_pos:
        ld a,b
        ld (spr_y),a
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
; sprite_save_bg - copy the 3 x height screen bytes under the sprite into
; bg_buffer and remember where they came from.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
sprite_save_bg:
        ld a,(spr_y)
        ld (bg_y),a
        call row_table_entry    ; IX -> address of the top row
        ld a,(spr_col)
        ld (bg_col),a
        ld c,a                  ; C = column, added to every row address
        ld a,(spr_height)
        ld (bg_height),a
        ld b,a                  ; B = rows to do

        ld de,bg_buffer
.row:   ld a,(ix+0)             ; HL = row address + column
        add a,c                 ; (can't carry: low 5 bits of a row address
        ld l,a                  ;  are 0 and the column is at most 29)
        ld h,(ix+1)

        ld a,(hl)               ; byte 0
        ld (de),a
        inc de
        inc l
        ld a,(hl)               ; byte 1
        ld (de),a
        inc de
        inc l
        ld a,(hl)               ; byte 2
        ld (de),a
        inc de

        inc ix                  ; next table entry = next pixel row
        inc ix
        djnz .row

        ld a,1
        ld (bg_valid),a
        ret

;------------------------------------------------------------------------------
; sprite_restore_bg - put back what sprite_save_bg saved (erases the sprite)
; Does nothing on the very first frame, when nothing has been saved yet.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
sprite_restore_bg:
        ld a,(bg_valid)
        or a
        ret z

        ld a,(bg_y)
        call row_table_entry
        ld a,(bg_col)
        ld c,a
        ld a,(bg_height)
        ld b,a

        ld hl,bg_buffer
.row:   ld a,(ix+0)             ; DE = row address + column
        add a,c
        ld e,a
        ld d,(ix+1)

        ld a,(hl)               ; byte 0
        ld (de),a
        inc hl
        inc e
        ld a,(hl)               ; byte 1
        ld (de),a
        inc hl
        inc e
        ld a,(hl)               ; byte 2
        ld (de),a
        inc hl

        inc ix
        inc ix
        djnz .row
        ret

;------------------------------------------------------------------------------
; sprite_draw - draw a masked sprite at the position from sprite_set_pos
; In:  HL -> table of 8 image pointers (one per shift), e.g. fish_right_f0
; Corrupts: AF, BC, DE, HL, IX
;
; Register plan inside the loop:
;   HL -> image bytes (mask, data, mask, data, ...)
;   DE -> screen byte being drawn
;   IX -> row table entry,  B = rows left,  C = column
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
        call row_table_entry    ; (corrupts DE, which is why HL was pushed)
        pop hl
        ld a,(spr_col)
        ld c,a
        ld a,(spr_height)
        ld b,a

.row:   ld a,(ix+0)             ; DE = row address + column
        add a,c
        ld e,a
        ld d,(ix+1)

        ; one screen byte = (screen AND mask) OR data, three times
        ld a,(de)               ; background
        and (hl)                ; mask: clear where the sprite is solid
        inc hl
        or (hl)                 ; data: set the ink pixels
        inc hl
        ld (de),a
        inc e

        ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc e

        ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a

        inc ix
        inc ix
        djnz .row
        ret

; --- Sprite state ------------------------------------------------------------
spr_y:          db 0            ; where the next draw goes
spr_col:        db 0
spr_shift:      db 0
spr_height:     db 0

bg_valid:       db 0            ; 0 until the first save
bg_y:           db 0            ; where bg_buffer was saved from
bg_col:         db 0
bg_height:      db 0
bg_buffer:      ds SPRITE_BYTES * SPRITE_MAX_H
