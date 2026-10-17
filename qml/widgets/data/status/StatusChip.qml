// A connection of the status widget: a round chip, lit when the connection is on, with a ring when it is connected. It
// takes no touches itself: DataWidget.qml's handle lies over the whole widget (so that a long press anywhere lifts it),
// and the face sets down and acts on taps (StatusFace.qml pressAt, tapAt).
import QtQuick 2.6
import Sailfish.Silica 1.0

Item {
    id: chip

    property string icon
    property bool on
    property bool connected
    property bool down
    property real diameter: Theme.itemSizeSmall

    width: diameter
    height: diameter

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: chip.down ? Theme.rgba(Theme.highlightBackgroundColor, Theme.highlightBackgroundOpacity)
                         : chip.on ? Theme.rgba(Theme.highlightBackgroundColor, 0.42)
                                   : Theme.rgba(Theme.primaryColor, 0.1)
        border.width: chip.connected ? Math.max(2, Math.round(2 * Theme.pixelRatio))
                                     : Math.max(1, Math.round(Theme.pixelRatio))
        border.color: chip.connected ? Theme.highlightColor : Theme.rgba(Theme.primaryColor, chip.on ? 0.0 : 0.3)
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Icon {
        anchors.centerIn: parent
        width: Math.round(chip.diameter * 0.56)
        height: width
        source: chip.icon ? "image://theme/" + chip.icon : ""
        highlighted: chip.on || chip.down
        opacity: chip.on ? 1.0 : 0.85
    }
}
