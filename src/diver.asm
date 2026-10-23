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
; The art has 3 frames (legs apart, half way, together). A kick is
;   apart -> half -> together -> half -> apart ...
; so the order is kept in a 4-entry table, kick_sequence, rather than
; storing the "half way" frame twice. That saves 1920 bytes of pre-shifted
; data, at the cost of one table lookup.
;==============================================================================

; Clamps. Rightmost x keeps all DIVER_BYTES bytes of a shifted row on the
; screen line: 256 - 4*8 + 7 = 231. Bottom: last row of the seabed.
DIVER_MIN_X     equ 0
DIVER_MAX_X     equ 256 - DIVER_BYTES * 8 + 7
DIVER_MIN_Y     equ WATER_TOP_ROW * 8
DIVER_MAX_Y     equ (PLAY_BOTTOM_ROW + 1) * 8 - DIVER_HEIGHT

DIVER_GLIDE     equ 2           ; art frame shown when not moving

;------------------------------------------------------------------------------
; update_diver - move from input_state (000FUDLR), clamp, step the animation
; Corrupts: AF, B
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
        cp DIVER_MAX_Y
        jr nc,.not_down
        inc a
        ld (diver_y),a
.not_down:
        bit IN_UP_BIT,b
        jr z,.not_up
        ld a,(diver_y)
        cp DIVER_MIN_Y + 1
        jr c,.not_up
        dec a
        ld (diver_y),a
.not_up:
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

kick_sequence:  db 0, 1, 2, 1   ; apart, half, together, half

; --- Diver state -------------------------------------------------------------
diver_x:        db 60           ; pixels
diver_y:        db 110          ; pixels, top row of the sprite
diver_facing:   db FACE_RIGHT
diver_moving:   db 0            ; 1 if a direction was held last update
diver_anim:     db 0            ; frames spent moving (wraps; only low bits used)
diver_frame:    db 0            ; art frame last chosen (debug)
diver_bg:       ds BG_DATA + DIVER_BYTES * DIVER_HEIGHT  ; background record
