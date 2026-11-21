#!/bin/sh
# Render the preview picture (icons/social.svg, 1280 x 640) to a PNG, in the tool image: the picture is drawn next to
# the images it shows, with the site's Albert Sans made known to fontconfig. scripts/icons.sh makes the one for the
# repository's settings with it, scripts/site.sh the one the site's pages name for link previews.
# Usage: sh scripts/social.sh REPO PNG
set -eu
repo=$1
work=$(mktemp -d)
cp "$repo/icons/social.svg" "$repo/icons/seaglass.svg" "$repo/docs/images/widgets.jpg" "$repo/docs/images/switcher.jpg" \
    "$work/"
mkdir -p /usr/local/share/fonts
python3 -I -c 'import sys
from fontTools.ttLib import TTFont
font = TTFont(sys.argv[1] + "/site/assets/fonts/albert-sans-latin-wght-normal.woff2")
font.flavor = None
font.save("/usr/local/share/fonts/AlbertSans.ttf")' "$repo"
fc-cache -f >/dev/null
rsvg-convert -w 1280 -h 640 -o "$2" "$work/social.svg"
rm -rf "$work"
