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
;
; Assemble with -DTIMING_BARS to get build/diver-timing.sna, which turns the
; border white while sprites are being drawn (see docs/SPRITES.md, Timing).
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

        call draw_scenery       ; water, seabed and weeds to swim over

;------------------------------------------------------------------------------
; main_loop - one pass per 50 Hz frame
;------------------------------------------------------------------------------
main_loop:
        call wait_frame

        ; Sprites first, straight after the interrupt, so all of it is
        ; finished before the TV beam reaches the water (row 7 = pixel line
        ; 56) and no sprite is ever seen half-erased. Measured with
        ; `make timing`: done by about line 37. See "Timing" in docs/SPRITES.md.
    IFDEF TIMING_BARS
        ld a,WHITE
        out (ULA_PORT),a        ; border white: sprite work starts
    ENDIF
        ; 1. erase everything, in the REVERSE of the order it was drawn
        call diver_restore
        call fish_restore
        ; 2. save + draw, back to front: the diver goes on top of the fish
        call fish_draw
        call diver_draw
    IFDEF TIMING_BARS
        ld a,BLACK
        out (ULA_PORT),a        ; border black: sprite work done
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
        jr main_loop

;------------------------------------------------------------------------------
; Engine modules
;------------------------------------------------------------------------------
        INCLUDE "interrupts.asm"
        INCLUDE "screen.asm"
        INCLUDE "text.asm"
        INCLUDE "input.asm"
        INCLUDE "sprite.asm"
        INCLUDE "scenery.asm"
        INCLUDE "fish.asm"
        INCLUDE "diver.asm"

; --- Graphics (generated by tools/gfx2asm.py from gfx/*.txt) -----------------
        INCLUDE "../gfx/fish.asm"
        INCLUDE "../gfx/diver.asm"

; --- Data --------------------------------------------------------------------
str_title:      db "DIVER ENGINE",0
str_sub:        db "ZX Spectrum 48K - v0.4",0
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
        ASSERT BORDER_FRAMES == 8, "main_loop's rrca x3 assumes BORDER_FRAMES = 8"
        ASSERT code_end <= $C000, "engine code has outgrown $8000-$BFFF"

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
