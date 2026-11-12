;==============================================================================
; bss.asm - the buffers that start empty, built at run time
;
; These used to be DS lines in each file, so the tape carried their
; zeros. Now they are only addresses: boot (main.asm) zeroes BSS_START
; up to BSS_END once, and nothing is loaded there. They live in the
; uncontended RAM above the scroll buffers, from $F300, because the
; frame reads most of them.
;
; Each one is listed here, not in its own file, because a DEFL counter
; cannot take a size that is defined further down, and the sprite sizes
; come from the pictures, which are assembled after the code. Its own
; file has a comment where it used to be.
;
; The order is the order the files had them, so buffers that were next
; to each other still are. A buffer never crosses a 256-byte page: the
; counter skips to the next page instead, so INC L walks are safe.
;==============================================================================

BSS_START       equ SCROLL_BUF_END

bss_ptr = BSS_START

        ; BSS name, size: name is the next free address, then the counter
        ; moves on. (A comparison is -1 when true, so & 1 makes it 1.)
        MACRO BSS name?, size?
bss_ptr = bss_ptr + ((((bss_ptr & 255) + (size?)) > 256) & 1) * ((256 - (bss_ptr & 255)) & 255)
name?   equ bss_ptr
bss_ptr = bss_ptr + (size?)
        ENDM

; --- scroll.asm: the seabed's columns
        BSS paint_tiles, 33             ; columns 0..31 in order, then the pending column
        BSS silo_at, 8                  ; their left halves' aligned columns, -1..32
        BSS silo_rest, 2 * 8            ; their first column and byte count
        BSS silo_cells, 3 * 8
        BSS silo_new, 3 * 8
        BSS front_tiles, 32
        BSS front_h, 32                 ; solid pixels from the bottom of the screen
        BSS back_tiles, 32
        BSS ground_feed, GROUND_PX      ; pixels still to shift in, bit 7 next
        BSS slow_feed, BACK_PX
        BSS column_pat, BACK_PX         ; top byte first. The ground uses the first 8.

; --- stats.asm: the test builds' stat line
    IFDEF STATS
        BSS stats_screen, 32            ; the character on each cell
        BSS stats_force, 4              ; one bit per column to draw again
    ENDIF

; --- the sprites' background records, and the wheel's shifter
        BSS wheel_bg, BG_DATA + WHEEL_BYTES * WHEEL_HEIGHT
    IFDEF TWO_BOMBS
        BSS tb_bg, BG_DATA + WHEEL_BYTES * WHEEL_HEIGHT    ; Trigon's second bomb
    ENDIF
        BSS preshift_row, 8             ; preshift.asm: 4 mask,ink pairs, left byte first
        BSS preshift_ptr, 2 * 8         ; preshift.asm: where each shift's copy has got to

; --- score.asm and codes.asm
        BSS score, 3                    ; BCD, low byte first
        BSS hiscore, 3                  ; kept while the machine is on
        BSS level_next, 3               ; the score that finishes this level, BCD
        BSS hud_text, HUD_LEN           ; what each cell shows, 0 = not drawn yet
        BSS hud_new, HUD_LEN
        BSS banner_chars, 8             ; "LEVEL" and the number
        BSS code_buf, CODE_LEN + 1      ; six letters and a 0, for print_string
        BSS code_in, 3                  ; a typed code, as 24 bits

; --- what the torpedo, the missile, the fish, the diver and a burst cover
        BSS torp_save, 8                ; row 0 bytes 0 and 1, then row 1 bytes 0 and 1; 4-7 a twin's second torpedo
        BSS msl_save, MSL_ROWS * 2
        BSS fish_bg, BG_DATA + FISH_BYTES * FISH_HEIGHT
        BSS diver_bg, BG_DATA + DIVER_BYTES * DIVER_HEIGHT
        BSS boom_bg, BOOM_ROWS * 2
    IFDEF TRIGON
        ; the diver's belt (src/trigon/theme.asm)
        BSS tp_belt, 1                  ; his belt's colour, 0 = white (nothing painted)
        BSS tp_d_on, 1                  ; not 0 = tp_d_at's cells are painted
        BSS tp_d_at, 2                  ; L column, H row
        BSS tp_d_size, 2                ; C columns, B rows
        BSS tp_new_don, 1
        BSS tp_new_dat, 2
        BSS tp_new_dsize, 2
        ; the fish's, the missile's and the bombs' paint (src/trigon/theme.asm).
        ; What is painted now (the soak reads tp_fish_on and tp_fish_at):
        BSS tp_fish_on, 1               ; not 0 = tp_fish_at's cells are painted
        BSS tp_fish_at, 2               ; L column, H row
        BSS tp_fish_ink, 1              ; their colour, 0 = none
        BSS tp_msl_on, 1
        BSS tp_msl_at, 2
        BSS tp_msl_size, 2              ; C columns, B rows
        BSS tp_wpc, 2                   ; the bomb's box when they were painted
        BSS tp_wpr, 2
        BSS tp_wn, 1
      IFDEF TWO_BOMBS
        BSS tp_w2pc, 2                  ; the second bomb's, the same
        BSS tp_w2pr, 2
        BSS tp_w2n, 1
      ENDIF
        ; What this step wants:
        BSS tp_new_fat, 2
        BSS tp_new_fink, 1
        BSS tp_new_mon, 1
        BSS tp_new_mat, 2
        BSS tp_new_msize, 2
      IFDEF POWERUPS
        ; the belt's pop-up (tp_belt_pop, theme.asm)
        BSS tp_bdue, 1                  ; a new belt's colour, to pop up when the banner goes
        BSS tp_pbelt, 1                 ; not 0: the next pop-up is "BELT", in this colour
        BSS tp_pcol, 1                  ; the colour its cells were painted
        BSS tp_pcell, 2                 ; their first cell's attribute, high byte 0 = none
      ENDIF
    ENDIF
    IFDEF POWERUPS
        BSS pop_glyph, 4                ; a power's points: the pop-up's four glyphs (boom.asm)
    ENDIF
    IFDEF ENEMY_DIVER
        BSS ed_bg, BG_DATA + EDIVER_BYTES * EDIVER_HEIGHT  ; Trigon's enemy diver (experiment)
    ENDIF

BSS_END         equ bss_ptr
BSS_LENGTH      equ BSS_END - BSS_START
