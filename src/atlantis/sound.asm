;==============================================================================
; sound.asm - the beeper: noise in the frame's spare time, and the knell
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
; A sound is a run of bursts, one per step, described by six bytes (see
; SND_* below): how many bursts, how long the first is, how much shorter
; each gets, how dense the first is, how much sparser each gets, and the
; pitch. snd_start copies a description in. One sound plays at a time:
; a new one replaces the last. So when a bomb hits the diver, the
; bomb's crunch is replaced by his at once.
;
; The noise is an 8-bit LFSR (the same Galois form as wheel_rng, done
; without a branch). Each step of it sets the speaker when the new value
; is below the density. The pitch is how many passes (scanlines) a value
; is held before the next step: 1 is the highest hiss, 2 an octave down.
;
; At 25 the picture frame stays quiet: snd_gate is 0 there, and main
; opens it for the idle frame's wait only.
;
; snd_knell is different: the game is over, nothing else needs the
; processor, so it plays a tone straight through.
;==============================================================================

    IFNDEF NO_SOUND

snd_left:       db 0            ; bursts still to play. 0 = silent.
snd_lines:      db 0            ; length of the next burst, in scanlines
snd_lines_step: db 0            ; taken off snd_lines after each burst
snd_density:    db 0            ; speaker-on chance of the next burst, /256
snd_dens_step:  db 0            ; taken off snd_density after each burst
snd_pitch:      db 1            ; passes each noise value is held
snd_seed:       db $5A          ; the LFSR. Never 0.
snd_border:     db 0            ; border colour, from main_loop's heartbeat
snd_gate:       db 1            ; 0 = this wait stays quiet (25's picture)
snd_tune:       dw 0            ; the next note of a tune; 0 = a noise sound

; A description, in the order the variables above are kept.
        MACRO SND_DEF frames, lines, density, pitch
        db frames
        db lines
        db lines / frames
        db density
        db density / frames
        db pitch
        ASSERT frames >= 1 && lines <= 255 && density <= 255
        ASSERT lines / frames >= 1, "the last burst would be 0 lines long"
        ASSERT pitch >= 1, "a pitch of 0 would hold a value 256 lines"
        ENDM

snd_boom_def:   SND_DEF CFG_BOOM_SND_FRAMES, CFG_BOOM_SND_LINES, CFG_BOOM_SND_DENSITY, CFG_BOOM_SND_PITCH
snd_fish_def:   SND_DEF CFG_FISH_SND_FRAMES, CFG_FISH_SND_LINES, CFG_FISH_SND_DENSITY, CFG_FISH_SND_PITCH
snd_launch_def: SND_DEF CFG_LAUNCH_SND_FRAMES, CFG_LAUNCH_SND_LINES, CFG_LAUNCH_SND_DENSITY, CFG_LAUNCH_SND_PITCH
snd_missile_def: SND_DEF CFG_MISSILE_SND_FRAMES, CFG_MISSILE_SND_LINES, CFG_MISSILE_SND_DENSITY, CFG_MISSILE_SND_PITCH
snd_diver_def:  SND_DEF CFG_DIVER_SND_FRAMES, CFG_DIVER_SND_LINES, CFG_DIVER_SND_DENSITY, CFG_DIVER_SND_PITCH

;------------------------------------------------------------------------------
; snd_boom_start  - a bomb blown up
; snd_fish_start  - a fish that dies
; snd_missile_start - a missile shot down
; snd_launch_start - a missile leaving its silo, only into silence
; snd_diver_start - the diver losing a life
; snd_start       - HL = a six-byte description
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
snd_boom_start:
        ld hl,snd_boom_def
        jr snd_start
snd_fish_start:
        ld hl,snd_fish_def
        jr snd_start
snd_missile_start:
        ld hl,snd_missile_def
        jr snd_start
snd_launch_start:
        ld a,(snd_left)
        or a
        ret nz                  ; an explosion is playing: let it finish
        ld hl,snd_launch_def
        jr snd_start
snd_diver_start:
        ld hl,snd_diver_def
snd_start:
        ld de,snd_left
        ld bc,6
        ldir
        ld hl,0
        ld (snd_tune),hl        ; a noise sound ends any tune
        ld hl,snd_op_noise
        ; fall through

; HL = the seven bytes snd_tick steps its value with: noise or tone.
snd_set_op:
        ld de,snd_tick.op
        ld bc,7
        ldir
        ret

;------------------------------------------------------------------------------
; snd_tune_start - a tune: HL = notes, two bytes each, 0 to end.
;   half-period  scanlines each half of the square wave lasts. The tone
;                is 15625 / (2 * this) Hz: 15 is C5, 12 E5, 10 G5.
;   length       in 1/50 seconds
; The tune plays in the same spare time as the noise, one note after
; another, at the same tempo at 50 and 25. A noise sound started over it
; ends it.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
snd_tune_start:
        ld (snd_tune),hl
        ld hl,snd_op_tone
        call snd_set_op
        ; fall through

; The next note into snd_pitch and snd_left, or silence at the end.
; Corrupts: AF, HL
snd_next_note:
        ld hl,(snd_tune)
        ld a,(hl)
        or a
        jr z,.end
        ld (snd_pitch),a
        inc hl
        ld a,(hl)
        ld (snd_left),a
        inc hl
        ld (snd_tune),hl
        ret
.end:   ld (snd_left),a         ; 0: silent
        ld l,a
        ld h,a
        ld (snd_tune),hl
        ret

; snd_tick's step, as noise or as a tone. Both are 7 bytes and 27
; T-states, so a pass stays one scanline whichever is in.
snd_op_noise:
        srl d                   ; Galois LFSR: shift, and XOR the taps
        sbc a,a
        and $B8
        xor d
        ld d,a
snd_op_tone:
        ld a,d                  ; 0 and $FF in turn: under and over the
        cpl                     ; density, so the speaker is a square wave
        ld d,a
        and $FF                 ; padding, 7 T-states
        nop
        nop
        ASSERT $ - snd_op_tone == 7 && snd_op_tone - snd_op_noise == 7

; The level jingle: G4, C5, E5, G5, a breath of E5, then G5 held.
snd_tune_level:
        db 20, 5, 15, 5, 12, 5, 10, 10, 12, 4, 10, 20, 0

; snd_reset - silence, for a new game and for the knell. Corrupts: AF
snd_reset:
        xor a
        ld (snd_left),a
        ld (snd_tune),a
        ld (snd_tune + 1),a
        ret

;------------------------------------------------------------------------------
; snd_tick - play this step's burst in the wait for the interrupt, then
;            make the next one shorter and sparser
; spare_count calls it while snd_left is not 0, after the step's work,
; with the interrupt not yet arrived.
; In:  A = snd_left. HL = 0, the spare-line count so far
; Out: HL = lines counted (one per pass, as spare_count counts them)
;      NZ: the interrupt arrived during the burst. Z: the burst finished
;      first, and the caller waits out the rest of the frame.
;      DE = vsync_flag either way, which spare_count's loop reads.
; Corrupts: AF, BC, DE, HL, IX
;------------------------------------------------------------------------------
snd_tick:
        ld b,a
        ld a,(snd_tune + 1)     ; tunes are above $00FF
        or a
        jp nz,.tune
        ld a,b
        dec a
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
        ld a,(snd_pitch)
        ld ixh,a                ; IXH = passes a value is held
        ld ixl,1                ; IXL = passes left: step on the first
        ld a,(snd_seed)
        ld d,a                  ; D = the LFSR
        ld a,(snd_border)
        and 7
        ld e,a                  ; E = border bits, speaker and MIC off
        ld hl,0

        ; One pass is one scanline, 224 T-states:
        ;   inc hl 6, ld a,(nn) 13, or a 4, jr nz 7, dec ixl 8,
        ;   hold or step 55 (both ways), ld/cp/sbc/and/or 23, out 11,
        ;   21 nops 84, djnz 13
.line:  inc hl
        ld a,(vsync_flag)
        or a
        jr nz,.irq
        dec ixl
        jr z,.step              ; 12 taken, 7 not
        dup 9                   ; hold: 7 + 36 + 12 = 55
        nop
        edup
        jr .held
.step:  ld a,ixh                ; step: 12 + 8 + 8 + 27 = 55
        ld ixl,a
.op:    srl d                   ; Galois LFSR: shift, and XOR the taps
        sbc a,a                 ; when a 1 fell out. No branch, so every
        and $B8                 ; pass is the same length. A tune puts
        xor d                   ; snd_op_tone here instead.
        ld d,a
.held:  ld a,d
        cp c                    ; carry: below the density
        sbc a,a
        and %00010000           ; the speaker bit
        or e
        out (ULA_PORT),a
        dup 21
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

        ; A tune. This step's 1/50 seconds come off the note; at the end
        ; of it, the next one. Then a burst of the tone that lasts until
        ; the interrupt: the whole of the spare time.
.tune:  ld a,(step_ticks)
        ld c,a
        ld a,b
        sub c
        jr z,.next
        jr nc,.keep
.next:  call snd_next_note
        ld a,(snd_left)
        or a
        jr nz,.play
        ld hl,0                 ; the tune is over: nothing played
        ld de,vsync_flag
        ret                     ; Z
.keep:  ld (snd_left),a
.play:  ld c,128                ; the tone's middle
        ld b,255                ; lines: until the interrupt
        ld a,(snd_pitch)
        ld ixh,a
        ld ixl,1
        ld d,0
        ld a,(snd_border)
        and 7
        ld e,a
        ld hl,0
        jp .line

;------------------------------------------------------------------------------
; snd_knell - the last life. A Pac-Man style death: falling "wah"s, each
; starting a little lower and a little shorter than the one before, then
; two low pops. It plays straight through (about a second and a half)
; while the last picture stays on the screen; game_over calls it before
; the menu.
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
KNELL_TOP       equ 40          ; first wah starts here (half-period units)
KNELL_FALL      equ 140         ; and falls this far
KNELL_LOWER     equ 8           ; each wah starts this much lower
KNELL_SHORTER   equ 4           ; and falls this much less

        ASSERT KNELL_TOP + KNELL_FALL + (CFG_KNELL_WAHS - 1) * (KNELL_LOWER - KNELL_SHORTER) <= 255, "the last wah ends past 255"
        ASSERT KNELL_SHORTER < KNELL_LOWER

snd_knell:
        call snd_reset
        ld a,(snd_border)
        and 7
        ld d,a                  ; D = what goes to the port: border + speaker
        ld l,KNELL_TOP
        ld h,KNELL_TOP + KNELL_FALL
        ld e,CFG_KNELL_WAHS
.wah:   push hl
        ld c,1
        call snd_sweep
        pop hl
        ld a,l
        add a,KNELL_LOWER
        ld l,a
        ld a,h
        add a,KNELL_LOWER - KNELL_SHORTER
        ld h,a
        dec e
        jr nz,.wah

        call .gap
        ld hl,(250 << 8) | 110  ; pop: 110 down to 250, quickly
        ld c,4
        call snd_sweep
        call .gap
        ld hl,(250 << 8) | 110
        ld c,4
        call snd_sweep
        ld a,d
        and 7
        out (ULA_PORT),a        ; speaker in
        ret

.gap:   ld b,6                  ; about an eighth of a second of quiet
.halt:  halt
        djnz .halt
        ret

;------------------------------------------------------------------------------
; snd_sweep - a square wave whose pitch falls
; In: L = first half-period, H = last, C = how much each half-period
;     grows. One unit is 25 T-states: 40 is about 1.6 kHz, 160 about
;     430 Hz. D = the port byte (border, and the speaker bit as it is).
; Out: D with the speaker bit as it was left.
; Corrupts: AF, B, L
;------------------------------------------------------------------------------
snd_sweep:
.half:  ld a,d
        xor %00010000
        ld d,a
        out (ULA_PORT),a
        ld b,l
.wait:  nop
        nop
        nop
        djnz .wait
        ld a,l
        add a,c
        ret c                   ; past 255
        ld l,a
        cp h
        jr c,.half
        ret

    ENDIF
