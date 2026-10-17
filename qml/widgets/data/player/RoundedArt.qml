// Album art with rounded corners (the Now playing widget), or a tinted tile with a note while there is none; the
// player's app icon can sit on its corner.
//   source     the art's URL, or ""
//   appIcon    the player's icon id (a theme name or a path, as LauncherIcon takes it), or ""
//   radius     the corners
import QtQuick 2.6
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0

Item {
    id: art

    property string source
    property string appIcon
    property real radius: Theme.paddingMedium
    readonly property bool shown: picture.status === Image.Ready

    // no art: a tile with a note
    Rectangle {
        anchors.fill: parent
        radius: art.radius
        visible: !art.shown
        color: Theme.rgba(Theme.highlightBackgroundColor, 0.22)

        Icon {
            anchors.centerIn: parent
            width: Math.round(Math.min(parent.width, parent.height) * 0.42)
            height: width
            source: "image://theme/icon-m-music"
            highlighted: true
        }
    }

    Image {
        id: picture

        anchors.fill: parent
        visible: false
        source: art.source
        sourceSize.width: Math.ceil(art.width)
        sourceSize.height: Math.ceil(art.height)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
    }

    Rectangle {
        id: corners

        anchors.fill: parent
        radius: art.radius
        visible: false
    }

    OpacityMask {
        anchors.fill: parent
        visible: art.shown
        source: picture
        maskSource: corners
    }

    // the player's app on the art's corner
    Image {
        readonly property real size: Math.round(Math.min(art.width * 0.3, art.height * 0.3, Theme.iconSizeMedium * 0.8))

        visible: art.appIcon !== "" && status === Image.Ready
        x: art.width - size * 0.8
        y: art.height - size * 0.8
        width: size
        height: size
        sourceSize.width: size
        sourceSize.height: size
        smooth: true
        source: art.appIcon === "" ? ""
                : art.appIcon.indexOf(":/") !== -1 || art.appIcon.indexOf("data:image/png;base64") === 0 ? art.appIcon
                : art.appIcon.charAt(0) === "/" ? "file://" + art.appIcon
                : "image://theme/" + art.appIcon
    }
}
