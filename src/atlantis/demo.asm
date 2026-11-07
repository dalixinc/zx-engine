;==============================================================================
; demo.asm - the attract demo (AUTOPLAY, where boot goes to the menu)
;
; If the menu sits for CFG_DEMO_WAIT seconds with no key down, a level 1
; game starts with the computer at the controls: main_loop's call to
; read_input (main_loop.input_call) is patched to demo_input, which
; makes up input_state each step. It swims him level with the bomb, or
; else the fish, while it is ahead of him, fires when he is level, and
; steps aside from a silo missile coming up near him. Any key, or
; CFG_DEMO_TIME seconds, goes back to the menu (enter_menu, which puts
; read_input back). A demo that loses its last life goes back too,
; with no knell, and its score is never a high score.
;
; Only level 1, so nothing later is given away, and row 0 says DEMO.
;==============================================================================

    IFDEF AUTOPLAY

; Where he waits with nothing ahead of him, and how near (pixel rows)
; counts as level with it: fire, and stop climbing or sinking.
DEMO_REST_Y     equ 100
DEMO_LEVEL      equ 3
; A target that has come within DEMO_CLOSE pixels of his left edge
; unshot is let past: he aims DEMO_AVOID rows below it instead (above
; it, if that would take him below DEMO_LOW, near the weed).
DEMO_CLOSE      equ 56
DEMO_AVOID      equ 24
DEMO_LOW        equ 140
; A missile closer than this to his middle, either way, is dodged.
DEMO_DODGE      equ 20
; He swims back left past this x, and turns to face right again below
; DEMO_TURN_X, so he is not turning every step.
DEMO_BACK_X     equ 140
DEMO_TURN_X     equ 110

;------------------------------------------------------------------------------
; demo_input - read_input's place in a demo: a key ends it, so does its
; time; otherwise the computer's keys go into input_state, as
; read_input's would. Every step, so it is in the hot code.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
demo_input:
        ld a,(input_state)
        ld (input_prev),a
        xor a
        in a,(ULA_PORT)         ; every half-row at once
        cpl
        and %00011111
        jp nz,enter_menu        ; a key: back to the menu
        ld hl,(frame_count)     ; game_reset started it at 0
        ld de,-CFG_DEMO_TIME * 50
        add hl,de
        jp c,enter_menu         ; its time is up

        ; What he aims at: B = the height he wants (his top row), D = 1
        ; if there is something ahead of him to shoot.
        ld a,(diver_x)
        ld c,a
        ld b,DEMO_REST_Y
        ld d,0
        ld a,(wheel_phase)
        or a
        jr z,.fish
        ld a,(wheel_x + 1)
        or a
        jr nz,.fish             ; still off the right edge
        ld a,(wheel_x)
        sub c
        jr c,.fish              ; behind him
        ld l,a                  ; L = how far ahead
        ld a,(wheel_y)
        add a,WHEEL_HEIGHT / 2 - TORP_MOUTH_Y - 1
        jr .aim
.fish:  ld a,(fish_x)
        sub c
        jr c,.steer             ; behind him: wait at the resting height
        ld l,a
        ld a,(fish_y)
        add a,FISH_HEIGHT / 2 - TORP_MOUTH_Y - 1
.aim:   ld b,a
        inc d
        ld a,l
        cp DEMO_CLOSE
        jr nc,.steer
        dec d                   ; too close: no shot, out of its way
        ld a,b
        add a,DEMO_AVOID
        cp DEMO_LOW
        jr c,.avoid
        sub 2 * DEMO_AVOID
.avoid: ld b,a

.steer: ld e,0                  ; E = the keys
        ld a,(diver_y)
        ld h,a
        ld a,b
        sub h                   ; how far below him it is
        jr nc,.below
        neg
        cp DEMO_LEVEL
        jr c,.level
        set IN_UP_BIT,e
        jr .side
.below: cp DEMO_LEVEL
        jr c,.level
        set IN_DOWN_BIT,e
        jr .side
.level: ; Level with it: fire, on every other 4 frames, so each press
        ; is a new one (torpedo_fire wants fire up the step before).
        ld a,d
        or a
        jr z,.side
        ld a,(frame_count)
        and 4
        jr z,.side
        set IN_FIRE_BIT,e

.side:  ; A missile coming up near him: step aside, away from it.
        ld a,(msl_phase)
        or a
        jr z,.home
        ld a,(msl_x)
        sub c
        sub DIVER_WIDTH / 2     ; A = its x less his middle
        jr nc,.right_of
        neg
        cp DEMO_DODGE
        jr nc,.home
        set IN_RIGHT_BIT,e      ; it is left of his middle: go right
        jr .done
.right_of:
        cp DEMO_DODGE
        jr nc,.home
        set IN_LEFT_BIT,e
        jr .done

.home:  ; Otherwise keep to the left half, facing right.
        ld a,(diver_facing)
        or a                    ; FACE_RIGHT is 0
        ld a,c
        jr z,.facing
        cp DEMO_TURN_X
        jr nc,.left
        set IN_RIGHT_BIT,e      ; far enough back: face right again
        jr .done
.facing:
        cp DEMO_BACK_X
        jr c,.done
.left:  set IN_LEFT_BIT,e
.done:  ld a,e
        ld (input_state),a
        ret

        COLD
;------------------------------------------------------------------------------
; demo_idle - each menu frame: a key starts the wait again; after
; CFG_DEMO_WAIT seconds without one, the demo starts.
; Corrupts: AF, DE, HL
;------------------------------------------------------------------------------
demo_idle:
        xor a
        in a,(ULA_PORT)
        cpl
        and %00011111
        jr nz,demo_arm
        ld hl,(frame_count)
        ld de,(demo_from)
        or a
        sbc hl,de
        ld de,CFG_DEMO_WAIT * 50
        or a
        sbc hl,de
        ret c
        ; A level 1 game, with the computer's keys.
        ld a,1
        ld (start_level),a
        ld (demo_on),a
        ld hl,demo_input
        ld (main_loop.input_call + 1),hl
        jp game_reset

;------------------------------------------------------------------------------
; demo_off - enter_menu: the keyboard's keys again, and the wait from now
; Corrupts: AF, HL
;------------------------------------------------------------------------------
demo_off:
        xor a
        ld (demo_on),a
        ld hl,read_input
        ld (main_loop.input_call + 1),hl
demo_arm:
        ld hl,(frame_count)
        ld (demo_from),hl
        ret

;------------------------------------------------------------------------------
; demo_label - game_reset, in a demo: DEMO on row 0, which play leaves
; alone (the sprites photograph it like water).
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
demo_label:
        ld a,WATER_ATTR
        ld (text_attr),a
        ld hl,str_demo
        ld bc,(0 << 8) | 7
        jp print_string
str_demo:       db "DEMO - PRESS ANY KEY",0

demo_on:        db 0            ; 1 = the computer is playing
demo_from:      dw 0            ; frame_count when the menu's wait began
        HOT

        ASSERT CFG_DEMO_WAIT >= 1 && CFG_DEMO_WAIT <= 600
        ASSERT CFG_DEMO_TIME >= 1 && CFG_DEMO_TIME <= 600
    ENDIF
