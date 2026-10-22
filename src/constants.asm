;==============================================================================
; constants.asm - hardware addresses and engine-wide constants
;==============================================================================

; --- Memory map (see the plan Page) -----------------------------------------
SCREEN          equ $4000       ; bitmap, 6144 bytes, interleaved rows
SCREEN_SIZE     equ 6144
ATTRS           equ $5800       ; attributes, 32x24 = 768 bytes
ATTRS_SIZE      equ 768
CODE_START      equ $8000       ; engine code lives in uncontended RAM
STACK_TOP       equ $FDFD       ; first PUSH writes $FDFC/$FDFB, grows down
IM2_JP          equ $FDFD       ; JP <isr> lives here (3 bytes)
IM2_TABLE       equ $FE00       ; 257-byte vector table, all $FD
IM2_VECTOR_BYTE equ $FD         ; -> every vector reads as $FDFD

; --- Font --------------------------------------------------------------------
; The 48K ROM font lives at $3D00 (char 32 = space). We only READ the glyph
; bytes; no ROM routines are called. Point FONT_BASE at your own 96-char,
; 8-bytes-per-glyph font later and nothing else needs to change.
FONT_BASE       equ $3D00 - 32*8

; --- I/O ---------------------------------------------------------------------
ULA_PORT        equ $FE         ; border colour (bits 0-2), beeper, keyboard

; --- Colours / attributes ----------------------------------------------------
BLACK   equ 0
BLUE    equ 1
RED     equ 2
MAGENTA equ 3
GREEN   equ 4
CYAN    equ 5
YELLOW  equ 6
WHITE   equ 7
BRIGHT  equ %01000000
FLASH   equ %10000000

; attribute byte = FLASH | BRIGHT | PAPER<<3 | INK
        MACRO ATTR ink, paper
        db (paper << 3) | ink
        ENDM

; --- Engine tuning -----------------------------------------------------------
BORDER_FRAMES   equ 8           ; change border colour every N frames (power of 2)
