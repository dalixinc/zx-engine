#!/bin/sh
# tools/webstamp.sh - make web: stamp each file's hash into
# docs/play/index.html, so a browser fetches a new build at once instead
# of keeping the last one for GitHub Pages' ten minutes. The snapshot's
# address ends in &type=.sna because JSSpeccy picks a file's type by how
# the whole address ends (docs/WEB.md). tools/webstamp.ps1 is the same
# for build.bat.
set -e
sna=$(sha1sum build/atlantis.sna | cut -c1-8)
tap=$(sha1sum build/atlantis.tap | cut -c1-8)
page=docs/play/index.html
sed -i -E \
    -e "s/'atlantis\.sna(\?v=[0-9a-f]+&type=\.sna)?'/'atlantis.sna?v=${sna}\&type=.sna'/" \
    -e "s/href=\"atlantis\.tap(\?v=[0-9a-f]+)?\"/href=\"atlantis.tap?v=${tap}\"/" \
    "$page"
echo "$page: atlantis.sna v=$sna, atlantis.tap v=$tap"
