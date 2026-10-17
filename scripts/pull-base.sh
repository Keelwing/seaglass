#!/bin/bash
# Copy the stock home screen files the hook changes from the phone into out/base/OSVERSION (read-only on the
# phone). They are Jolla's proprietary files: out/ is never committed. Prints the base directory.
# Usage: scripts/pull-base.sh
set -euo pipefail
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"

check_ssh
os=$(phone_os_version)
case $os in ''|*[!0-9.]*) die "unexpected Sailfish OS version: '$os'" ;; esac
base=$OUT_DIR/base/$os
files=()
while IFS= read -r f; do files+=("$f"); done < <(python3 -I "$REPO_ROOT/hook/apply_hook.py" --files)

rm -rf "$base.tmp"
mkdir -p "$base.tmp"
# NO_PM_PRELOAD: Patchmanager's preload shows every process the patched files, tar included
# shellcheck disable=SC2029  # the file list is expanded here on purpose
ssh -o BatchMode=yes "$SEAGLASS_SSH" "cd / && NO_PM_PRELOAD=1 tar cf - ${files[*]}" | tar -C "$base.tmp" -xf -
for f in "${files[@]}"; do
    if grep -q seaglass "$base.tmp/$f"; then
        rm -rf "$base.tmp"
        die "$f came patched (Patchmanager's preload ignored NO_PM_PRELOAD?)"
    fi
done
ssh -o BatchMode=yes "$SEAGLASS_SSH" 'rpm -q lipstick-jolla-home-qt5' > "$base.tmp/PACKAGE"
echo "$os" > "$base.tmp/OS_VERSION"
rm -rf "$base"
mv "$base.tmp" "$base"
ln -sfn "$os" "$OUT_DIR/base/current"
log "stock files of Sailfish OS $os ($(cat "$base/PACKAGE")) in ${base#"$REPO_ROOT"/}"
echo "$base"
