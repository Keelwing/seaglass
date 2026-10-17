// An app (or a folder) in the app search (SearchSheet.qml): its icon and name, and the folder it is in; a folder shows
// its apps on it as on the app grid (FolderPreview.qml, a glass tile with the glass); the best match is ringed (Enter
// launches it). A tap chooses it, a long press asks to show it in the grid.
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import "../badges"

Item {
    id: tile

    property var entry
    property bool first
    property Item glass
    readonly property bool isFolder: entry ? !!entry.isFolder : false

    signal chosen(bool longPress)

    readonly property bool down: area.pressed && area.containsMouse

    height: icon.height + name.height + (place.visible ? place.height : 0) + 2 * Theme.paddingMedium

    // the best match: a ring of light
    Rectangle {
        anchors.centerIn: icon
        width: icon.width + 2 * Theme.paddingSmall
        height: width
        radius: width * 0.3
        visible: tile.first
        color: "transparent"
        border.width: Math.max(2, Math.round(2 * Theme.pixelRatio))
        border.color: Theme.rgba(Theme.highlightColor, 0.8)
    }

    LauncherIcon {
        id: icon

        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.paddingMedium
        // a glass folder: the glass tile instead of the shape (as the hook does on the grid)
        icon: !tile.entry ? "" : preview.item && preview.item.glass ? "" : tile.entry.iconId
        pressed: tile.down

        // a folder: its apps on it, as on the app grid
        Loader {
            id: preview

            property QtObject folder: tile.isFolder ? tile.entry.item : null
            property bool pressed: tile.down
            property Item glass: tile.glass
            property string iconId: tile.isFolder ? tile.entry.iconId : ""

            anchors.fill: parent
            active: tile.isFolder
            source: "../folders/FolderPreview.qml"
        }

        // an app's notification badge (a folder's is on its preview)
        IconBadge {
            item: !tile.isFolder && tile.entry ? tile.entry.item : null
        }
    }

    Label {
        id: name

        anchors.top: icon.bottom
        anchors.topMargin: Theme.paddingSmall
        x: Theme.paddingSmall / 2
        width: parent.width - Theme.paddingSmall
        horizontalAlignment: implicitWidth > width ? Text.AlignLeft : Text.AlignHCenter
        truncationMode: TruncationMode.Fade
        font.pixelSize: Theme.fontSizeTiny
        color: tile.down ? Theme.highlightColor : Theme.primaryColor
        text: tile.entry ? tile.entry.title : ""
    }

    // the folder it is in, or that it is a folder
    Label {
        id: place

        anchors.top: name.bottom
        x: name.x
        width: name.width
        visible: text !== ""
        horizontalAlignment: implicitWidth > width ? Text.AlignLeft : Text.AlignHCenter
        truncationMode: TruncationMode.Fade
        font.pixelSize: Theme.fontSizeTiny
        color: Theme.secondaryColor
        //: The app search: an app inside a folder (%1: the folder's name); or a folder itself
        text: !tile.entry ? "" : tile.entry.isFolder ? qsTr("Folder")
                                 : tile.entry.folder ? qsTr("in %1").arg(tile.entry.folder) : ""
    }

    MouseArea {
        id: area

        anchors.fill: parent
        onClicked: tile.chosen(false)
        onPressAndHold: tile.chosen(true)
    }
}
