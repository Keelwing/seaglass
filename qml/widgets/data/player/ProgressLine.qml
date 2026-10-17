// A thin progress line (the Now playing widget): a faint track, filled in the highlight colour.
import QtQuick 2.6
import Sailfish.Silica 1.0

Item {
    id: line

    // 0 .. 1
    property real value

    height: Math.max(2, Math.round(Theme.paddingSmall / 2))

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.rgba(Theme.primaryColor, 0.18)
    }

    Rectangle {
        width: Math.max(line.height, line.width * Math.max(0, Math.min(1, line.value)))
        height: line.height
        radius: height / 2
        visible: line.value > 0
        color: Theme.highlightColor
    }
}
