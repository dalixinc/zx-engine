;==============================================================================
; layout.asm - Engine Demo 1 seabed
;
; Included by src/main.asm only. Atlantis has its own copy of these names
; in src/atlantis/layout.asm (different rows, different heights). The
; shared code (the diver's clamp, the fish depth) reads the names; it does
; not care which game set them.
;
; Rows are character rows (0-23). Sprites work in pixels (y = row * 8).
; The ground is two scrolling silhouettes. Each is two character rows, so
; the profile can rise and fall. The near one sits directly under the far
; one and stops at the debug text (row 22). See scroll.asm and
; docs/SCROLLING.md.
;==============================================================================

WATER_TOP_ROW   equ 7           ; first row of open water
BACK_ROW        equ 18          ; far strip: yellow hills, slow, seaweed
BACK_PX         equ 16          ; two character rows (pixel lines 144-159)
FRONT_ROW       equ 20          ; near strip: black hills, fast, rocks, silos
FRONT_PX        equ 16          ; two character rows (pixel lines 160-175)

; Bottom of the near silhouette, one past the last pixel it owns. The
; diver's feet stop one pixel above whatever column is under him.
NEAR_BOTTOM     equ FRONT_ROW * 8 + FRONT_PX

WATER_ATTR      equ BRIGHT | WHITE | (BLUE << 3)
; Far hills: yellow ink, blue paper. A set pixel is sand, a clear pixel is
; the water showing through. The top far row is this pair for every column.
BACK_HILL_ATTR  equ BRIGHT | YELLOW | (BLUE << 3)
; A seaweed column's bottom cell only. Green ink, yellow paper: the plant
; is green and the cell behind it is sand. Blue water cannot also be in
; that cell. See SCROLLING.md.
BACK_WEED_ATTR  equ BRIGHT | GREEN | (YELLOW << 3)
; Near hills: black ink, yellow paper. Everything in the strip (ground,
; rocks, silos) is black; the clear pixels are the yellow background.
FRONT_ATTR      equ BRIGHT | BLACK | (YELLOW << 3)

; Pixel buffers for the strips. Ordinary RAM, not screen RAM, so rotating
; them is not slowed by the ULA. Filled by scroll_init, not stored on tape.
;   BACK_BUF  16*32 = 512 bytes, FRONT_BUF 16*32 = 512, together 1024.
;   $F000-$F3FF. The row table at $FA00 is well clear of this.
SCROLL_BASE     equ $F000
BACK_BUF        equ SCROLL_BASE
FRONT_BUF       equ BACK_BUF + BACK_PX * 32
SCROLL_BUF_END  equ FRONT_BUF + FRONT_PX * 32
