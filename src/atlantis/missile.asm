;==============================================================================
; missile.asm - the silos fire missiles straight up
;
; One missile at a time. After a random wait (CFG_MISSILE_GAP_MIN to
; _MAX), a silo on screen near the diver (CFG_MISSILE_RANGE) is picked,
; at random if there are several, and its missile sits in the hatch,
; scrolling with the ground, for CFG_MISSILE_ARM. That is the warning.
; Then it leaves, straight up, CFG_MISSILE_SPEED pixels per 1/50 second,
; and keeps the screen column it left from. It is gone below the hearts
; (row 2): the top of the water, as far as the sprites go.
;
; It leaves only when the ground has put it at shift 0, 1 or 2. At those
; the six pixels fit in one byte (gfx/missile.txt), so in flight it is
; one byte a row: the cheapest sprite on the screen. That is a front_fine
; of 3, 4 or 5, and at 25 frames a second, which moves the ground two
; pixels a step, one of those always comes round.
;
; Touching the diver is a hit, the same as the bomb: the burst, a life,
; back to the left edge and his crunch. A torpedo blows it up, with its
; own sound (CFG_MISSILE_SND_*).
;
; Drawing: save, draw, restore, as the other sprites do, in the same
; layer order. Up in the water it is drawn first, straight after the
; burst (the bottom layer), and restored last. In the hatch, or low in
; the weed, it is drawn after the seabed copy, first of the late
; sprites, and restored after them. msl_vn says which, the way torp_vn
; does for the torpedo.
;==============================================================================

; gfx/missile.asm comes after the code, and DUP needs the number now.
MSL_ROWS        equ 8

MSL_ARMED       equ 1
MSL_FLY         equ 2
MSL_SINK        equ 3           ; a power-up, going down

; What the slot holds. A power-up uses the missile's slot, its draw and
; its test against the diver: while one is up no missile is, so it adds
; no frame the missile does not already cost.
MSL_KIND_MISSILE equ 0
MSL_KIND_HEART  equ 1           ; one more life
MSL_KIND_DOUBLE equ 2           ; the double shot for CFG_DOUBLE_TIME
; It sinks from below the hearts and is gone above the weed, so it is
; always drawn before the seabed copy, and always one byte a row: its x
; is a multiple of 8, and the water does not scroll.
POWER_TOP       equ MSL_TOP
POWER_LOW       equ BACK_ROW * 8 - MISSILE_HEIGHT
MSL_LOW         equ $80         ; msl_vn: drawn after the seabed copy

; In the hatch: the nose stands six pixels out of the dome's top row.
MSL_ARMED_Y     equ BACK_ROW * 8 - 6
; Centred on the 16-pixel silo: its left pixel is 5 in from the silo's.
MSL_DX          equ (16 - MISSILE_WIDTH) / 2
; Gone when its top would go above this: below the hearts on row 1.
MSL_TOP         equ 2 * 8
; Its bottom pixel on row 21 or below: drawn after the copy.
MSL_LATE_Y      equ BACK_ROW * 8 - MISSILE_HEIGHT + 1

; Which silos can be picked, by the aligned column of the left half.
; It scrolls left while it is armed (CFG_MISSILE_ARM, then at most 7
; frames more for the right shift), and must still be on screen when
; it leaves. On the right, both bytes of a shifted missile fit.
MSL_PICK_MIN    equ 1 + (CFG_MISSILE_ARM + 8 + 7) / 8
MSL_PICK_MAX    equ 29

; The box: every pixel of the missile against the diver's box in hit.asm.
MHIT_X_LO       equ HIT_DIVER_L - (MISSILE_WIDTH - 1)
MHIT_X_SPAN     equ HIT_DIVER_R - MHIT_X_LO + 1
MHIT_Y_LO       equ HIT_DIVER_T - (MISSILE_HEIGHT - 1)
MHIT_Y_SPAN     equ HIT_DIVER_B - MHIT_Y_LO + 1

        ASSERT MISSILE_WIDTH == 6 && MISSILE_HEIGHT == MSL_ROWS, "missile.asm draws a 6 x 8 picture"
        ASSERT CFG_MISSILE_SPEED >= 1 && CFG_MISSILE_SPEED < MISSILE_HEIGHT + TORPEDO_HEIGHT, "a torpedo could pass through it"
        ASSERT CFG_MISSILE_GAP_MAX <= 255 && CFG_MISSILE_GAP_MIN <= CFG_MISSILE_GAP_MAX
        ASSERT CFG_MISSILE_GAP_MAX - CFG_MISSILE_GAP_MIN + 1 <= 255
        ASSERT CFG_MISSILE_ARM <= 64, "it would scroll off the left before it leaves"
        ASSERT MSL_PICK_MIN <= MSL_PICK_MAX
        ASSERT MSL_PICK_MIN * 8 + MSL_LEAD >= 0, "the missile's x when it leaves would be negative"
        ASSERT CFG_MISSILE_RANGE >= 0 && CFG_MISSILE_RANGE <= 127

; One masked byte: save what is under it at (BC), then
;   screen = (screen AND mask) OR data
; HL walks the picture (mask, data, ...), DE the screen.
        MACRO MSL_BYTE
        ld a,(de)
        ld (bc),a
        inc bc
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        ENDM

; DE one pixel row down the screen. 27 T-states inside a character
; cell, more on the row that crosses into the next one.
        MACRO MSL_DOWN
        inc d
        ld a,d
        and 7
        jr nz,1F
        ld a,e
        add a,32
        ld e,a
        jr c,1F                 ; into the next third: D already is
        ld a,d
        sub 8
        ld d,a
1:
        ENDM

msl_phase:      db 0            ; 0 waiting, MSL_ARMED, MSL_FLY
msl_wait:       db CFG_MISSILE_GAP_MIN ; 1/50 seconds until one is armed
msl_arm:        db 0            ; 1/50 seconds left in the hatch
msl_world:      dw 0            ; world column of its silo's left half
msl_x:          db 0            ; left pixel of the picture
msl_y:          db 0            ; top pixel row
msl_seed:       db $C3          ; its own shift register. Never 0.
msl_home:       db 0            ; 1 = this one homes (CFG_MSL_HOME_LEVEL)
msl_hfrac:      db 0            ; its fraction of a pixel sideways
; The first level of each (config.asm). The tester's switch (cheat_poll) makes all
; three 1. In this order: missile_gone steps through them.
power_levels:
pw_heart_lvl:   db CFG_POWER_LEVEL
pw_double_lvl:  db CFG_DOUBLE_LEVEL
pw_piranha_lvl: db CFG_PIRANHA_LEVEL
msl_gap_min:    db CFG_MISSILE_GAP_MIN  ; this level's wait (score.asm sets
msl_gap_span:   db CFG_MISSILE_GAP_MAX - CFG_MISSILE_GAP_MIN + 1 ; them)
    IFDEF POWERUPS
msl_kind:       db 0            ; what is up: MSL_KIND_*
msl_next:       db 0            ; what the next turn brings
msl_pfrac:      db 0            ; a sinking power-up's fraction of a pixel
    ENDIF

; What the last draw covered: bytes a row (1 or 2), plus MSL_LOW when it
; was drawn after the copy. 0 = nothing on screen. Restore clears it.
msl_vn:         db 0
msl_vaddr:      dw 0            ; screen byte of its top-left corner
; msl_save: in bss.asm (zeroed at start-up, not on the tape)

        COLD
;------------------------------------------------------------------------------
; missile_reset - none armed, none on screen, the first one a gap away
; Corrupts: AF
;------------------------------------------------------------------------------
missile_reset:
        xor a
        ld (msl_phase),a
        ld (msl_vn),a
    IFDEF POWERUPS
        ld (msl_kind),a
        ld (msl_next),a
    ENDIF
    IFDEF MEAS_MISSILE
        ld (msl_wait),a
    ELSE
        ld a,(msl_gap_min)
        ld (msl_wait),a
    ENDIF
        ret

        HOT

;------------------------------------------------------------------------------
; missile_update - one 1/50 second. main_loop calls it once a step at 50,
; and idle_move calls it twice at 25.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
missile_update:
        ld a,(msl_phase)
        dec a
        jr z,missile_armed
        dec a
        jr z,.fly
    IFDEF POWERUPS
        dec a
        jp z,power_sink
    ENDIF
        ld hl,msl_wait
        ld a,(hl)
        or a
    IFDEF POWERUPS
        jp z,missile_or_power
    ELSE
        jp z,missile_pick
    ENDIF
        dec (hl)
        ret
.fly:   ld a,(msl_y)
        sub CFG_MISSILE_SPEED
        cp MSL_TOP
        jp c,missile_gone       ; it was at least MSL_TOP, so no borrow
        ld (msl_y),a
        ld a,(msl_home)
        or a
        ret z
        ; A homing missile (CFG_MSL_HOME_LEVEL on): a pixel towards his
        ; middle each time the fraction carries. Off a byte it is two
        ; bytes a row (missile_draw does both); up to x 247 the second
        ; byte is still on the screen.
        ld a,(msl_hfrac)
        add a,CFG_MSL_HOME
        ld (msl_hfrac),a
        ret nc
        ld a,(diver_x)
        add a,MSL_AIM
        ld b,a
        ld a,(msl_x)
        cp b
        ret z
        jr c,.right
        dec a                   ; never below his middle, so never below 0
        ld (msl_x),a
        ret
.right: cp MSL_HOME_MAX
        ret nc
        inc a
        ld (msl_x),a
        ret

; In the hatch. Its x follows the silo, worked out from the silo's world
; column, so it scrolls with the ground however many shifts this step had.
missile_armed:
        ld hl,(msl_world)
        ld de,(front_origin)
        or a
        sbc hl,de               ; the aligned column now, 1..29
        ld a,l
        add a,a
        add a,a
        add a,a
        ld hl,front_fine
        sub (hl)
        add a,MSL_DX
        ld (msl_x),a
        ld hl,msl_arm
        ld a,(hl)
        or a
        jr z,.ready
        dec (hl)
        ret
.ready: ld a,(front_fine)
        sub 3
        cp 3
        ret nc                  ; not 3, 4 or 5: one more 1/50 second
        ld a,MSL_FLY
        ld (msl_phase),a
        ; Homing from CFG_MSL_HOME_LEVEL (and on a measured level 9).
        ld a,(level_n)
        cp CFG_MSL_HOME_LEVEL
        sbc a,a                 ; $FF below that level, 0 from it
        inc a                   ; 0 below, 1 from it
        ld (msl_home),a
    IFNDEF NO_SOUND
        jp snd_launch_start     ; whoosh
    ELSE
        ret
    ENDIF

;------------------------------------------------------------------------------
; missile_pick - arm the missile of a random silo on screen
; Nothing happens if there is none: the next 1/50 second tries again.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
        MACRO MSL_CANDIDATE     ; Z clear: A is not a column that can fire
        cp MSL_PICK_MIN
        jr c,1F                 ; NZ: below. -1 is 255, so it fails next.
        cp MSL_PICK_MAX + 1
        jr c,2F
        or a                    ; NZ: above (CP left Z on MSL_PICK_MAX + 1)
        jr 1F
2:
    IFDEF MEAS_MISSILE
        cp a                    ; measurement: any silo, so one is always up
    ELSE
        call msl_near           ; Z: it will leave close to the diver
    ENDIF
1:
        ENDM

; Only a silo near the diver fires: one whose missile will leave
; within CFG_MISSILE_RANGE pixels of his middle. It is armed now and
; leaves about CFG_MISSILE_ARM + 4 pixels further left (the ground
; scrolls a pixel each 1/50 second, and it waits for front_fine 3..5),
; so that is where it is measured.
; In: A = the silo's aligned column, MSL_PICK_MIN..MSL_PICK_MAX.
; Out: Z if it is near. Preserves A, BC, HL. Corrupts: F, DE
MSL_LEAD        equ MSL_DX - CFG_MISSILE_ARM - 4
MSL_AIM         equ (DIVER_WIDTH - MISSILE_WIDTH) / 2
MSL_HOME_MAX    equ 247             ; two bytes a row still end in column 31
        ASSERT (MSL_HOME_MAX + MISSILE_WIDTH - 1) / 8 <= 31
        ASSERT CFG_MSL_HOME >= 1 && CFG_MSL_HOME <= 255 && CFG_MSL_HOME_LEVEL >= 1

msl_near:
        ld d,a
        add a,a
        add a,a
        add a,a                 ; the silo's x now (n <= 29: no carry)
        add a,MSL_LEAD          ; the missile's x when it leaves
        ld e,a
        ld a,(diver_x)
        add a,MSL_AIM           ; a missile there would hit his middle
        sub e
        jr nc,.abs
        neg
.abs:   cp CFG_MISSILE_RANGE + 1
        ld a,d
        jr nc,.far
        cp a                    ; Z
        ret
.far:   or a                    ; NZ: a column that can fire is never 0
        ret

missile_pick:
        ld a,(silo_n)
        or a
        ret z
        ld b,a
        ld hl,silo_at
        ld c,0
.count: ld a,(hl)
        inc hl
        MSL_CANDIDATE
        jr nz,.not
        inc c
.not:   djnz .count
        ld a,c
        or a
        ret z
        call msl_rng
.mod:   sub c
        jr nc,.mod
        add a,c
        ld c,a                  ; this one of them, 0 first
        ld hl,silo_at
.find:  ld a,(hl)
        inc hl
        MSL_CANDIDATE
        jr nz,.find
        dec c
        jp p,.find
        ld hl,(front_origin)
        ld e,a
        ld d,0
        add hl,de
        ld (msl_world),hl
        ld a,MSL_ARMED_Y
        ld (msl_y),a
        ld a,CFG_MISSILE_ARM
        ld (msl_arm),a
        ld a,MSL_ARMED
        ld (msl_phase),a
        jp missile_armed        ; its x now, before it is drawn

;------------------------------------------------------------------------------
; Power-ups. missile_gone rolls what the next turn brings (msl_next);
; when the wait is over, a power-up appears at once, where a missile
; would wait for a silo near the diver.
;   missile_or_power  the wait is over: a missile, or msl_next's power-up
;   power_sink        one 1/50 second of its fall
;   power_take        the diver touched it (missile_hit)
;------------------------------------------------------------------------------
    IFDEF POWERUPS
missile_or_power:
        ld a,(msl_next)
        or a
        jp z,missile_pick
        ld (msl_kind),a
        xor a
        ld (msl_next),a
        ; A column near him: his middle, give or take 32 pixels, on a
        ; byte, and the whole picture on the screen.
        call msl_rng
        and 63
        ld l,a
        ld h,0
        ld a,(diver_x)
        ld e,a
        ld d,h
        add hl,de
        ld de,DIVER_WIDTH / 2 - 4 - 32
        add hl,de
        bit 7,h
        jr z,.right
        ld hl,0                 ; off the left: column 0
.right: ld a,h
        or a
        ld a,l
        jr z,.fits
        ld a,248
.fits:  cp 249
        jr c,.col
        ld a,248
.col:   and $F8
        ld (msl_x),a
        ld a,POWER_TOP
        ld (msl_y),a
        ld a,MSL_SINK
        ld (msl_phase),a
        ret

power_sink:
        ld a,(msl_pfrac)
        add a,CFG_POWER_SPEED
        ld (msl_pfrac),a
        ret nc                  ; not a whole pixel yet
        ld a,(msl_y)
        inc a
        cp POWER_LOW + 1
        jp nc,missile_gone      ; at the weed: gone
        ld (msl_y),a
        ret

; A = msl_kind (not 0). Out: carry clear: not a hit.
power_take:
        dec a
        jr nz,.double
        ld hl,lives
        ld a,(hl)
        cp CFG_LIVES_MAX
        jr nc,.done             ; full: it is used up all the same
        inc (hl)
        ld hl,hud_dirty
        set HUD_HEARTS,(hl)     ; one more heart on row 1
        jr .done
.double:
        ld a,1
        ld (double_on),a
        ld hl,(frame_count)
        ld de,CFG_DOUBLE_TIME * 50
        add hl,de
        ld (double_until),hl
        ld hl,double_tick       ; the clock: main_loop's missile_update calls
        call double_calls       ; go through double_tick until it runs out
        ld hl,hud_dirty
        set HUD_HEARTS,(hl)     ; the bubble on row 1, beside the hearts
.done:  call missile_gone
    IFNDEF NO_SOUND
        ld hl,snd_tune_power
        call snd_tune_start
    ENDIF
        or a
        ret

; cheat_poll - the testers' switch, on the menu only (menu_loop calls it;
; play never does). Held down together, its two keys (notes/, not the
; docs) make hearts, the bubble and the piranha come from level 1 until
; the machine is reset. It answers once, with a short beep and the
; border flickering, so the tester knows it took. Not on any screen.
; Corrupts: AF, BC, HL
CHEAT_KEYS      equ %00000110   ; port $7FFE: Symbol Shift (bit 1) and M (bit 2)
cheat_on:       db 0
cheat_poll:
        ld bc,(ROW_SPC_B << 8) | ULA_PORT
        in a,(c)
        and CHEAT_KEYS
        ret nz                  ; not both down
        ld hl,cheat_on
        ld a,(hl)
        or a
        ret nz                  ; already on: no second beep
        ld (hl),1
        ld a,1
        ld (pw_heart_lvl),a
        ld (pw_double_lvl),a
        ld (pw_piranha_lvl),a
        ; The beep: 150 half-waves, the speaker and the border together.
        ld b,150
.wave:  ld a,b
        and %00010000 | RED     ; speaker bit 4 and the border, in turn
        out (ULA_PORT),a
        ld c,40
.wait:  dec c
        jr nz,.wait
        djnz .wave
        ld a,BLUE               ; the menu's border back
        out (ULA_PORT),a
        ret

; The double shot's clock. While it lasts, main_loop's two calls to
; missile_update (.msl_uc1, .msl_uc2) come here first, so a game
; without one pays nothing. When it runs out: the bubble beside the
; hearts goes, a falling jingle plays, and the calls go back.
; Corrupts: AF, BC, DE, HL (as missile_update)
double_tick:
        ld hl,(frame_count)
        ld de,(double_until)
        or a
        sbc hl,de
        bit 7,h
        jp nz,missile_update    ; before double_until
        call double_end
        jp missile_update

; The double shot is over: by its clock, or a new game. Corrupts: AF, HL
double_end:
        xor a
        ld (double_on),a
        ld hl,hud_dirty
        set HUD_HEARTS,(hl)     ; the bubble on row 1 goes
        ld hl,missile_update
        call double_calls
    IFNDEF NO_SOUND
        ld hl,snd_tune_down
        jp snd_tune_start
    ELSE
        ret
    ENDIF

; HL into main_loop's two missile_update calls. Corrupts: nothing else
double_calls:
        ld (fish_mv.msl_uc1 + 1),hl
        ld (fish_mv2.msl_uc2 + 1),hl
        ret
        ASSERT ({fish_mv.msl_uc1} & $FF) == $CD && {fish_mv.msl_uc1 + 1} == missile_update, ".msl_uc1 is not CALL missile_update"
        ASSERT ({fish_mv2.msl_uc2} & $FF) == $CD && {fish_mv2.msl_uc2 + 1} == missile_update, ".msl_uc2 is not CALL missile_update"
        ASSERT CFG_POWER_SPEED >= 1 && CFG_POWER_SPEED <= 255, "CFG_POWER_SPEED is 256ths of a pixel a 1/50 second: 1 to 255"

        ASSERT MSL_ROWS == 8, "the power-ups are 8 rows: missile_draw draws MSL_ROWS"
        ASSERT CFG_LIVES_MAX >= CFG_LIVES && CFG_LIVES_MAX <= 9, "CFG_LIVES_MAX: CFG_LIVES to 9"
        ASSERT CFG_HEART_ODDS + CFG_DOUBLE_ODDS <= 256
        ASSERT CFG_DOUBLE_TIME >= 1 && CFG_DOUBLE_TIME <= 600, "CFG_DOUBLE_TIME is seconds, up to 10 minutes"
        ASSERT CFG_DOUBLE_COOLDOWN >= 1 && CFG_DOUBLE_COOLDOWN <= CFG_FIRE_COOLDOWN
        ASSERT CFG_POWER_LEVEL >= 1 && CFG_POWER_LEVEL <= 99 && CFG_DOUBLE_LEVEL >= 1 && CFG_DOUBLE_LEVEL <= 99 && CFG_PIRANHA_LEVEL >= 1 && CFG_PIRANHA_LEVEL <= 99
    ENDIF

;------------------------------------------------------------------------------
; missile_gone - shot, spent on the diver, or out of the top. The next
; restore takes it off the screen. The next one is a random gap away.
; Corrupts: AF, B
;------------------------------------------------------------------------------
missile_gone:
        xor a
        ld (msl_phase),a
    IFDEF MEAS_MISSILE
        ld (msl_wait),a         ; measurement: the next one at once
        ret
    ELSE
      IFDEF POWERUPS
        ; What the next turn brings: now and then a power-up, each from
        ; its own level (power_levels). A = 0 here.
        ld (msl_kind),a
        call msl_rng
        ld c,a
        ld b,MSL_KIND_MISSILE
        ld a,(level_n)
        ld hl,pw_heart_lvl
        cp (hl)
        jr c,.no_heart          ; too early for hearts
        ld a,c
        cp CFG_HEART_ODDS
        jr c,.heart
.no_heart:
        ld a,(level_n)
        inc hl                  ; pw_double_lvl
        cp (hl)
        jr c,.next              ; too early for the bubble
        ld a,c
        sub CFG_HEART_ODDS
        jr c,.next              ; the hearts' share: a missile
        cp CFG_DOUBLE_ODDS
        jr nc,.next
        ld b,MSL_KIND_DOUBLE
        jr .next
.heart: ld b,MSL_KIND_HEART
.next:  ld a,b
        ld (msl_next),a
      ENDIF
        ld a,(msl_gap_span)
        ld b,a
        call msl_rng
.mod:   sub b
        jr nc,.mod
        add a,b
        ld b,a
        ld a,(msl_gap_min)
        add a,b
        ld (msl_wait),a
        ret
    ENDIF

; Out: A = the next value of an 8-bit shift register. Corrupts: F
msl_rng:
        ld a,(msl_seed)
        srl a
        jr nc,.keep
        xor $B8
.keep:  ld (msl_seed),a
        ret

;------------------------------------------------------------------------------
; missile_hit - the missile against the diver
; Call after hit_check: a bomb that has just cost a life gets the step.
; Out: carry set if the diver was hit.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
missile_hit:
        ld a,(msl_phase)
        or a
        ret z
    IF CFG_HIT_FLASH > 0
        ld a,(hit_flash)
        cp CFG_HIT_FLASH
        ret z                   ; already hit this step (carry clear)
    ENDIF
        ld a,(diver_x)
        ld b,a
        ld a,(msl_x)
        sub b
        add a,-MHIT_X_LO
        cp MHIT_X_SPAN
        jr nc,.miss
        ld a,(diver_y)
        ld b,a
        ld a,(msl_y)
        sub b
        add a,-MHIT_Y_LO
        cp MHIT_Y_SPAN
        jr nc,.miss
    IFDEF POWERUPS
        ld a,(msl_kind)
        or a
        jp nz,power_take        ; a power-up: his
    ENDIF
    IFDEF MEASURE
        ; A measurement holds the diver on the seabed, under the silos,
        ; where every missile would hit him and explode. It pays for the
        ; test and nothing else: MEAS_BOOM measures the explosion.
        or a
        ret
    ELSE
        call boom_at_missile
        call missile_gone
        jp diver_hurt
    ENDIF
.miss:  or a
        ret

;------------------------------------------------------------------------------
; missile_shot - the running torpedo against the missile
; torpedo_hit calls this first.
; Out: carry set if it hit: the burst is up, and both are spent.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
missile_shot:
        ld a,(msl_phase)
        or a
        ret z
    IFDEF POWERUPS
        ld a,(msl_kind)
        or a
        ret nz                  ; a power-up: the torpedo passes through
    ENDIF
        ld a,(msl_y)
        ld b,a
        ld a,(torp_y)
        sub b
        add a,TORPEDO_HEIGHT - 1
        cp TORPEDO_HEIGHT + MISSILE_HEIGHT - 1
        ret nc
        ld hl,(torp_x)          ; 16 bits: it can hang off an edge
        ld a,(msl_x)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ld de,TORPEDO_WIDTH - 1
        add hl,de
        ld a,h
        or a
        ret nz                  ; carry clear
        ld a,l
        cp TORPEDO_WIDTH + MISSILE_WIDTH - 1
        ret nc
        call boom_at_missile
        call missile_gone
        call torpedo_spent
        ld a,(level_pts_msl)
        call score_add
        scf
        ret

;------------------------------------------------------------------------------
; missile_draw_early - before the seabed copy, if it is up in the water
; missile_draw_late  - after the copy, if it is in the hatch or the weed
; main_loop calls these only while msl_phase is not 0.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
missile_draw_early:
        ld a,(msl_y)
        cp MSL_LATE_Y
        ret nc
        xor a
        jr missile_draw

missile_draw_late:
        ld a,(msl_y)
        cp MSL_LATE_Y
        ret c
        ld a,MSL_LOW
        ; fall through

; In: A = MSL_LOW or 0, for the record.
missile_draw:
        ld c,a
        ld a,(msl_x)
        and 7
        cp 3                    ; shifts 0, 1 and 2 are one byte a row
        ld a,1
        adc a,0                 ; no carry: 2
        xor 3                   ; 1 -> 2, 2 -> 1
        or c
        ld (msl_vn),a
        ld a,(msl_x)
        and 7
        add a,a
        ld e,a
        ld d,0
        ; The flame flickers: the long frame, then the short one, every
        ; 2 1/50 seconds (gfx/missile.txt). 32 T-states.
    IFDEF POWERUPS
        ld a,(msl_kind)
        or a
        jr z,.missile
        ld hl,heart_tab         ; byte-aligned: DE is 0
        dec a
        jr z,.flame
        ld hl,bubble_tab
        jr .flame
.missile:
    ENDIF
        ld a,(frame_count)
        and 2
        ld hl,missile_right_f0
        jr z,.flame
        ld hl,missile_right_f1
.flame: add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de                 ; the picture at this shift
        ld a,(msl_y)
        call row_table_entry
        ld a,(msl_x)
        rrca
        rrca
        rrca
        and 31
        or (ix+0)
        ld e,a
        ld d,(ix+1)
        ld (msl_vaddr),de
        pop hl
        ld bc,msl_save
        ld a,(msl_vn)
        and 3
        dec a
        jp nz,.two
        DUP MSL_ROWS - 1
        MSL_BYTE
        MSL_DOWN
        EDUP
        MSL_BYTE
        ret
.two:   DUP MSL_ROWS - 1
        MSL_BYTE
        inc e
        MSL_BYTE
        dec e
        MSL_DOWN
        EDUP
        MSL_BYTE
        inc e
        MSL_BYTE
        ret

;------------------------------------------------------------------------------
; missile_restore - put back what the last draw covered
; main_loop calls this at the place msl_vn says.
; Corrupts: AF, DE, HL
;------------------------------------------------------------------------------
missile_restore:
        ld a,(msl_vn)
        and 3
        ld de,(msl_vaddr)
        ld hl,msl_save
        dec a
        jp nz,.two
        ld (msl_vn),a           ; A is 0
        DUP MSL_ROWS - 1
        ld a,(hl)
        ld (de),a
        inc hl
        MSL_DOWN
        EDUP
        ld a,(hl)
        ld (de),a
        ret
.two:   xor a
        ld (msl_vn),a
        DUP MSL_ROWS - 1
        ld a,(hl)
        ld (de),a
        inc hl
        inc e
        ld a,(hl)
        ld (de),a
        inc hl
        dec e
        MSL_DOWN
        EDUP
        ld a,(hl)
        ld (de),a
        inc hl
        inc e
        ld a,(hl)
        ld (de),a
        ret

; The power-ups' pictures. In the code block, as the double shot's tables.
; The two pictures, 8 by 8, mask then ink a row: the shift-0 entry of a
; table of shifts, which is all a byte-aligned power-up needs.
        MACRO POWER_ROW ink
        db ~(ink) & $FF, ink
        ENDM
        MACRO POWER_DATA
heart_tab:      dw heart_pic
bubble_tab:     dw bubble_pic
heart_pic:                      ; the hearts' own heart (data.asm, lives_heart)
        POWER_ROW %00000000
        POWER_ROW %01101100
        POWER_ROW %11111110
        POWER_ROW %11111110
        POWER_ROW %01111100
        POWER_ROW %00111000
        POWER_ROW %00010000
        POWER_ROW %00000000
bubble_pic:                     ; a bubble with two torpedoes in it: the double shot
        POWER_ROW %00111100
        POWER_ROW %01000010
        POWER_ROW %10111001
        POWER_ROW %10000001
        POWER_ROW %10111001
        POWER_ROW %01000010
        POWER_ROW %00111100
        POWER_ROW %00000000
        ENDM
    IFDEF POWERUPS
        POWER_DATA
    ENDIF
