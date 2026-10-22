;==============================================================================
; fish.asm - the test sprite: a fish you steer with the keys or joystick
;
; This is the "game object" side: it owns the fish's position, facing and
; animation, and decides which pre-shifted image to give sprite.asm. All the
; pixel pushing happens in sprite.asm.
;
; Movement is 1 pixel per frame (50 pixels a second) in any of 8 directions.
; The position is clamped to the play area, so the fish never leaves the
; water/seabed region and the sprite never runs off the edge of the screen.
;==============================================================================

FISH_MIN_X      equ 0
FISH_MAX_X      equ 256 - 16 - 1        ; 239: keeps all 3 bytes of a shifted
                                        ; row on the same screen line
FISH_MIN_Y      equ WATER_TOP_ROW * 8   ; top pixel row of the water
FISH_MAX_Y      equ (PLAY_BOTTOM_ROW + 1) * 8 - FISH_HEIGHT

FACE_RIGHT      equ 0
FACE_LEFT       equ 1

;------------------------------------------------------------------------------
; update_fish - move the fish from input_state (000FUDLR), then clamp it
; Corrupts: AF, B
;------------------------------------------------------------------------------
update_fish:
        ld a,(input_state)
        ld b,a                  ; keep the bits; each test re-reads B

        bit IN_RIGHT_BIT,b
        jr z,.not_right
        ld a,(fish_x)
        cp FISH_MAX_X
        jr nc,.not_right        ; already at the right edge (x >= max)
        inc a
        ld (fish_x),a
        ld a,FACE_RIGHT
        ld (fish_facing),a
.not_right:
        bit IN_LEFT_BIT,b
        jr z,.not_left
        ld a,(fish_x)
        cp FISH_MIN_X + 1
        jr c,.not_left          ; already at the left edge (x = 0)
        dec a
        ld (fish_x),a
        ld a,FACE_LEFT
        ld (fish_facing),a
.not_left:
        bit IN_DOWN_BIT,b
        jr z,.not_down
        ld a,(fish_y)
        cp FISH_MAX_Y
        jr nc,.not_down
        inc a
        ld (fish_y),a
.not_down:
        bit IN_UP_BIT,b
        jr z,.not_up
        ld a,(fish_y)
        cp FISH_MIN_Y + 1
        jr c,.not_up
        dec a
        ld (fish_y),a
.not_up:
        ret

;------------------------------------------------------------------------------
; draw_fish - erase last frame's fish and draw it at its new position
; Call straight after HALT, before anything else touches the screen.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
draw_fish:
        call sprite_restore_bg  ; 1. put back what was under the old fish

        ld a,(fish_y)           ; 2. where the new one goes
        ld b,a
        ld a,(fish_x)
        ld c,a
        ld e,FISH_HEIGHT
        call sprite_set_pos

        call sprite_save_bg     ; 3. remember what is under it

        call fish_image         ; 4. draw it
        jp sprite_draw          ; (jp instead of call + ret: same effect)

;------------------------------------------------------------------------------
; fish_image - HL -> shift table for the current facing and animation frame
; The frame flips every ANIM_FRAMES video frames: (frame_count / 8) AND 1.
; Index into fish_images = facing * 2 + frame. Corrupts: AF, DE
;------------------------------------------------------------------------------
fish_image:
        ld a,(frame_count)
        and ANIM_FRAMES         ; one bit of the counter: 0 or ANIM_FRAMES
        jr z,.frame0
        ld a,1
.frame0:
        ld e,a                  ; E = animation frame, 0 or 1
        ld a,(fish_facing)
        add a,a                 ; facing * 2 (2 frames per facing)
        add a,e
        ld (fish_frame),a       ; (kept for the debug line)
        add a,a                 ; * 2 again: fish_images holds 16-bit words
        ld e,a
        ld d,0
        ld hl,fish_images
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ret

; --- Fish state --------------------------------------------------------------
fish_x:         db 40           ; pixels, 0-239
fish_y:         db 100          ; pixels, top row of the sprite
fish_facing:    db FACE_RIGHT
fish_frame:     db 0            ; image index last drawn (for debugging)
