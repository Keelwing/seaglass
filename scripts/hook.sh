#!/bin/bash
# Generate the Patchmanager hook of a Sailfish OS series (patchmanager/diffs/SERIES.patch) with hook/apply_hook.py:
# from the phone's stock files, or with a VERSION from that release's, downloaded (no phone). A new version goes into
# patchmanager/versions: as a release when it came from the phone, as a preview otherwise. patch.json's
# "compatible" list follows the release versions.
# Usage: scripts/hook.sh [VERSION]     (make hook [VERSION=5.1.0.11])
set -euo pipefail
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"

if [ $# -gt 0 ]; then
    base=$("$REPO_ROOT/scripts/stock-base.sh" "$1")
    channel=preview
else
    base=$("$REPO_ROOT/scripts/pull-base.sh")
    channel=release
fi
os=$(cat "$base/OS_VERSION")
diff=$(diff_of "$os")
mkdir -p "$(dirname "$diff")"
python3 -I "$REPO_ROOT/hook/apply_hook.py" "$base" > "$diff.tmp" \
    || { rm -f "$diff.tmp"; die "the hook does not fit Sailfish OS $os (see above)"; }
mv "$diff.tmp" "$diff"
if [ -z "$(channel_of "$os")" ]; then
    echo "$os $channel" >> "$PATCH_DIR/versions"
    log "added Sailfish OS $os to patchmanager/versions as a $channel"
fi
sync_compatible
log "hook for Sailfish OS $os: ${diff#"$REPO_ROOT"/} ($(grep -c '^+[^+]' "$diff") added lines)"
log "next: make check-hooks (every version), then make rpm"
