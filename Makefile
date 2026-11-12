# ATLANTIS - ZX Spectrum 48K
# make            build build/atlantis.tap (+ .sna snapshot and .lst listing).
#                 The tape is packed with ZX0 (build/zx0, compiled from
#                 tools/zx0/ with $(CC)); build/atlantis-plain.tap is the
#                 same game unpacked, which needs nothing but sjasmplus.
# make run        build and launch in Fuse. EMU=fuse-sdl by default;
#                 EMU=fuse (or fuse-gtk) if that is the one installed.
# make timing     build/atlantis-timing.sna: border colour shows where the
#                 frame's time goes
# make demo       Engine Demo 1, still build/diver.tap (tag engine-demo-1)
# make run-demo   launch that tape
# make shot       headless screenshot of Atlantis (Linux, needs xvfb)
# make input-test headless key/Kempston test of the DEMO (it reads row 22)
# make sprite-test headless diver + fish test of the DEMO
# make web       rebuild, then copy the snapshot and the tape to docs/play/
#                 for the browser version (docs/WEB.md). Commit and push them.
#                 Trigon's go to docs/play/trigon/.
# make trigon     TRIGON, the second game: build/trigon.tap and .sna
#                 (src/trigon/main.asm: the Atlantis game with TRIGON defined)
# make run-trigon launch its tape
# make trigon-seas build/trigon-sea-black.sna and -dark.sna, to compare
# make trigon-soak build/trigon-soak.sna, the soak with Trigon's art and colours
# make trigon-ediver build/trigon-ediver.sna, the enemy diver experiment
# make finale     FINALE, the third game: build/finale.tap and .sna
#                 (src/finale/: a copy of the Atlantis and Trigon sources)
# make run-finale launch its tape
# make finale-soak, finale-measure, unpack-check-finale: as Trigon's
# make clean

ASM       ?= sjasmplus
# Fuse opens in a small window. Pass a graphics filter to scale it, for
# example: make run EMU="fuse -g 3x". -g is short for --graphics-filter.
# Choices include 2x, 3x, 4x, hq3x and advmame3x. To make it permanent, add
# export EMU="fuse -g 3x" to ~/.bashrc, or set the filter in Fuse's Options
# menu and choose Options > Save, which writes ~/.fuserc. --full-screen
# works only with the SDL build (fuse-sdl).
EMU       ?= fuse-sdl
PYTHON    ?= python3
GFX       := gfx/fish.asm gfx/diver.asm
ATL_GFX   := gfx/diver_raw.asm gfx/fish_raw.asm gfx/rfish_raw.asm gfx/wheel_raw.asm gfx/wheel_spin.asm gfx/torpedo.asm gfx/missile.asm
SHARED    := src/constants.asm src/interrupts.asm src/screen.asm src/text.asm \
             src/input.asm src/sprite.asm src/fish.asm src/diver.asm \
             src/loader.asm
DEMO_SRC  := src/main.asm src/layout.asm src/scenery.asm src/scroll.asm $(SHARED)
ATL_SRC   := src/atlantis/main.asm src/atlantis/layout.asm \
             src/atlantis/config.asm src/atlantis/data.asm \
             src/atlantis/scenery.asm src/atlantis/scroll.asm \
             src/atlantis/stats.asm src/atlantis/rate.asm \
             src/atlantis/menu.asm src/atlantis/wheel.asm src/atlantis/hit.asm src/atlantis/torpedo.asm \
             src/atlantis/fastsprite.asm src/atlantis/boom.asm src/atlantis/sound.asm \
             src/atlantis/silo.asm src/atlantis/missile.asm src/atlantis/score.asm src/atlantis/codes.asm src/atlantis/preshift.asm src/atlantis/bss.asm \
             src/atlantis/soak.asm src/atlantis/udg.asm src/atlantis/demo.asm src/atlantis/interlude.asm $(SHARED)
TRI_SRC   := $(ATL_SRC) src/trigon/main.asm src/trigon/config.asm \
             src/trigon/theme.asm src/trigon/gate.asm src/trigon/ediver.asm \
             src/trigon/twobomb.asm src/trigon/lance.asm src/trigon/moves.asm \
             src/trigon/ending.asm
TRI_GFX   := gfx/diver_raw.asm gfx/torpedo.asm gfx/trigon/piranha_raw.asm \
             gfx/trigon/round-fish_raw.asm gfx/trigon/pulsar_raw.asm \
             gfx/trigon/spinning-wheel_raw.asm gfx/trigon/missile.asm
FIN_SRC   := $(wildcard src/finale/*.asm) $(SHARED)
FIN_GFX   := gfx/diver_raw.asm gfx/torpedo.asm gfx/trigon/pulsar_raw.asm gfx/trigon/missile.asm
ZX0       := build/zx0
CC        ?= cc

TAP       := build/atlantis.tap
SNA       := build/atlantis.sna
TRI_TAP   := build/trigon.tap
TRI_SNA   := build/trigon.sna
FIN_TAP   := build/finale.tap
FIN_SNA   := build/finale.sna
DEMO_TAP  := build/diver.tap
DEMO_SNA  := build/diver.sna

.PHONY: all run run-sna shot timing demo run-demo input-test sprite-test soak web clean unpack-check \
        trigon run-trigon trigon-seas trigon-soak trigon-ediver unpack-check-trigon \
        finale run-finale finale-soak finale-measure unpack-check-finale

all: $(TAP) $(SNA) $(TRI_TAP) $(TRI_SNA) $(FIN_TAP) $(FIN_SNA)

# main.asm writes the snapshot, the plain tape and the three blocks as
# they are in memory, with their ends in build/atlantis.exp.
ATL_BLOCKS := build/atlantis-cold.bin build/atlantis-code.bin build/atlantis-data.bin build/atlantis-udg.bin
$(SNA) $(ATL_BLOCKS) build/atlantis.exp build/atlantis-plain.tap &: $(ATL_SRC) $(ATL_GFX) gfx/loading.scr gfx/city_pix.zx0 gfx/city_atr.zx0 | build
	$(ASM) --nologo --fullpath=off --lst=build/atlantis.lst --sym=build/atlantis.sym --exp=build/atlantis.exp src/atlantis/main.asm

# ZX0 packs them and the loading screen, and tape.asm puts them on the
# tape behind its unpacker (docs/MEMORY.md).
$(ZX0): tools/zx0/zx0.c tools/zx0/optimize.c tools/zx0/compress.c tools/zx0/memory.c tools/zx0/zx0.h | build
	$(CC) -O2 -o $@ tools/zx0/zx0.c tools/zx0/optimize.c tools/zx0/compress.c tools/zx0/memory.c

# The .delta file is ZX0's in-place margin for the block: how far past
# the unpacked bytes' end the packed ones must end for an unpack over
# itself. tape.asm checks the code's (CODE_DELTA).
build/%.zx0 build/%.delta: build/%.bin $(ZX0)
	$(ZX0) -f $< build/$*.zx0 > build/$*.zx0.log
	sed -n 's/.*(delta \([0-9]*\)).*/\1/p' build/$*.zx0.log > build/$*.delta
	test -s build/$*.delta

# Erin's city for the interlude: a whole screen, packed. Both committed,
# so the game builds without Python or zx0 (build.bat).
gfx/city.scr: tools/mkcity.py gfx/city_bitmap.bin gfx/city_attrs.bin
	$(PYTHON) tools/mkcity.py $@
# Packed in two: the pixels go straight to the screen, the colours aside
# until the circle shows them (interlude.asm).
gfx/city_pix.zx0: gfx/city.scr $(ZX0) | build
	head -c 6144 $< > build/city_pix.bin
	$(ZX0) -f build/city_pix.bin $@ >/dev/null
gfx/city_atr.zx0: gfx/city.scr $(ZX0) | build
	tail -c 768 $< > build/city_atr.bin
	$(ZX0) -f build/city_atr.bin $@ >/dev/null

build/loading.zx0: gfx/loading.scr $(ZX0)
	$(ZX0) -f $< $@ >/dev/null

$(TAP): src/atlantis/tape.asm src/atlantis/tapecheck.asm tools/dzx0_standard.asm build/atlantis.exp build/loading.zx0 $(ATL_BLOCKS:.bin=.zx0) build/atlantis-code.delta
	$(ASM) --nologo --fullpath=off -DCODE_DELTA=$$(cat build/atlantis-code.delta) src/atlantis/tape.asm

# A test tape: it unpacks, then prints the sums of what it unpacked and
# how long that took, instead of starting the game.
unpack-check: $(TAP)
	$(ASM) --nologo --fullpath=off -DCODE_DELTA=$$(cat build/atlantis-code.delta) -DUNPACK_CHECK src/atlantis/tape.asm

# Trigon: the same game with TRIGON defined (src/trigon/main.asm), its
# own blocks, its own packed tape (tape.asm with -DTRIGON).
trigon: $(TRI_TAP) $(TRI_SNA)

TRI_BLOCKS := build/trigon-cold.bin build/trigon-code.bin build/trigon-data.bin build/trigon-udg.bin
$(TRI_SNA) $(TRI_BLOCKS) build/trigon.exp build/trigon-plain.tap &: $(TRI_SRC) $(TRI_GFX) gfx/trigon/loading.scr | build
	$(ASM) --nologo --fullpath=off --lst=build/trigon.lst --sym=build/trigon.sym --exp=build/trigon.exp src/trigon/main.asm

build/trigon-loading.zx0: gfx/trigon/loading.scr $(ZX0)
	$(ZX0) -f $< $@ >/dev/null

$(TRI_TAP): src/atlantis/tape.asm src/atlantis/tapecheck.asm tools/dzx0_standard.asm build/trigon.exp build/trigon-loading.zx0 $(TRI_BLOCKS:.bin=.zx0) build/trigon-code.delta
	$(ASM) --nologo --fullpath=off -DTRIGON -DCODE_DELTA=$$(cat build/trigon-code.delta) src/atlantis/tape.asm

unpack-check-trigon: $(TRI_TAP)
	$(ASM) --nologo --fullpath=off -DTRIGON -DCODE_DELTA=$$(cat build/trigon-code.delta) -DUNPACK_CHECK src/atlantis/tape.asm

run-trigon: $(TRI_TAP)
	$(EMU) --machine 48 --auto-load --traps --fastload $(TRI_TAP)

# The two seas side by side (CFG_SEA, src/trigon/config.asm): snapshots only.
trigon-seas: $(TRI_SRC) $(TRI_GFX) gfx/trigon/loading.scr | build
	$(ASM) --nologo --fullpath=off -DSEA_SNA -DCFG_SEA=0 src/trigon/main.asm
	$(ASM) --nologo --fullpath=off -DSEA_SNA -DCFG_SEA=1 src/trigon/main.asm

# The enemy diver, an experiment (src/trigon/ediver.asm): a snapshot only.
trigon-ediver: $(TRI_SRC) $(TRI_GFX) src/trigon/ediver.asm gfx/trigon/ediver_raw.asm gfx/trigon/loading.scr | build
	$(ASM) --nologo --fullpath=off -DENEMY_DIVER src/trigon/main.asm

trigon-soak: $(TRI_SRC) $(TRI_GFX) | build
	$(ASM) --nologo --fullpath=off -DSOAK --lst=build/trigon-soak.lst src/trigon/main.asm

# Finale: its own copy of the sources (src/finale/), assembled with
# TRIGON defined as Trigon's are; its own blocks and packed tape.
finale: $(FIN_TAP) $(FIN_SNA)

FIN_BLOCKS := build/finale-cold.bin build/finale-code.bin build/finale-data.bin build/finale-udg.bin
$(FIN_SNA) $(FIN_BLOCKS) build/finale.exp build/finale-plain.tap &: $(FIN_SRC) $(FIN_GFX) gfx/finale/loading.scr | build
	$(ASM) --nologo --fullpath=off --lst=build/finale.lst --sym=build/finale.sym --exp=build/finale.exp src/finale/finale.asm

build/finale-loading.zx0: gfx/finale/loading.scr $(ZX0)
	$(ZX0) -f $< $@ >/dev/null

$(FIN_TAP): build/finale.exp build/finale-loading.zx0 $(FIN_BLOCKS:.bin=.zx0) build/finale-code.delta tools/dzx0_standard.asm
	$(ASM) --nologo --fullpath=off -DTRIGON -DCODE_DELTA=$$(cat build/finale-code.delta) src/finale/tape.asm

unpack-check-finale: $(FIN_TAP)
	$(ASM) --nologo --fullpath=off -DTRIGON -DCODE_DELTA=$$(cat build/finale-code.delta) -DUNPACK_CHECK src/finale/tape.asm

run-finale: $(FIN_TAP)
	$(EMU) --machine 48 --auto-load --traps --fastload $(FIN_TAP)

finale-soak: $(FIN_SRC) $(FIN_GFX) | build
	$(ASM) --nologo --fullpath=off -DSOAK --lst=build/finale-soak.lst src/finale/finale.asm

finale-measure: $(FIN_SRC) $(FIN_GFX) | build
	$(ASM) --nologo --fullpath=off -DMEASURE src/finale/finale.asm

demo: $(DEMO_TAP)

$(DEMO_TAP) $(DEMO_SNA): $(DEMO_SRC) $(GFX) | build
	$(ASM) --nologo --fullpath=off --lst=build/diver.lst --sym=build/diver.sym src/main.asm

build:
	mkdir -p build

# Sprite data: ASCII art -> pre-shifted masked bytes. The generated .asm is
# committed too, so you only need Python if you change the .txt art.
gfx/%.asm: gfx/%.txt tools/gfx2asm.py
	$(PYTHON) tools/gfx2asm.py $< $@ $*

# The sprites Atlantis shifts itself at start-up (src/atlantis/preshift.asm):
# the art unshifted. The spinning wheel keeps every other frame. Engine
# Demo 1 still uses gfx/fish.asm, gfx2asm.py's pre-shifted fish.
gfx/wheel_spin.asm: gfx/wheel-full.txt tools/gfx2raw.py tools/gfx2asm.py
	$(PYTHON) tools/gfx2raw.py $< $@ wspin 4
gfx/fish_raw.asm: gfx/fish-atlantis.txt tools/gfx2raw.py tools/gfx2asm.py
	$(PYTHON) tools/gfx2raw.py $< $@ fish 1
# Atlantis's second fish, the round one, from Engine Demo 1's art.
gfx/rfish_raw.asm: gfx/fish.txt tools/gfx2raw.py tools/gfx2asm.py
	$(PYTHON) tools/gfx2raw.py $< $@ rfish 1
gfx/wheel_raw.asm: gfx/wheel.txt tools/gfx2raw.py tools/gfx2asm.py
	$(PYTHON) tools/gfx2raw.py $< $@ wheel 1
gfx/diver_raw.asm: gfx/diver-atlantis.txt tools/gfx2raw.py tools/gfx2asm.py
	$(PYTHON) tools/gfx2raw.py $< $@ diver 1
# Erin's Trigon sprites: under the Atlantis names, as Trigon draws them
# with the same code (src/trigon/main.asm).
gfx/trigon/piranha_raw.asm: gfx/trigon/piranha.txt tools/gfx2raw.py tools/gfx2asm.py
	$(PYTHON) tools/gfx2raw.py $< $@ fish 1
gfx/trigon/round-fish_raw.asm: gfx/trigon/round-fish.txt tools/gfx2raw.py tools/gfx2asm.py
	$(PYTHON) tools/gfx2raw.py $< $@ rfish 1
gfx/trigon/pulsar_raw.asm: gfx/trigon/pulsar.txt tools/gfx2raw.py tools/gfx2asm.py
	$(PYTHON) tools/gfx2raw.py $< $@ wheel 1
gfx/trigon/spinning-wheel_raw.asm: gfx/trigon/spinning-wheel.txt tools/gfx2raw.py tools/gfx2asm.py
	$(PYTHON) tools/gfx2raw.py $< $@ wspin 4
gfx/trigon/missile.asm: gfx/trigon/missile.txt tools/gfx2asm.py
	$(PYTHON) tools/gfx2asm.py $< $@ missile
gfx/trigon/ediver_raw.asm: gfx/trigon/ediver.txt tools/gfx2raw.py tools/gfx2asm.py
	$(PYTHON) tools/gfx2raw.py $< $@ ediver 1

# The loading screen, drawn from the same sprites. Committed, like the
# .asm above, so the tape builds without Python.
gfx/loading.scr: VERSION tools/mkloadscreen.py gfx/diver-atlantis.txt gfx/fish-atlantis.txt gfx/wheel.txt gfx/torpedo.txt
	$(PYTHON) tools/mkloadscreen.py $@
gfx/trigon/loading.scr: src/trigon/VERSION tools/mkloadscreen.py gfx/diver-atlantis.txt gfx/torpedo.txt \
                        gfx/trigon/pulsar.txt gfx/trigon/piranha.txt gfx/trigon/round-fish.txt
	$(PYTHON) tools/mkloadscreen.py --trigon $@
gfx/finale/loading.scr: src/finale/VERSION tools/mkloadscreen.py gfx/diver-atlantis.txt gfx/torpedo.txt \
                        gfx/trigon/pulsar.txt
	$(PYTHON) tools/mkloadscreen.py --finale $@

run: $(TAP)
	$(EMU) --machine 48 --auto-load --traps --fastload $(TAP)

run-sna: $(SNA)
	$(EMU) --machine 48 $(SNA)

run-demo: $(DEMO_TAP)
	$(EMU) --machine 48 --auto-load --traps --fastload $(DEMO_TAP)

shot: $(TAP)
	xvfb-run -a -s "-screen 0 1024x768x24" tools/screenshot.sh $(TAP) build/atlantis-tap-screenshot.png 12

# headless keyboard + Kempston test of Engine Demo 1 (Linux only).
# Those scripts read the demo's row-22 debug digits, so they stay on diver.tap.
input-test: $(DEMO_TAP) $(DEMO_SNA)
	KEYS="p:1.0 q:0.8 space:0.1 o:0.5 a:0.5 p:hold" xvfb-run -a -s "-screen 0 1024x768x24" tools/input-test.sh $(DEMO_SNA) build/input
	KEYS="8:hold 8:1.0 0:0.1" xvfb-run -a -s "-screen 0 1024x768x24" tools/input-test.sh $(DEMO_SNA) build/altkeys
	BOOT=12 KEYS="q:hold p:hold space:hold" xvfb-run -a -s "-screen 0 1024x768x24" tools/input-test.sh $(DEMO_TAP) build/kempston --kempston --joystick-keyboard-output 2

# headless sprite test of Engine Demo 1 (Linux only): see tools/sprite-test.sh
sprite-test: $(DEMO_SNA)
	xvfb-run -a -s "-screen 0 1024x768x24" tools/sprite-test.sh $(DEMO_SNA) build/diver

# Same program as `make`, but the border shows how long each part of the
# frame takes. Launch the snapshot with $(EMU) --machine 48 build/atlantis-timing.sna
timing: $(ATL_SRC) $(ATL_GFX) | build
	$(ASM) --nologo --fullpath=off -DTIMING_BARS --lst=build/atlantis-timing.lst src/atlantis/main.asm

# Background-restore soak. Not part of the tape. Green border and "OK" after
# 1024 scripted frames; the checks themselves are slow, so give it two minutes.
soak: $(ATL_SRC) $(ATL_GFX) | build
	$(ASM) --nologo --fullpath=off -DSOAK --lst=build/atlantis-soak.lst src/atlantis/main.asm

# The web page (docs/play/index.html, JSSpeccy 3) plays the snapshot and
# offers the tape to download. The copies are committed, because GitHub
# Pages serves docs/ straight from git.
web: $(TAP) $(SNA) $(TRI_TAP) $(TRI_SNA)
	cp $(SNA) docs/play/atlantis.sna
	cp $(TAP) docs/play/atlantis.tap
	@sh tools/webstamp.sh
	cp $(TRI_SNA) docs/play/trigon/trigon.sna
	cp $(TRI_TAP) docs/play/trigon/trigon.tap
	@sh tools/webstamp.sh trigon docs/play/trigon
	@echo "docs/play/ and docs/play/trigon/ updated: commit them and push to update the site"

clean:
	rm -f build/*.tap build/*.sna build/*.lst build/*.sym build/*.png \
	      build/*.bin build/*.zx0 build/*.exp $(ZX0)
