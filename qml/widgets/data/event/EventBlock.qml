// An event on the Next event widget (EventFace.qml): its calendar's colour bar beside the title, the location and the
// time, with a line above (header) or below (footer). It is a control of the face (its key): a tap opens the event, and
// it lights while pressed. It takes no touches itself.
//   host   the EventFace (titleOf, locationOf, timeOf, soon, pressedKey, barWidth)
//   event  {key, title, location, start, end, allDay, color, cancelled}, or null
//   lines  the title's lines
//   dim    the smaller look of an event further on
import QtQuick 2.6
import Sailfish.Silica 1.0

Item {
    id: block

    property Item host
    property var event: null
    property int lines: 2
    property bool dim
    property string header
    property string footer

    readonly property string key: event ? "event:" + event.key : ""
    readonly property bool down: host !== null && key !== "" && host.pressedKey === key

    height: column.height + 2 * Theme.paddingSmall

    Rectangle {
        anchors.fill: parent
        radius: Theme.paddingMedium
        visible: block.down
        color: Theme.rgba(Theme.highlightBackgroundColor, Theme.highlightBackgroundOpacity)
    }

    Column {
        id: column

        x: Theme.paddingSmall
        y: Theme.paddingSmall
        width: block.width - 2 * x
        spacing: Theme.paddingSmall / 2

        Label {
            visible: block.header !== ""
            width: parent.width
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
            text: block.header
        }

        Row {
            width: parent.width
            spacing: Theme.paddingMedium

            Rectangle {
                width: block.host ? block.host.barWidth : 4
                height: details.height
                radius: width / 2
                color: block.event && block.event.color ? block.event.color : Theme.highlightColor
                opacity: block.event && block.event.cancelled ? 0.4 : 1.0
            }

            Column {
                id: details

                width: parent.width - x

                Label {
                    width: parent.width
                    wrapMode: Text.Wrap
                    maximumLineCount: block.lines
                    elide: Text.ElideRight
                    font.pixelSize: block.dim ? Theme.fontSizeExtraSmall : Theme.fontSizeSmall
                    font.strikeout: block.event !== null && block.event.cancelled
                    color: block.down ? Theme.highlightColor : block.dim ? Theme.secondaryColor : Theme.primaryColor
                    text: block.host ? block.host.titleOf(block.event) : ""
                }

                Label {
                    readonly property string place: block.host ? block.host.locationOf(block.event) : ""

                    visible: place !== ""
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    text: place
                }

                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: block.host && block.host.soon(block.event) ? Theme.highlightColor : Theme.secondaryColor
                    text: block.host ? block.host.timeOf(block.event, true) : ""
                }
            }
        }

        Label {
            visible: block.footer !== ""
            width: parent.width
            font.pixelSize: Theme.fontSizeTiny
            color: Theme.highlightColor
            text: block.footer
        }
    }
}
