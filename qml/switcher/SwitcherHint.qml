// The card row's hint, the first few times (docs/SWITCHER.md): a glass chip with an arrow that nudges up, "Flick a card
// up to close it". SwitcherController.qml decides when it shows.
//   glass    the GlassSource; without it a plain tint
//   running  the arrow moves
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../glass"

Item {
    id: hint

    property Item glass
    property bool running: visible
    property real nudge: 0

    width: hintRow.width + 2 * Theme.paddingLarge
    height: Theme.itemSizeExtraSmall

    GlassPane {
        id: pane

        anchors.fill: parent
        radius: height / 2
        glass: hint.glass
        frost: 1
        color: hint.glass ? hint.glass.tintColor(4) : "transparent"
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        visible: !pane.visible
        color: Theme.rgba("black", 0.6)
    }

    Row {
        id: hintRow

        anchors.centerIn: parent
        spacing: Theme.paddingSmall

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: hint.nudge
            source: "image://theme/icon-m-up"
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: Theme.fontSizeSmall
            //: The task switcher's card row, the first few times
            text: qsTr("Flick a card up to close it")
        }
    }

    SequentialAnimation {
        running: hint.running
        loops: Animation.Infinite
        onRunningChanged: if (!running) hint.nudge = 0

        NumberAnimation { target: hint; property: "nudge"; from: 0; to: -Theme.paddingMedium; duration: 450; easing.type: Easing.OutQuad }
        NumberAnimation { target: hint; property: "nudge"; to: 0; duration: 450; easing.type: Easing.InQuad }
        PauseAnimation { duration: 700 }
    }
}
