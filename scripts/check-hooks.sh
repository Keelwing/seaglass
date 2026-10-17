#!/bin/bash
# Check the hook against every Sailfish OS version in patchmanager/versions, with each release's stock files
# downloaded from Jolla (scripts/stock-base.sh). No phone needed: CI runs this.
# Usage: scripts/check-hooks.sh     (make check-hooks)
set -euo pipefail
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"

count=0
for version in $(versions); do
    "$REPO_ROOT/scripts/check-hook.sh" "$version"
    count=$((count + 1))
done
log "the hook fits all $count versions"
