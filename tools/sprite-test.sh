#!/bin/bash
# Headless sprite test: load the snapshot in Fuse, steer the diver with
# xdotool, and screenshot each stage.  Run under xvfb-run (see Makefile).
# Row 22 of each screenshot shows the diver's X, Y and image index in hex;
# tools/read-debug.py reads them back off the pictures.
# The fish swims across at y 76 on its own the whole time.
# usage: tools/sprite-test.sh <file.sna> <outprefix>
IN="$1"; OUT="$2"
fuse-sdl --machine 48 --no-sound --graphics-filter 2x "$IN" >/tmp/fuse-sprite.log 2>&1 &
PID=$!
sleep ${BOOT:-4}
WID=$(xdotool search --pid "$PID" | head -1)
xdotool windowactivate --sync "$WID" 2>/dev/null || xdotool windowfocus --sync "$WID"
shot() { import -window "$WID" "$OUT-$1.png"; }
hold() { xdotool keydown "$1"; sleep "$2"; xdotool keyup "$1"; sleep 0.3; }
# burst NAME KEY N: hold KEY and take N shots while it is held (kick frames)
burst() { xdotool keydown "$2"; for i in $(seq 1 "$3"); do shot "$1-$i"; done; xdotool keyup "$2"; sleep 0.3; }

shot 01-start                     # x 60, idle: glide frame (IMG 02)
burst 02-kick-right p 6           # swimming right: kick frames 0/1/2
hold a 1.4;  shot 03-seabed       # down to the seabed: y clamps at 153 ($99)
burst 04-kick-left o 6            # turned left (IMG 03..05) over the weed
hold o 1.2;  shot 05-left-edge    # left edge: x clamps at 0
hold q 1.8;  shot 06-fish-depth   # up to the fish's depth: they cross
hold p 2.0                        # out to x ~100, then wait for the fish
for i in $(seq -w 1 16); do shot 07-cross-$i; sleep 0.25; done
burst 07b-kick-left o 6           # left-facing kick frames in open water
hold p 3.5;  shot 08-right-edge   # right edge: x clamps at 231 ($E7)
hold a 2.2;  shot 09-seabed-right # back down onto the seabed (y 153)
kill "$PID"
