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

; Each new level brings him back up to this many lives if he has fewer
; (score.asm, level_up): on the level change only, not on a death or a
; start from a level code. 0 turns it off; at most CFG_LIVES_MAX.
CFG_LEVEL_LIVES     equ 3

; --- The story (story.asm) ------------------------------------------------------
; Typed out when 1 starts a game, before it. In 1/50 seconds: a
; letter, the pause at a paragraph, and the wait after the last line
; (a key ends it sooner). The click is a speaker pulse this many
; DJNZ loops long (about 13 T-states each).
CFG_STORY_CHAR      equ 3
CFG_STORY_PARA      equ 40
CFG_STORY_END       equ 250
CFG_STORY_CLICK     equ 30

; The loading screen stays up this many 1/50 seconds after start-up,
; before the menu, or until a key (story.asm, screen_pause). The web
; page plays the snapshot, which starts with the screen and clears it
; for the menu half a second later; a tape has shown it while loading.
; 0 leaves the pause out.
CFG_SCREEN_PAUSE    equ 100

; After a hit the border flashes red and black for this many game
; steps. 32 is about two thirds of a second at 50 frames a second, and
; twice that at 25. 0 turns the flash off.
CFG_HIT_FLASH       equ 32
CFG_HIT_INK         equ RED     ; and black

; When the diver is hit, the game stops for a moment: nothing moves, he
; flashes through four colours for CFG_DEATH_FLASH 1/50 seconds, then
; blows up where he was and is gone. CFG_DEATH_TIME after the hit, the
; game carries on: the next life, or GAME OVER. Both are in 1/50
; seconds and the same at 50 and 25 (a death runs at 50 at either
; speed). 25 and 90 are half a second and 1.8 seconds.
CFG_DEATH_FLASH     equ 25
CFG_DEATH_TIME      equ 90

; Symbol Shift + S or F blinks the border white and black, so you can
; see the chord was heard. This is how many game steps the blink lasts.
; 12 is three blinks: about a quarter of a second at 50 frames a
; second, half a second at 25. 0 turns the blink off.
CFG_CHORD_FLASH     equ 12

; The border. Each level has one steady colour, its row's border in
; CFG_LEVELS below, and the border flashes only for something that
; happens: a death (red and black, hit.asm), a new level (white and
; black, for CFG_LEVEL_FLASH steps), a special bomb going off (its own
; colour, CFG_SPECIAL_FLASH), and a Symbol Shift chord (above). Then it
; goes back to the level's colour.
; Atlantis keeps to the light colours: GREEN, CYAN, YELLOW, WHITE.
; The dark ones (BLACK, BLUE, RED, MAGENTA) are kept for Trigon, the
; levels after 20, so its borders say at once that it is somewhere worse.
CFG_LEVEL_FLASH     equ 24

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

; The second kind of bomb, the spinning wheel (wspin.asm), the same way.
; Red, so the player sees at once that it is not the pulsar.
CFG_SPIN_INK        equ BRIGHT | RED | (BLUE << 3)

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

; (The wait above is level 1's. Later levels take theirs from
; CFG_LEVELS, below.)

; How long it sits in the hatch first, in 1/50 seconds: the warning.
; It leaves a few frames later than this, when the ground has put it
; where it is cheapest to draw. Up to 64.
CFG_MISSILE_ARM      equ 25

; Pixels it climbs per 1/50 second. From the hatch to the top of the
; water is about 150 pixels: 2 takes a second and a half, 3 one second.
CFG_MISSILE_SPEED    equ 2

; Homing missiles, from CFG_MSL_HOME_LEVEL: as it climbs, a missile
; drifts towards the diver's middle, a pixel each time CFG_MSL_HOME
; (256ths of a pixel a 1/50 second, 1-255) carries. 128 is 25 pixels a
; second, so on its way up from the hatch it can close about 35.
; A homing missile shot (or thrown) scores CFG_MSL_HOME_PTS, 0 to 99,
; instead of its level's missile points.
CFG_MSL_HOME_LEVEL   equ 10
CFG_MSL_HOME         equ 128
CFG_MSL_HOME_PTS     equ 15

; --- Power-ups (missile.asm, torpedo.asm) --------------------------------------
; Now and then the missile's turn brings a power-up instead: it sinks
; from below the hearts, in a column near the diver, and he takes it by
; touching it. Torpedoes pass through it. It is gone at the weed.
;   the heart     one more life, up to CFG_LIVES_MAX
;   the bubble    the double shot: for CFG_DOUBLE_TIME seconds he can
;                 fire again while a torpedo is still running, so two
;                 can be out at once
; Each one has a first level (1 = from the start). Each time a missile
; ends, the next turn is a heart CFG_HEART_ODDS times in 256 (from
; CFG_POWER_LEVEL) and a bubble CFG_DOUBLE_ODDS times in 256 (from
; CFG_DOUBLE_LEVEL); otherwise a missile.
CFG_POWER_LEVEL      equ 2       ; hearts from this level
CFG_DOUBLE_LEVEL     equ 4       ; the double shot's bubble from this level
; The fish: before this level every fish is the round one; from it, one
; fish in four is the piranha (boom.asm, fish_kind_pick).
CFG_PIRANHA_LEVEL    equ 6
CFG_HEART_ODDS       equ 32      ; about one turn in 8
CFG_DOUBLE_ODDS      equ 12      ; about one turn in 21
CFG_POWER_SPEED      equ 160     ; it sinks this many 256ths of a pixel a 1/50
                                 ; second: 160 is 31 pixels a second, slower than
                                 ; the diver's 50, so he can catch one up (1-255)
CFG_LIVES_MAX        equ 5       ; hearts on row 1 at most (up to 9)
CFG_DOUBLE_TIME      equ 30      ; seconds of the double shot
; The wait between launches while the double shot lasts, in 1/50
; seconds (CFG_FIRE_COOLDOWN's, which is longer than most torpedoes
; take to cross, would never let two be out). 10 puts them about 40
; pixels apart.
CFG_DOUBLE_COOLDOWN  equ 10

; --- Special bombs (special.asm) ----------------------------------------------
; Rarer power-ups, by the same roll, each with its own share of the 256
; and its own first level. The diver carries one at a time (a new one
; replaces it), shown on row 1, and sets it off with the key in
; special.asm. Both take away a silo missile at once.
;   suction   pulls the bomb and the fish down towards the seabed, where
;             they stay, alive: the escape. The missile goes silently.
;   shove     throws them to the right edge, where they blow up and
;             score as if shot, and so does the missile
;   nuke      clears them (a testing knob: 0 leaves it out of the build)
CFG_SUCTION_LEVEL    equ 5
CFG_SHOVE_LEVEL      equ 7
CFG_NUKE_LEVEL       equ 99      ; only the testers' switch brings it
CFG_SUCTION_ODDS     equ 11      ; about one turn in 23: the escape, twice as
CFG_SHOVE_ODDS       equ 5       ; common as the throw (one in 51), which kills
CFG_NUKE_ODDS        equ 8
; How long the pull or the throw lasts, in 1/50 seconds, and how far
; they move each 1/50 second, in pixels.
CFG_SPECIAL_TIME     equ 24
CFG_SUCTION_SPEED    equ 6       ; down
CFG_SHOVE_SPEED      equ 8       ; right
; What a power scores, 0 to 99, for each thing it clears, in place of
; the level's points: suction for each enemy it pulls out of the way
; and the missile it takes away, shove for each one it blows up, the
; nuke for each one it takes. The total shows in small figures ("+20")
; where the last burst was, for CFG_POP_TIME television frames.
CFG_PTS_SUCTION      equ 10
CFG_PTS_SHOVE        equ 20
CFG_PTS_NUKE         equ 50
CFG_POP_TIME         equ 50
; Setting one off flashes the border in its colour and black, two steps
; each, for this many steps (a chord's flash is CFG_CHORD_FLASH), and
; plays its own slide (sound.asm). Colours: 5 cyan, 6 yellow.
CFG_SPECIAL_FLASH    equ 24
CFG_SUCTION_INK      equ 5
CFG_SHOVE_INK        equ 6
; The quake: shove and the nuke stop the action for CFG_QUAKE_TIME 1/50
; seconds (50 is a second) while the picture shakes up and down by
; CFG_QUAKE_SHAKE pixel rows (1 to 8; each jump is held CFG_QUAKE_HOLD
; television frames), the border flashes, and the beeper rumbles and
; fades. CFG_QUAKE_PITCH is the rumble's pitch: pixel rows copied per
; noise value, so higher is deeper. Suction has no quake: the escape
; stays quiet.
CFG_QUAKE_TIME       equ 50
CFG_QUAKE_SHAKE      equ 3
CFG_QUAKE_HOLD       equ 2
CFG_QUAKE_PITCH      equ 3

; --- The city interlude (interlude.asm) -----------------------------------------
; Finishing level CFG_INTERLUDE_LEVEL, the last of Atlantis, stops the
; game for Erin's picture of the city, with a chime, until a fresh key
; or CFG_INTERLUDE_TIME 1/50 seconds (up to 255: 250 is 5 seconds). Then
; the next level starts as usual. The border while it shows is
; CFG_INTERLUDE_BORDER, the blue of the water round the picture.
CFG_INTERLUDE_LEVEL  equ 20
CFG_INTERLUDE_TIME   equ 250
CFG_INTERLUDE_BORDER equ BLUE
; It starts black but for ATLANTIS, and the picture's colours come on in a
; circle growing from the middle, led by a ring of this cell colour.
CFG_INTERLUDE_RIM    equ BRIGHT | (WHITE << 3) | WHITE

; --- The attract demo (demo.asm) ----------------------------------------------
; After CFG_DEMO_WAIT seconds on the menu with no key down, the computer
; plays level 1 for CFG_DEMO_TIME seconds, then the menu comes back.
; Any key stops it at once.
CFG_DEMO_WAIT        equ 15
CFG_DEMO_TIME        equ 25

; --- Score and levels (score.asm) ---------------------------------------------
; The levels, one row each, in order:
;   points   what this level needs, on top of the last level's target
;   gap min, gap max   the missile wait for this level (see above), in
;            1/50 seconds
;   haste    how much faster the bombs fly. 0 is 1 pixel per 1/50
;            second. 64 adds a pixel every 4th 1/50 second (a quarter
;            faster), 128 every other one (half again). Up to 255.
;   bomb     which bomb: BOMB_P the pulsar, BOMB_W the spinning wheel.
;            A bomb already in flight when the level changes keeps its
;            kind; the next one is the new level's.
; Then how the level looks (level.asm):
;   ink      the bomb's cell colour, as CFG_WHEEL_INK above.
;   bmove    how the bomb moves: MOVE_BOB, today's small bob, or
;            MOVE_WAVE, the wave below (CFG_BOMB_WAVE_*), or MOVE_HOME,
;            the small bob while its middle drifts towards the diver's
;            depth, until it has passed him (wheel_home, level.asm).
;   hunt     how hard MOVE_HOME hunts: added to a fraction each 1/50
;            second, and the bomb's middle moves a pixel towards the
;            diver each time it carries. 64 is a pixel every 4th 1/50
;            second. 1 to 128 with MOVE_HOME (128 is half the diver's own
;            speed, so he can always swim clear), and 0 with the others.
;   fmove    how the fish moves: MOVE_STRAIGHT, at a fixed depth, or
;            MOVE_WAVE, up and down (CFG_FISH_WAVE_*). The fish swimming
;            when the level changes keeps its way; the next one swims
;            the new level's (as the bomb, and as the fish's kind).
;   fspeed   the fish's haste, the same way as the bomb's: 0 is a pixel
;            per 1/50 second, 64 a quarter faster. Only with MOVE_WAVE;
;            MOVE_STRAIGHT is the old fish and must have 0.
;   border   the level's steady border colour (see CFG_LEVEL_FLASH
;            above: light colours for Atlantis), or BORDER_BEAT for the
;            heartbeat, the slow round of colours level 1 once had.
; Then what a torpedo scores on this level, 0 to 99 each:
;   fish, bomb, missile. The spinning wheel's rows score 3 for a bomb, the
;            pulsar's 2. A homing missile scores CFG_MSL_HOME_PTS instead. Something that runs into the diver scores
;            nothing.
; Level 1 is the game as it was: the soak expects that. After the last
; row, the last row repeats. The level codes depend only on the level's
; number, so changing a row (its points to finish, too) changes no code.
BOMB_P              equ 0       ; the pulsar
BOMB_W              equ 1       ; the spinning wheel
MOVE_BOB            equ 0       ; bomb: the small bob
MOVE_STRAIGHT       equ 0       ; fish: straight across
MOVE_WAVE           equ 1       ; either: the wave
MOVE_HOME           equ 2       ; bomb: the bob, drifting to the diver's depth
BORDER_BEAT         equ $FF     ; the heartbeat's round of colours
CFG_L2_INK          equ BRIGHT | YELLOW | (BLUE << 3)
; A new colour each level, so the bomb says the level has changed:
; red, magenta, green, cyan, yellow, black, then red again for 9.
CFG_HUNT_INK        equ BRIGHT | MAGENTA | (BLUE << 3)  ; level 4
CFG_L5_INK          equ BRIGHT | GREEN | (BLUE << 3)
CFG_L6_INK          equ BRIGHT | CYAN | (BLUE << 3)
CFG_L7_INK          equ BRIGHT | YELLOW | (BLUE << 3)
CFG_L8_INK          equ BRIGHT | BLACK | (BLUE << 3)

        MACRO CFG_LEVELS
        ;          points  gap min  gap max  haste  bomb    ink            bmove      hunt fmove          fspeed border        fish bomb missile
        LEVEL_ROW  200,    CFG_MISSILE_GAP_MIN, CFG_MISSILE_GAP_MAX, 0, BOMB_P, CFG_WHEEL_INK, MOVE_BOB, 0, MOVE_STRAIGHT, 0, CYAN, 1, 2, 10
        LEVEL_ROW  300,    70,      185,     24,    BOMB_P, CFG_L2_INK,    MOVE_WAVE, 0,   MOVE_WAVE,     48,    GREEN,        1,   2,   10
        LEVEL_ROW  450,    65,      170,     48,    BOMB_W, CFG_SPIN_INK,  MOVE_WAVE, 0,   MOVE_STRAIGHT, 0,     YELLOW,       1,   3,   10
        LEVEL_ROW  550,    60,      155,     72,    BOMB_W, CFG_HUNT_INK,  MOVE_HOME, 48,  MOVE_WAVE,     56,    WHITE,        1,   3,   10
        LEVEL_ROW  650,    55,      140,     96,    BOMB_W, CFG_L5_INK,    MOVE_WAVE, 0,   MOVE_STRAIGHT, 0,     CYAN,         1,   3,   10
        LEVEL_ROW  750,    50,      125,     120,   BOMB_W, CFG_L6_INK,    MOVE_HOME, 88,  MOVE_WAVE,     64,    GREEN,        1,   3,   10
        LEVEL_ROW  850,    45,      110,     144,   BOMB_W, CFG_L7_INK,    MOVE_WAVE, 0,   MOVE_STRAIGHT, 0,     YELLOW,       1,   3,   10
        LEVEL_ROW  950,    40,      95,      168,   BOMB_W, CFG_L8_INK,    MOVE_HOME, 128, MOVE_WAVE,     72,    WHITE,        1,   3,   10
        LEVEL_ROW  1100,   35,      80,      192,   BOMB_W, CFG_SPIN_INK,  MOVE_HOME, 128, MOVE_WAVE,     80,    CYAN,         1,   3,   10
        ; Level 10: the missiles home (CFG_MSL_HOME_LEVEL). It repeats to 20,
        ; the last of Atlantis (CFG_INTERLUDE_LEVEL).
        LEVEL_ROW  1400,   35,      80,      192,   BOMB_W, CFG_SPIN_INK,  MOVE_HOME, 128, MOVE_WAVE,     80,    GREEN,        1,   3,   10
        ENDM

; The waves (MOVE_WAVE). A wave is a sine, AMP pixels above the middle
; and AMP below. SPEED is how far along it each 1/50 second goes: one
; whole wave takes 256 / SPEED 1/50 seconds, so 2 is about 2.6 seconds
; and 3 about 1.7. Keep the slope gentle: AMP * 6.3 * SPEED / 256 is the
; most it climbs in a 1/50 second, and above 1 pixel the bomb's colour
; has to be repainted whole on that step, which costs time. So the
; bomb's AMP * SPEED must be 40 or less: level.asm asserts it.
; The bomb: 16 and 2 climb at most 0.8 of a pixel. Its middle is kept
; AMP clear of the score row and of the seaweed. The bomb still crosses
; at the level's haste.
CFG_BOMB_WAVE_AMP    equ 16
CFG_BOMB_WAVE_SPEED  equ 2
; The fish swims about its usual depth (pixel row 76), AMP up and down.
; 12 and 3 climb at most 0.9 of a pixel. Level 2's fspeed of 48 makes it
; about a fifth faster across.
CFG_FISH_WAVE_AMP    equ 12
CFG_FISH_WAVE_SPEED  equ 3

; How long the "LEVEL n" banner stays up, in 1/50 seconds. 100 is two
; seconds. From level 4 the level's code is under it, and it stays up
; for _CODE_TIME instead, long enough to read six letters.
CFG_BANNER_TIME      equ 100
CFG_BANNER_CODE_TIME equ 200

; Levels with a code (codes.asm): 2 to this. Atlantis is 1 to 20, then
; the city interlude; Trigon, after it, will need this raised. Each code is worked out from its level number, so
; changing this changes no code, it only adds or drops some. Up to 31.
CFG_CODE_LEVELS      equ 20

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

; A missile leaving its silo: a quick, low whoosh. It only starts if
; nothing else is playing, so it never cuts off an explosion.
CFG_LAUNCH_SND_FRAMES  equ 6
CFG_LAUNCH_SND_LINES   equ 40
CFG_LAUNCH_SND_DENSITY equ 112
CFG_LAUNCH_SND_PITCH   equ 4

; A missile shot by a torpedo: short and thin, a crackle.
CFG_MISSILE_SND_FRAMES  equ 8
CFG_MISSILE_SND_LINES   equ 56
CFG_MISSILE_SND_DENSITY equ 64
CFG_MISSILE_SND_PITCH   equ 1

; The diver losing a life: a long, deep rumble that dies away, through
; the whole death (CFG_DEATH_TIME), one burst a 1/50 second. Nothing
; moves then, so each frame has plenty of time to spare and the bursts
; are long. FRAMES must not be more than CFG_DEATH_TIME.
CFG_DIVER_SND_FRAMES  equ 85
CFG_DIVER_SND_LINES   equ 255
CFG_DIVER_SND_DENSITY equ 128
CFG_DIVER_SND_PITCH   equ 6

; The torpedo leaving: a short zap, two falling notes. Each LASER_NOTE
; is the half-period of a square wave in scanlines (the tone is 7812 /
; this Hz, so 2 is 3.9 kHz and 5 is 1.6 kHz, 1 to 255), then how many
; 1/50 seconds it lasts. A step of 25 is two ticks and plays one note
; whatever its length, so this is 60 ms at 50 and 80 ms at 25 (it was
; 240). It plays only in the spare time at the end of each step. It
; starts the moment the torpedo leaves, but only into silence: it never
; cuts off an explosion, a jingle or another sound, and an explosion
; that starts after it cuts it short.
        MACRO CFG_LASER
        LASER_NOTE 2, 2
        LASER_NOTE 5, 1
        ENDM

; The last life: the death knell, played through before GAME OVER, while
; the last picture stays on the screen. Nothing else is running then,
; so it is a plain tone and can take as long as it likes. It is a run
; of falling "wah"s, each a little lower and shorter than the last, then
; two low pops. This is how many wahs (snd_knell in sound.asm).
CFG_KNELL_WAHS        equ 9
