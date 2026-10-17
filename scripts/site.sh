#!/bin/bash
# Build the GitHub Pages site into out/site (scripts/site.py in the tool image): the landing page, the docs from the
# repository's Markdown, the images and the icon. The pages workflow (.github/workflows/pages.yml) publishes it.
# Usage: scripts/site.sh     (make site)
set -euo pipefail
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"

tools_image
mkdir -p "$OUT_DIR/site"
docker run --rm -v "$REPO_ROOT:/src:ro" -v "$OUT_DIR/site:/out" "$TOOLS_IMAGE" sh -euc '
    python3 -I /src/scripts/site.py /src /out
    chown -R "$(stat -c %u:%g /out)" /out
'
log "site: ${OUT_DIR#"$REPO_ROOT"/}/site/index.html"
