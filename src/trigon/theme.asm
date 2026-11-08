;==============================================================================
; trigon/theme.asm - Trigon's colours
;
; While trigon_on is set (art.asm: from the city to the menu), each new
; level's look is the Atlantis row's (level_style) with Trigon's colours
; over it, from config.asm:
;   - a steady border from the dark set, CFG_TRIGON_BORDER_0 to _3 by the
;     level number, so two levels in a row never share one
;   - the bomb's ink, CFG_TRIGON_INK_0 to _3 the same way (on the sea's
;     paper, as every bomb colour is)
;   - the death's border flash in CFG_TRIGON_HIT_INK and black, as red
;     would hardly show against a red or black border
; The new level's flash (white) and a special bomb's (cyan, yellow) show
; against them all. The diver stays white. The fish and the missile have
; no colour of their own: like the diver, they take the water's ink.
;==============================================================================

;------------------------------------------------------------------------------
; trigon_style - il_level (interlude.asm), on each level change in Trigon
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
trigon_style:
        ld a,(level_n)
        and 3
        ld e,a
        ld d,0
        ld hl,trigon_borders
        add hl,de
        ld a,(hl)
        ld (beat_fixed + 1),a   ; as level_style writes a fixed border
        push de
        ld hl,beat_fixed
        ld de,step_skip.beat
        ld bc,4
        ldir
        pop de
        ld hl,trigon_inks
        add hl,de
        ld a,(hl)
        ld (level_ink),a        ; the next bomb's colour (wheel_type)
        ld a,CFG_TRIGON_HIT_INK
        jr trigon_hit

; trigon_off (art.asm): the death flash red again. Corrupts: AF
trigon_plain:
        ld a,RED
trigon_hit:
        ld (step_skip.hit_ink + 1),a
        ret

trigon_borders: db CFG_TRIGON_BORDER_0, CFG_TRIGON_BORDER_1, CFG_TRIGON_BORDER_2, CFG_TRIGON_BORDER_3
trigon_inks:    db CFG_TRIGON_INK_0, CFG_TRIGON_INK_1, CFG_TRIGON_INK_2, CFG_TRIGON_INK_3
        ASSERT CFG_TRIGON_BORDER_0 != CFG_TRIGON_BORDER_1 && CFG_TRIGON_BORDER_1 != CFG_TRIGON_BORDER_2 && CFG_TRIGON_BORDER_2 != CFG_TRIGON_BORDER_3 && CFG_TRIGON_BORDER_3 != CFG_TRIGON_BORDER_0, "two Trigon levels in a row would share a border"
        ASSERT CFG_TRIGON_BORDER_0 <= 7 && CFG_TRIGON_BORDER_1 <= 7 && CFG_TRIGON_BORDER_2 <= 7 && CFG_TRIGON_BORDER_3 <= 7 && CFG_TRIGON_HIT_INK <= 7
