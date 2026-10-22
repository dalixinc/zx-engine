;==============================================================================
; main.asm - DIVER ENGINE entry point (milestones 1 + 2)
;
;   Milestone 1 "Hello Spectrum": clear the screen and print a title.
;   Milestone 2 "Heartbeat": IM2 frame interrupt, HALT-driven main loop,
;                frame counter, border colour cycling.
;   Milestone 3 "Input": QAOP/SPACE + 5678/0 + Kempston move a 16x16 block;
;                FIRE cycles its colour. Debug bytes shown on row 23.
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

        ld a,WHITE | (BLACK << 3)
        ld (text_attr),a
        ld hl,str_help
        ld bc,(4 << 8) | 0
        call print_string

;------------------------------------------------------------------------------
; main_loop - one pass per 50 Hz frame
;------------------------------------------------------------------------------
main_loop:
        call wait_frame

        ; draw first, while the beam is still in the top border
        call draw_block

        ; border: change colour every BORDER_FRAMES frames
        ld hl,(frame_count)
        ld a,l
        rrca                    ; divide by 8 (BORDER_FRAMES)
        rrca
        rrca
        call set_border

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

        ; read input, then update game state for the next frame's draw
        call read_input
        call update_block
        jr main_loop

;------------------------------------------------------------------------------
; Engine modules
;------------------------------------------------------------------------------
        INCLUDE "interrupts.asm"
        INCLUDE "screen.asm"
        INCLUDE "text.asm"
        INCLUDE "input.asm"
        INCLUDE "block.asm"

; --- Data --------------------------------------------------------------------
str_title:      db "DIVER ENGINE",0
str_sub:        db "ZX Spectrum 48K - v0.2",0
str_frames:     db "FRAMES: ",0
str_input:      db "KEY    JOY    IN",0
str_help:       db "QAOP/5678 move, SPACE/0 fire",0

code_end:
CODE_LENGTH     equ code_end - code_start

        ASSERT (MOVE_FRAMES & (MOVE_FRAMES-1)) == 0, "MOVE_FRAMES must be a power of 2"
        ASSERT BORDER_FRAMES == 8, "main_loop's rrca x3 assumes BORDER_FRAMES = 8"
        ASSERT code_end <= $C000, "engine code has outgrown $8000-$BFFF"

;------------------------------------------------------------------------------
; Outputs
;------------------------------------------------------------------------------
        INCLUDE "loader.asm"

        EMPTYTAP "build/diver.tap"
        SAVETAP  "build/diver.tap", BASIC, "diver", basic_start, BASIC_LENGTH, 10
        SAVETAP  "build/diver.tap", CODE,  "diverc", code_start, CODE_LENGTH

        ; Snapshot for quick testing: jumps straight to entry, no tape load
        SAVESNA  "build/diver.sna", entry
