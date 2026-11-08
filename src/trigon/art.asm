;==============================================================================
; trigon/art.asm - Erin's Trigon sprites, swapped in at the city interlude
;
; Trigon's enemies are Erin's art (gfx/trigon/*.txt): the piranha, the
; round fish (an angler), the pulsar, the spinning wheel and the
; missile, each the same size, frames and facings as the Atlantis one
; it replaces, so it uses the same buffers, tables and draws.
;
; TRIGON_ART_DATA goes in the data block (main.asm): the four that
; preshift makes at start-up are kept unshifted, as the Atlantis art is
; (in the cold block), and the missile, which gfx2asm.py shifts at
; build time, whole, laid out as gfx/missile.asm is.
;==============================================================================

        INCLUDE "../../gfx/trigon/piranha_raw.asm"
        INCLUDE "../../gfx/trigon/round-fish_raw.asm"
        INCLUDE "../../gfx/trigon/pulsar_raw.asm"
        INCLUDE "../../gfx/trigon/spinning-wheel_raw.asm"

        ; Each one must fit the Atlantis one's buffers and tables exactly.
        ASSERT TFISH_WIDTH == FISH_WIDTH && TFISH_HEIGHT == FISH_HEIGHT && TFISH_PICS == FISH_PICS && TFISH_RAW == FISH_RAW && TFISH_WIDE == FISH_WIDE
        ASSERT TRFISH_WIDTH == RFISH_WIDTH && TRFISH_HEIGHT == RFISH_HEIGHT && TRFISH_PICS == RFISH_PICS && TRFISH_RAW == RFISH_RAW && TRFISH_WIDE == RFISH_WIDE
        ASSERT TWHEEL_WIDTH == WHEEL_WIDTH && TWHEEL_HEIGHT == WHEEL_HEIGHT && TWHEEL_PICS == WHEEL_PICS && TWHEEL_RAW == WHEEL_RAW && TWHEEL_WIDE == WHEEL_WIDE
        ASSERT TWSPIN_WIDTH == WSPIN_WIDTH && TWSPIN_HEIGHT == WSPIN_HEIGHT && TWSPIN_PICS == WSPIN_PICS && TWSPIN_RAW == WSPIN_RAW && TWSPIN_WIDE == WSPIN_WIDE

        MACRO TRIGON_ART_DATA
        TFISH_ART
        TRFISH_ART
        TWHEEL_ART
        TWSPIN_ART
        INCLUDE "../../gfx/trigon/missile.asm"
tmissile_end:
        ENDM
