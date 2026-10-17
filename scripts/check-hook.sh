#!/bin/bash
# Check that the committed hook fits a Sailfish OS version's home screen, the way Patchmanager applies it:
#   1. the stock files give exactly the series' diff (patchmanager/diffs/SERIES.patch),
#   2. "patch -p1" applies it to a copy of them without fuzz or offsets,
#   3. qmllint (Qt 5) accepts the patched files,
#   4. patchmanager/versions lists the version (and patch.json, for a release).
# Usage: scripts/check-hook.sh [VERSION | BASE]
#   (none)   the phone's stock files (scripts/pull-base.sh)
#   VERSION  that release's, downloaded from Jolla (scripts/stock-base.sh): no phone needed
#   BASE     a directory pulled before
set -euo pipefail
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"

if [ $# -eq 0 ]; then
    base=$("$REPO_ROOT/scripts/pull-base.sh")
elif [ -d "$1" ]; then
    base=$(cd "$1" && pwd)
else
    base=$("$REPO_ROOT/scripts/stock-base.sh" "$1")
fi
os=$(cat "$base/OS_VERSION")
diff=$(diff_of "$os")
[ -f "$diff" ] || die "no ${diff#"$REPO_ROOT"/} for Sailfish OS $os (run: make hook VERSION=$os)"

python3 -I "$REPO_ROOT/hook/apply_hook.py" "$base" --check "$diff"
log "$os 1/4 the hook matches the stock files (${diff#"$REPO_ROOT"/})"

# GNU patch in the tool image, like Patchmanager's on the phone
tools_image
work=$OUT_DIR/check-hook/$os
rm -rf "$work"
mkdir -p "$work"
cp -R "$base/usr" "$work/"
cp "$diff" "$work/unified_diff.patch"
out=$(docker run --rm -v "$work:/w" -w /w "$TOOLS_IMAGE" patch -p1 --forward --no-backup-if-mismatch \
        -i unified_diff.patch 2>&1) || { echo "$out" >&2; die "patch failed"; }
if echo "$out" | grep -E -i "fuzz|offset|reject" >&2; then
    die "patch applied only with fuzz or offsets"
fi
log "$os 2/4 patch -p1 applies cleanly"

files=()
while IFS= read -r f; do files+=("$f"); done < <(python3 -I "$REPO_ROOT/hook/apply_hook.py" --files)
docker run --rm -v "$work:/w:ro" -w /w "$TOOLS_IMAGE" qmllint "${files[@]}"
log "$os 3/4 qmllint accepts the patched files"

channel=$(channel_of "$os")
[ -n "$channel" ] || die "patchmanager/versions does not list Sailfish OS $os (make hook adds it)"
if [ "$channel" = release ] && ! python3 -I -c 'import json, sys; sys.exit(sys.argv[2] not in json.load(open(sys.argv[1]))["compatible"])' \
        "$PATCH_DIR/patch.json" "$os"; then
    die "patch.json does not list Sailfish OS $os, a release version (make hook syncs it)"
fi
log "$os 4/4 listed as a $channel"
