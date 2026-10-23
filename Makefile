# DIVER ENGINE - ZX Spectrum 48K
# make        build build/diver.tap (+ .sna snapshot and .lst listing)
# make run    build and launch in Fuse
# make shot   headless screenshot via Xvfb (Linux only)
# make input-test  headless key/Kempston test with xdotool
# make sprite-test headless diver + fish test (then tools/make-diver-montage.py)
# make timing  build/diver-timing.sna: white border while sprites draw
# make clean

ASM      ?= sjasmplus
EMU      ?= fuse-sdl
SRC      := $(wildcard src/*.asm)
TAP      := build/diver.tap
SNA      := build/diver.sna
PYTHON   ?= python3
GFX      := gfx/fish.asm gfx/diver.asm

.PHONY: all run run-sna shot input-test sprite-test timing clean

all: $(TAP)

$(TAP) $(SNA): $(SRC) $(GFX) | build
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

shot: $(TAP)
	xvfb-run -a -s "-screen 0 1024x768x24" tools/screenshot.sh $(TAP) build/diver-tap-screenshot.png 12

# headless keyboard + Kempston test (Linux only); screenshots in build/
input-test: $(TAP) $(SNA)
	KEYS="p:1.0 q:0.8 space:0.1 o:0.5 a:0.5 p:hold" xvfb-run -a -s "-screen 0 1024x768x24" tools/input-test.sh $(SNA) build/input
	KEYS="8:hold 8:1.0 0:0.1" xvfb-run -a -s "-screen 0 1024x768x24" tools/input-test.sh $(SNA) build/altkeys
	BOOT=12 KEYS="q:hold p:hold space:hold" xvfb-run -a -s "-screen 0 1024x768x24" tools/input-test.sh $(TAP) build/kempston --kempston --joystick-keyboard-output 2

# headless sprite test (Linux only): see tools/sprite-test.sh
sprite-test: $(SNA)
	xvfb-run -a -s "-screen 0 1024x768x24" tools/sprite-test.sh $(SNA) build/diver

# Same program, but the border shows how long the sprite code takes
timing: $(SRC) $(GFX) | build
	$(ASM) --nologo --fullpath=off -DTIMING_BARS src/main.asm

clean:
	rm -f build/*.tap build/*.sna build/*.lst build/*.sym build/*.png
