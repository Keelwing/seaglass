// An event in one line on the Next event widget (EventFace.qml): its start (or All day), its calendar's colour bar and
// its title. It is a control of the face (its key): a tap opens the event, and it lights while pressed. It takes no
// touches itself.
//   host   the EventFace (titleOf, startOf, soon, pressedKey, barWidth)
//   event  {key, title, start, end, allDay, color, cancelled}, or null
//   large  the panel's rows: a larger font and a column for the times
import QtQuick 2.6
import Sailfish.Silica 1.0

Item {
    id: line

    property Item host
    property var event: null
    property bool large

    readonly property string key: event ? "event:" + event.key : ""
    readonly property bool down: host !== null && key !== "" && host.pressedKey === key
    readonly property real fontSize: large ? Theme.fontSizeSmall : Theme.fontSizeExtraSmall

    height: Math.round(fontSize * 1.6)

    Rectangle {
        anchors.fill: parent
        radius: Theme.paddingSmall
        visible: line.down
        color: Theme.rgba(Theme.highlightBackgroundColor, Theme.highlightBackgroundOpacity)
    }

    Row {
        x: Theme.paddingSmall
        width: line.width - 2 * x
        height: line.height
        spacing: Theme.paddingMedium

        Label {
            id: time

            anchors.verticalCenter: parent.verticalCenter
            width: line.large ? Math.max(implicitWidth, line.fontSize * 3.4) : implicitWidth
            font.pixelSize: line.fontSize
            color: line.host && line.host.soon(line.event) ? Theme.highlightColor : Theme.secondaryColor
            text: line.host && line.event ? line.host.startOf(line.event) : ""
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: line.host ? line.host.barWidth : 4
            height: Math.round(line.fontSize * 1.1)
            radius: width / 2
            color: line.event && line.event.color ? line.event.color : Theme.highlightColor
            opacity: line.event && line.event.cancelled ? 0.4 : 1.0
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x
            truncationMode: TruncationMode.Fade
            font.pixelSize: line.fontSize
            font.strikeout: line.event !== null && line.event.cancelled
            color: line.down ? Theme.highlightColor : line.large ? Theme.primaryColor : Theme.secondaryColor
            text: line.host ? line.host.titleOf(line.event) : ""
        }
    }
}
