;==============================================================================
; main.asm - DIVER ENGINE entry point (milestones 1 + 2)
;
;   Milestone 1 "Hello Spectrum": clear the screen and print a title.
;   Milestone 2 "Heartbeat": IM2 frame interrupt, HALT-driven main loop,
;                frame counter, border colour cycling.
;   Milestone 3 "Input": QAOP/SPACE + 5678/0 + Kempston, one input byte.
;                Debug bytes shown on row 23.
;   Milestone 4 "Sprites": a masked, pre-shifted, animated fish moves pixel
;                by pixel over an underwater backdrop (see docs/SPRITES.md).
;                Row 22 shows the fish's X, Y and image number in hex.
;   Milestone 5 "Diver": the player is now a 24-pixel diver with a jet unit;
;                the fish swims by itself as a second sprite. Row 22 shows
;                the diver's X, Y and image number.
;   v0.5 "Parallax": the seabed is two scrolling strips (far yellow seaweed,
;                near black rocks and missile silos). See docs/SCROLLING.md.
;
; Assemble with -DTIMING_BARS to get build/diver-timing.sna. Border colours:
;   white   restore, then draw sprites that are still in open water
;   cyan    copy the two strips up to the screen
;   magenta draw the diver if he is on the ground, then scroll the buffers
;   yellow  debug text, input, move the diver and the fish
;   black   the frame's work is done
; See docs/SCROLLING.md.
;
; Build:  make          (writes build/diver.tap and build/diver.sna)
;==============================================================================

        DEVICE ZXSPECTRUM48

        INCLUDE "constants.asm"

        ORG CODE_START
code_start:

;------------------------------------------------------------------------------
; entry - called from BASIC with RANDOMIZE USR 32768
;------------------------------------------------------------------------------
entry:
        di
        ld sp,STACK_TOP
        call im2_init           ; also re-enables interrupts
        call build_row_table    ; screen address of each pixel row (sprites)

        ld a,BLACK
        call set_border
        ld a,WHITE | (BLACK << 3)
        call cls

        ; --- title -----------------------------------------------------------
        ld a,BRIGHT | YELLOW | (BLUE << 3)
        ld (text_attr),a
        ld hl,str_title
        ld bc,(2 << 8) | 10     ; row 2, col 10
        call print_string

        ld a,CYAN | (BLACK << 3)
        ld (text_attr),a
        ld hl,str_sub
        ld bc,(5 << 8) | 4
        call print_string

        ld a,WHITE | (BLACK << 3)
        ld (text_attr),a
        ld hl,str_frames
        ld bc,(22 << 8) | 1
        call print_string
        ld hl,str_input
        ld bc,(23 << 8) | 1
        call print_string

        ld hl,str_fishpos
        ld bc,(22 << 8) | 15
        call print_string

        ld hl,str_help
        ld bc,(4 << 8) | 4
        call print_string

        call draw_scenery       ; water, then the two scrolling strips

;------------------------------------------------------------------------------
; main_loop - one pass per 50 Hz frame
;------------------------------------------------------------------------------
main_loop:
        call wait_frame

        ; Screen writes first, straight after the interrupt, so they finish
        ; before the beam reaches them. Water starts at scanline 56, the far
        ; strip at 144. See docs/SCROLLING.md for why the order is this and
        ; not "restore, blit, then both sprites".
    IFDEF TIMING_BARS
        ld a,WHITE
        out (ULA_PORT),a        ; white: restore, then water sprites
    ENDIF
        ; Restore FIRST, while the screen still matches the saved bytes.
        ; Drawing order is the reverse: fish, then diver, so the diver stays
        ; in front. Whoever overlaps a strip is drawn after the copy below,
        ; otherwise the copy would wipe him and his saved bytes would be
        ; last frame's ground. The fish is fixed above the strips.
        call diver_restore
        call fish_restore
        call fish_draw
        ld a,(diver_y)
        add a,DIVER_HEIGHT - 1  ; pixel row of his lowest line
        cp BACK_ROW * 8         ; far strip starts here
        jr nc,.blit             ; feet touch a strip: draw him after the copy
        call diver_draw
.blit:
    IFDEF TIMING_BARS
        ld a,CYAN
        out (ULA_PORT),a        ; cyan: copy both strips
    ENDIF
        call scroll_blit
        ; Same test as above. If his feet are on a strip he was not drawn
        ; yet; drawing him now saves the ground the copy just put up.
        ld a,(diver_y)
        add a,DIVER_HEIGHT - 1
        cp BACK_ROW * 8
        jr c,.diver_done
    IFDEF TIMING_BARS
        ld a,MAGENTA
        out (ULA_PORT),a        ; magenta: diver over the new ground
    ENDIF
        call diver_draw
.diver_done:
    IFDEF TIMING_BARS
        ld a,MAGENTA
        out (ULA_PORT),a        ; magenta: off-screen buffer scroll
    ENDIF
        call scroll_world
    IFDEF TIMING_BARS
        ld a,YELLOW
        out (ULA_PORT),a        ; yellow: debug text, input, game update
    ENDIF

    IFNDEF TIMING_BARS
        ; border: change colour every BORDER_FRAMES frames
        ld hl,(frame_count)
        ld a,l
        rrca                    ; divide by 8 (BORDER_FRAMES)
        rrca
        rrca
        call set_border
    ENDIF

        ; show the 16-bit frame counter so we can see the loop is alive
        ld hl,(frame_count)
        ld bc,(22 << 8) | 9
        call print_hex16

        ; debug: KEY / JOY / IN bytes in hex
        ld a,(input_keys)
        ld bc,(23 << 8) | 5
        call print_hex8
        ld a,(input_joy)
        ld bc,(23 << 8) | 12
        call print_hex8
        ld a,(input_state)
        ld bc,(23 << 8) | 18
        call print_hex8

        ; debug: diver X, Y (pixels) and image index (facing*3 + frame)
        ld a,(diver_x)
        ld bc,(22 << 8) | 17
        call print_hex8
        ld a,(diver_y)
        ld bc,(22 << 8) | 22
        call print_hex8
        call diver_image_index  ; the image drawn this frame
        ld bc,(22 << 8) | 29
        call print_hex8

        ; read input, then update game state for the next frame's draw
        call read_input
        call update_diver
        call update_fish
    IFDEF TIMING_BARS
        ld a,BLACK
        out (ULA_PORT),a        ; border black: this frame's work is finished
    ENDIF
        jp main_loop           ; JR only reaches 128 bytes back, and this loop is longer

;------------------------------------------------------------------------------
; Engine modules
;------------------------------------------------------------------------------
        INCLUDE "interrupts.asm"
        INCLUDE "screen.asm"
        INCLUDE "text.asm"
        INCLUDE "input.asm"
        INCLUDE "sprite.asm"
        INCLUDE "scenery.asm"
        INCLUDE "scroll.asm"
        INCLUDE "fish.asm"
        INCLUDE "diver.asm"

; --- Graphics (generated by tools/gfx2asm.py from gfx/*.txt) -----------------
        INCLUDE "../gfx/fish.asm"
        INCLUDE "../gfx/diver.asm"

; --- Data --------------------------------------------------------------------
str_title:      db "DIVER ENGINE",0
str_sub:        db "ZX Spectrum 48K - v0.5",0
str_frames:     db "FRAMES: ",0
str_input:      db "KEY    JOY    IN",0
str_fishpos:    db "X    Y    IMG",0
str_help:       db "QAOP or 5678 to swim",0

code_end:
CODE_LENGTH     equ code_end - code_start

        ASSERT (ANIM_FRAMES & (ANIM_FRAMES-1)) == 0, "ANIM_FRAMES must be a power of 2 (fish_image tests one bit)"
        ASSERT DIVER_ANIM_STEP == 4, "diver_image_index divides by 4 with two RRCAs"
        ASSERT DIVER_FRAMES == 3, "diver_image_index multiplies facing by 3"
        ASSERT FISH_FRAMES == 2, "fish_image_index multiplies facing by 2"
        ASSERT code_end <= ROW_TABLE, "code has run into the row table"
        ASSERT SCROLL_BUF_END <= ROW_TABLE, "scroll buffers run into the row table"
        ASSERT (BACK_PX % 8) == 0, "back strip must be whole character rows"
        ASSERT (FRONT_PX % 8) == 0, "front strip must be whole character rows"
        ASSERT (SCROLL_BASE & 255) == 0, "shift_one_row uses DEC L, so rows must not cross a page"
        ASSERT (FRONT_BUF & 31) == 0, "each front row must be 32-byte aligned"
        ASSERT BORDER_FRAMES == 8, "main_loop's rrca x3 assumes BORDER_FRAMES = 8"
        ASSERT code_end <= $C000, "engine code has outgrown $8000-$BFFF"
        ASSERT FISH_SWIM_Y + FISH_HEIGHT <= BACK_ROW * 8, "fish reaches the strips; main_loop draws it before the blit"

;------------------------------------------------------------------------------
; Outputs
;------------------------------------------------------------------------------
        INCLUDE "loader.asm"

    IFNDEF TIMING_BARS          ; the timing build only makes a snapshot
        EMPTYTAP "build/diver.tap"
        SAVETAP  "build/diver.tap", BASIC, "diver", basic_start, BASIC_LENGTH, 10
        SAVETAP  "build/diver.tap", CODE,  "diverc", code_start, CODE_LENGTH
    ENDIF

        ; Snapshot for quick testing: jumps straight to entry, no tape load
    IFDEF TIMING_BARS
        SAVESNA  "build/diver-timing.sna", entry
    ELSE
        SAVESNA  "build/diver.sna", entry
    ENDIF
