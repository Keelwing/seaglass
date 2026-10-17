#!/bin/bash
# Run the development harness (harness/harness.qml) on the phone as the device user: it draws the phone's
# launcher folders with qml/ from this tree, next to the stock look. No root, and the home screen is not
# touched: the harness reads a copy of ~/.config/lipstick, and the script checks that the real
# applications.menu did not change. The phone must be unlocked with the display on.
# Usage: scripts/harness.sh [--scene "NAME [ARGUMENT]"] [--shot NAME] [--grab SECS] [--frames NAME] [--picture PATH]
#        [--wait SECS] [--keep] [--own-apps] [--slow-animations]
#   --scene  folders (default), selector ["Android=panel"], controller ["AI=card,Android=panel,..."],
#            layout ["normal|edit AI=card@5,... drag=AI drop=Android"], motion ["zoom|spring|reveal|slide|fade
#            [nocascade] [nodepth] [from=TITLE] [card] [slow=8]"]
#            (harness/harness.qml)
#   --shot   copy the harness's own screenshot to out/shots/NAME.png
#   --grab   when the harness takes that screenshot, in seconds after the scene starts (default 2.5)
#   --frames the frames a scene grabbed (motion) to out/frames/NAME/, with their delay in centiseconds
#            (out/frames/NAME/delay), and a GIF of them to out/shots/NAME.gif; it waits up to 3 minutes past --wait
#            for the scene's run to end
#   --picture the wallpaper the scenes draw (a file on the phone); by default a stock ambience picture, never the
#            phone's own wallpaper, which may be private
#   --wait   seconds between the start and the screenshot (default 6)
#   --keep   leave the harness running (default: closed after the screenshot)
#   --own-apps  the phone's own apps and folders (a copy of its menu). By default the harness shows only the stock
#            apps, in made-up folders (Media, Office, Tools: harness/public-launcher.sh), so that whatever it draws
#            can be shared
#   --slow-animations  qmlscene's slow motion (every animation and Timer 5 times slower), for the film scene's frames
# Prints the harness's output (QML warnings included) at the end.
# shellcheck disable=SC2029  # remote commands are built here on purpose
set -euo pipefail
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"

scene=folders
picture=
frames=
shot=
wait=6
grab=
keep=0
public=1
slow=
while [ $# -gt 0 ]; do
    case $1 in
        --scene) scene=${2:?}; shift ;;
        --shot) shot=${2:?}; shift ;;
        --grab) grab=${2:?}; shift ;;
        --frames) frames=${2:?}; shift ;;
        --picture) picture=${2:?}; shift ;;
        --wait) wait=${2:?}; shift ;;
        --keep) keep=1 ;;
        --public) public=1 ;;
        --own-apps) public=0 ;;
        --slow-animations) slow=--slow-animations ;;
        *) die "unknown option: $1" ;;
    esac
    shift
done
case $shot$frames in *[!A-Za-z0-9._-]*) die "invalid name: $shot$frames" ;; esac
case $scene in *[!A-Za-z0-9\ ,=@._-]*) die "invalid scene: $scene" ;; esac
case $wait in ''|*[!0-9]*) die "invalid wait: $wait" ;; esac
case $grab in *[!0-9.]*) die "invalid grab: $grab" ;; esac
case $picture in *[!A-Za-z0-9/._-]*) die "invalid picture: $picture" ;; esac

check_ssh
dir=$SEAGLASS_REMOTE_DIR/harness
menu_sum() { ssh -o BatchMode=yes "$SEAGLASS_SSH" 'sha256sum ~/.config/lipstick/applications.menu' | cut -d' ' -f1; }
# "[q]" keeps the pattern from matching the remote shell that runs pkill
stop() { ssh -o BatchMode=yes "$SEAGLASS_SSH" "pkill -f '[q]mlscene .*$dir/harness/harness.qml' 2>/dev/null || true"; }

before=$(menu_sum)
stop
ssh -o BatchMode=yes "$SEAGLASS_SSH" "rm -rf ~/$dir && mkdir -p ~/$dir/config/lipstick \
    && cp -R ~/.config/lipstick/. ~/$dir/config/lipstick/ && ln -s ~/.config/dconf ~/$dir/config/dconf"
COPYFILE_DISABLE=1 tar --exclude="._*" --exclude=.DS_Store -C "$REPO_ROOT" -cf - qml harness \
    | ssh -o BatchMode=yes "$SEAGLASS_SSH" "tar -C ~/$dir -xf -"
# the public launcher replaces the copy of the phone's menu, and the data directories hide the phone's own apps
xdg=
if [ "$public" = 1 ]; then
    ssh -o BatchMode=yes "$SEAGLASS_SSH" "sh ~/$dir/harness/public-launcher.sh \$HOME/$dir"
    xdg="XDG_DATA_DIRS=\$HOME/$dir/public/data XDG_DATA_HOME=\$HOME/$dir/public/home"
fi
echo "$scene" | ssh -o BatchMode=yes "$SEAGLASS_SSH" "cat > ~/$dir/harness/scene && mkdir -p ~/$dir/harness/frames"
[ -z "$picture" ] || echo "$picture" | ssh -o BatchMode=yes "$SEAGLASS_SSH" "cat > ~/$dir/harness/picture"
[ -z "$grab" ] || echo "$grab" | ssh -o BatchMode=yes "$SEAGLASS_SSH" "cat > ~/$dir/harness/grab"
# the Patchmanager settings page, with the pages of this tree instead of the installed ones, and no D-Bus calls
sed -e 's|file:///usr/share/seaglass/qml/|../qml/|' -e 's|inHarness: false|inHarness: true|' \
    "$REPO_ROOT/patchmanager/main.qml" \
    | ssh -o BatchMode=yes "$SEAGLASS_SSH" "cat > ~/$dir/harness/SettingsPage.qml"
# never the phone's own wallpaper or photo in the glass page's preview: no ambience picture until the scene gives
# the stock one, and the stock picture instead of a photo set on the phone
ssh -o BatchMode=yes "$SEAGLASS_SSH" "sed -i \
    -e 's|property string ambienceFile: ambiencePicture.value|property string ambienceFile: \"\"|' \
    -e 's|property bool persistentGlass: true|property bool persistentGlass: false|' ~/$dir/qml/settings/GlassPage.qml"
# (...&): the subshell exits at once, so the SSH session does not wait for the harness
ssh -o BatchMode=yes "$SEAGLASS_SSH" "cd ~/$dir && ($xdg XDG_CONFIG_HOME=\$HOME/$dir/config QT_LOGGING_TO_CONSOLE=1 \
    nohup qmlscene $slow \$HOME/$dir/harness/harness.qml > harness.log 2>&1 < /dev/null &)"
sleep "$wait"
# a run that records frames ends with the "frames N delay D" line: wait for it
if [ -n "$frames" ]; then
    for _ in $(seq 60); do
        ssh -o BatchMode=yes "$SEAGLASS_SSH" "grep -q 'harness: frames [0-9]* delay' ~/$dir/harness.log" && break
        sleep 3
    done
fi

# The harness grabs its own window into harness.png (Lipstick's screenshot call needs the privileged group)
if [ -n "$shot" ]; then
    mkdir -p "$OUT_DIR/shots"
    # ssh + cat: scp (sftp) stalled on the phone
    if ssh -o BatchMode=yes "$SEAGLASS_SSH" "cat ~/$dir/harness/harness.png" > "$OUT_DIR/shots/$shot.png.tmp"; then
        mv "$OUT_DIR/shots/$shot.png.tmp" "$OUT_DIR/shots/$shot.png"
        log "screenshot: ${OUT_DIR#"$REPO_ROOT"/}/shots/$shot.png"
    else
        rm -f "$OUT_DIR/shots/$shot.png.tmp"
        log "no screenshot (is the display on and unlocked? see the output below)"
    fi
fi

if [ -n "$frames" ]; then
    rm -rf "$OUT_DIR/frames/$frames"
    mkdir -p "$OUT_DIR/frames/$frames" "$OUT_DIR/shots"
    ssh -o BatchMode=yes "$SEAGLASS_SSH" "cd ~/$dir/harness/frames && tar cf - ." | tar -C "$OUT_DIR/frames/$frames" -xf -
    count=$(find "$OUT_DIR/frames/$frames" -name 'f_*.jpg' | wc -l | tr -d ' ')
    # the frame delay the harness logged (the animation time between two grabs), in centiseconds
    delay=$(ssh -o BatchMode=yes "$SEAGLASS_SSH" "cat ~/$dir/harness.log" | sed -n 's/.*harness: frames [0-9]* delay \([0-9]*\).*/\1/p' | tail -1)
    case $delay in ''|*[!0-9]*) delay=2 ;; esac
    echo "$delay" > "$OUT_DIR/frames/$frames/delay"
    if [ "$count" -gt 0 ]; then
        tools_image
        docker run --rm -v "$OUT_DIR:/o" -w /o "$TOOLS_IMAGE" sh -c \
            "convert -delay $delay -loop 0 frames/$frames/f_*.jpg -resize 360x -colors 128 -layers Optimize shots/$frames.gif"
        log "$count frames, $delay cs each: ${OUT_DIR#"$REPO_ROOT"/}/shots/$frames.gif"
    else
        log "no frames (is the display on and unlocked?)"
    fi
fi

[ "$keep" = 1 ] || stop
# without the libhybris loader noise
ssh -o BatchMode=yes "$SEAGLASS_SSH" "cat ~/$dir/harness.log" \
    | grep -v -E 'libselinux|mali_kbase|MEMPROF|not accessible for the namespace|needed or dlopened' || true
[ "$(menu_sum)" = "$before" ] || die "the real applications.menu changed while the harness ran"
