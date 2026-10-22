# DIVER ENGINE - ZX Spectrum 48K
# make        build build/diver.tap (+ .sna snapshot and .lst listing)
# make run    build and launch in Fuse
# make shot   headless screenshot via Xvfb (Linux only)
# make clean

ASM      ?= sjasmplus
EMU      ?= fuse-sdl
SRC      := $(wildcard src/*.asm)
TAP      := build/diver.tap
SNA      := build/diver.sna

.PHONY: all run run-sna shot clean

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

clean:
	rm -f build/*.tap build/*.sna build/*.lst build/*.sym build/*.png
