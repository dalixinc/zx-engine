;==============================================================================
; rate.asm - 50 or 25 frames a second, and the spare-scanline count
;
; step_ticks is how many 1/50-second television frames one game step
; stands in for.
;   50 frames a second: step_ticks = 1. The step runs every interrupt.
;   25 frames a second: step_ticks = 2. The picture frame is one fast
;   tick, the same work as 50. The next frame only moves, and does not
;   draw.
; Every distance in the game is written per 1/50 second. A step moves
; that distance step_ticks times. Both speeds cover the same water in
; the same real second. 25 takes the steps in pairs, so it looks less
; smooth and no faster.
;
; Symbol Shift + F switches speed during play. The edge is the same
; rule as Symbol Shift + S: the moment both keys go down, it flips.
; Holding them does not flip again. F on its own is not a movement key
; and does nothing here.
;
; spare_lines is how many scanlines were left after the previous step's
; work, before the next television frame began. A scanline is one pixel
; row of the television picture, border included: 224 units of time on
; a 48K Spectrum. The stat line prints this number. It is the one that
; says whether the step still fits.
;==============================================================================

game_rate:      db CFG_START_RATE
step_ticks:     db 1
step_saved:     db 1            ; the real rate while a tick forces 1
spare_lines:    db 0            ; 0..99 shown; the true count is capped
spare_late:     db 0            ; 1 if the step had already missed the interrupt
spare_pic:      db 0            ; 25 fps: spare lines in the picture frame
spare_pic_late: db 0
spare_idle:     db 0            ; 25 fps: spare lines in the idle frame
spare_idle_late: db 0
rate_prev:      db 0            ; last frame's Symbol Shift + F
chord_flash:    db 0            ; steps of border flash left; 0 = normal border

;------------------------------------------------------------------------------
; rate_init - the speed from config.asm, before the menu is shown
; rate_apply - In: A = 50 or 25. Stores the speed and step_ticks.
; Corrupts: AF
;------------------------------------------------------------------------------
rate_init:
        ld a,CFG_START_RATE
rate_apply:
        ld (game_rate),a
        cp 25
        ld a,1
        jr nz,.one
        ld a,2
.one:   ld (step_ticks),a
        ; The digits reprint every eight steps. A new speed should show
        ; on the next step, so the counter is set to reprint then.
        ld a,7
        ld (stats_phase),a
        ret

;------------------------------------------------------------------------------
; chords_poll - Symbol Shift + P, F or S, once per step
; Symbol Shift is one key, so it is read once and shared. P, F and S are
; three more reads. Reading Shift again for each chord was a scanline
; the heavy frame does not have.
; P returns to the menu. F flips the speed and switches the digits on,
; so the new "25/s" or "50/s" shows. S shows or hides the digits.
; F and S also start a short white/black border flash (main_loop's
; heartbeat), so you can see the chord was heard. P needs no flash: the
; menu appearing is the answer.
; Each one fires on the edge, the moment both keys go down. Holding does
; not fire again. The key on its own is not the chord.
; Leave is checked first, so a return to the menu does not also flip the
; speed on the way out. Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
chords_poll:
        call stats_key_sym
        ld d,a                  ; kept: the later checks still need it
        call leave_key_p
        and d
        ld hl,leave_prev
        call rising_edge
        jp nz,enter_menu
        call rate_key_f
        and d
        ld hl,rate_prev
        call rising_edge
        jr z,.stats
        ld a,(game_rate)
        cp 25
        ld a,50
        jr z,.setrate
        ld a,25
.setrate:
        call rate_apply
        ld a,1
        ld (stats_on),a         ; show the new speed on the stat line
        ld a,CFG_CHORD_FLASH
        ld (chord_flash),a
.stats: call stats_key_s
        and d
        ld hl,stats_chord_prev
        call rising_edge
        ret z
        ld a,(stats_on)
        xor 1
        ld (stats_on),a
        ld a,CFG_CHORD_FLASH
        ld (chord_flash),a
        ret

; Out: A nonzero if F is down. F is the fourth key on the A-S-D-F-G row,
; counting from A. Corrupts: AF, BC.
rate_key_f:
    IFDEF SOAK
        ld a,(soak_f)
        cp $FF
        jr z,.hw
        neg                     ; as stats_key_sym: through the real mask
        jr .mask
.hw:
    ENDIF
        ld bc,ROW_A_G * 256 + ULA_PORT
        in a,(c)
        cpl
.mask:  and %00001000
        ret

;------------------------------------------------------------------------------
; rising_edge - shared by the Symbol Shift chords and available here
; In:  A = 0 if the chord is up this frame, nonzero if it is down
;      HL -> the byte that remembered last frame
; Out: NZ if the chord has just gone down. Z if it is up, or if it was
;      already down (holding does not count again).
;      The remembered byte is updated either way.
; Corrupts: AF, C
;------------------------------------------------------------------------------
rising_edge:
        ld c,a
        ld a,(hl)
        ld (hl),c
        or a
        jr nz,.held
        ld a,c
        or a
        ret
.held:  xor a
        ret

;------------------------------------------------------------------------------
; rate_arm - remember the chord as it is now, so a key that is already
;            down when play starts does not flip the speed at once
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
rate_arm:
        call stats_key_sym
        ld e,a
        call rate_key_f
        and e
        ld (rate_prev),a
        ret

;------------------------------------------------------------------------------
; spare_count - how many whole scanlines are left in this television frame
;
; Call at the end of the step, with interrupts on, after the work.
; The frame flag was cleared at the start of the step. If the work ran
; past the next interrupt, the flag is already set and the spare count
; is 0: the step did not fit.
;
; Otherwise we walk a loop that takes exactly one scanline (224 units
; of time: the same length as the 56 NOPs the measurement sled uses).
; The number of loops that finish before the interrupt is the spare
; count. That waiting IS the pause until the next frame, so the game
; does not wait a second time afterwards.
;
; The loop below, and why it is one scanline. These are the ordinary
; instruction times, and this code sits above $8000 where the screen
; hardware does not slow them down:
;   inc hl              6
;   ld a,(de)           7
;   or a                4
;   jr nz, not taken    7
;   47 empty instructions, 4 each = 188
;   jr back             12
;   total               224
; Out: spare_lines set. The frame flag is set, unless we were already
;      late, in which case it was set before we were called.
; Corrupts: AF, DE, HL
;------------------------------------------------------------------------------
spare_count:
        xor a
        ld (spare_late),a
        ld de,vsync_flag
        ld a,(de)
        or a
        jr nz,.none
        ld hl,0
.line:  inc hl
        ld a,(de)
        or a
        jr nz,.got
        dup 47
        nop
        edup
        jr .line
.got:   dec hl                  ; this trip saw the flag: it was not a whole spare line
        ld a,h
        or a
        jr z,.store
        ld l,255                ; more than a byte: show the cap
        jr .store8
.none:  ld a,1
        ld (spare_late),a
        ld hl,0
.store: ld a,l
.store8:cp 100                  ; the stat line has two digits
        jr c,.keep
        ld a,99
.keep:  ld (spare_lines),a
        ret
