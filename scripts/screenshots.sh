#!/bin/bash
# The public screenshots and animations (docs/DEVELOPMENT.md): the harness in its public mode (only
# the stock apps, in made-up folders, a stock ambience picture, sample data), each scene grabbed on the phone into
# out/shots/ or out/frames/, then made 540 px wide (JPEG) or 360 px wide (animated WebP) into docs/images/. The phone
# must be unlocked with the display on.
# Usage: scripts/screenshots.sh [NAME...]     (make screenshots; NAME: only these, e.g. widgets switcher-pinch)
set -euo pipefail
# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"

# NAME|SCENE|WAIT|GRAB|CROP|OPTIONS: the shot list.
#   NAME     a still (NAME.jpg), or an animation (NAME.webp: the scene's run, recorded with --frames)
#   GRAB     a still's moment in the scene's timeline (seconds)
#   CROP     the part to keep, in phone pixels (the search: above the harness's keyboard stand-in)
#   OPTIONS  slow: qmlscene's slow motion (the film scene); w=WIDTH, q=QUALITY of an animation (360, 70)
shots=(
    "widgets|widgets normal glass clock=card@0,status=shelf@7,player=card@9,event=panel@20,weather=shelf@30|10"
    "folders|layout normal Media=card@5,Office=panel@13|8"
    "search|search pos=bottom|13|8.6|1032x1440+0+0"
    "badges|badges|8"
    "switcher|switcher|10"
    "settings|settings|10"
    "folder-motion.webp|motion zoom glass from=Media|14"
    "switcher-pinch.webp|switcher mode=pinch chips=1 recent=1|24"
    "switcher-close.webp|switcher mode=cards chips=1 recent=1|20"
    "glass.webp|glass|26|||w=320 q=60"
    "glass-clear.webp|glass look=clear photo=ruska|26|||w=320 q=60"
    "search-typing.webp|search pos=bottom type=ca,set,med|26||1032x1440+0+0"
    "widget-move.webp|film clip=move|50|||slow"
    "widget-add.webp|film clip=add|60|||slow"
    "widget-resize.webp|film clip=resize|50|||slow"
    "settings-animations|settings Animations|10|1.2"
    "animations-sailfish.webp|reel seaglass,tide,aurora|30|||w=300 q=55"
    "animations-elements.webp|reel ember,volt,frost|30|||w=300 q=55"
    "animations-extreme.webp|reel shatter,singularity,dust|32|||w=300 q=55"
)

# wanted NAME [FILTER...]: no filter, or NAME is one of them
wanted() { [ $# -le 1 ] && return 0; local n; for n in "${@:2}"; do [ "$n" = "$1" ] && return 0; done; return 1; }

tools_image
mkdir -p "$REPO_ROOT/docs/images"
for shot in "${shots[@]}"; do
    IFS='|' read -r name scene wait grab crop options <<< "$shot"
    base=${name%.webp}
    wanted "$base" "$@" || continue
    log "$name: $scene"
    if [ "$base" != "$name" ]; then
        width=360 quality=70 extra=()
        for option in $options; do
            case $option in
                slow) extra+=(--slow-animations) ;;
                w=*) width=${option#w=} ;;
                q=*) quality=${option#q=} ;;
                *) die "unknown option: $option" ;;
            esac
        done
        rm -rf "$OUT_DIR/frames/public-$base"
        "$REPO_ROOT/scripts/harness.sh" --public ${extra[@]+"${extra[@]}"} --scene "$scene" --frames "public-$base" \
            --wait "$wait" >/dev/null
        [ -s "$OUT_DIR/frames/public-$base/f_000.jpg" ] || die "no frames of $name (is the display on and unlocked?)"
        docker run --rm -v "$OUT_DIR/frames/public-$base:/in:ro" -v "$REPO_ROOT/docs/images:/out" "$TOOLS_IMAGE" sh -euc '
            convert -delay "$(cat /in/delay)" -loop 0 /in/f_*.jpg ${2:+-crop "$2" +repage} -resize "$3x" \
                -quality "$4" -define webp:method=6 "/out/$1"
            chown "$(stat -c %u:%g /out)" "/out/$1"
        ' sh "$name" "$crop" "$width" "$quality"
    else
        name=$name.jpg
        rm -f "$OUT_DIR/shots/public-$base.png"
        "$REPO_ROOT/scripts/harness.sh" --public --scene "$scene" --shot "public-$base" --wait "$wait" \
            ${grab:+--grab "$grab"} >/dev/null
        [ -s "$OUT_DIR/shots/public-$base.png" ] || die "no screenshot of $base (is the display on and unlocked?)"
        docker run --rm -v "$OUT_DIR/shots:/in:ro" -v "$REPO_ROOT/docs/images:/out" "$TOOLS_IMAGE" sh -euc '
            convert "/in/public-$1.png" ${2:+-crop "$2" +repage} -resize 540x -strip -quality 85 -sampling-factor 4:2:0 \
                "/out/$1.jpg"
            chown "$(stat -c %u:%g /out)" "/out/$1.jpg"
        ' sh "$base" "$crop"
    fi
    log "  docs/images/$name ($(du -h "$REPO_ROOT/docs/images/$name" | cut -f1))"
done
