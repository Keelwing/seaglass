// The loading effect on a launching cover (docs/ANIMATIONS.md). The Patchmanager hook loads this into a Loader over
// a cover in the switcher (switcher/SwitcherItem.qml) while its app starts; the Loader is its parent and gives
// launcherItem (the app) and radius (the cover's corners). The hook reads playing: while it is true, the stock busy
// indicator and icon stay hidden. The style is chosen once, when the cover starts loading.
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import "../settings"
import "styles.js" as Styles

Item {
    id: loading

    readonly property var launcherItem: parent ? parent.launcherItem : null
    property string style: "stock"
    readonly property bool playing: style !== "stock" && effect.ready
    property real time

    anchors.fill: parent

    AnimationSettings {
        id: settings
    }

    NoiseTile {
        id: noise
    }

    LauncherIcon {
        id: icon

        size: Math.round(Theme.iconSizeLauncher * 1.5)
        icon: loading.launcherItem ? loading.launcherItem.iconId : ""
    }

    ShaderEffectSource {
        id: iconTexture

        width: 0
        height: 0
        textureSize: Qt.size(icon.width, icon.height)
        hideSource: true
        sourceItem: icon
    }

    Effect {
        id: effect

        anchors.fill: parent
        visible: loading.playing
        style: loading.style === "stock" ? "" : loading.style
        moment: "load"
        source: iconTexture
        noiseTex: noise
        time: loading.time
        radiusPx: loading.parent && loading.parent.radius !== undefined ? loading.parent.radius : 0
        tint: Qt.vector3d(Theme.highlightColor.r, Theme.highlightColor.g, Theme.highlightColor.b)
        useTint: settings.ambience ? 1 : 0
        opacity: 0

        NumberAnimation on opacity {
            running: loading.playing
            to: 1
            duration: 200
        }
    }

    NumberAnimation on time {
        running: loading.playing
        from: 0
        to: 3600
        duration: 3600000
    }

    Component.onCompleted: style = Styles.choose(settings, "loading")
}
