#!/bin/bash
# The home screen's messages of this boot (QML warnings and errors, seaglass's own lines), from the
# journal, which needs root on the phone: asks for the developer-mode password (devel-su). Saves them to
# out/journal.txt and prints the last lines.
# Usage: scripts/journal.sh [LINES]     (make journal; default 80 lines printed)
set -euo pipefail
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"

lines=${1:-80}
case $lines in ''|*[!0-9]*) die "invalid line count: $lines" ;; esac

check_ssh
# into the device user's home: root's file there can be removed by the user (in /tmp it could not)
# shellcheck disable=SC2016  # expanded on the phone
ssh -t "$SEAGLASS_SSH" 'devel-su sh -c "journalctl -b --no-pager -o short-precise \
    | grep -E \"lipstick|seaglass|\\.qml\" > $HOME/.seaglass-journal.txt; chmod 0644 $HOME/.seaglass-journal.txt"'
mkdir -p "$OUT_DIR"
ssh -o BatchMode=yes "$SEAGLASS_SSH" 'cat ~/.seaglass-journal.txt && rm -f ~/.seaglass-journal.txt' > "$OUT_DIR/journal.txt"
log "$(wc -l < "$OUT_DIR/journal.txt") lines in ${OUT_DIR#"$REPO_ROOT"/}/journal.txt"
tail -n "$lines" "$OUT_DIR/journal.txt"
