;==============================================================================
; main.asm - ATLANTIS
;
; The game. Engine Demo 1 (src/main.asm, tag engine-demo-1) is the same
; engine with the old two-strip seabed; this file is the Atlantis seabed,
; the frame loop, and the stat overlay. Shared code is included from src/.
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

        ld a,BLACK
        call set_border
        ld a,WATER_ATTR         ; the whole screen starts as open water
        call cls

        call draw_scenery       ; seabed colours and the first copy of the strips

        ; The title is painted after the water, so its cells keep the
        ; colours print_char writes. Row 0 is left as water: that is
        ; where the stat overlay goes, and it is blank until asked for.
        ld a,BRIGHT | YELLOW | (BLUE << 3)
        ld (text_attr),a
        ld hl,str_title
        ld bc,(2 << 8) | 12
        call print_string

        ld a,WATER_ATTR
        ld (text_attr),a
        ld hl,str_help
        ld bc,(4 << 8) | 6
        call print_string
        ld hl,str_stats
        ld bc,(5 << 8) | 4
        call print_string

;------------------------------------------------------------------------------
; main_loop - one pass per 50 Hz frame
;------------------------------------------------------------------------------
main_loop:
        call wait_frame

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
        call stats_poll         ; Symbol Shift + S, edge-triggered
        call read_input
    IFDEF SOAK
        call soak_apply_input   ; the script wins over the real keyboard
    ENDIF

    IFDEF TIMING_BARS
        ld a,WHITE
        out (ULA_PORT),a
    ENDIF
        ; Restore first, while the screen still matches the photographs.
        ; Draw order is fish, wheel, diver (back to front), so restore is
        ; the reverse: diver, wheel, fish. The wheel is drawn after the
        ; fish, so where they overlap its photograph contains the fish
        ; and has to be put back before the fish's is.
        call diver_restore
        call wheel_restore
        call fish_restore
        call stats_prepare      ; drop the digits if a sprite is about to
                                ; photograph row 0. Otherwise leave them:
                                ; the beam is about to read that row.
    IFDEF SOAK
        call soak_after_restore
    ENDIF

        call fish_draw
        call wheel_draw         ; always above the seaweed, so always here
        ld a,(diver_y)
        add a,DIVER_HEIGHT - 1  ; his lowest pixel
        cp BACK_ROW * 8         ; seabed starts at row 21
        jr nc,.low
        call diver_draw         ; still in open water: the copy will not touch him
.low:
        ; If a sprite is on row 0, the digits go back on top now,
        ; after the photograph and before we spend the frame on the seabed.
        ; The wheel is included: it can bob up to y = 0.
        call stats_overlay_if_row0

    IFDEF TIMING_BARS
        ld a,CYAN
        out (ULA_PORT),a
    ENDIF
        call scroll_blit        ; also paints the weed, on the full-copy frame
    IFDEF SOAK
        call soak_after_blit    ; the picture the next restore must match
    ENDIF

        ld a,(diver_y)
        add a,DIVER_HEIGHT - 1
        cp BACK_ROW * 8
        jr c,.diver_done        ; he was drawn with the fish
    IFDEF TIMING_BARS
        ld a,MAGENTA
        out (ULA_PORT),a
    ENDIF
        call diver_draw         ; feet on the seabed: photograph THIS ground
.diver_done:

    IFDEF TIMING_BARS
        ld a,RED
        out (ULA_PORT),a
    ENDIF
        call scroll_shift_ground

        ; Slow layer: every other frame. The phase flips here, not inside
        ; the shift, so the green border can be turned on only when the
        ; rotate actually runs.
        ld a,(slow_phase)
        xor 1
        ld (slow_phase),a
        jr z,.slow_done
    IFDEF TIMING_BARS
        ld a,GREEN
        out (ULA_PORT),a
    ENDIF
        call scroll_shift_slow
.slow_done:

    IFDEF TIMING_BARS
        ld a,YELLOW
        out (ULA_PORT),a
    ELSE
    IFNDEF SOAK
        ; Heartbeat. The digits are hidden by default, so the border is
        ; what shows the frame loop is alive. rrca x3 is / BORDER_FRAMES.
        ld hl,(frame_count)
        ld a,l
        rrca
        rrca
        rrca
        call set_border
    ENDIF
    ENDIF

        ; No sprite on row 0: refresh the digits now, after the beam has
        ; left the row. A sprite on row 0 was already handled above.
        call stats_overlay_if_clear

        call update_diver
        call update_fish
        call update_wheel
    IFDEF SOAK
        call soak_after_update
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
        ; Not the tape. Halt at the end of one frame so a screenshot can
        ; catch the wheel at a known x. The draw for this frame has
        ; already happened; SHOT_FRAME is the frame_count (1 on the
        ; first loop).
        ld hl,(frame_count)
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
        jp main_loop

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
        INCLUDE "wheel.asm"
        INCLUDE "../fish.asm"
        INCLUDE "../diver.asm"
    IFDEF SOAK
        INCLUDE "soak.asm"
    ENDIF

        INCLUDE "../../gfx/fish.asm"
        INCLUDE "../../gfx/diver.asm"
        INCLUDE "../../gfx/wheel.asm"

str_title:      db "ATLANTIS",0
str_help:       db "QAOP or 5678 to swim",0
str_stats:      db "Symbol Shift + S: stats",0

    IFDEF SLACK_LINES
slack_loops:    dw 0            ; loops since entry, including the warmup
slack_measured: dw 0            ; loops inside the measured window
slack_base:     dw 0            ; frame_count when the window opened
slack_armed:    db 0
    ENDIF

code_end:
CODE_LENGTH     equ code_end - code_start

        DISPLAY "atlantis code_end ", code_end

        ASSERT (ANIM_FRAMES & (ANIM_FRAMES - 1)) == 0, "ANIM_FRAMES must be a power of 2"
        ASSERT DIVER_ANIM_STEP == 4, "diver_image_index divides by 4 with two RRCAs"
        ASSERT DIVER_FRAMES == 3, "diver_image_index multiplies facing by 3"
        ASSERT FISH_FRAMES == 2, "fish_image_index multiplies facing by 2"
        ASSERT WHEEL_FRAMES == 4, "wheel_drift masks the frame with 3"
        ASSERT (WHEEL_FRAMES & (WHEEL_FRAMES - 1)) == 0, "wheel frame mask"
        ASSERT WHEEL_BYTES == 3, "a 16px sprite shifts to 3 bytes"
        ASSERT WHEEL_HEIGHT == 16
        ASSERT WHEEL_SPEED == 1, "the soak's frame numbers assume 1px/frame"
        ASSERT WHEEL_GAP == 48, "the soak's frame numbers assume this pause"
        ASSERT WHEEL_BOB == 6
        ASSERT WHEEL_TOP_BASE == 6
        ASSERT WHEEL_LOW_BASE == 146, "lowest base must sit one bob above the weed"
        ASSERT WHEEL_LOW_BASE + WHEEL_BOB + WHEEL_HEIGHT <= BACK_ROW * 8, "wheel enters the seaweed"
        ASSERT 36 >= WHEEL_TOP_BASE
        ASSERT 70 >= WHEEL_TOP_BASE
        ASSERT 100 <= WHEEL_LOW_BASE
        ASSERT 120 <= WHEEL_LOW_BASE
        ASSERT 50 <= WHEEL_LOW_BASE
        ASSERT 24 >= WHEEL_TOP_BASE
        ASSERT code_end <= ROW_TABLE, "code has run into the row table"
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
        ASSERT BORDER_FRAMES == 8, "the rrca x3 above assumes BORDER_FRAMES = 8"
        ASSERT code_end <= $C000, "engine code has outgrown $8000-$BFFF"

        INCLUDE "../loader.asm"

    IFNDEF TIMING_BARS
    IFNDEF SOAK
    IFNDEF SLACK_LINES
    IFNDEF SHOT_FRAME
        EMPTYTAP "build/atlantis.tap"
        SAVETAP  "build/atlantis.tap", BASIC, "atlantis", basic_start, BASIC_LENGTH, 10
        SAVETAP  "build/atlantis.tap", CODE, "atlantc", code_start, CODE_LENGTH
        SAVESNA  "build/atlantis.sna", entry
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
