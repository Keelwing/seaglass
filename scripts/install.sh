#!/bin/bash
# Install (or remove) the package on the phone: asks for the developer-mode password (devel-su).
# Usage: scripts/install.sh [--remove]
# shellcheck disable=SC2029  # "~" is expanded by the remote shell
set -euo pipefail
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"

check_ssh
if [ "${1:-}" = --remove ]; then
    exec ssh -t "$SEAGLASS_SSH" "devel-su rpm -e seaglass"
fi
[ $# -eq 0 ] || die "unknown option: $1"

rpm=$(latest_rpm)
[ -n "$rpm" ] || die "no package in out/rpm (run: make rpm)"
name=$(basename "$rpm")
ssh -o BatchMode=yes "$SEAGLASS_SSH" "test -r ~/$SEAGLASS_REMOTE_DIR/$name" || die "$name is not on the phone (run: make deploy)"
exec ssh -t "$SEAGLASS_SSH" "devel-su rpm -U --replacepkgs ~/$SEAGLASS_REMOTE_DIR/$name"
