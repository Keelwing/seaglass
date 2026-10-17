#!/bin/bash
# Why is (or isn't) the preview on the home screen? Read-only checks on the phone, in the order they matter:
# the package, Patchmanager's preload, the patch, the patched files, the home screen restart, the OS version.
# Usage: scripts/status.sh     (make status)
# shellcheck disable=SC2016  # the remote script expands its own variables
set -euo pipefail
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"

check_ssh
ssh -o BatchMode=yes "$SEAGLASS_SSH" sh -s <<'EOF'
ok() { echo "  ok    $*"; }
bad() { echo "  FIX   $*"; status=1; }
status=0
home=/usr/share/lipstick-jolla-home-qt5/launcher

if rpm -q seaglass >/dev/null 2>&1; then ok "package: $(rpm -q seaglass)"
else bad "package seaglass is not installed (make install)"; fi

if grep -q libpreloadpatchmanager /etc/ld.so.preload 2>/dev/null; then ok "Patchmanager's preload is in /etc/ld.so.preload"
else
    bad "Patchmanager's preload is missing from /etc/ld.so.preload (owned by $(rpm -qf /etc/ld.so.preload 2>/dev/null),"
    echo "        an OS update replaces it): no patch reaches the home screen. Put it back as root, then restart the"
    echo "        home screen:  devel-su sh -c \"sed -i '/libpreloadpatchmanager/ d' /etc/ld.so.preload;"
    echo "        echo /usr/lib64/libpreloadpatchmanager.so >> /etc/ld.so.preload\""
fi

applied=$(dbus-send --system --print-reply --dest=org.SfietKonstantin.patchmanager /org/SfietKonstantin/patchmanager \
    org.SfietKonstantin.patchmanager.isPatchApplied string:seaglass 2>/dev/null | sed -n 's/.*boolean //p')
if [ "$applied" = true ]; then ok "patch seaglass is active in Patchmanager"
else bad "patch seaglass is not active (Settings > Patchmanager)"; fi

patched=/tmp/patchmanager$home/LauncherGrid.qml
if grep -q seaglass "$patched" 2>/dev/null; then ok "Patchmanager's patched LauncherGrid.qml has the hook"
elif [ "$applied" = true ]; then bad "no patched LauncherGrid.qml in /tmp/patchmanager (deactivate and activate the patch)"; fi

started=$(date -d "$(systemctl --user show -p ActiveEnterTimestamp --value lipstick | cut -d' ' -f2-3)" +%s 2>/dev/null || echo 0)
if [ -f "$patched" ] && [ "$started" -gt 0 ]; then
    if [ "$started" -ge "$(stat -c %Y "$patched")" ]; then ok "the home screen started after the patch was applied"
    else bad "the home screen runs since before the patch was applied: restart it (Patchmanager offers it)"; fi
fi

os=$(sed -n 's/^VERSION_ID=//p' /etc/os-release | tr -d '"')
if grep -q "\"$os\"" /usr/share/patchmanager/patches/seaglass/patch.json 2>/dev/null; then
    ok "Sailfish OS $os is in patch.json's compatible list"
else bad "Sailfish OS $os is not in patch.json's compatible list (make check-hook, make hook)"; fi
exit $status
EOF
