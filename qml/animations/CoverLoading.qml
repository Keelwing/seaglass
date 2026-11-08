// The loading effect on a launching cover (docs/ANIMATIONS.md). The Patchmanager hook loads this into a Loader over
// a cover in the switcher (switcher/SwitcherItem.qml) while its app starts; the Loader is its parent and gives
// launcherItem (the app) and radius (the cover's corners). The hook reads playing: while it is true, the stock busy
// indicator and icon stay hidden. The style is chosen once, when the cover starts loading; a stock moment makes nothing
// but this item.
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import "../settings"
import "styles.js" as Styles

Item {
    id: loading

    readonly property var launcherItem: parent ? parent.launcherItem : null
    property string style: "stock"
    readonly property bool playing: drawn.item !== null && drawn.item.playing

    anchors.fill: parent

    AnimationSettings {
        id: settings
    }

    Loader {
        id: drawn

        anchors.fill: parent
        active: loading.style !== "stock"
        sourceComponent: Component {
            Item {
                id: pieces

                readonly property bool playing: effect.ready

                // the clock runs on the render thread until the cover goes
                onPlayingChanged: {
                    if (playing)
                        effect.runClock(3600)
                }
                Component.onCompleted: {
                    if (playing)
                        effect.runClock(3600)
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
                    visible: pieces.playing
                    style: loading.style
                    moment: "load"
                    source: iconTexture
                    noiseTex: noise
                    radiusPx: loading.parent && loading.parent.radius !== undefined ? loading.parent.radius : 0
                    tint: Qt.vector3d(Theme.highlightColor.r, Theme.highlightColor.g, Theme.highlightColor.b)
                    useTint: settings.ambience ? 1 : 0
                    opacity: 0

                    OpacityAnimator on opacity {
                        running: pieces.playing
                        to: 1
                        duration: 200
                    }
                }
            }
        }
    }

    Component.onCompleted: style = Styles.choose(settings, "loading")
}
