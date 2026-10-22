# DIVER ENGINE - ZX Spectrum 48K
# make        build build/diver.tap (+ .sna snapshot and .lst listing)
# make run    build and launch in Fuse
# make shot   headless screenshot via Xvfb (Linux only)
# make input-test  headless key/Kempston test with xdotool
# make clean

ASM      ?= sjasmplus
EMU      ?= fuse-sdl
SRC      := $(wildcard src/*.asm)
TAP      := build/diver.tap
SNA      := build/diver.sna

.PHONY: all run run-sna shot input-test clean

all: $(TAP)

$(TAP) $(SNA): $(SRC) | build
	$(ASM) --nologo --fullpath=off --lst=build/diver.lst --sym=build/diver.sym src/main.asm

build:
	mkdir -p build

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

clean:
	rm -f build/*.tap build/*.sna build/*.lst build/*.sym build/*.png
