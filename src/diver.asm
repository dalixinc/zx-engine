;==============================================================================
; diver.asm - the player: a diver with a jet unit, steered by keys/Kempston
;
; Movement is 1 pixel per frame in any of 8 directions, clamped to the play
; area. He turns to face the way he is going (left/right).
;
; Animation: the flipper kick only advances while he is moving. Standing
; still he shows the "legs together, glide" frame. Why: a diver kicking
; while going nowhere looks wrong, and it makes it obvious on screen whether
; input is getting through. (An idle bob could be added later.)
;
; The art has 3 frames (legs apart, half way, crossed). A kick is
;   apart -> half -> crossed -> half -> apart ...
; so the order is kept in a 4-entry table, kick_sequence, rather than
; storing the "half way" frame twice. That saves 1920 bytes of pre-shifted
; data, at the cost of one table lookup.
;==============================================================================

; Clamps. Rightmost x keeps all DIVER_BYTES bytes of a shifted row on the
; screen line: 256 - 4*8 + 7 = 231. The bottom is not a fixed row any more:
; clamp_to_terrain holds his feet one pixel above the near silhouette.
DIVER_MIN_X     equ 0
DIVER_MAX_X     equ 256 - DIVER_BYTES * 8 + 7
DIVER_MIN_Y     equ WATER_TOP_ROW * 8

DIVER_GLIDE     equ 2           ; art frame shown when not moving

;------------------------------------------------------------------------------
; update_diver - move from input_state (000FUDLR), clamp, step the animation
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
update_diver:
        ld a,(input_state)
        ld b,a                  ; keep the bits; each test looks at B

        bit IN_RIGHT_BIT,b
        jr z,.not_right
        ld a,FACE_RIGHT         ; turn even if we're already at the edge
        ld (diver_facing),a
        ld a,(diver_x)
        cp DIVER_MAX_X
        jr nc,.not_right        ; at the right edge (x >= max)
        inc a
        ld (diver_x),a
.not_right:
        bit IN_LEFT_BIT,b
        jr z,.not_left
        ld a,FACE_LEFT
        ld (diver_facing),a
        ld a,(diver_x)
        cp DIVER_MIN_X + 1
        jr c,.not_left          ; at the left edge (x = 0)
        dec a
        ld (diver_x),a
.not_left:
        bit IN_DOWN_BIT,b
        jr z,.not_down
        ld a,(diver_y)
        inc a                   ; the terrain clamp below pulls this back
        ld (diver_y),a          ; if it went into the hill
.not_down:
        bit IN_UP_BIT,b
        jr z,.not_up
        ld a,(diver_y)
        cp DIVER_MIN_Y + 1
        jr c,.not_up
        dec a
        ld (diver_y),a
.not_up:
        ; Every frame, including when he is still. The ground scrolls
        ; whether or not he is swimming, and a hill has to be able to
        ; lift him. B still holds the input bits; the clamp gives them back.
        call clamp_to_terrain
        ; animation: count frames only while a direction is held
        ld a,b
        and IN_UP | IN_DOWN | IN_LEFT | IN_RIGHT
        jr z,.idle
        ld a,1
        ld (diver_moving),a
        ld a,(diver_anim)
        inc a                   ; wraps 255 -> 0, harmless: only bits 2-3
        ld (diver_anim),a       ; are used to pick the kick step
        ret
.idle:  xor a
        ld (diver_moving),a
        ld (diver_anim),a       ; restart the kick from the top next time
        ret

;------------------------------------------------------------------------------
; diver_restore / diver_draw - same split as the fish (see fish.asm)
; Corrupts: AF, BC, DE, HL, IX, IY
;------------------------------------------------------------------------------
diver_restore:
        ld iy,diver_bg
        jp sprite_restore_bg

diver_draw:
        ld a,(diver_y)
        ld b,a
        ld a,(diver_x)
        ld c,a
        ld d,DIVER_BYTES
        ld e,DIVER_HEIGHT
        call sprite_set_pos

        ld iy,diver_bg
        call sprite_save_bg

        call diver_image_index
        ld hl,diver_images
        call sprite_image
        jp sprite_draw

;------------------------------------------------------------------------------
; diver_image_index - A = facing * DIVER_FRAMES + art frame
; While moving: art frame = kick_sequence[(diver_anim / DIVER_ANIM_STEP) & 3]
; While still (diver_moving = 0): the glide frame.
; Corrupts: AF, DE, HL
;------------------------------------------------------------------------------
diver_image_index:
        ld a,(diver_moving)
        or a
        jr nz,.moving
        ld a,DIVER_GLIDE        ; not moving: glide pose
        jr .got_frame

.moving:
        ld a,(diver_anim)
        rrca                    ; / DIVER_ANIM_STEP (= 4): two right shifts
        rrca
        and %00000011           ; 4 steps in a kick
        ld e,a
        ld d,0
        ld hl,kick_sequence
        add hl,de
        ld a,(hl)               ; A = art frame for this step

.got_frame:
        ld (diver_frame),a      ; (kept for the debug line)
        ld e,a
        ld a,(diver_facing)     ; facing * 3 = facing*2 + facing
        ld d,a
        add a,a
        add a,d
        add a,e                 ; + art frame
        ret

kick_sequence:  db 0, 1, 2, 1   ; apart, half, crossed, half

;------------------------------------------------------------------------------
; clamp_to_terrain - feet one pixel above the tallest near column he covers
;
; The near strip is a height per column (front_h), plus the column still
; sliding in on the right (front_h_pending). His 24 pixels can cover up to
; four columns, five when the right-hand one is that incoming column.
;
;   column under screen x  =  (x + front_fine) / 8
;   height of that column  =  front_h[(front_head + column) & 31]
;
; front_fine is how far the strip has moved since the columns last lined
; up with the screen. front_head is which slot of the ring is the left
; edge. The incoming column is number 32 (front_h_pending).
;
; max y = NEAR_BOTTOM - height - DIVER_HEIGHT. NEAR_BOTTOM is the pixel
; just under the strip. A valley (the shortest step in near_profile) lets
; him down the furthest; a silo is the full 16 pixels, so he stops with
; his feet on the pixel above the tip. He is allowed to overlap the far
; yellow hills. Those are behind him. Only the black strip stops him.
;
; In:  B = input flags, preserved. Corrupts: AF, C, DE, HL
;------------------------------------------------------------------------------
clamp_to_terrain:
        push bc
        ld a,(diver_x)
        ld hl,front_fine
        add a,(hl)              ; left edge. diver_x + fine is at most 238.
        ld l,a
        rrca
        rrca
        rrca
        and %00011111
        ld b,a                  ; B = first column

        ld a,l
        add a,DIVER_BYTES * 8 - 1
        ld c,a                  ; low byte of the right edge (wraps at 256)
        ld a,0
        adc a,0                 ; LD does not clear the carry, so this is 1
        ld h,a                  ; when the right edge is past the last pixel
        ld a,c
        rrca
        rrca
        rrca
        and %00011111
        ld c,a                  ; column within that low byte
        ld a,h
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a                 ; bit 8 of the pixel becomes 32 columns
        or c
        ld c,a                  ; C = last column (0..32)

        ld e,0                  ; tallest height so far
.scan:  ld a,b
        cp 32
        jr nc,.pending          ; column 32 is front_h_pending, not the table
        ld a,(front_head)       ; ring: screen column B lives at this slot
        add a,b
        and 31
        push bc                 ; C is the last column; E is the tallest so far
        ld c,a
        ld b,0
        ld hl,front_h
        add hl,bc
        pop bc
        ld a,(hl)
        cp e
        jr c,.shorter
        ld e,a
.shorter:
        ld a,b
        cp c
        jr z,.apply
        inc b
        jr .scan
.pending:
        ld a,(front_h_pending)
        cp e
        jr c,.apply
        ld e,a
.apply: ld a,NEAR_BOTTOM - DIVER_HEIGHT
        sub e                   ; E is 0..16, so this does not borrow
        ld hl,diver_y
        cp (hl)
        jr nc,.done             ; already at or above the skyline
        ld (hl),a
.done:  pop bc
        ret

; --- Diver state -------------------------------------------------------------
diver_x:        db 60           ; pixels
diver_y:        db 110          ; pixels, top row of the sprite
diver_facing:   db FACE_RIGHT
diver_moving:   db 0            ; 1 if a direction was held last update
diver_anim:     db 0            ; frames spent moving (wraps; only low bits used)
diver_frame:    db 0            ; art frame last chosen (debug)
diver_bg:       ds BG_DATA + DIVER_BYTES * DIVER_HEIGHT  ; background record
