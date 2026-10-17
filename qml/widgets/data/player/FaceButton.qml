// A round button on a data widget's face: an icon, a disc while it is pressed, and a filled disc for the main control
// (play/pause). Like a status chip it takes no touches itself: DataWidget.qml's handle lies over the whole widget, and
// the face hit-tests its buttons by key (pressAt, tapAt).
import QtQuick 2.6
import Sailfish.Silica 1.0

Item {
    id: button

    // what the face does on a tap
    property string key
    property string icon
    property bool down
    // a filled disc (the main control)
    property bool filled
    // drawn dim, and not hit, when false
    property bool available: true
    property real diameter: Theme.itemSizeSmall
    property real iconScale: 0.6

    width: diameter
    height: diameter
    opacity: available ? 1.0 : 0.3

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: button.down ? Theme.rgba(Theme.highlightBackgroundColor, Theme.highlightBackgroundOpacity)
                           : button.filled ? Theme.rgba(Theme.highlightBackgroundColor, 0.42) : "transparent"
        border.width: button.filled ? 0 : Math.max(1, Math.round(Theme.pixelRatio))
        border.color: Theme.rgba(Theme.primaryColor, button.down ? 0 : 0.14)
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Icon {
        anchors.centerIn: parent
        width: Math.round(button.diameter * button.iconScale)
        height: width
        source: button.icon ? "image://theme/" + button.icon : ""
        highlighted: button.down || button.filled
    }
}
