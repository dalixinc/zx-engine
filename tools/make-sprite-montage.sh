#!/bin/bash
# Build build/montage-sprites.png from the shots taken by tools/sprite-test.sh.
# Each tile: the full screen, plus a 4x zoom around the fish with red lines on
# the 8-pixel byte boundaries, so you can see the fish sitting part-way
# through a byte (proof that the pre-shifted copies are used).
# The x/y values below are read off the debug line in each shot.
set -e
cd build
tile() { # name x y "label"
  local f="sprite-$1.png" x=$2 y=$3
  local cx=$(( (x / 8) * 8 - 16 )); [ $cx -lt 0 ] && cx=0
  local cy=$(( y - 12 )); [ $(( cy + 40 )) -gt 192 ] && cy=152
  # 64x40 Spectrum pixels (doubled by Fuse's 2x filter), enlarged 2x more
  convert "$f" -crop 128x80+$(( 64 + 2*cx ))+$(( 48 + 2*cy )) +repage -filter point -resize 200% /tmp/z.png
  local draw="" gx
  for gx in 0 32 64 96 128 160 192 224 256; do draw="$draw line $gx,0 $gx,159"; done
  convert /tmp/z.png -stroke red -strokewidth 1 -draw "$draw" /tmp/z_$1.png
  convert "$f" -resize 50% /tmp/f_$1.png
  convert /tmp/f_$1.png /tmp/z_$1.png -background black -gravity center -append \
     -background white -gravity north -splice 0x34 -pointsize 15 -fill black -annotate +0+3 "$4" /tmp/t_$1.png
}
tile 1-start     40 100 "1 start: x 40 (\$28, shift 0)  y 100"
tile 2-right-few 46 100 "2 right: x 46 (\$2E, shift 6)"
tile 3-seabed    46 167 "3 on seabed: y 167, mask shows pebbles"
tile 4-left-weed 33 167 "4 faced left: x 33 (\$21, shift 1)"
tile 5-back-up   33 136 "5 up over weed; seabed restored"
tile 6-anim-2    33 136 "6a tail frame: IMG 03 (left, frame 1)"
tile 6-anim-3    33 136 "6b tail frame: IMG 02 (left, frame 0)"
montage /tmp/t_1-start.png /tmp/t_2-right-few.png /tmp/t_3-seabed.png /tmp/t_4-left-weed.png \
        /tmp/t_5-back-up.png /tmp/t_6-anim-2.png /tmp/t_6-anim-3.png \
        -tile 4x -geometry +6+6 -background '#ddd' montage-sprites.png
echo "wrote build/montage-sprites.png"
