# ATLANTIS - ZX Spectrum 48K
# make            build build/atlantis.tap (+ .sna snapshot and .lst listing)
# make run        build and launch in Fuse. EMU=fuse-sdl by default;
#                 EMU=fuse (or fuse-gtk) if that is the one installed.
# make timing     build/atlantis-timing.sna: border colour shows where the
#                 frame's time goes
# make demo       Engine Demo 1, still build/diver.tap (tag engine-demo-1)
# make run-demo   launch that tape
# make shot       headless screenshot of Atlantis (Linux, needs xvfb)
# make input-test headless key/Kempston test of the DEMO (it reads row 22)
# make sprite-test headless diver + fish test of the DEMO
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
SHARED    := src/constants.asm src/interrupts.asm src/screen.asm src/text.asm \
             src/input.asm src/sprite.asm src/fish.asm src/diver.asm \
             src/loader.asm
DEMO_SRC  := src/main.asm src/layout.asm src/scenery.asm src/scroll.asm $(SHARED)
ATL_SRC   := src/atlantis/main.asm src/atlantis/layout.asm \
             src/atlantis/scenery.asm src/atlantis/scroll.asm \
             src/atlantis/stats.asm src/atlantis/soak.asm $(SHARED)

TAP       := build/atlantis.tap
SNA       := build/atlantis.sna
DEMO_TAP  := build/diver.tap
DEMO_SNA  := build/diver.sna

.PHONY: all run run-sna shot timing demo run-demo input-test sprite-test soak clean

all: $(TAP)

$(TAP) $(SNA): $(ATL_SRC) $(GFX) | build
	$(ASM) --nologo --fullpath=off --lst=build/atlantis.lst --sym=build/atlantis.sym src/atlantis/main.asm

demo: $(DEMO_TAP)

$(DEMO_TAP) $(DEMO_SNA): $(DEMO_SRC) $(GFX) | build
	$(ASM) --nologo --fullpath=off --lst=build/diver.lst --sym=build/diver.sym src/main.asm

build:
	mkdir -p build

# Sprite data: ASCII art -> pre-shifted masked bytes. The generated .asm is
# committed too, so you only need Python if you change the .txt art.
gfx/%.asm: gfx/%.txt tools/gfx2asm.py
	$(PYTHON) tools/gfx2asm.py $< $@ $*

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
timing: $(ATL_SRC) $(GFX) | build
	$(ASM) --nologo --fullpath=off -DTIMING_BARS --lst=build/atlantis-timing.lst src/atlantis/main.asm

# Background-restore soak. Not part of the tape. Green border and "OK" after
# 1024 scripted frames; the checks themselves are slow, so give it two minutes.
soak: $(ATL_SRC) $(GFX) | build
	$(ASM) --nologo --fullpath=off -DSOAK --lst=build/atlantis-soak.lst src/atlantis/main.asm

clean:
	rm -f build/*.tap build/*.sna build/*.lst build/*.sym build/*.png
