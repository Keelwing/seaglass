#!/bin/bash
# Copy the package (make rpm) to the phone: ~/seaglass, for make install.
# shellcheck disable=SC2029  # remote paths are expanded on the phone on purpose
set -euo pipefail
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"

check_ssh
rpm=$(latest_rpm)
[ -n "$rpm" ] || die "no package in out/rpm (run: make rpm)"
log "copying $(basename "$rpm") to $SEAGLASS_SSH:~/$SEAGLASS_REMOTE_DIR"
ssh -o BatchMode=yes "$SEAGLASS_SSH" "mkdir -p ~/$SEAGLASS_REMOTE_DIR && rm -f ~/$SEAGLASS_REMOTE_DIR/seaglass-*.noarch.rpm"
# ssh + cat: scp (sftp) can stall on the phone
# shellcheck disable=SC2094  # the remote file only shares the name
ssh -o BatchMode=yes "$SEAGLASS_SSH" "cat > ~/$SEAGLASS_REMOTE_DIR/$(basename "$rpm")" < "$rpm"
# dependencies and file conflicts, without root and without installing
ssh -o BatchMode=yes "$SEAGLASS_SSH" "rpm -U --test ~/$SEAGLASS_REMOTE_DIR/$(basename "$rpm")" \
    && log "rpm -U --test: ok (next: make install)"
