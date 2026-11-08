#!/bin/sh
# tools/webstamp.sh - make web: stamp each file's hash into
# docs/play/index.html, so a browser fetches a new build at once instead
# of keeping the last one for GitHub Pages' ten minutes. The snapshot's
# address ends in &type=.sna because JSSpeccy picks a file's type by how
# the whole address ends (docs/WEB.md). tools/webstamp.ps1 is the same
# for build.bat.
#
# Arguments: the game's name and its page's folder, atlantis and
# docs/play when left out; make web runs it again with trigon and
# docs/play/trigon.
set -e
name=${1:-atlantis}
dir=${2:-docs/play}
sna=$(sha1sum $dir/$name.sna | cut -c1-8)
tap=$(sha1sum $dir/$name.tap | cut -c1-8)
page=$dir/index.html
sed -i -E \
    -e "s/'$name\.sna(\?v=[0-9a-f]+&type=\.sna)?'/'$name.sna?v=${sna}\&type=.sna'/" \
    -e "s/href=\"$name\.tap(\?v=[0-9a-f]+)?\"/href=\"$name.tap?v=${tap}\"/" \
    "$page"
echo "$page: $name.sna v=$sna, $name.tap v=$tap"
