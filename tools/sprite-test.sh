#!/bin/bash
# Headless sprite test: load the snapshot in Fuse, steer the fish with
# xdotool, and screenshot each stage.  Run under xvfb-run (see Makefile).
# Row 22 of each screenshot shows the fish's X, Y and image index in hex,
# so you can read the exact pixel position off the picture.
# usage: tools/sprite-test.sh <file.sna> <outprefix>
IN="$1"; OUT="$2"
fuse-sdl --machine 48 --no-sound --graphics-filter 2x "$IN" >/tmp/fuse-sprite.log 2>&1 &
PID=$!
sleep ${BOOT:-4}
WID=$(xdotool search --pid "$PID" | head -1)
xdotool windowactivate --sync "$WID" 2>/dev/null || xdotool windowfocus --sync "$WID"
shot() { import -window "$WID" "$OUT-$1.png"; }
hold() { xdotool keydown "$1"; sleep "$2"; xdotool keyup "$1"; sleep 0.3; }

shot 1-start                    # x = 40 ($28), a multiple of 8, facing right
hold p 0.11; shot 2-right-few   # nudged right by a few pixels: shift != 0
hold a 1.6;  shot 3-seabed      # dropped onto the seabed (y clamps at 167)
hold o 0.25; shot 4-left-weed   # turned left, over the weed at column 4
hold q 0.6;  shot 5-back-up     # swum up again: seabed/weed must be intact
for i in 1 2 3 4 5 6; do shot 6-anim-$i; sleep 0.05; done   # tail wag
kill "$PID"
