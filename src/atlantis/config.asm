;==============================================================================
; config.asm - the numbers you change
;
; This file is only numbers. Nothing here is drawn, and nothing here
; moves by itself. Change a number, save, and run `make run`. The new
; value is in the game. You do not have to touch any other file.
;
; Distances and speeds below are "per 1/50 second". That is one
; television frame. At 50 frames a second the game takes one of those
; steps every frame. At 25 it waits for two television frames and then
; takes two steps at once, so a minute of swimming covers the same
; water either way. 25 just looks coarser.
;==============================================================================

; How far right the diver may swim. This is the pixel of his LEFT edge.
; 0 is the left of the screen. 255 would be the right, but he is 24
; pixels wide, so the picture itself cannot start past 231. The left
; edge of the screen already stops him at 0. 160 leaves him in the left
; part of the picture, which is where a side-scroller wants the player:
; the sea keeps scrolling, and he does not sit on the right-hand edge.
CFG_DIVER_MAX_X     equ 160

; The frame rate the menu offers when the tape loads.
;   50  one step every television frame (smooth)
;   25  one step every two television frames (coarser, same real speed)
; The menu can still switch this before you start, and Symbol Shift + F
; switches it during play. Only 50 and 25 are allowed.
; 50 is the start. A build can force 25 with -DCFG_START_RATE=25.
; The menu and Symbol Shift + F can still switch during play.
    IFNDEF CFG_START_RATE
CFG_START_RATE      equ 50
    ENDIF

; --- Lives ---------------------------------------------------------------------
; How many times the wheel bomb can hit the diver. The last hit ends the
; game and the menu says GAME OVER. 1 to 9: the stat line has one digit.
CFG_LIVES           equ 3

; After a hit the border flashes red and black for this many game
; steps. 32 is about two thirds of a second at 50 frames a second, and
; twice that at 25. 0 turns the flash off.
CFG_HIT_FLASH       equ 32

; Symbol Shift + S or F blinks the border white and black, so you can
; see the chord was heard. This is how many game steps the blink lasts.
; 12 is three blinks: about a quarter of a second at 50 frames a
; second, half a second at 25. 0 turns the blink off.
CFG_CHORD_FLASH     equ 12

; Television frames before another torpedo can be launched.
; frame_count ticks once per interrupt, so 48 is about a second
; at either game speed. One torpedo at a time already applies.
; This is the extra wait, measured from the launch, and it runs
; while that shot is still in flight. 0 is a fresh press with
; no wait. A shot that crosses from the left of the screen takes
; most of this second, so the wait is felt on a short shot, from
; the right, rather than as a pause after every one.
; The check is done only when fire is down. A frame with fire up
; does not pay for it: the heavy seabed has one scanline spare.
CFG_FIRE_COOLDOWN   equ 48

; --- The wheel bomb, the first enemy type ------------------------------------
; Bob height: how many pixels the bomb swings above its middle, and the
; same number below. 6 is a gentle bob. A bigger number is a taller swing.
; The spawn heights are chosen so a swing of this size still starts in
; the water. Wobble, below, can carry a later bomb down onto the sand.
CFG_WHEEL_BOB       equ 6

; Bob speed: how many steps along the sine the bomb takes per 1/50 second.
; 1 is the original smooth swing (a full up-and-down takes 32/50 of a
; second). 2 swings twice as fast. 0 is not allowed: the bomb would freeze
; at one height.
CFG_WHEEL_BOB_SPEED equ 1

; Wobble. Dalix's noise, the "temperature" of the movement.
;   0   the sine is exact. Every bomb of this type bobs the same way.
;   1   a rare nudge. The swing size breathes a little, the middle drifts
;       a little, and a new bomb starts at a different point on the sine.
;   8   about half of the steps are nudged. Lively, and no two bombs match.
;  15   almost every step is nudged. The path wanders.
; The number is compared with a fresh random value from 0 to 15, so 16
; would not mean anything more than 15. The random comes from the same
; shift-register the spawn height already uses.
CFG_WHEEL_WOBBLE    equ 0

; The bomb's colour. This is the whole cell colour: the ink, and the
; paper behind it. Black ink on the blue of the sea, with the bright bit
; set so the blue stays the same brightness as the water.
;   BRIGHT | BLACK | (BLUE << 3)
; On open water the wheel is black on blue. A cell of sand is yellow ink
; on that same blue; while the bomb covers it the yellow becomes black
; and the blue paper stays. A cell of weed is green on blue and turns
; black on blue the same way. The ground is black on yellow, so a cell
; of ground also loses its yellow paper and becomes blue. When the bomb
; moves on, the cell is put back.
CFG_WHEEL_INK       equ BRIGHT | BLACK | (BLUE << 3)

; --- Silo missiles (missile.asm) ----------------------------------------------
; One at a time. After a random wait, a silo on the screen arms its
; missile: it sits in the hatch, scrolling with the ground, then flies
; straight up and keeps its column. A torpedo blows it up. Touching the
; diver is a hit, the same as a bomb.
;
; The wait, in 1/50 seconds, from one missile ending to the next being
; armed: a random number from _MIN to _MAX. 50 is a second. Up to 255.
CFG_MISSILE_GAP_MIN  equ 75
CFG_MISSILE_GAP_MAX  equ 200

; Only a silo near the diver fires: its missile must leave within this
; many pixels, either side, of the middle of the diver. Smaller is more
; dangerous: 0 is straight up under him. Until a silo comes that close,
; the wait is over but nothing fires. Up to 127. 40 is five characters.
CFG_MISSILE_RANGE    equ 40

; How long it sits in the hatch first, in 1/50 seconds: the warning.
; It leaves a few frames later than this, when the ground has put it
; where it is cheapest to draw. Up to 64.
CFG_MISSILE_ARM      equ 25

; Pixels it climbs per 1/50 second. From the hatch to the top of the
; water is about 150 pixels: 2 takes a second and a half, 3 one second.
CFG_MISSILE_SPEED    equ 2

; The beeper (sound.asm). Each explosion is white noise, played in
; short bursts in the spare time at the end of each step, so it never
; makes a frame late: a burst stops at the interrupt, however long it
; was meant to be. Each burst is shorter and sparser than the one
; before, so the sound fades out.
;   _FRAMES   bursts, one a step (at 25, in the idle frame)
;   _LINES    the first burst, in scanlines (64 us each). A heavy frame
;             has fewer spare lines than this, and its burst is cut short.
;   _DENSITY  how often the speaker is pushed out, out of 256, in the
;             first burst. 128 is the loudest hiss; lower is thinner.
;   _PITCH    scanlines each noise value is held. 1 is the highest
;             hiss; 2 is an octave lower; 3 lower still.
; The lines and the density both fall by a FRAMES-th each burst.
; Assemble with -DNO_SOUND to leave the beeper out altogether.

; A bomb shot by a torpedo.
CFG_BOOM_SND_FRAMES  equ 10
CFG_BOOM_SND_LINES   equ 60
CFG_BOOM_SND_DENSITY equ 128
CFG_BOOM_SND_PITCH   equ 2

; A fish that dies: shorter and higher.
CFG_FISH_SND_FRAMES  equ 6
CFG_FISH_SND_LINES   equ 48
CFG_FISH_SND_DENSITY equ 128
CFG_FISH_SND_PITCH   equ 1

; A missile shot by a torpedo: short and thin, a crackle.
CFG_MISSILE_SND_FRAMES  equ 8
CFG_MISSILE_SND_LINES   equ 56
CFG_MISSILE_SND_DENSITY equ 64
CFG_MISSILE_SND_PITCH   equ 1

; The diver losing a life (not the last): longer and lower.
CFG_DIVER_SND_FRAMES  equ 24
CFG_DIVER_SND_LINES   equ 72
CFG_DIVER_SND_DENSITY equ 128
CFG_DIVER_SND_PITCH   equ 3

; The last life: the death knell, played through before GAME OVER, while
; the last picture stays on the screen. Nothing else is running then,
; so it is a plain tone and can take as long as it likes. It is a run
; of falling "wah"s, each a little lower and shorter than the last, then
; two low pops. This is how many wahs (snd_knell in sound.asm).
CFG_KNELL_WAHS        equ 9
