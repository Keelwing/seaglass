// The name chip under an app's cover in the task switcher (docs/SWITCHER.md): a small glass capsule with the app's icon
// and name, centred under the cover. It fades out in the stock housekeeping mode, where the stock close button sits on
// the cover's bottom edge. The hook loads it into a Loader under each cover (SwitcherItem.qml) that provides these; the
// card row and the harness set them directly.
//   glass         the GlassSource; without it a plain tint
//   launcherItem  the app (its iconId and title)
//   hidden        the housekeeping mode
//   maxWidth      the cover's width: a longer name fades
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import "../glass"

Item {
    id: chip

    property Item glass: parent && parent.glass !== undefined ? parent.glass : null
    property var launcherItem: parent && parent.launcherItem !== undefined ? parent.launcherItem : null
    property bool hidden: parent && parent.hidden !== undefined ? parent.hidden : false
    property real maxWidth: parent && parent.maxWidth !== undefined ? parent.maxWidth : (parent ? parent.width : 0)

    readonly property real iconSize: Theme.iconSizeSmall

    width: Math.min(maxWidth, row.width + 2 * Theme.paddingMedium)
    height: iconSize + 2 * Theme.paddingSmall
    opacity: hidden || !launcherItem ? 0 : 1
    visible: opacity > 0
    Behavior on opacity { FadeAnimation {} }

    GlassPane {
        id: pane

        anchors.fill: parent
        radius: height / 2
        glass: chip.glass
        frost: 1
        color: chip.glass ? chip.glass.tintColor(4) : "transparent"
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        visible: !pane.visible
        color: Theme.rgba(Theme.highlightDimmerColor, 0.7)
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.paddingSmall

        LauncherIcon {
            anchors.verticalCenter: parent.verticalCenter
            size: chip.iconSize
            icon: chip.launcherItem ? chip.launcherItem.iconId : ""
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, Math.min(implicitWidth, chip.maxWidth - chip.iconSize - Theme.paddingSmall
                                                       - 2 * Theme.paddingMedium))
            truncationMode: TruncationMode.Fade
            font.pixelSize: Theme.fontSizeExtraSmall
            text: chip.launcherItem ? String(chip.launcherItem.title || "").replace(/\n|\r/g, " ") : ""
        }
    }
}
