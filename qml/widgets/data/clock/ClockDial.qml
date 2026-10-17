// The clock widget's analogue face: a dial with twelve ticks, an hour and a minute hand, the minute hand's tip in the
// highlight colour. No second hand: the clock updates once a minute.
import QtQuick 2.6
import Sailfish.Silica 1.0

Item {
    id: dial

    property date time: new Date()

    readonly property real minutes: time.getMinutes()
    readonly property real hours: time.getHours() % 12 + minutes / 60
    readonly property real line: Math.max(2, Math.round(2 * Theme.pixelRatio))

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.rgba(Theme.primaryColor, 0.06)
        border.width: Math.max(1, Math.round(Theme.pixelRatio))
        border.color: Theme.rgba(Theme.primaryColor, 0.22)
    }

    Repeater {
        model: 12

        Item {
            anchors.fill: parent
            rotation: index * 30

            Rectangle {
                readonly property bool major: index % 3 === 0

                anchors.horizontalCenter: parent.horizontalCenter
                y: dial.height * 0.06
                width: major ? dial.line * 1.5 : dial.line
                height: dial.height * (major ? 0.08 : 0.05)
                radius: width / 2
                color: Theme.rgba(Theme.primaryColor, major ? 0.7 : 0.35)
            }
        }
    }

    // the hour hand
    Item {
        anchors.fill: parent
        rotation: dial.hours * 30

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: dial.height * 0.24
            width: dial.line * 2.5
            height: dial.height * 0.26 + width / 2
            radius: width / 2
            color: Theme.primaryColor
        }
    }

    // the minute hand
    Item {
        anchors.fill: parent
        rotation: dial.minutes * 6

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: dial.height * 0.1
            width: dial.line * 1.6
            height: dial.height * 0.4 + width / 2
            radius: width / 2
            color: Theme.primaryColor
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: dial.height * 0.1
            width: dial.line * 1.6
            height: dial.height * 0.1
            radius: width / 2
            color: Theme.highlightColor
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: dial.line * 4
        height: width
        radius: width / 2
        color: Theme.highlightColor
    }
}
