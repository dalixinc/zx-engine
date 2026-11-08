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

;------------------------------------------------------------------------------
; trigon_on - 1 from the city interlude to the menu: Erin's art is in
; (and the dark theme, theme.asm). Cleared by trigon_off.
;------------------------------------------------------------------------------
trigon_on:      db 0

;------------------------------------------------------------------------------
; trigon_art_in - at the city, after it is shown: the enemies' shifted
; copies made from Erin's art, into the Atlantis buffers, and the
; missile's pictures exchanged for hers. Sets trigon_on. Takes about a
; quarter of a second, while the picture is still up.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
trigon_art_in:
        ld hl,trigon_jobs
        call preshift_list
        ld a,(trigon_on)
        or a
        ld a,1
        ld (trigon_on),a
        ret nz                  ; the missile is hers already
        jr trigon_missile

;------------------------------------------------------------------------------
; trigon_off - enter_menu: the Atlantis art back if Erin's is in, and the
; Atlantis theme (theme.asm). The menu's demo and city use Atlantis art.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
trigon_off:
        ld a,(trigon_on)
        or a
        ret z
        xor a
        ld (trigon_on),a
        call trigon_plain       ; the Atlantis death flash (theme.asm)
        call il_art_atlantis    ; the enemies' copies (interlude.asm)
        ; fall through: the missile's pictures back

; Exchange the missile's pictures with Erin's: the same layout, so doing
; it twice puts them back. Corrupts: AF, BC, DE, HL
trigon_missile:
        ld hl,missile_right_f0_s0
        ld de,tmissile_right_f0_s0
        ld bc,missile_end - missile_right_f0_s0
.swap:  ld a,(de)
        push af
        ld a,(hl)
        ld (de),a
        pop af
        ld (hl),a
        inc hl
        inc de
        dec bc
        ld a,b
        or c
        jr nz,.swap
        ret
        ASSERT missile_end - missile_right_f0_s0 == tmissile_end - tmissile_right_f0_s0, "Erin's missile is not laid out as the Atlantis one"

; As preshift_enemies (preshift.asm), from Erin's art.
trigon_jobs:
    IFDEF TWO_FISH
        PRESHIFT_JOB trfish_src, RFISH_HI, 2, RFISH_HEIGHT, RFISH_WIDE, RFISH_RAW, 0
        PRESHIFT_JOB trfish_src + 2 * RFISH_RAW_PIC, RFISH_BUF, 2, RFISH_HEIGHT, RFISH_WIDE, RFISH_RAW, 0
    ENDIF
        PRESHIFT_JOB tfish_src, FISH_BUF, FISH_PICS, FISH_HEIGHT, FISH_WIDE, FISH_RAW, 0
        PRESHIFT_JOB twheel_src, WHEEL_BUF, WHEEL_PICS, WHEEL_HEIGHT, WHEEL_WIDE, WHEEL_RAW, 0
        PRESHIFT_JOB twspin_src, WSPIN_BUF, WSPIN_PICS, WSPIN_HEIGHT, WSPIN_WIDE, WSPIN_RAW, 0
        dw 0
