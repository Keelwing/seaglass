#!/bin/bash
# Render the colour icon (icons/seaglass.svg) for the releases, out/icons/seaglass-200.png (200 x 200), and the GitHub
# preview (icons/social.svg), out/icons/seaglass-social.png (1280 x 640, uploaded by hand in the repository's
# settings), with the site's Albert Sans. The Patchmanager glyphs are installed as SVG and need no rendering.
# Usage: scripts/icons.sh     (make icons)
set -euo pipefail
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"

tools_image
mkdir -p "$OUT_DIR/icons"
docker run --rm -v "$REPO_ROOT:/src:ro" -v "$OUT_DIR/icons:/out" "$TOOLS_IMAGE" sh -euc '
    rsvg-convert -w 200 -h 200 -o /out/seaglass-200.png /src/icons/seaglass.svg
    # the preview, next to the pictures it shows, with Albert Sans from the site made known to fontconfig
    work=$(mktemp -d)
    cp /src/icons/social.svg /src/icons/seaglass.svg /src/docs/images/widgets.jpg /src/docs/images/switcher.jpg "$work/"
    mkdir -p /usr/local/share/fonts
    python3 -I -c "from fontTools.ttLib import TTFont; f = TTFont(\"/src/site/assets/fonts/albert-sans-latin-wght-normal.woff2\"); f.flavor = None; f.save(\"/usr/local/share/fonts/AlbertSans.ttf\")"
    fc-cache -f >/dev/null
    rsvg-convert -w 1280 -h 640 -o /out/seaglass-social.png "$work/social.svg"
    chown "$(stat -c %u:%g /out)" /out/seaglass-200.png /out/seaglass-social.png
'
log "icons: ${OUT_DIR#"$REPO_ROOT"/}/icons/seaglass-200.png, seaglass-social.png"
