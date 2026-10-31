;==============================================================================
; main.asm - ATLANTIS
;
; The game. Engine Demo 1 (src/main.asm, tag engine-demo-1) is the same
; engine with the old two-strip seabed; this file is the Atlantis seabed,
; the frame loop, and the stat overlay. Shared code is included from src/.
;
; The tape opens on the start screen (menu.asm). Play has no words on it.
; Distances are per 1/50 second. At 25 frames a second the loop waits for
; a second interrupt and every distance is applied twice, so a minute of
; swimming covers the same water. The pictures and the tables live at
; DATA_START ($C000), above the instructions.
;
; Assemble with -DTIMING_BARS for build/atlantis-timing.sna. The border is
; a clock for that build:
;   white    restore, wipe the overlay if a sprite is on row 0, draw
;            sprites that are still above the seabed (fish, wheel bomb,
;            and the diver while he is up in the water)
;   cyan     copy the seabed. The full-copy frame also repaints the weed
;            colours here, before the beam reaches that row.
;   magenta  the diver, if his feet are on the seabed
;   red      rotate the ground buffer (every frame)
;   green    rotate the slow buffer. Absent on the frames it does not move.
;   yellow   stat overlay, then move the diver, the fish and the wheel bomb
;   black    this frame's work is done
; A frame with no green band is the one that shows a new sand position:
; it copies all 16 slow rows and recolours the weed. The green frame
; only repairs the sand (the silo tops moved) and then rotates the slow
; buffer for next time. See docs/SCROLLING.md.
;
; Assemble with -DSOAK for the background-restore check (not the tape).
;
; Build:  make            (build/atlantis.tap and build/atlantis.sna)
;         make demo       (build/diver.tap, Engine Demo 1, unchanged)
;==============================================================================

        DEVICE ZXSPECTRUM48

        ; fish.asm reads this. See the FISH_SWIM_Y note in that file.
        DEFINE ATLANTIS

        INCLUDE "../constants.asm"
        INCLUDE "layout.asm"
        INCLUDE "config.asm"

    IFDEF MEASURE
        IFNDEF MEAS_STATS
MEAS_STATS      equ 0
        ENDIF
        IFNDEF MEAS_RATE
MEAS_RATE       equ CFG_START_RATE
        ENDIF
        IFNDEF MEAS_WARMUP
MEAS_WARMUP     equ 40
        ENDIF
        IFNDEF MEAS_WINDOW
        ; Steps after the warmup whose spare count is kept. 512 is the
        ; same window the nop sled uses, so a rare heavy frame (the
        ; weed copy, with the bomb three bytes wide) is not missed.
        ; 64 steps can land entirely on the cheaper copies.
MEAS_WINDOW     equ 512
        ENDIF
    ENDIF

        ORG CODE_START
code_start:

;------------------------------------------------------------------------------
; entry - RANDOMIZE USR 32768
;------------------------------------------------------------------------------
entry:
        di
        ld sp,STACK_TOP
        call im2_init
        call build_row_table

        call rate_init

        ; A measurement build, the timing border and the spare-scanline
        ; sled start straight in the water. They would sit on the menu
        ; forever, because nothing presses key 1 for them. The tape, and
        ; the soak, open on the menu.
    IFDEF SLACK_LINES
        jp game_reset
    ELSE
    IFDEF TIMING_BARS
        jp game_reset
    ELSE
    IFDEF SHOT_FRAME
        jp game_reset
    ELSE
    IFDEF MEASURE
        jp game_reset
    ELSE
        jp enter_menu
    ENDIF
    ENDIF
    ENDIF
    ENDIF

;------------------------------------------------------------------------------
; main_loop - one step
; At 50 frames a second that is one television frame. At 25 it is two.
; The picture frame is the 50 body: same draw, then one fast tick.
; The idle frame only moves (no drawing), and it starts on an interrupt.
;------------------------------------------------------------------------------
main_loop:
        ; The spare-scanline count already waited for the interrupt at
        ; the end of the previous step. Clear the flag now, so this
        ; step can see whether its own work runs past the next one.
        ; The sled and the timing border keep the old wait instead:
        ; the count would swallow the interrupt those builds are timing.
    IFDEF SLACK_LINES
        call wait_frame
    ELSE
    IFDEF TIMING_BARS
        call wait_frame
    ELSE
    IFDEF SHOT_FRAME
        call wait_frame
    ELSE
        xor a
        ld (vsync_flag),a
    ENDIF
    ENDIF
    ENDIF

    IFDEF SLACK_LINES
        ; Not in the tape. Count loops against interrupts so a nop sled
        ; (below) can say how many spare scanlines the frame has.
        ; -DSLACK_WARMUP=n ignores the first n loops, which is how the
        ; "diver on the bottom" measurement skips the dive down.
        IFNDEF SLACK_WARMUP
SLACK_WARMUP    equ 0
        ENDIF
        ld hl,(slack_loops)
        inc hl
        ld (slack_loops),hl
        ; 16-bit compare against the warmup. A bare "cp low" after the
        ; high bytes match is not enough: once the high byte moves on,
        ; a low byte that happens to be small is still past the warmup.
        ; Those loops used to be left out of the count, and the
        ; interrupts they spent showed up as dropped frames.
        ld a,h
        cp SLACK_WARMUP / 256   ; immediate. Parentheses would be CP (HL).
        jr c,.slack_play        ; high byte still below
        jr nz,.slack_go         ; high byte above: warmup is over
        ld a,l
        cp SLACK_WARMUP & 255
        jr c,.slack_play
.slack_go:
        ld a,(slack_armed)
        or a
        jr nz,.slack_tick
        ld a,1
        ld (slack_armed),a      ; this return is the start of the window
        ld hl,(frame_count)
        ld (slack_base),hl
        jr .slack_play
.slack_tick:
        ld hl,(slack_measured)
        inc hl
        ld (slack_measured),hl
        ld a,h
        cp 2                    ; 512 measured loops
        jr c,.slack_play
        ld hl,(frame_count)
        ld de,(slack_base)
        or a
        sbc hl,de               ; interrupts since the window opened
        ld de,(slack_measured)
        or a
        sbc hl,de               ; 0 = one interrupt each loop, no frame dropped
        push hl
        ld a,h
        or l
        ld a,GREEN
        jr z,.slack_colour
        ld a,RED
.slack_colour:
        out (ULA_PORT),a
        ld a,BRIGHT | WHITE | (BLUE << 3)
        ld (text_attr),a
        pop hl                  ; extra interrupts over the 512 loops
        ld bc,(8 << 8) | 12
        call print_hex16
        di
.slack_halt:
        halt
        jr .slack_halt
.slack_play:
    ENDIF

    IFDEF SOAK
        call soak_begin         ; scripted keys / fish depth for this frame
    ENDIF
        ; Before anything moves, so the whole step is one speed and a
        ; return to the menu does not swim a frame on the way out.
        call chords_poll        ; Symbol Shift with P, F or S. One read of Shift.
        call read_input
    IFDEF SOAK
        call soak_apply_input   ; the script wins over the real keyboard
    ENDIF
    IFDEF MEAS_DOWN
        ld a,IN_DOWN
        ld (input_state),a
    ENDIF
    IFDEF MEAS_FIRE
        ; Measurement only. Fire goes down on every other step, so a
        ; new torpedo leaves as soon as the last one is spent and one
        ; is nearly always running.
        ld a,(frame_count)
        and 1
        jr z,.meas_nofire
        ld a,(input_state)
        or IN_FIRE
        ld (input_state),a
.meas_nofire:
    ENDIF

    IFDEF TIMING_BARS
        ld a,WHITE
        out (ULA_PORT),a
    ENDIF
        ; Restore first, while the screen still matches the photographs.
        ; Restore is the reverse of last step's draw order, so where two
        ; sprites overlap, the one drawn later (whose photograph holds
        ; the other) is put back first.
        ;
        ; Draw order:
        ;   up in the water, before the seabed copy: the higher of the
        ;       diver and the wheel, then the lower one, then the fish.
        ;       The torpedo goes straight after the diver: it is new at
        ;       his height, so it shares his place in the race.
        ;   on the seabed, after the copy: diver, wheel, torpedo
        ; The beam runs down the picture while this happens. A sprite is
        ; missing from the picture if the beam reaches it after it was
        ; erased and before it is drawn again. With a fixed order, the
        ; one drawn second lost that race whenever it was near the top:
        ; first the diver, behind a bomb, and then, the other way round,
        ; a bomb at the surface. Drawing the higher one first, and
        ; restoring it last, gives each the shortest gap where the beam
        ; reaches it soonest. The fish swims at pixel row 76, which the
        ; beam reaches much later, so it goes last.
        ; The order between the diver and the bomb is not about which
        ; is in front. If they overlap it is a hit and the bomb goes.
        ; diver_late, wheel_late, wheel_first and torp_vn remember what
        ; was done,
        ; so the restore below runs in exactly the reverse order.
        ;
        ; The fish and the diver go through the tight walker. The shared
        ; routines are what Engine Demo 1 still calls.
        ; NO_WHEEL is a measurement switch, the same kind of thing as
        ; SLACK_LINES. The tape does not define it. It leaves the bomb
        ; out so the spare-scanline count can be taken with no bomb
        ; on screen.
        ld a,(torp_vn)          ; drawn after the copy: TORP_LOW is set
        rla
        call c,torpedo_restore
    IFNDEF NO_WHEEL
        ld a,(wheel_late)
        or a
        call nz,wheel_restore
    ENDIF
        ld a,(diver_late)
        or a
        call nz,diver_restore_fast
fish_rest_call:
        call fish_restore_fast
    IFNDEF NO_WHEEL
        ld a,(wheel_first)
        or a
        jr nz,.wheel_was_first
        ld a,(wheel_late)
        or a
        call z,wheel_restore
    ENDIF
        ld a,(torp_vn)          ; 1 or 2: drawn before the copy
        dec a
        cp 2
        call c,torpedo_restore
        ld a,(diver_late)
        or a
        call z,diver_restore_fast
    IFNDEF NO_WHEEL
        jr .restored
.wheel_was_first:
        ld a,(torp_vn)          ; 1 or 2: drawn before the copy
        dec a
        cp 2
        call c,torpedo_restore
        ld a,(diver_late)
        or a
        call z,diver_restore_fast
        ld a,(wheel_late)       ; set only with wheel_late clear,
        or a                    ; but the test keeps the rule simple
        call z,wheel_restore
.restored:
    ENDIF
        call stats_prepare      ; drop the digits if a sprite is about to
                                ; photograph row 0. Otherwise leave them:
                                ; the beam is about to read that row.
        ld a,(lives_dirty)      ; the hearts, while no sprite is on screen
        or a
        call nz,lives_draw
    IFDEF SOAK
        call soak_after_restore
    ENDIF

        ; Which half each is drawn in. Once the diver's feet reach the
        ; weed he is drawn after the copy (draw_late), or the copy would
        ; paint over him. The same for the bomb. SBC A,A turns the
        ; carry into 0 (up in the water) or $FF (drawn late).
        ld a,(diver_y)
        add a,DIVER_HEIGHT - 1  ; his lowest pixel
        cp BACK_ROW * 8         ; seabed starts at row 21
        ccf
        sbc a,a
        ld (diver_late),a
    IFNDEF NO_WHEEL
        call wheel_is_low       ; carry set: up in the water, or not shown
        ccf
        sbc a,a
        ld (wheel_late),a
        ; The bomb goes first if it is in the water and its top is
        ; above the diver's. A diver on the seabed is drawn late
        ; anyway, so that order does not matter there.
        ld b,0
        or a
        jr nz,.order
        ld a,(diver_y)
        ld c,a
        ld a,(wheel_y)
        cp c
        jr nc,.order
        dec b                   ; $FF: the bomb first
.order: ld a,b
        ld (wheel_first),a
        or a
        call nz,wheel_draw_early
    ENDIF
        ld a,(diver_late)
        or a
        call z,diver_draw_fast
        ; The torpedo, if one is running above the weed. It is drawn here
        ; even when the diver is late: the order is the same either way.
        ld a,(torp_on)
        dec a                   ; TORP_HIGH is 1
        call z,torpedo_draw
    IFNDEF NO_WHEEL
        ld a,(wheel_first)
        or a
        jr nz,.wheel_drawn
        ld a,(wheel_late)
        or a
        call z,wheel_draw_early
.wheel_drawn:
    ENDIF
fish_draw_call:
        call fish_draw_fast
        ; If a sprite is on row 0, the digits go back on top now,
        ; after the photograph and before we spend the frame on the seabed.
        ; The wheel is included: it can bob up to y = 0.
        call stats_overlay_if_row0

        ; Same order as 50. The blit, then one shift, then the border,
        ; then one fast tick. Nothing above the shift is extra at 50.
        ; At 25 the idle frame does the second shift and the second tick.
    IFDEF TIMING_BARS
        ld a,CYAN
        out (ULA_PORT),a
    ENDIF
        call scroll_blit        ; also paints the weed, on the full-copy frame
    IFDEF SOAK
        call soak_after_blit    ; the picture the next restore must match
    ENDIF
        call draw_late

    IFDEF TIMING_BARS
        ld a,RED
        out (ULA_PORT),a
    ENDIF
        call scroll_shift_ground
        ; Phase 0 means the screen matches the slow buffer. Flipping
        ; it and rotating only when the result is 1 leaves the buffer
        ; one pixel ahead, which the next full copy shows.
        ld a,(slow_phase)
        xor 1
        ld (slow_phase),a
        jr z,.scrolled
    IFDEF TIMING_BARS
        ld a,GREEN
        out (ULA_PORT),a
    ENDIF
        call scroll_shift_slow
.scrolled:

    IFDEF TIMING_BARS
        ld a,YELLOW
        out (ULA_PORT),a
    ELSE
    IFNDEF SOAK
        ; Heartbeat. The digits are hidden by default, so the border is
        ; what shows the frame loop is alive. rrca x3 is / BORDER_FRAMES.
        ; After a hit, hit_flash counts down and the border flashes red
        ; and black, four steps each. Otherwise, after a Symbol Shift
        ; chord, chord_flash blinks it white and black, two steps each.
        ; A hit wins. With neither flash this costs about 58 T-states
        ; more than the plain heartbeat did.
        ld a,(hit_flash)
        or a
        jr z,.nohit
        dec a
        ld (hit_flash),a
        and 4
        ld a,RED
        jr nz,.border
        xor a                   ; BLACK
        jr .border
.nohit: ld a,(chord_flash)
        or a
        jr z,.beat
        dec a
        ld (chord_flash),a
        and 2
        ld a,WHITE
        jr nz,.border
        xor a                   ; BLACK
        jr .border
.beat:  ld hl,(frame_count)
        ld a,l
        rrca
        rrca
        rrca
.border:
        call set_border
    ENDIF
    ENDIF

        ; No sprite on row 0: refresh the digits now, after the beam has
        ; left the row. A sprite on row 0 was already handled above.
        call stats_overlay_if_clear

        ; One pixel each. The second pixel, at 25, is the idle frame.
        call update_diver
fish_mv:
        call update_fish
        ; The wheel and the torpedo apply step_ticks themselves. This
        ; frame always does one fast tick. 50 already has step_ticks = 1.
        ld a,(step_ticks)
        ld (step_saved),a
        cp 2
        jr nz,.actors
        ld a,1
        ld (step_ticks),a
.actors:
        ld a,(torp_on)
        or a
        call nz,torpedo_move
        ld a,(input_state)
        and IN_FIRE
        call nz,torpedo_fire
    IFNDEF NO_WHEEL
        call update_wheel
    IFNDEF SOAK
        ; Before hit_check: a bomb that was shot first is already gone.
        ld a,(torp_on)
        or a
        call nz,torpedo_hit
        call hit_check
        jr nc,.lived
        ld a,(step_saved)
        ld (step_ticks),a
        jp game_over
.lived:
    ENDIF
    ENDIF
        ld a,(step_saved)
        ld (step_ticks),a

    IFDEF SOAK
        ; At 25 the idle tick has not run yet. The script reads the
        ; position after the whole step.
        ld a,(step_ticks)
        cp 2
        jr z,.soak_later
        call soak_after_update
.soak_later:
    ENDIF
    IFDEF TIMING_BARS
        ld a,BLACK
        out (ULA_PORT),a
    ENDIF
    IFDEF SLACK_LINES
        ; One scanline (224 T-states) per repetition, after the real work.
        ; Used to measure how close the frame is to the next interrupt.
        ; Not part of the tape. 56 NOPs = 224 T-states.
        dup SLACK_LINES
        dup 56
        nop
        edup
        edup
    ENDIF
    IFDEF SHOT_FRAME
        ; Not the tape. Halt at the end of one loop so a screenshot can
        ; catch the wheel at a known x. The draw for this frame has
        ; already happened. The count is loops, not frame_count, so the
        ; picture matches a movement step even on a build that drops one.
        ld hl,(shot_loops)
        inc hl
        ld (shot_loops),hl
        ld de,SHOT_FRAME
        or a
        sbc hl,de
        jr nz,.shot_go
        di
.shot_halt:
        halt
        jr .shot_halt
.shot_go:
    ENDIF
        ; Sled, timing border, and shot builds sync with wait_frame.
        ; The second tick goes in the frame that wait opens.
    IFDEF SLACK_LINES
        DEFINE IDLE_HOLD
    ENDIF
    IFDEF TIMING_BARS
        DEFINE IDLE_HOLD
    ENDIF
    IFDEF SHOT_FRAME
        DEFINE IDLE_HOLD
    ENDIF
    IFDEF IDLE_HOLD
        call idle_hold
    ENDIF
        ; Count the scanlines left. That wait IS the sync. At 25 this
        ; is the picture frame; the idle frame is counted on its own,
        ; after it has been started on an interrupt.
    IFNDEF SLACK_LINES
    IFNDEF TIMING_BARS
    IFNDEF SHOT_FRAME
        call spare_count
        ld a,(step_saved)
        cp 2
        jr nz,.after_idle
        ld a,(spare_lines)
        ld (spare_pic),a
        ld a,(spare_late)
        ld (spare_pic_late),a
        or a
        jr z,.idle_on_time
        ; Already past the beam. Wait for a real interrupt, or the
        ; second tick starts late and the next picture tears.
        call wait_frame
.idle_on_time:
        xor a
        ld (vsync_flag),a       ; this tick owns the frame that just began
        call idle_tick
        call spare_count
        ld a,(spare_lines)
        ld (spare_idle),a
        ld a,(spare_late)
        ld (spare_idle_late),a
        or a
        jr z,.idle_merge
        call wait_frame         ; next picture starts on an interrupt
.idle_merge:
        ; Stat line shows the tighter frame.
        ld a,(spare_pic_late)
        or a
        jr z,.pic_ok
        ld (spare_late),a
.pic_ok:
        ld a,(spare_idle)
        ld b,a
        ld a,(spare_pic)
        cp b
        jr nc,.idle_soaked     ; idle was tighter; spare_lines is already it
        ld (spare_lines),a
.idle_soaked:
    IFDEF SOAK
        call soak_after_update
    ENDIF
.after_idle:
    IFDEF MEASURE
        ; The warmup is not counted. The window after it keeps the
        ; smallest spare, because the sand-only copy is much cheaper
        ; than the copy that also moves the weed. A single step can
        ; land on the cheap one and look fine while the other misses.
        ld hl,(meas_loops)
        inc hl
        ld (meas_loops),hl
        ld de,MEAS_WARMUP
        or a
        sbc hl,de
        jp c,.meas_go          ; still warming up
        jr nz,.meas_sample
        ld hl,(frame_count)    ; end of the warmup: the window starts now
        ld (meas_base),hl
        jp .meas_go
.meas_sample:
        ; meas_min / meas_max / meas_zeros: the picture frame at 25,
        ; and the only frame at 50. The idle frame is meas_min2,
        ; meas_max2 and meas_zeros2.
        ld a,(step_ticks)
        cp 2
        jr nz,.meas_one
        ld a,(spare_pic)
        ld hl,meas_min
        call meas_keep
        ld a,(spare_pic_late)
        or a
        jr z,.meas_idle
        ld hl,(meas_zeros)
        inc hl
        ld (meas_zeros),hl
.meas_idle:
        ld a,(spare_idle)
        ld hl,meas_min2
        call meas_keep
        ld a,(spare_idle_late)
        or a
        jr z,.meas_notzero
        ld hl,(meas_zeros2)
        inc hl
        ld (meas_zeros2),hl
        jr .meas_notzero
.meas_one:
        ld a,(spare_lines)
        ld hl,meas_min
        call meas_keep
        ld a,(spare_late)
        or a
        jr z,.meas_notzero
        ld hl,(meas_zeros)
        inc hl
        ld (meas_zeros),hl
.meas_notzero:
        ld hl,(meas_loops)
        ld de,MEAS_WARMUP + MEAS_WINDOW
        or a
        sbc hl,de
        jr nz,.meas_go
        ld hl,(frame_count)
        ld de,(meas_base)
        or a
        sbc hl,de
        ld (meas_frames),hl
        ; Printing is after the timed work, with interrupts off.
        di
        ; Row 2 is open water on this build: the title is not drawn
        ; during play, and neither sprite reaches it. Row 10 is the
        ; fish, and his pixels were being read as the digits.
        ld a,(meas_min)
        ld bc,(2 << 8) | 0
        call print_hex8
        ld hl,(meas_zeros)
        ld bc,(2 << 8) | 2
        call print_hex16
        ld a,(meas_max)
        ld bc,(2 << 8) | 7
        call print_hex8
        ld hl,(meas_frames)
        ld bc,(2 << 8) | 10
        call print_hex16
        ld a,(meas_min2)
        ld bc,(3 << 8) | 0
        call print_hex8
        ld hl,(meas_zeros2)
        ld bc,(3 << 8) | 2
        call print_hex16
        ld a,(meas_max2)
        ld bc,(3 << 8) | 7
        call print_hex8
        ld hl,(meas_loops)
        ld bc,(3 << 8) | 10
        call print_hex16
        ld a,GREEN
        out (ULA_PORT),a
.meas_halt:
        halt
        jr .meas_halt
.meas_go:
    ENDIF
    ENDIF
    ENDIF
    ENDIF
        jp main_loop

;------------------------------------------------------------------------------
; idle_tick - the second 1/50 second. No drawing.
; The picture frame already shifted and moved once. This is the other
; pixel, on the fast paths (step_ticks forced to 1). Restores step_ticks
; from step_saved. hit_check may jump to game_over.
; Corrupts: AF, BC, DE, HL, IX, IY
;------------------------------------------------------------------------------
idle_tick:
        ld a,1
        ld (step_ticks),a
    IFDEF TIMING_BARS
        ld a,RED
        out (ULA_PORT),a
    ENDIF
        call scroll_shift_ground
        ld a,(slow_phase)
        xor 1
        ld (slow_phase),a
        jr z,.noslow
    IFDEF TIMING_BARS
        ld a,GREEN
        out (ULA_PORT),a
    ENDIF
        call scroll_shift_slow
.noslow:
        call update_diver
fish_mv2:
        call update_fish
        ld a,(torp_on)
        or a
        call nz,torpedo_move
        ld a,(input_state)
        and IN_FIRE
        call nz,torpedo_fire
    IFNDEF NO_WHEEL
        call update_wheel
    IFNDEF SOAK
        ld a,(torp_on)
        or a
        call nz,torpedo_hit
        call hit_check
        jr nc,.lived
        ld a,(step_saved)
        ld (step_ticks),a
        jp game_over
.lived:
    ENDIF
    ENDIF
        ld a,(step_saved)
        ld (step_ticks),a
        ret

; Timing, sled, and shot builds have no spare_count. Open the idle
; frame with a real interrupt, then do the second tick and nothing else.
    IFDEF IDLE_HOLD
idle_hold:
        ld a,(step_saved)
        cp 2
        ret nz
        call wait_frame
        call idle_tick
    IFDEF SOAK
        call soak_after_update
    ENDIF
        ret
    ENDIF

;------------------------------------------------------------------------------
; draw_late - the diver, the bomb and the torpedo, when the seabed copy
; would cover them
; main_loop already decided which half each one is drawn in, and kept
; that in diver_late and wheel_late for the next restore.
; Corrupts: AF, BC, DE, HL, IX, IY
;------------------------------------------------------------------------------
draw_late:
        ld a,(diver_late)
        or a
        jr z,.diver_done
    IFDEF TIMING_BARS
        ld a,MAGENTA
        out (ULA_PORT),a
    ENDIF
        call diver_draw_fast
.diver_done:
    IFNDEF NO_WHEEL
        ld a,(wheel_late)
        or a
        jr z,.wheel_done
        call wheel_draw
        call wheel_colours
.wheel_done:
    ENDIF
        ld a,(torp_on)
        rla                     ; TORP_LOW is bit 7
        ret nc
        jp torpedo_draw

    IFNDEF NO_WHEEL
; The bomb above the seabed: the picture, then its colours.
wheel_draw_early:
        call wheel_draw
        jp wheel_colours
    ENDIF

; Which half of the step each sprite was drawn in: 0 before the seabed
; copy, $FF after it. wheel_first is $FF when the bomb was drawn before
; the diver. Read by the next step's restore.
diver_late:     db 0
wheel_late:     db 0
wheel_first:    db 0

;------------------------------------------------------------------------------
; Engine, then the Atlantis-only pieces, then the shared actors.
;------------------------------------------------------------------------------
        INCLUDE "../interrupts.asm"
        INCLUDE "../screen.asm"
        INCLUDE "../text.asm"
        INCLUDE "../input.asm"
        INCLUDE "../sprite.asm"
        INCLUDE "scenery.asm"
        INCLUDE "scroll.asm"
        INCLUDE "stats.asm"
        INCLUDE "rate.asm"
        INCLUDE "wheel.asm"
        INCLUDE "hit.asm"
        INCLUDE "torpedo.asm"
        INCLUDE "../fish.asm"
        INCLUDE "../diver.asm"
        ; After the fish and the diver, so the wrappers can call their
        ; image-index routines. The demo does not include this file.
        INCLUDE "fastsprite.asm"
        INCLUDE "boom.asm"
        INCLUDE "menu.asm"
    IFDEF SOAK
        INCLUDE "soak.asm"
    ENDIF

    IFDEF SLACK_LINES
slack_loops:    dw 0            ; loops since entry, including the warmup
slack_measured: dw 0            ; loops inside the measured window
slack_base:     dw 0            ; frame_count when the window opened
slack_armed:    db 0
    ENDIF
    IFDEF SHOT_FRAME
shot_loops:     dw 0            ; main-loop passes, 1 on the first
    ENDIF
    IFDEF MEASURE
meas_loops:     dw 0
meas_base:      dw 0            ; frame_count when the window opened
meas_frames:    dw 0            ; interrupts across the window
; In: A = spare count, HL -> min byte. The next byte is the max.
meas_keep:
        cp (hl)
        jr nc,.max
        ld (hl),a
.max:   inc hl
        cp (hl)
        ret c
        ret z
        ld (hl),a
        ret

meas_min:       db 255          ; smallest spare in the picture frame
meas_max:       db 0            ; largest spare in that same frame
meas_zeros:     dw 0            ; picture frames that missed the interrupt
meas_min2:      db 255          ; idle frame, 25 fps only
meas_max2:      db 0
meas_zeros2:    dw 0
    ENDIF

code_end:
CODE_LENGTH     equ code_end - code_start

        DISPLAY "atlantis code_end ", code_end

        ; Pictures, words and tables. Above the instructions, below the
        ; scroll buffers. Loaded as the second CODE block on the tape.
        ORG DATA_START
data_start:
        INCLUDE "data.asm"
        INCLUDE "../../gfx/fish.asm"
        INCLUDE "../../gfx/diver.asm"
        INCLUDE "../../gfx/wheel.asm"
        INCLUDE "../../gfx/torpedo.asm"
data_end:
DATA_LENGTH     equ data_end - data_start
        DISPLAY "atlantis data_end ", data_end
        DISPLAY "atlantis data bytes ", DATA_LENGTH

        ASSERT (ANIM_FRAMES & (ANIM_FRAMES - 1)) == 0, "ANIM_FRAMES must be a power of 2"
        ASSERT DIVER_ANIM_STEP == 4, "diver_image_index divides by 4 with two RRCAs"
        ASSERT DIVER_FRAMES == 3, "diver_image_index multiplies facing by 3"
        ASSERT FISH_FRAMES == 2, "fish_image_index multiplies facing by 2"
        ASSERT WHEEL_FRAMES == 8, "the pulsar animation is eight steps"
        ASSERT (WHEEL_FRAMES & (WHEEL_FRAMES - 1)) == 0, "wheel frame mask"
        ASSERT WHEEL_WIDTH == 12
        ASSERT WHEEL_BYTES == 3, "the widest shift of the 12px wheel is 3 bytes"
        ASSERT WHEEL_HEIGHT == 12
        ASSERT WHEEL_SPEED == 1, "the soak's frame numbers assume 1px per 1/50 second"
        ASSERT WHEEL_GAP == 48, "the soak's frame numbers assume this pause"
        ASSERT WHEEL_BOB == 6, "the sine table is drawn for a swing of 6"
        ASSERT WHEEL_TOP_BASE == CFG_WHEEL_BOB, "the surface spawn is one swing below the top"
        ASSERT WHEEL_LOW_BASE + CFG_WHEEL_BOB + WHEEL_HEIGHT <= BACK_ROW * 8, "the lowest spawn enters the seaweed"
        ASSERT code_end <= DATA_START, "instructions have run into the pictures"
        ASSERT data_end <= SCROLL_BASE, "pictures have run into the scroll buffers"
        ASSERT SCROLL_BUF_END <= ROW_TABLE, "scroll buffers run into the row table"
        ASSERT (SCROLL_BASE & 255) == 0, "shift_one_row uses DEC L, so a row must not cross a page"
        ASSERT (BACK_BUF & 31) == 0, "each slow row must be 32-byte aligned"
        ASSERT (GROUND_BUF & 31) == 0, "each ground row must be 32-byte aligned"
        ASSERT BACK_PX == 16, "the slow buffer is weed (8) plus sand (8)"
        ASSERT GROUND_PX == 8, "the ground row is one character tall"
        ASSERT SILO_H == 16, "a silo has to stand up out of the ground row"
        ASSERT BACK_ROW == 21, "seaweed is the row above the sand"
        ASSERT SAND_ROW == 22, "sand is the row above the ground"
        ASSERT GROUND_ROW == 23, "the black ground is the bottom row"
        ASSERT NEAR_BOTTOM == 192, "the clamp measures from the bottom of the screen"
        ASSERT DIVER_MIN_Y == 0, "he is allowed up onto row 0"
        ASSERT FISH_SWIM_Y == 76, "the fish stays at the demo's depth"
        ASSERT FISH_SWIM_Y + FISH_HEIGHT <= BACK_ROW * 8, "the fish reaches the seabed; it is drawn before the blit"
        ASSERT TORPEDO_WIDTH == 7 && TORPEDO_BYTES == 2, "the torpedo is one or two bytes a row"
        ASSERT 2 * (TORP_SPEED + WHEEL_SPEED) < TORP_X_SPAN, "at 25 a torpedo could jump over a bomb"
        ASSERT CFG_LIVES >= 1 && CFG_LIVES <= 9, "the stat line has one digit for the lives"
        ASSERT HIT_X_SPAN > 0 && HIT_Y_SPAN > 0, "a hit box has no size"
        ASSERT BORDER_FRAMES == 8, "the rrca x3 above assumes BORDER_FRAMES = 8"
    IFDEF SOAK
        ASSERT CFG_START_RATE = 25 || CFG_START_RATE = 50, "soak rate is 25 or 50"
        ASSERT CFG_WHEEL_WOBBLE == 0, "the soak expects a smooth bob"
        ASSERT CFG_WHEEL_BOB == 6, "the soak expects a swing of 6"
        ASSERT CFG_WHEEL_BOB_SPEED == 1, "the soak expects one sine step per frame"
        ASSERT SOAK_BUF_END <= ROW_TABLE, "soak photographs run into the row table"
    ENDIF

        INCLUDE "../loader.asm"

    IFNDEF TIMING_BARS
    IFNDEF SOAK
    IFNDEF SLACK_LINES
    IFNDEF SHOT_FRAME
    IFNDEF MEASURE
        EMPTYTAP "build/atlantis.tap"
        SAVETAP  "build/atlantis.tap", BASIC, "atlantis", basic_start, BASIC_LENGTH, 10
        SAVETAP  "build/atlantis.tap", CODE, "atlantc", code_start, CODE_LENGTH
        SAVETAP  "build/atlantis.tap", CODE, "atlantd", data_start, DATA_LENGTH
        SAVESNA  "build/atlantis.sna", entry
    ENDIF
    ENDIF
    ENDIF
    ENDIF
    ENDIF

    IFDEF TIMING_BARS
        SAVESNA "build/atlantis-timing.sna", entry
    ENDIF
    IFDEF SOAK
        SAVESNA "build/atlantis-soak.sna", entry
    ENDIF
    IFDEF SLACK_LINES
        SAVESNA "build/atlantis-slack.sna", entry
    ENDIF
    IFDEF SHOT_FRAME
        SAVESNA "build/atlantis-shot.sna", entry
    ENDIF
    IFDEF MEASURE
        SAVESNA "build/atlantis-measure.sna", entry
    ENDIF
