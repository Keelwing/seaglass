#!/bin/bash
# Build the package in the tool image: a noarch RPM with the QML and the Patchmanager patch. No Sailfish SDK
# needed. Output: out/rpm/seaglass-VERSION-1.noarch.rpm (CHANNEL=preview: the testers' package, -0.preview1)
set -euo pipefail
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"

tools_image
mkdir -p "$OUT_DIR/rpm"
channel=${CHANNEL:-release}
log "building seaglass $(version) ($channel)"
name=$(docker run --rm -e CHANNEL="$channel" -v "$REPO_ROOT:/src:ro" -v "$OUT_DIR/rpm:/out" "$TOOLS_IMAGE" \
    sh /src/rpm/build.sh)
rpm=$OUT_DIR/rpm/$name
log "package: ${rpm#"$REPO_ROOT"/} ($(du -h "$rpm" | cut -f1))"
