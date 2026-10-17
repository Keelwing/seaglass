# shellcheck shell=bash
# Shared settings for the host-side (macOS/Linux) scripts.

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
OUT_DIR=${OUT_DIR:-$REPO_ROOT/out}

# SSH target for the phone (an ~/.ssh/config alias with key login)
SEAGLASS_SSH=${SEAGLASS_SSH:-jolla}
# Working directory on the phone (device user's home): packages, the harness
SEAGLASS_REMOTE_DIR=${SEAGLASS_REMOTE_DIR:-seaglass}
TOOLS_IMAGE=${TOOLS_IMAGE:-seaglass-tools:dev}
# the GitHub workflows' linter (make lint)
ACTIONLINT_IMAGE=${ACTIONLINT_IMAGE:-rhysd/actionlint:1.7.12}

# The Patchmanager patch (patchmanager/): scripts/hook.sh, scripts/check-hook.sh
# shellcheck disable=SC2034
PATCH_DIR=$REPO_ROOT/patchmanager

# patchmanager/versions: the versions the hook is made for ("VERSION CHANNEL"), all or one channel's
versions() { sed -e 's/#.*//' "$PATCH_DIR/versions" | awk -v c="${1:-}" 'NF == 2 && (c == "" || $2 == c) { print $1 }'; }
channel_of() { sed -e 's/#.*//' "$PATCH_DIR/versions" | awk -v v="$1" '$1 == v { print $2 }'; }
# the hook of a version's series (5.2.0.20 -> patchmanager/diffs/5.2.patch)
diff_of() { echo "$PATCH_DIR/diffs/$(echo "$1" | cut -d. -f1,2).patch"; }

# patch.json's "compatible" list: the release versions, newest first
sync_compatible() {
    python3 -I - "$PATCH_DIR/patch.json" "$(versions release | tr '\n' ' ')" <<'PY'
import json, sys
path, listed = sys.argv[1], sys.argv[2].split()
with open(path, encoding="utf-8") as f:
    meta = json.load(f)
meta["compatible"] = sorted(listed, key=lambda v: [int(p) for p in v.split(".")], reverse=True)
with open(path, "w", encoding="utf-8") as f:
    json.dump(meta, f, indent=4, ensure_ascii=False)
    f.write("\n")
PY
}

# One SSH connection for all the calls of a script and the next ones for ten minutes: fewer connections, and an
# open one keeps working when the Mac runs out of local ports (docs/DEVELOPMENT.md). The socket path must stay short.
ssh() {
    command ssh -o ControlMaster=auto -o ControlPath="/tmp/seaglass-%C" -o ControlPersist=600 "$@"
}

log() { printf '%s: %s\n' "$(basename "$0")" "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

check_ssh() {
    ssh -o BatchMode=yes -o ConnectTimeout=5 "$SEAGLASS_SSH" true 2>/dev/null \
        || die "cannot reach '$SEAGLASS_SSH' over SSH with a key (set SEAGLASS_SSH, or add an ~/.ssh/config alias)"
}

version() { tr -d ' \n' < "$REPO_ROOT/VERSION"; }

# The Sailfish OS version of the phone, e.g. 5.2.0.20
phone_os_version() {
    ssh -o BatchMode=yes "$SEAGLASS_SSH" 'sed -n "s/^VERSION_ID=//p" /etc/os-release' | tr -d '"\r'
}

# The tool image (rpmbuild, qmllint for Qt 5, shellcheck). Built again only when docker/Dockerfile changes (its
# hash is a label of the image): a build asks the registry even with everything cached, and works offline so
file_sha() { shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1 || sha256sum "$1" | cut -d' ' -f1; }
tools_image() {
    command -v docker >/dev/null || die "docker not found"
    docker info >/dev/null 2>&1 || die "docker daemon is not running"
    local sum
    sum=$(file_sha "$REPO_ROOT/docker/Dockerfile")
    [ "$(docker image inspect -f '{{ index .Config.Labels "seaglass.dockerfile" }}' "$TOOLS_IMAGE" 2>/dev/null)" = "$sum" ] \
        && return 0
    docker buildx build --load -q --label "seaglass.dockerfile=$sum" -t "$TOOLS_IMAGE" "$REPO_ROOT/docker" >/dev/null
}

# the newest package of the channel (CHANNEL=preview: the testers')
latest_rpm() {
    local release=1
    [ "${CHANNEL:-release}" = preview ] && release=0.preview1
    # shellcheck disable=SC2012  # our own predictable file names
    ls -t "$OUT_DIR"/rpm/seaglass-*-"$release".noarch.rpm 2>/dev/null | head -1
}
