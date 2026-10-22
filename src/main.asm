;==============================================================================
; main.asm - DIVER ENGINE entry point (milestones 1 + 2)
;
;   Milestone 1 "Hello Spectrum": clear the screen and print a title.
;   Milestone 2 "Heartbeat": IM2 frame interrupt, HALT-driven main loop,
;                frame counter, border colour cycling.
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

;------------------------------------------------------------------------------
; main_loop - one pass per 50 Hz frame
;------------------------------------------------------------------------------
main_loop:
        call wait_frame

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

        ; TODO milestone 3+: read input, update entities, draw
        jr main_loop

;------------------------------------------------------------------------------
; Engine modules
;------------------------------------------------------------------------------
        INCLUDE "interrupts.asm"
        INCLUDE "screen.asm"
        INCLUDE "text.asm"

; --- Data --------------------------------------------------------------------
str_title:      db "DIVER ENGINE",0
str_sub:        db "ZX Spectrum 48K - v0.1",0
str_frames:     db "FRAMES: ",0

code_end:
CODE_LENGTH     equ code_end - code_start

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
