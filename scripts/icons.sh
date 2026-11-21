#!/bin/bash
# Render the colour icon (icons/seaglass.svg) for the releases, out/icons/seaglass-200.png (200 x 200), and the GitHub
# preview (icons/social.svg, rendered by scripts/social.sh), out/icons/seaglass-social.png (1280 x 640, uploaded by
# hand in the repository's settings). The Patchmanager glyphs are installed as SVG and need no rendering.
# Usage: scripts/icons.sh     (make icons)
set -euo pipefail
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"

tools_image
mkdir -p "$OUT_DIR/icons"
docker run --rm -v "$REPO_ROOT:/src:ro" -v "$OUT_DIR/icons:/out" "$TOOLS_IMAGE" sh -euc '
    rsvg-convert -w 200 -h 200 -o /out/seaglass-200.png /src/icons/seaglass.svg
    sh /src/scripts/social.sh /src /out/seaglass-social.png
    chown "$(stat -c %u:%g /out)" /out/seaglass-200.png /out/seaglass-social.png
'
log "icons: ${OUT_DIR#"$REPO_ROOT"/}/icons/seaglass-200.png, seaglass-social.png"
