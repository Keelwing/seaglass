// The clock widget's next alarm: a small capsule with the alarm icon and the time.
import QtQuick 2.6
import Sailfish.Silica 1.0

Rectangle {
    id: chip

    property alias text: label.text

    width: row.width + 2 * Theme.paddingMedium
    height: Math.round(Theme.fontSizeSmall * 1.8)
    radius: height / 2
    color: Theme.rgba(Theme.highlightBackgroundColor, 0.22)

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.paddingSmall

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(Theme.fontSizeSmall * 1.1)
            height: width
            source: "image://theme/icon-m-alarm"
            highlighted: true
        }

        Label {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.highlightColor
        }
    }
}
