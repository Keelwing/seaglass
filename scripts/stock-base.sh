#!/bin/bash
# The stock files the hook changes, for a Sailfish OS release, without a phone: downloaded from Jolla's public
# release repository (scripts/stock.py) and unpacked into out/compat/VERSION/base, once. They are Jolla's files:
# out/ is never committed, and CI never uploads them. Prints the base directory.
# Usage: scripts/stock-base.sh VERSION
set -euo pipefail
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"

version=${1:?a Sailfish OS version, e.g. 5.1.0.11}
case $version in *[!0-9.]*|'') die "not a Sailfish OS version: $version" ;; esac
dir=$OUT_DIR/compat/$version
base=$dir/base
files=()
while IFS= read -r f; do files+=("./$f"); done < <(python3 -I "$REPO_ROOT/hook/apply_hook.py" --files)
complete=1
for f in "${files[@]}"; do [ -f "$base/$f" ] || complete=; done
# a base made before the hook changed more files is unpacked again
if [ ! -f "$base/OS_VERSION" ] || [ -z "$complete" ]; then
    tools_image
    rm -rf "${dir:?}"
    mkdir -p "$base"
    docker run --rm -v "$REPO_ROOT:/src:ro" -v "$dir:/out" "$TOOLS_IMAGE" sh -euc '
        python3 -I /src/scripts/stock.py "$1" /out >/dev/null
        shift
        bsdtar -xf /out/lipstick.rpm -C /out/base "$@"
        chown -R "$(stat -c %u:%g /out)" /out
    ' sh "$version" "${files[@]}"
    cp "$dir/PACKAGE" "$base/PACKAGE"
    echo "$version" > "$base/OS_VERSION"
    log "stock files of Sailfish OS $version ($(cat "$base/PACKAGE")) in ${base#"$REPO_ROOT"/}"
fi
echo "$base"
