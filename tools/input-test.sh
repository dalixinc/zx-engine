#!/bin/bash
# Headless input test: load the snapshot in Fuse, hold keys with xdotool
# (XTEST), and screenshot before/after.  Run under xvfb-run.
# usage: tools/input-test.sh <file> <outprefix> [extra fuse args...]
IN="$1"; OUT="$2"; shift 2
fuse-sdl --machine 48 --no-sound --auto-load --traps --fastload --graphics-filter 2x "$@" "$IN" >/tmp/fuse-input.log 2>&1 &
PID=$!
sleep ${BOOT:-4}
WID=$(xdotool search --pid "$PID" | head -1)
xdotool windowactivate --sync "$WID" 2>/dev/null || xdotool windowfocus --sync "$WID"
shot() { import -window "$WID" "$OUT-$1.png"; }
hold() { xdotool keydown "$1"; sleep "$2"; xdotool keyup "$1"; sleep 0.3; }
shot 0-start
for step in $KEYS; do              # KEYS="p:1.0 q:0.8 space:0.2"
  k=${step%%:*}; t=${step#*:}
  if [ "$t" = "hold" ]; then xdotool keydown "$k"; sleep 0.5; shot "held-$k"; xdotool keyup "$k"; sleep 0.3
  else hold "$k" "$t"; shot "after-$k"; fi
done
kill "$PID"
