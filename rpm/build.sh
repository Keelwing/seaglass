#!/bin/sh
# Stage the package tree and build the RPM. Runs in the tool image (scripts/rpm.sh), where /src is the
# repository (read-only) and /out receives seaglass-VERSION-RELEASE.noarch.rpm; or on any Linux host with
# rpmbuild:   SRC=. OUT=out/rpm sh rpm/build.sh
# CHANNEL=preview builds the testers' package: patch.json lists the preview versions of patchmanager/versions too,
# and its release (0.preview1) sorts before the final package of the same version.
set -eu

SRC=$(cd "${SRC:-/src}" && pwd)
OUT=${OUT:-/out}
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
VERSION=$(tr -d ' \n' < "$SRC/VERSION")
[ -n "$VERSION" ] || { echo "no VERSION" >&2; exit 1; }
grep -q "\"version\": \"$VERSION\"" "$SRC/patchmanager/patch.json" \
    || { echo "patchmanager/patch.json: version is not $VERSION" >&2; exit 1; }
ls "$SRC"/patchmanager/diffs/*.patch >/dev/null 2>&1 \
    || { echo "patchmanager/diffs/ has no hook (run: make hook)" >&2; exit 1; }
CHANNEL=${CHANNEL:-release}
case $CHANNEL in
    release) RELEASE=1 ;;
    preview) RELEASE=0.preview1 ;;
    *) echo "unknown CHANNEL: $CHANNEL" >&2; exit 1 ;;
esac

TOP=$(mktemp -d)
ROOT=$TOP/SOURCES/root
mkdir -p "$ROOT/usr/share/seaglass"

cp -R "$SRC/qml" "$ROOT/usr/share/seaglass/"
install -D -m 0644 "$SRC/patchmanager/patch.json" "$ROOT/usr/share/patchmanager/patches/seaglass/patch.json"
if [ "$CHANNEL" = preview ]; then
    python3 -I - "$ROOT/usr/share/patchmanager/patches/seaglass/patch.json" "$SRC/patchmanager/versions" <<'PY'
import json, sys
path, versions = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as f:
    meta = json.load(f)
for line in open(versions, encoding="utf-8"):
    words = line.split("#")[0].split()
    if len(words) == 2 and words[1] == "preview" and words[0] not in meta["compatible"]:
        meta["compatible"].append(words[0])
with open(path, "w", encoding="utf-8") as f:
    json.dump(meta, f, indent=4, ensure_ascii=False)
    f.write("\n")
PY
fi
# one hook per Sailfish OS series: %post puts the phone's in the patch's folder as unified_diff.patch
mkdir -p "$ROOT/usr/share/seaglass/diffs"
install -m 0644 "$SRC"/patchmanager/diffs/*.patch "$ROOT/usr/share/seaglass/diffs/"
: > "$ROOT/usr/share/patchmanager/patches/seaglass/unified_diff.patch"
# the patch's settings page (Patchmanager pushes it when the patch is tapped)
install -D -m 0644 "$SRC/patchmanager/main.qml" "$ROOT/usr/share/patchmanager/patches/seaglass/main.qml"
# its icon in the list of patches: main.svg under a dark ambience, main-light.svg under a light one
install -m 0644 "$SRC/patchmanager/main.svg" "$SRC/patchmanager/main-light.svg" \
    "$ROOT/usr/share/patchmanager/patches/seaglass/"
install -D -m 0644 "$SRC/README.md" "$ROOT/usr/share/doc/seaglass/README.md"
install -D -m 0644 "$SRC/CHANGELOG.md" "$ROOT/usr/share/doc/seaglass/CHANGELOG.md"
# the settings' What's new reads it next to the QML (documentation may not be installed)
install -m 0644 "$SRC/CHANGELOG.md" "$ROOT/usr/share/seaglass/CHANGELOG.md"
install -D -m 0644 "$SRC/LICENSE" "$ROOT/usr/share/licenses/seaglass/LICENSE"
find "$ROOT" -name .DS_Store -delete
find "$ROOT" -type d -exec chmod 0755 {} +
find "$ROOT" -type f -exec chmod 0644 {} +

rpmbuild -bb --quiet --target noarch --define "_topdir $TOP" --define "seaglass_version $VERSION" \
    --define "seaglass_release $RELEASE" \
    "$SRC/rpm/seaglass.spec"
# the other channel's package stays
rm -f "$OUT"/seaglass-*-"$RELEASE".noarch.rpm
cp "$TOP/RPMS/noarch/seaglass-$VERSION-$RELEASE.noarch.rpm" "$OUT/"
chown "$(stat -c %u:%g "$OUT")" "$OUT/seaglass-$VERSION-$RELEASE.noarch.rpm"
rm -rf "$TOP"
echo "seaglass-$VERSION-$RELEASE.noarch.rpm"
