#!/bin/bash
# Headless smoke test: boot a 48K in Fuse (SDL) under Xvfb, auto-load a
# .tap/.sna, wait, and grab the emulator window as PNG.
# usage: xvfb-run -a -s "-screen 0 1024x768x24" tools/screenshot.sh build/diver.tap build/shot.png 12
set -e
IN="$1"; OUT="$2"; WAIT="${3:-12}"
fuse-sdl --machine 48 --no-sound --auto-load --traps --fastload --graphics-filter 2x "$IN" >/dev/null 2>&1 &
PID=$!
sleep "$WAIT"
WID=$(xdotool search --pid "$PID" 2>/dev/null | head -1 || true)
if [ -n "$WID" ]; then import -window "$WID" "$OUT"; else import -window root "$OUT"; fi
sleep 2
if [ -n "$WID" ]; then import -window "$WID" "${OUT%.png}-2s-later.png"; else import -window root "${OUT%.png}-2s-later.png"; fi
kill "$PID" 2>/dev/null || true
