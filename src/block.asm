;==============================================================================
; block.asm - milestone 3 test object: a 16x16 (2x2 cell) attribute block
;
; Drawn purely with attributes, so it costs 8 byte writes per frame and can't
; flicker. draw_block runs straight after HALT while the beam is still in the
; top border.
;==============================================================================

;------------------------------------------------------------------------------
; update_block - move by input every MOVE_FRAMES frames, cycle colour on a
; fresh FIRE press. Corrupts: AF, BC, HL
;------------------------------------------------------------------------------
update_block:
        ; FIRE: rising edge -> next paper colour (1-7, skipping black)
        ld a,(input_prev)
        cpl
        ld b,a
        ld a,(input_state)
        and b                   ; bits newly pressed this frame
        and IN_FIRE
        jr z,.nofire
        ld a,(block_colour)
        inc a
        and 7
        jr nz,.setc
        inc a
.setc:  ld (block_colour),a
.nofire:
        ld a,(frame_count)
        and MOVE_FRAMES-1
        ret nz

        ld a,(input_state)
        ld c,a
        ld hl,block_x
        bit IN_LEFT_BIT,c
        jr z,.nl
        ld a,(hl)
        cp PLAY_LEFT
        jr z,.nl
        dec (hl)
.nl:    bit IN_RIGHT_BIT,c
        jr z,.nr
        ld a,(hl)
        cp PLAY_RIGHT-BLOCK_SIZE+1
        jr z,.nr
        inc (hl)
.nr:    ld hl,block_y
        bit IN_UP_BIT,c
        jr z,.nu
        ld a,(hl)
        cp PLAY_TOP
        jr z,.nu
        dec (hl)
.nu:    bit IN_DOWN_BIT,c
        ret z
        ld a,(hl)
        cp PLAY_BOTTOM-BLOCK_SIZE+1
        ret z
        inc (hl)
        ret

;------------------------------------------------------------------------------
; draw_block - erase at the old position, draw at the new one
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
draw_block:
        ld a,(old_y)
        ld b,a
        ld a,(old_x)
        ld c,a
        ld e,BG_ATTR
        call fill_2x2

        ld a,(block_y)
        ld (old_y),a
        ld b,a
        ld a,(block_x)
        ld (old_x),a
        ld c,a
        ld a,(block_colour)
        rlca
        rlca
        rlca                    ; colour -> PAPER bits
        or BRIGHT
        ld e,a
        ; fall through

;------------------------------------------------------------------------------
; fill_2x2 - In: B,C = top-left cell, E = attribute. Corrupts: AF, HL
;------------------------------------------------------------------------------
fill_2x2:
        call attr_addr
        ld (hl),e
        inc l
        ld (hl),e
        ld a,l
        add a,31                ; down one row, back one column
        ld l,a
        jr nc,.nc
        inc h
.nc:    ld (hl),e
        inc l
        ld (hl),e
        ret

; --- Block state -------------------------------------------------------------
block_x:        db 15
block_y:        db 13
old_x:          db 15
old_y:          db 13
block_colour:   db RED
