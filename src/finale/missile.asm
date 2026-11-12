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
MSL_KIND_SUCTION equ 3          ; the special bombs (special.asm): carried,
MSL_KIND_SHOVE  equ 4           ; then set off
MSL_KIND_NUKE   equ 5
; How many kinds the roll has: the nuke is left out when its level is 0.
POWER_KINDS     equ 1           ; Finale: the heart only
; It sinks from below the hearts and is gone above the weed, so it is
; always drawn before the seabed copy, and always one byte a row: its x
; is a multiple of 8, and the water does not scroll.
POWER_TOP       equ MSL_TOP
POWER_LOW       equ BACK_ROW * 8 - MISSILE_HEIGHT
; From CFG_POWER_WIDE_LEVEL it falls in any of the columns 0 to
; POWER_WIDE_COLS - 1, the ones the diver can touch with a few pixels to
; spare: he stops at CFG_DIVER_MAX_X, and missile_hit takes one whose x
; is up to HIT_DIVER_R right of his. Checked in the ASSERTs below.
POWER_WIDE_COLS equ (CFG_DIVER_MAX_X + HIT_DIVER_R - 8) / 8 + 1
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
; Each power-up's first level and its share of the roll, by kind, then
; the piranha's first level (config.asm). The testers' switch
; (cheat_poll) makes every level 1. missile_gone walks the pairs.
power_tab:
pw_heart_lvl:   db CFG_POWER_LEVEL, CFG_HEART_ODDS
pw_piranha_lvl: db CFG_PIRANHA_LEVEL
        ASSERT pw_piranha_lvl - power_tab == 2 * POWER_KINDS
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
      IFNDEF TRIGON
        ld (ink_cells + 1),a  ; no coloured cells to put back (the screen is new)
      ENDIF
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
        ; Homing from CFG_MSL_HOME_LEVEL (and on a measured level 10).
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
    IFDEF ENEMY_DIVER
      IFNDEF MEAS_MISSILE
        jp z,ed_msl_pick        ; Finale: missiles only where the level has them
      ELSE
        jp z,missile_pick
      ENDIF
    ELSE
        jp z,missile_pick
    ENDIF
        ld (msl_kind),a
        xor a
        ld (msl_next),a
        ; A column near him: his middle, give or take 32 pixels, on a
        ; byte, and the whole picture on the screen.
        call msl_rng
    IFNDEF TRIGON
        ld b,a
        ld a,(level_n)
        cp CFG_POWER_WIDE_LEVEL
        jr nc,.wide             ; from that level: anywhere he can reach
        ld a,b
    ENDIF
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
    IFNDEF TRIGON
        jp ink_if               ; a power-up: its cells in its colour
    ELSE
        ret
    ENDIF
    IFNDEF TRIGON
        ; Any of the columns he can touch, so some fall far from him. A
        ; roll past them is rolled again. Each next value of the shift
        ; register is the last one shifted, and alone it never landed
        ; on some columns; the clock mixed in reaches them all.
.wide:  call msl_rng
        ld hl,frame_count
        xor (hl)
        and 31
        cp POWER_WIDE_COLS
        jr nc,.wide
        add a,a
        add a,a
        add a,a
        jr .col
    ENDIF

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
    IFNDEF TRIGON
        and 6                   ; y & 7 now 0 or 1: it covers other cells,
        jp z,ink_if             ; so its colour moves down
    ENDIF
        ret

; A = msl_kind (not 0). Out: carry clear: not a hit.
power_take:
        ld hl,lives
        ld a,(hl)
        cp CFG_LIVES_MAX
        jr nc,.done             ; full: it is used up all the same
        inc (hl)
        ld hl,hud_dirty
        set HUD_HEARTS,(hl)     ; one more heart on row 1
.done:
power_done:
        call missile_gone
    IFNDEF NO_SOUND
        ld hl,snd_tune_power
        call snd_tune_start
    ENDIF
        or a
        ret

        COLD
; cheat_poll - the testers' switch, on the menu only (menu_loop calls it;
; play never does), so in the cold block. Held down together, its two
; keys (notes/, not the docs) make every power-up and the piranha come
; from level 1 until the machine is reset. It answers once, with a short beep and the
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
        ld hl,power_tab
        ld b,POWER_KINDS
.lvl:   ld (hl),1
        inc hl
        inc hl
        djnz .lvl
        ld (hl),1               ; pw_piranha_lvl
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
        HOT


;------------------------------------------------------------------------------
; power_build - the sinking heart's masked picture (POWER_PICS), from
; row 1's cell, at start-up: mask then ink a row, the mask the ink's
; complement, as missile_draw reads them. Corrupts: AF, B, DE, HL
;------------------------------------------------------------------------------
        COLD
power_build:
        ld hl,lives_heart
        ld de,POWER_PICS
        ld b,POWER_KINDS * 8
.row:   ld a,(hl)
        inc hl
        cpl
        ld (de),a
        inc de
        cpl
        ld (de),a
        inc de
        djnz .row
        ret
        HOT

        ASSERT CFG_POWER_SPEED >= 1 && CFG_POWER_SPEED <= 255, "CFG_POWER_SPEED is 256ths of a pixel a 1/50 second: 1 to 255"

        ASSERT MSL_ROWS == 8, "the power-ups are 8 rows: missile_draw draws MSL_ROWS"
        ASSERT CFG_LIVES_MAX >= CFG_LIVES && CFG_LIVES_MAX <= 9, "CFG_LIVES_MAX: CFG_LIVES to 9"
        ASSERT CFG_HEART_ODDS + CFG_DOUBLE_ODDS + CFG_SUCTION_ODDS + CFG_SHOVE_ODDS + CFG_NUKE_ODDS <= 256
        ASSERT CFG_DOUBLE_TIME >= 1 && CFG_DOUBLE_TIME <= 600, "CFG_DOUBLE_TIME is seconds, up to 10 minutes"
        ASSERT CFG_DOUBLE_COOLDOWN >= 1 && CFG_DOUBLE_COOLDOWN <= CFG_FIRE_COOLDOWN
        ASSERT CFG_POWER_LEVEL >= 1 && CFG_POWER_LEVEL <= 99 && CFG_DOUBLE_LEVEL >= 1 && CFG_DOUBLE_LEVEL <= 99 && CFG_PIRANHA_LEVEL >= 1 && CFG_PIRANHA_LEVEL <= 99
    IFNDEF TRIGON
        ASSERT CFG_POWER_WIDE_LEVEL >= 1 && CFG_POWER_WIDE_LEVEL <= 255, "CFG_POWER_WIDE_LEVEL: 1 to 255 (past the last level: never)"
        ASSERT POWER_WIDE_COLS >= 1 && POWER_WIDE_COLS <= 32 && (POWER_WIDE_COLS - 1) * 8 <= CFG_DIVER_MAX_X + HIT_DIVER_R, "a power-up in the last wide column would be out of the diver's reach"
    ENDIF
    ENDIF

        ; Once a missile, as it ends: in the cold block.
        COLD
;------------------------------------------------------------------------------
; msl_points - what the missile just shot or thrown scores: its level's
; points, or CFG_MSL_HOME_PTS if it was homing. missile_gone leaves
; msl_home alone, so this may come before or after it.
; Out: A = the points, BCD. Corrupts: F
;------------------------------------------------------------------------------
msl_points:
        ld a,(msl_home)
        or a
        ld a,(level_pts_msl)
        ret z
        ld a,((CFG_MSL_HOME_PTS / 10) << 4) | (CFG_MSL_HOME_PTS % 10)
        ret
        ASSERT CFG_MSL_HOME_PTS >= 0 && CFG_MSL_HOME_PTS <= 99, "points are one BCD byte: 0 to 99"

;------------------------------------------------------------------------------
; missile_gone - shot, spent on the diver, or out of the top. The next
; restore takes it off the screen. The next one is a random gap away.
; Corrupts: AF, BC, D, HL
;------------------------------------------------------------------------------
missile_gone:
    IFDEF POWERUPS
    IFNDEF TRIGON
        call ink_unpaint        ; a power-up's coloured cells back to water
    ENDIF
    ENDIF
        xor a
        ld (msl_phase),a
    IFDEF MEAS_MISSILE
        ld (msl_wait),a         ; measurement: the next one at once
        ret
    ELSE
      IFDEF POWERUPS
        ; What the next turn brings: now and then a power-up. The roll
        ; lands in one kind's share (power_tab, in turn) or past them
        ; all; a share whose first level has not come is a missile.
        ; A = 0 here.
        ld (msl_kind),a
        call msl_rng
        ld c,a
        ld hl,power_tab
        ld b,MSL_KIND_HEART
.roll:  ld d,(hl)               ; its first level
        inc hl
        ld a,c
        sub (hl)                ; its share
        inc hl
        jr c,.share
        ld c,a
        inc b
        ld a,b
        cp POWER_KINDS + 1
        jr c,.roll
        ld b,MSL_KIND_MISSILE   ; past every share
        jr .next
.share: ld a,(level_n)
        cp d
        jr nc,.next             ; from its level: this kind
        ld b,MSL_KIND_MISSILE
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
        HOT

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
        call msl_points
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
        ; A power-up: its masked picture (POWER_PICS, built at start-up),
        ; 16 bytes a kind. Byte-aligned, so no shifts.
        ld a,(msl_kind)
        or a
        jr z,.missile
        add a,a
        add a,a
        add a,a
        add a,a
        add a,POWER_PICS_BASE & $FF
        ld l,a
        ld h,POWER_PICS_BASE >> 8
        push hl
        jr .pic
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
.pic:
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

; The power-ups' pictures: POWER_PICS (bss.asm), built at start-up by
; power_build (special.asm) from row 1's cells in the UDG area, mask then
; ink a row. Kind n's is 16 (n - 1) bytes in.
POWER_PICS_BASE equ POWER_PICS - 16
    IFDEF POWERUPS
        ASSERT (POWER_PICS & $FF) >= 16 && (POWER_PICS & $FF) + 16 * POWER_KINDS <= 256, "POWER_PICS_BASE to its end crosses a page: missile_draw adds to the low byte"
    ENDIF

;------------------------------------------------------------------------------
; A falling power-up's colour, Atlantis only: the heart CFG_HEART_INK,
; the special bombs CFG_FALL_SUCTION_INK, _SHOVE_INK and _NUKE_INK (the
; bubble stays white). Its picture is ink, so the colour is its cells':
; the one it is in, and the one below while it is not on a character
; row. They change only when its top crosses y & 7 = 0 or 1, so
; power_sink (and missile_or_power, when one appears) calls ink_if
; then, not every step.
;
; Only cells that are the water's colour are painted, and only cells it
; painted (ink_done) and that still have its colour are given back: the
; bomb's ink, the banner, the weed row and the fish's flash are never
; painted over, and the power-up is drawn in their colour while it is
; in them. A bomb or flash of the same colour that sits in a painted
; cell when the power-up moves on can be turned back to water there,
; until its own next paint. A bomb that leaves a painted cell paints it
; water; the power-up is white there until its next change (at most 8
; pixels). Nothing is left coloured: missile_gone gives its cells back,
; and missile_reset forgets them.
; With CFG_HELD_INK, lives_draw colours the carried bomb's cell on row 1
; the same way (ink_held).
; Only read and run while one falls or row 1 changes, so in the data
; block. Expanded there by main.asm. Corrupts: AF, BC, D, HL (E kept:
; missile_gone's callers keep it)
;------------------------------------------------------------------------------
        MACRO INK_CODE
ink_tab:        db 0, HEART_ATTR, 0, SUCTION_ATTR, SHOVE_ATTR, NUKE_ATTR ; by MSL_KIND_*, 0 = white
        ASSERT (ink_tab & $FF) + MSL_KIND_NUKE < 256, "ink_look adds the kind to the low byte"
ink_cells:      dw 0            ; colour address of its top cell; high byte 0 = none
ink_now:        db 0            ; the colour it painted
ink_done:       db 0            ; the cells it painted: bit 0 the top, bit 1 the one below
; A = a kind. Out: A = its colour, Z if it has none. Corrupts: F, HL
ink_look:
        add a,ink_tab & $FF
        ld l,a
        ld h,ink_tab >> 8
        ld a,(hl)
        or a
        ret
ink_if:
        ld a,(msl_kind)
        call ink_look
        ret z                   ; a missile or the bubble: white
        ld (ink_now),a
        call ink_unpaint
        ld a,(msl_y)
        and 7
        ld d,1                  ; on a character row: one cell
        jr z,ink_one
        ld d,3                  ; else that one and the one below
ink_one:
        ld a,(msl_y)
        and $F8                 ; the character row, times 8
        ld l,a
        ld h,ATTRS >> 10
        add hl,hl
        add hl,hl               ; ATTRS + row * 32
        ld a,(msl_x)            ; on a byte: the column in its top 5 bits
        rrca
        rrca
        rrca
        or l
        ld l,a
        ld (ink_cells),hl
        ld a,(ink_now)
        ld b,a
        ld c,WATER_ATTR         ; water becomes its colour
        jr ink_swap
ink_unpaint:
        ld hl,(ink_cells)
        ld a,h
        or a
        ret z
        xor a
        ld (ink_cells + 1),a
        ld a,(ink_done)
        ld d,a                  ; only the cells it painted
        ld a,(ink_now)
        ld c,a
        ld b,WATER_ATTR         ; its colour becomes water
; HL = the top cell, D = which may change (bit 0 it, bit 1 the one
; below): each of those that is C becomes B. Out: ink_done = those that did.
ink_swap:
        xor a
        ld (ink_done),a
        rr d
        jr nc,ink_low
        ld a,(hl)
        cp c
        jr nz,ink_low
        ld (hl),b
        ld a,1
        ld (ink_done),a
ink_low:
        rr d
        ret nc
        ld a,l                  ; one row down, leaving E alone
        add a,32
        ld l,a
        jr nc,ink_down
        inc h
ink_down:
        ld a,(hl)
        cp c
        ret nz
        ld (hl),b
        ld hl,ink_done
        set 1,(hl)
        ret
    IF CFG_HELD_INK
; ink_held - A = the carried bomb's kind (0 = none): its cell on row 1
; in its colour, or the water's. lives_draw calls it. Keeps A.
; Corrupts: F, HL
ink_held:
        push af
        call ink_look
        jr nz,ink_held_set
        ld a,WATER_ATTR
ink_held_set:
        ld (ATTRS + LIVES_ROW * 32 + LIVES_COL - 4),a
        pop af
        ret
    ENDIF
        ENDM
    IFNDEF TRIGON
HEART_ATTR      equ CFG_HEART_INK | SEA
SUCTION_ATTR    equ CFG_FALL_SUCTION_INK | SEA
SHOVE_ATTR      equ CFG_FALL_SHOVE_INK | SEA
NUKE_ATTR       equ CFG_FALL_NUKE_INK | SEA
        ASSERT HEART_ATTR != WATER_ATTR && SUCTION_ATTR != WATER_ATTR && SHOVE_ATTR != WATER_ATTR && NUKE_ATTR != WATER_ATTR, "a power-up's ink is the water's (white)"
        ASSERT MSL_KIND_HEART == 1 && MSL_KIND_DOUBLE == 2 && MSL_KIND_SUCTION == 3 && MSL_KIND_SHOVE == 4 && MSL_KIND_NUKE == 5, "ink_tab is in kind order"
        ASSERT (ATTRS & $3FF) == 0, "ink_if builds the colour address from ATTRS >> 10"
        ASSERT (POWER_LOW & 7) == 0 && POWER_LOW / 8 < BACK_ROW, "a power-up's lower cell could be the weed row"
    ENDIF
