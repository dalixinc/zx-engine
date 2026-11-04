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
msl_gap_min:    db CFG_MISSILE_GAP_MIN  ; this level's wait (score.asm sets
msl_gap_span:   db CFG_MISSILE_GAP_MAX - CFG_MISSILE_GAP_MIN + 1 ; them)

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
        ld hl,msl_wait
        ld a,(hl)
        or a
        jr z,missile_pick
        dec (hl)
        ret
.fly:   ld a,(msl_y)
        sub CFG_MISSILE_SPEED
        cp MSL_TOP
        jp c,missile_gone       ; it was at least MSL_TOP, so no borrow
        ld (msl_y),a
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
