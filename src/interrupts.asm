;==============================================================================
; interrupts.asm - IM2 setup and the 50 Hz frame interrupt handler
;
; The Spectrum's data bus floats during the interrupt acknowledge, so the low
; byte of the vector is unpredictable. We fill 257 bytes at $FE00 with $FD so
; whatever byte is read, the vector is $FDFD, where we put a JP to our handler.
;==============================================================================

;------------------------------------------------------------------------------
; im2_init - build the vector table and switch to interrupt mode 2
; Corrupts: AF, BC, DE, HL
;------------------------------------------------------------------------------
im2_init:
        di
        ld hl,IM2_TABLE
        ld de,IM2_TABLE+1
        ld bc,256               ; 257 bytes total
        ld (hl),IM2_VECTOR_BYTE
        ldir

        ld a,$C3                ; JP nn opcode
        ld (IM2_JP),a
        ld hl,isr
        ld (IM2_JP+1),hl

        ld a,high IM2_TABLE
        ld i,a
        im 2
        ei
        ret

;------------------------------------------------------------------------------
; isr - runs once per frame (50 Hz), at the start of the top border.
; Keep it short: bump the frame counter and raise the vsync flag. Music,
; keyboard scanning, etc. can hook in here later.
;------------------------------------------------------------------------------
isr:
        push af
        push hl

        ld hl,(frame_count)
        inc hl
        ld (frame_count),hl

        ld a,1
        ld (vsync_flag),a

        pop hl
        pop af
        ei
        reti

;------------------------------------------------------------------------------
; wait_frame - block until the next interrupt has happened
;------------------------------------------------------------------------------
wait_frame:
        xor a
        ld (vsync_flag),a
.wait:  halt
        ld a,(vsync_flag)
        or a
        jr z,.wait
        ret

; --- Interrupt state ---------------------------------------------------------
frame_count:    dw 0            ; 16-bit, wraps every ~22 minutes
vsync_flag:     db 0
