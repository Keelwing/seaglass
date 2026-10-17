#!/bin/bash
# Compile every QML file of qml/ and the settings page with an older Sailfish OS's own Qt 5.6 and Silica: the
# Sailfish SDK's build target of that release (a rootfs, about 200 MB, from releases.sailfishos.org), imported as a
# Docker image, with qmlscene and the modules the home screen has added from Jolla's release repository. A file
# that does not parse, imports something the release lacks, or sets a property a type does not have, fails.
# Three modules only the running home screen or the Store provides get stubs (tests/qml-check/stubs).
# The image is built once per release and machine: i486 on x86, aarch64 on arm (both run natively).
# Usage: scripts/qml-check.sh [TARGET...]     (make qml-check; TARGET: an SDK target release, e.g. 5.1.0.11)
set -euo pipefail
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"

# the SDK targets Jolla publishes, one per older series (there is no 5.2 target yet)
targets=("$@")
[ ${#targets[@]} -gt 0 ] || targets=(5.1.0.11 5.0.0.62)
case $(uname -m) in
    arm64|aarch64) arch=aarch64 platform=linux/arm64 ;;
    *) arch=i486 platform=linux/386 ;;
esac
command -v docker >/dev/null || die "docker not found"
seven=$(command -v 7zz || command -v 7z || true)

image_for() {
    local target=$1 image=sfos-qml:$1-$arch
    if docker image inspect "$image" >/dev/null 2>&1; then
        echo "$image"
        return
    fi
    [ -n "$seven" ] || die "7z (p7zip) not found: it unpacks the SDK target"
    local dir=$OUT_DIR/sdk/$target name=Sailfish_OS-$target-Sailfish_SDK_Target-$arch.tar.7z
    local url=https://releases.sailfishos.org/sdk/targets/$name
    mkdir -p "$dir"
    if [ ! -s "$dir/$name" ]; then
        log "downloading the Sailfish OS $target SDK target ($arch)"
        curl -fsSL -o "$dir/$name.tmp" "$url" && mv "$dir/$name.tmp" "$dir/$name"
        curl -fsSL -o "$dir/$name.md5sum" "$url.md5sum"
    fi
    local want have
    want=$(cut -d' ' -f1 "$dir/$name.md5sum")
    have=$( (md5sum "$dir/$name" 2>/dev/null || md5 -r "$dir/$name") | cut -d' ' -f1)
    [ "$want" = "$have" ] || die "$name: the md5 does not match"
    "$seven" e -so "$dir/$name" 2>/dev/null | docker import --platform "$platform" - "sfos-target:$target-$arch" >/dev/null
    docker rm -f "sfos-qml-build" >/dev/null 2>&1 || true
    docker run --name sfos-qml-build --platform "$platform" "sfos-target:$target-$arch" /bin/sh -euc '
        rm -f /etc/zypp/repos.d/*.repo
        zypper -q ar -G "https://releases.jolla.com/releases/$1/jolla/$2/" jolla
        zypper -q --non-interactive in -y qt5-qtdeclarative-qmlscene qt5-plugin-platform-offscreen \
            lipstick-jolla-home-qt5-components nemo-qml-plugin-alarms-qt5 nemo-qml-plugin-calendar-qt5-lightweight
        zypper -q clean -a
    ' sh "$target" "$arch" >/dev/null
    docker commit sfos-qml-build "$image" >/dev/null
    docker rm sfos-qml-build >/dev/null
    docker rmi "sfos-target:$target-$arch" >/dev/null
    log "image $image"
    echo "$image"
}

files=$(mktemp -d)
trap 'rm -rf "$files"' EXIT
(cd "$REPO_ROOT/qml" && find . -name '*.qml' | sort | sed 's|^\./|/usr/share/seaglass/qml/|') > "$files/files.txt"
echo /usr/share/patchmanager/patches/seaglass/main.qml >> "$files/files.txt"
cp "$REPO_ROOT/tests/qml-check/check.qml" "$files/"

failed=0
for target in "${targets[@]}"; do
    image=$(image_for "$target")
    out=$(docker run --rm --platform "$platform" \
        -v "$REPO_ROOT/qml:/usr/share/seaglass/qml:ro" \
        -v "$REPO_ROOT/patchmanager:/usr/share/patchmanager/patches/seaglass:ro" \
        -v "$REPO_ROOT/tests/qml-check/stubs:/stubs:ro" -v "$files:/check:ro" \
        -e QT_QPA_PLATFORM=offscreen -e QT_LOGGING_TO_CONSOLE=1 -e QML2_IMPORT_PATH=/stubs -e XDG_RUNTIME_DIR=/tmp \
        "$image" /bin/sh -c 'exec 2>/dev/null; qmlscene /check/check.qml > /tmp/out 2>&1; cat /tmp/out')
    # qmlscene aborts once the check is done (no OpenGL for its window): the check's own lines tell
    summary=$(echo "$out" | sed -n 's/.*qml-check: \([0-9]* files, [0-9]* failed\)/\1/p')
    [ -n "$summary" ] || { echo "$out" >&2; die "Sailfish OS $target: the check did not run"; }
    echo "$out" | sed -n 's|.*qml-check: FAIL /usr/share/seaglass/qml/|FAIL |p; s|.*qml-check: FAIL |FAIL |p' >&2
    log "Sailfish OS $target ($arch): $summary"
    case $summary in *" 0 failed") ;; *) failed=1 ;; esac
done
[ "$failed" = 0 ] || die "QML that does not compile on an older Sailfish OS (see above)"
