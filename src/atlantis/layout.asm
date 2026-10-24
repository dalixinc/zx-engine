;==============================================================================
; layout.asm - Atlantis seabed
;
; Character rows are 0..23, top to bottom. Everything above row 21 is open
; water. The seabed is three bands, two scroll speeds:
;
;   row 21   seaweed, 8 pixels. Part of the SLOW layer. Green ink on blue
;            paper, and only in the cells a plant actually occupies.
;            Scrolls with the sand (1 pixel every 2 frames).
;   row 22   yellow sand, 8 pixels. The rest of the slow layer. Yellow ink
;            on blue paper, every column, painted once and never scrolled.
;            A silo is 16 pixels tall, so its top half stands in this row
;            and is drawn in THIS row's colours. That clash is deliberate.
;   row 23   black ground, 8 pixels. The FAST layer. Black ink on yellow
;            paper, every column, painted once. Scrolls 1 pixel a frame.
;            Rocks stay inside these 8 pixels. The bottom half of a silo
;            is here too.
;
; The slow layer is one 16-pixel buffer (weed on top of sand) so the plant
; cannot drift off the dune it was planted on. The fast layer's buffer is
; only the 8-pixel ground. Silo tops are stamped on after the sand is
; copied; a second full-width buffer for them does not fit in the frame.
; See docs/SCROLLING.md.
;==============================================================================

WATER_TOP_ROW   equ 0           ; open water from the top of the screen
BACK_ROW        equ 21          ; first row of the seabed (the seaweed)
SAND_ROW        equ 22
GROUND_ROW      equ 23

; Slow buffer: 8 weed rows + 8 sand rows. Fast buffer: 8 ground rows.
BACK_PX         equ 16
GROUND_PX       equ 8
SILO_H          equ 16          ; stands 8 pixels up into the sand row
ROCK_H          equ 6           ; a rock stays inside the ground row

; One past the last pixel on the screen. clamp_to_terrain subtracts the
; black column's height from this, so a silo of 16 stops the diver 16
; pixels above the bottom, which is the top of row 22.
NEAR_BOTTOM     equ 24 * 8

WATER_ATTR      equ BRIGHT | WHITE | (BLUE << 3)
SAND_ATTR       equ BRIGHT | YELLOW | (BLUE << 3)
WEED_ATTR       equ BRIGHT | GREEN | (BLUE << 3)
GROUND_ATTR     equ BRIGHT | BLACK | (YELLOW << 3)

; The fish keeps the demo's depth. main.asm DEFINEs ATLANTIS so fish.asm
; does not recompute this from WATER_TOP_ROW (that would be pixel row 20,
; on top of the title).
FISH_SWIM_Y     equ 76

; Pixel buffers. Ordinary RAM, not screen RAM, so the rotate is not slowed
; by the ULA. Built by scroll_init, not stored on the tape.
;   back    16*32 = 512 bytes at $F000
;   ground   8*32 = 256 bytes at $F200
;   $F300 is the first free byte. The row table at $FA00 is well clear.
SCROLL_BASE     equ $F000
BACK_BUF        equ SCROLL_BASE
GROUND_BUF      equ BACK_BUF + BACK_PX * 32
SCROLL_BUF_END  equ GROUND_BUF + GROUND_PX * 32
