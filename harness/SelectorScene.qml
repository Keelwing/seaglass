// The selector scene: an open folder after a tap on its icon, as the stock LauncherFolder.qml draws it: the
// header, the 16 folder shapes, and below them the home screen types (FolderTypeSelector.qml).
// Argument: "Folder title=type", e.g. "Office=panel".
import QtQuick 2.6
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import Nemo.Configuration 1.0
import "../qml/widgets/group"

Item {
    id: scene

    property Item harness
    property QtObject folder
    property string type: "icon"
    readonly property real cellWidth: harness ? harness.grid.cellWidth : Theme.iconSizeLauncher * 1.5
    readonly property real cellHeight: harness ? harness.grid.cellHeight : Theme.iconSizeLauncher * 1.8

    onHarnessChanged: {
        var pair = (harness.sceneArgument || "Office=panel").split("=")
        folder = harness.folderNamed(pair[0]) || harness.folders()[0]
        type = pair[1] || "icon"
    }


    Image {
        id: wallpaper

        anchors.fill: parent
        source: scene.harness ? "file://" + scene.harness.picture : ""
        fillMode: Image.PreserveAspectCrop
        visible: false
    }

    FastBlur {
        anchors.fill: parent
        source: wallpaper
        radius: 64
    }

    // LauncherFolder.qml's background
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.rgba(Theme.overlayBackgroundColor, 1.0) }
            GradientStop { position: 1.0; color: Theme.rgba(Theme.overlayBackgroundColor, Theme.opacityOverlay) }
        }
    }

    // Header: the folder icon (with the preview) and the title
    Rectangle {
        id: header

        width: parent.width
        height: Theme.paddingLarge + scene.cellHeight - Theme.fontSizeExtraSmall / 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.rgba(Theme.primaryColor, 0.0) }
            GradientStop { position: 1.0; color: Theme.rgba(Theme.primaryColor, 0.15) }
        }

        LauncherIcon {
            id: folderIcon

            x: (scene.width - (scene.harness ? scene.harness.grid.width : scene.width)) / 2
               + (scene.cellWidth - width) / 2
            y: Theme.paddingLarge + (scene.cellHeight - height - Theme.fontSizeExtraSmall) / 2
            icon: scene.folder ? scene.folder.iconId : ""

            Loader {
                property QtObject folder: scene.folder

                anchors.fill: parent
                source: Qt.resolvedUrl("../qml/folders/FolderPreview.qml")
            }
        }

        Label {
            anchors {
                right: parent.right
                rightMargin: Theme.horizontalPageMargin
                verticalCenter: folderIcon.verticalCenter
            }
            font.pixelSize: Theme.fontSizeExtraLarge
            font.family: Theme.fontFamilyHeading
            color: Theme.highlightColor
            text: scene.folder ? scene.folder.title : ""
        }

        Label {
            anchors {
                right: parent.right
                rightMargin: Theme.horizontalPageMargin
                top: folderIcon.bottom
            }
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.highlightColor
            text: "Select folder shape"
        }
    }

    Column {
        anchors.top: header.bottom
        anchors.topMargin: Theme.fontSizeExtraSmall / 2
        width: parent.width

        Grid {
            anchors.horizontalCenter: parent.horizontalCenter
            columns: scene.harness ? scene.harness.grid.columns : 4

            Repeater {
                model: 16

                Item {
                    width: scene.cellWidth
                    height: scene.cellHeight * 0.8

                    LauncherIcon {
                        anchors.centerIn: parent
                        icon: scene.harness ? scene.harness.shape(index + 1) : ""
                        opacity: scene.folder && icon === scene.folder.iconId ? Theme.opacityFaint : 1.0
                    }

                    Image {
                        anchors.centerIn: parent
                        source: scene.folder && scene.harness
                                && scene.harness.shape(index + 1) === scene.folder.iconId
                                ? "image://theme/icon-s-installed" : ""
                    }
                }
            }
        }

        // as the hook's Loader: the chooser reads folder from its parent
        Item {
            property QtObject folder: scene.folder

            width: parent.width
            height: chooser.height

            FolderTypeChooser {
                id: chooser

                width: parent.width
                store: FolderTypes {
                    persistent: false
                    memory: {
                        var map = {}
                        if (scene.folder)
                            map[scene.folder.title] = scene.type
                        return map
                    }
                }
                onFinished: console.log("harness: chooser finished, types", JSON.stringify(store.map))
            }
        }
    }
}
