#!/bin/sh
# Runs on the phone (scripts/harness.sh --public): a launcher for screenshots that anyone may see. It holds only the
# stock apps of Sailfish OS, in made-up folders, never the phone's own apps, folders or names.
#   DIR/public/data         XDG_DATA_DIRS: /usr/share as it is, but applications/ holds only the stock apps
#   DIR/public/home         XDG_DATA_HOME: empty (no apps installed for the user)
#   DIR/config/lipstick     XDG_CONFIG_HOME/lipstick: the made-up applications.menu and its folders
# Usage: sh public-launcher.sh DIR
set -eu
DIR=${1:?}

# The stock apps (desktop files of Jolla's packages), in the order of the made-up menu
ROOT_APPS="voicecall-ui jolla-messages jolla-contacts jolla-email sailfish-browser jolla-calendar jolla-settings store-client"
MEDIA_APPS="jolla-gallery jolla-camera jolla-mediaplayer"
OFFICE_APPS="sailfish-office jolla-notes jolla-calculator"
TOOLS_APPS="jolla-clock sailfish-audiorecorder sailfish-weather"

rm -rf "$DIR/public" "$DIR/config/lipstick"
mkdir -p "$DIR/public/data/applications" "$DIR/public/home" "$DIR/config/lipstick"
for entry in /usr/share/*; do
    [ "$entry" = /usr/share/applications ] || ln -s "$entry" "$DIR/public/data/"
done
for app in $ROOT_APPS $MEDIA_APPS $OFFICE_APPS $TOOLS_APPS; do
    if [ -e "/usr/share/applications/$app.desktop" ]; then
        ln -s "/usr/share/applications/$app.desktop" "$DIR/public/data/applications/"
    fi
done

folder() {  # NAME SHAPE APPS...
    name=$1 shape=$2
    shift 2
    printf '[Desktop Entry]\nName=%s\nIcon=icon-launcher-folder-%s\n' "$name" "$shape" > "$DIR/config/lipstick/Folder$name.directory"
    printf '    <Menu>\n        <Name>%s</Name>\n        <Directory>%s</Directory>\n' "$name" "$DIR/config/lipstick/Folder$name.directory"
    for app in "$@"; do printf '        <Filename>%s.desktop</Filename>\n' "$app"; done
    printf '    </Menu>\n'
}
{
    printf '<?xml version="1.0" encoding="UTF-8"?>\n<Menu>\n    <Name></Name>\n'
    for app in voicecall-ui jolla-messages jolla-contacts jolla-email sailfish-browser; do
        printf '    <Filename>%s.desktop</Filename>\n' "$app"
    done
    # shellcheck disable=SC2086  # word lists on purpose
    folder Media 06 $MEDIA_APPS
    printf '    <Filename>jolla-calendar.desktop</Filename>\n'
    # shellcheck disable=SC2086
    folder Office 09 $OFFICE_APPS
    printf '    <Filename>jolla-settings.desktop</Filename>\n    <Filename>store-client.desktop</Filename>\n'
    # shellcheck disable=SC2086
    folder Tools 14 $TOOLS_APPS
    printf '</Menu>\n'
} > "$DIR/config/lipstick/applications.menu"
