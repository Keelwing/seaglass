// The task switcher's "Recently closed" row (docs/SWITCHER.md): the apps closed last, newest first, as icons in a glass
// capsule like the search's; a tap starts the app again the stock way, a long press takes it off the row.
//   glass  the GlassSource; without it a plain tint
//   apps   [{title, iconId, filePath, item}]: item is the LauncherItem when it is still there
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import "../glass"

Item {
    id: recent

    property Item glass
    property var apps: []

    readonly property real iconSize: Math.round(Theme.iconSizeLauncher * 0.62)

    signal launch(var app)
    signal forget(var app)

    width: parent ? parent.width : 0
    height: apps.length > 0 ? title.height + Theme.paddingSmall + capsule.height : 0
    visible: apps.length > 0

    Label {
        id: title

        x: capsule.x + Theme.paddingLarge
        font.pixelSize: Theme.fontSizeExtraSmall
        color: Theme.secondaryHighlightColor
        //: The task switcher: the apps closed last
        text: qsTr("Recently closed")
    }

    Item {
        id: capsule

        anchors.horizontalCenter: parent.horizontalCenter
        y: title.height + Theme.paddingSmall
        width: Math.min(recent.width - 2 * Theme.paddingLarge, icons.width + 2 * Theme.paddingLarge)
        height: recent.iconSize + 2 * Theme.paddingMedium

        GlassPane {
            id: pane

            anchors.fill: parent
            radius: height / 2
            glass: recent.glass
            frost: 1
            color: recent.glass ? recent.glass.tintColor(4) : "transparent"
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            visible: !pane.visible
            color: Theme.rgba(Theme.highlightDimmerColor, 0.7)
        }

        Row {
            id: icons

            anchors.centerIn: parent
            spacing: Theme.paddingLarge

            Repeater {
                model: recent.apps

                MouseArea {
                    width: recent.iconSize
                    height: recent.iconSize
                    onClicked: recent.launch(modelData)
                    onPressAndHold: recent.forget(modelData)

                    LauncherIcon {
                        anchors.centerIn: parent
                        size: recent.iconSize
                        icon: modelData.iconId
                        pressed: parent.pressed && parent.containsMouse
                    }
                }
            }
        }
    }
}
