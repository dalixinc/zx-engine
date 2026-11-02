;==============================================================================
; sound.asm - beeper noise, played in the time the frame has left over
;
; The beeper is bit 4 of port 254. Bits 0-2 of the same port are the
; border, so every write carries the border colour main_loop last set
; (snd_border), and bit 3 (MIC) stays 0.
;
; The speaker only sounds while the processor keeps flipping that bit,
; so a sound is processor time. A step ends by waiting for the next
; interrupt in spare_count (rate.asm), one scanline a pass. snd_tick
; plays a burst inside that wait instead of idling: each pass of its
; loop is also exactly one scanline, counts the same way, and stops the
; moment the interrupt arrives. So the sound uses only time the frame
; was going to spend waiting, the spare count stays right, and a burst
; can never make a step late. A frame with little to spare just plays a
; shorter burst. (OUT to port 254 can be held up a few T-states while
; the screen is being drawn, which makes a pass a little longer than a
; scanline. The count then reads slightly low, never high.)
;
; A sound is a run of bursts, one per step: how many (snd_left), how
; long the first is (snd_lines), how dense (snd_density), and how much
; both drop each burst (snd_lines_step, snd_dens_step). snd_boom_start
; sets up the explosion. Other sounds can start a run of their own the
; same way. One sound plays at a time: a new one replaces the last.
;
; At 25 the picture frame stays quiet: snd_gate is 0 there, and main
; opens it for the idle frame's wait only.
;
; The noise is an 8-bit LFSR (the same Galois form as wheel_rng, done
; without a branch so every pass takes the same time). Each pass steps
; it once and sets the speaker when the new value is below the density.
;==============================================================================

    IFNDEF NO_SOUND

snd_left:       db 0            ; bursts still to play. 0 = silent.
snd_lines:      db 0            ; length of the next burst, in scanlines
snd_density:    db 0            ; speaker-on chance of the next burst, /256
snd_lines_step: db 0            ; taken off snd_lines after each burst
snd_dens_step:  db 0            ; taken off snd_density after each burst
snd_seed:       db $5A          ; the LFSR. Never 0.
snd_border:     db 0            ; border colour, from main_loop's heartbeat
snd_gate:       db 1            ; 0 = this wait stays quiet (25's picture)

BOOM_LINES_STEP equ CFG_BOOM_SND_LINES / CFG_BOOM_SND_FRAMES
BOOM_DENS_STEP  equ CFG_BOOM_SND_DENSITY / CFG_BOOM_SND_FRAMES

        ASSERT CFG_BOOM_SND_FRAMES >= 1 && CFG_BOOM_SND_FRAMES <= 255
        ASSERT BOOM_LINES_STEP >= 1, "the last burst would be 0 lines long"
        ASSERT CFG_BOOM_SND_LINES <= 255 && CFG_BOOM_SND_DENSITY <= 255

;------------------------------------------------------------------------------
; snd_boom_start - the explosion's crunch. boom_arm calls it.
; Corrupts: AF
;------------------------------------------------------------------------------
snd_boom_start:
        ld a,CFG_BOOM_SND_LINES
        ld (snd_lines),a
        ld a,BOOM_LINES_STEP
        ld (snd_lines_step),a
        ld a,CFG_BOOM_SND_DENSITY
        ld (snd_density),a
        ld a,BOOM_DENS_STEP
        ld (snd_dens_step),a
        ld a,CFG_BOOM_SND_FRAMES
        ld (snd_left),a
        ret

; snd_reset - silence, for a new game. Corrupts: AF
snd_reset:
        xor a
        ld (snd_left),a
        ret

;------------------------------------------------------------------------------
; snd_tick - play this step's burst in the wait for the interrupt, then
;            make the next one shorter and sparser
; spare_count calls it while snd_left is not 0, after the step's work,
; with the interrupt not yet arrived.
; In:  HL = 0, the spare-line count so far
; Out: HL = lines counted (one per pass, as spare_count counts them)
;      NZ: the interrupt arrived during the burst. Z: the burst finished
;      first, and the caller waits out the rest of the frame.
;      DE = vsync_flag either way, which spare_count's loop reads.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
snd_tick:
        dec a                   ; A = snd_left
        ld (snd_left),a
        ld a,(snd_density)
        ld c,a                  ; C = this burst's density
        ld hl,snd_dens_step
        sub (hl)
        jr nc,.dens
        xor a
.dens:  ld (snd_density),a
        ld a,(snd_lines)
        ld b,a                  ; B = this burst's length
        ld hl,snd_lines_step
        sub (hl)
        jr z,.short
        jr nc,.lines
.short: ld a,1
.lines: ld (snd_lines),a
        ld a,(snd_seed)
        ld d,a                  ; D = the LFSR
        ld a,(snd_border)
        and 7
        ld e,a                  ; E = border bits, speaker and MIC off
        ld hl,0

        ; One pass is one scanline, 224 T-states:
        ;   inc hl 6, ld a,(nn) 13, or a 4, jr nz 7,
        ;   LFSR 27, cp/sbc/and/or 19, out 11, 31 nops 124, djnz 13
.line:  inc hl
        ld a,(vsync_flag)
        or a
        jr nz,.irq
        srl d                   ; Galois LFSR: shift, and XOR the taps
        sbc a,a                 ; when a 1 fell out. No branch, so every
        and $B8                 ; pass is the same length.
        xor d
        ld d,a
        cp c                    ; carry: below the density
        sbc a,a
        and %00010000           ; the speaker bit
        or e
        out (ULA_PORT),a
        dup 31
        nop
        edup
        djnz .line

        ld a,d                  ; burst done, time left over
        ld (snd_seed),a
        ld a,e
        out (ULA_PORT),a        ; speaker back in
        ld de,vsync_flag
        xor a                   ; Z
        ret

.irq:   ld a,d
        ld (snd_seed),a
        ld a,e
        out (ULA_PORT),a
        ld de,vsync_flag
        or 1                    ; NZ: the frame is over
        ret

    ENDIF
