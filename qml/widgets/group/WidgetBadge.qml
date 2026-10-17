// On a folder icon in the launcher's edit mode, the badge that opens the folder out into a group widget in place (a
// card, which the widget's size control changes). Sits on the icon's top right corner, away from the stock uninstall
// button under the icon. Reports a tap with clicked().
import QtQuick 2.6
import Sailfish.Silica 1.0

MouseArea {
    id: badge

    readonly property bool down: pressed && containsMouse

    width: Theme.itemSizeExtraSmall
    height: width

    Rectangle {
        anchors.centerIn: parent
        width: Math.round(parent.width * 0.62)
        height: width
        radius: width / 2
        color: badge.down ? Theme.highlightColor : Theme.highlightBackgroundColor
        border.width: Math.max(1, Math.round(Theme.pixelRatio))
        border.color: Theme.rgba(Theme.primaryColor, 0.6)

        // "opens out": four squares
        Grid {
            anchors.centerIn: parent
            columns: 2
            spacing: Math.max(1, Math.round(parent.width * 0.06))

            Repeater {
                model: 4

                Rectangle {
                    width: Math.round(badge.width * 0.13)
                    height: width
                    radius: width * 0.3
                    color: Theme.primaryColor
                }
            }
        }
    }
}
