// A notification badge on an app or folder icon (docs/BADGES.md): how many notifications the app has (a folder: its
// apps together), or a dot, at the icon's top right corner, over its edge. It pops in when the first notification
// comes, and out when the last one goes.
//   count   the notifications (0: no badge)
//   style   count | dot
//   tone    accent (the ambience's highlight colour, dark figures) | red (white figures)
import QtQuick 2.6
import Sailfish.Silica 1.0

Item {
    id: badge

    property int count
    property string style: "count"
    property string tone: "accent"
    property real iconSize: Theme.iconSizeLauncher

    readonly property bool dot: style === "dot"
    readonly property real size: Math.round(iconSize * (dot ? 0.2 : 0.38))

    width: dot ? size : Math.max(size, figures.implicitWidth + 2 * Theme.paddingSmall)
    height: size
    visible: scale > 0
    scale: count > 0 ? 1 : 0
    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2 } }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: badge.tone === "red" ? "#e0342f" : Theme.highlightColor
        // a thin dark ring keeps it apart from the icon under it
        border.width: Math.max(1, Math.round(1.5 * Theme.pixelRatio))
        border.color: Theme.rgba("black", 0.28)
    }

    Label {
        id: figures

        anchors.centerIn: parent
        visible: !badge.dot
        font.pixelSize: Math.round(badge.size * 0.62)
        font.bold: true
        color: badge.tone === "red" ? "white" : Theme.highlightDimmerColor
        text: badge.count > 99 ? "99+" : badge.count
    }
}
