#!/bin/bash
# Assemble a release in out/release/TAG: the package, the OpenRepos icon, SHA256SUMS and the release notes (the
# version's section of CHANGELOG.md). When patchmanager/versions has preview versions, the testers' package
# (-0.preview1, those versions in its patch.json) comes along, with a word in the notes. With --publish, put it on
# GitHub with gh: a draft with every asset first, published once they are all up; an existing release gets its notes
# and assets replaced. The release workflow
# (.github/workflows/release.yml) runs this on a pushed tag.
# Usage: scripts/release.sh [TAG] [--publish]     (make release; TAG: vVERSION by default)
set -euo pipefail
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"

tag=
publish=0
for arg in "$@"; do
    case $arg in
        --publish) publish=1 ;;
        v[0-9]*) tag=$arg ;;
        *) die "unknown argument: $arg" ;;
    esac
done
version=$(version)
tag=${tag:-v$version}

# The tag, VERSION, patch.json and both changelogs name the same version
[ "$tag" = "v$version" ] || die "the tag $tag is not VERSION's v$version"
grep -q "\"version\": \"$version\"" "$REPO_ROOT/patchmanager/patch.json" \
    || die "patchmanager/patch.json: the version is not $version"
grep -q "^## $version (" "$REPO_ROOT/CHANGELOG.md" || die "CHANGELOG.md has no section for $version"
grep -q -- "- $version-1\$" "$REPO_ROOT/rpm/seaglass.spec" \
    || die "rpm/seaglass.spec: %changelog has no entry for $version-1"
if [ "$publish" = 1 ]; then
    # the assets are built from this tree: it must be the tag's
    [ "$(git -C "$REPO_ROOT" rev-parse "$tag^{commit}" 2>/dev/null)" = "$(git -C "$REPO_ROOT" rev-parse HEAD)" ] \
        || die "HEAD is not the tag $tag (check it out first)"
    [ -z "$(git -C "$REPO_ROOT" status --porcelain)" ] || die "the working tree has changes"
    command -v gh >/dev/null || die "gh not found"
fi

CHANNEL=release "$REPO_ROOT/scripts/rpm.sh"
"$REPO_ROOT/scripts/icons.sh"
rpm=$OUT_DIR/rpm/seaglass-$version-1.noarch.rpm
[ -s "$rpm" ] || die "no ${rpm#"$REPO_ROOT"/}"
preview_versions=$(versions preview | tr '\n' ' ' | sed 's/ $//; s/ / and /g')
preview=
if [ -n "$preview_versions" ]; then
    CHANNEL=preview "$REPO_ROOT/scripts/rpm.sh"
    preview=$OUT_DIR/rpm/seaglass-$version-0.preview1.noarch.rpm
    [ -s "$preview" ] || die "no ${preview#"$REPO_ROOT"/}"
fi

dir=$OUT_DIR/release/$tag
rm -rf "${dir:?}"
mkdir -p "$dir"
cp "$rpm" "$OUT_DIR/icons/seaglass-200.png" "$dir/"
assets=("$(basename "$rpm")" seaglass-200.png)
if [ -n "$preview" ]; then
    cp "$preview" "$dir/"
    assets+=("$(basename "$preview")")
fi
(cd "$dir" && for f in "${assets[@]}"; do printf '%s  %s\n' "$(file_sha "$f")" "$f"; done) > "$dir/SHA256SUMS"
assets+=(SHA256SUMS)

# The notes: what Seaglass is, the version's changes, how to install it
compatible=$(python3 -I -c 'import json, sys; print(" or ".join(json.load(open(sys.argv[1]))["compatible"]))' \
    "$REPO_ROOT/patchmanager/patch.json")
{
    echo "Home screen extensions for Sailfish OS: folder previews, group and data widgets, folder motion, glass, app"
    echo "search, notification badges, a richer task switcher and app animations. Every part is a setting, and the"
    echo "stock home screen stays whenever Seaglass cannot load."
    echo
    echo "## What's new in $version"
    echo
    # the section's lines, without the blank lines around them
    awk -v head="## $version (" '
        index($0, head) == 1 { on = 1; next }
        on && /^## / { exit }
        on && $0 == "" { blank++; next }
        on { if (started) while (blank-- > 0) print ""; blank = 0; started = 1; print }
    ' "$REPO_ROOT/CHANGELOG.md"
    echo
    echo "All changes: [CHANGELOG.md](https://github.com/Keelwing/seaglass/blob/$tag/CHANGELOG.md)."
    echo
    echo "## Install"
    echo
    echo "Requirements: Sailfish OS $compatible, and Patchmanager 3.2 or newer."
    echo
    echo "1. Download \`$(basename "$rpm")\` below, and install it:"
    echo "   \`devel-su pkcon install-local $(basename "$rpm")\`"
    echo "2. Open *Settings → Patchmanager*, activate *Seaglass*, and let Patchmanager restart the home screen."
    echo "3. Tap *Seaglass* in Patchmanager for its settings."
    echo
    echo "To remove it: \`devel-su rpm -e seaglass\` (this deactivates the patch first)."
    echo
    if [ -n "$preview" ]; then
        echo "## For testers on older Sailfish OS"
        echo
        echo "\`$(basename "$preview")\` is the same version for Sailfish OS $preview_versions. Its hook is checked"
        echo "against those releases' home screen files, and its QML compiles with their Qt and Silica, but it has not"
        echo "run on such a phone yet. If you try it, please say how it went, with the *Older Sailfish OS* issue"
        echo "form."
        echo
    fi
    echo "SHA-256 checksums are in \`SHA256SUMS\`."
} > "$dir/notes.md"
log "release $tag: ${dir#"$REPO_ROOT"/} (${assets[*]}, notes.md)"

[ "$publish" = 1 ] || exit 0
title="Seaglass $version"
paths=()
for f in "${assets[@]}"; do paths+=("$dir/$f"); done
if gh release view "$tag" >/dev/null 2>&1; then
    log "release $tag exists: replacing its notes and assets"
    gh release upload "$tag" "${paths[@]}" --clobber
    gh release edit "$tag" --title "$title" --notes-file "$dir/notes.md" --draft=false
else
    gh release create "$tag" "${paths[@]}" --verify-tag --draft --title "$title" --notes-file "$dir/notes.md"
    gh release edit "$tag" --draft=false
fi
log "published: $(gh release view "$tag" --json url --jq .url)"
