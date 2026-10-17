// The folders scene: the phone's folders with the preview and with the stock count, made-up folders of 2 to
// 24 apps, and the pressed and drop states, through the same Loader as the hook.
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import org.nemomobile.lipstick 0.1

Rectangle {
    id: scene

    property Item harness
    readonly property url previewUrl: Qt.resolvedUrl("../qml/folders/FolderPreview.qml")
    readonly property real cellWidth: Math.floor(width / 4)
    property var realFolders: []
    property var realStock: []
    property var madeUp: []
    property var states: []

    color: "#11161c"

    onHarnessChanged: {
        var real = harness.folders().map(function (folder) {
            return { "folder": folder, "shape": folder.iconId, "title": folder.title + " (" + folder.itemCount + ")" }
        })
        realFolders = real
        realStock = real.map(function (entry) {
            return { "folder": entry.folder, "shape": entry.shape, "title": entry.title, "stock": true }
        })

        var sizes = [2, 3, 4, 5, 6, 9, 10, 24]
        var made = []
        for (var i = 0; i < sizes.length; i++)
            made.push({ "folder": harness.madeUpFolder(sizes[i], 3 * i), "shape": harness.shape(1 + 2 * i), "title": sizes[i] + " apps" })
        madeUp = made

        states = [
            { "folder": harness.madeUpFolder(3, 5), "shape": harness.shape(2), "title": "pressed", "pressed": true },
            { "folder": harness.madeUpFolder(3, 5), "shape": harness.shape(4), "title": "drop (3)", "drop": true },
            { "folder": harness.madeUpFolder(7, 9), "shape": harness.shape(7), "title": "drop (7)", "drop": true },
            { "folder": harness.madeUpFolder(12, 1), "shape": harness.shape(8), "title": "drop (12)", "drop": true }
        ]
    }

    // One folder as on the app grid: LauncherIcon with the hook's Loader and the stock count
    Component {
        id: folderCell

        Item {
            readonly property var entry: modelData
            readonly property bool stock: !!entry.stock

            width: scene.cellWidth
            height: launcherIcon.height + label.height + Theme.paddingLarge

            LauncherIcon {
                id: launcherIcon

                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.paddingSmall
                icon: entry.shape
                pressed: !!entry.pressed

                Loader {
                    id: folderPreview

                    property QtObject folder: entry.folder
                    property bool pressed: !!entry.pressed
                    property bool dropTarget: !!entry.drop

                    anchors.fill: parent
                    active: !stock
                    source: scene.previewUrl
                }

                Text {
                    font.pixelSize: Theme.fontSizeExtraLarge
                    font.family: Theme.fontFamilyHeading
                    color: Theme.lightPrimaryColor
                    anchors.centerIn: parent
                    text: entry.folder.itemCount !== undefined ? entry.folder.itemCount : entry.folder.count
                    visible: folderPreview.status !== Loader.Ready
                }
            }

            Label {
                id: label

                anchors.top: launcherIcon.bottom
                anchors.topMargin: Theme.paddingSmall
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeTiny
                text: entry.title
            }
        }
    }

    Column {
        y: Theme.paddingLarge
        width: parent.width
        spacing: Theme.paddingSmall

        Repeater {
            model: [
                { "title": "Your folders: preview", "cells": scene.realFolders },
                { "title": "Your folders: stock", "cells": scene.realStock },
                { "title": "Sizes", "cells": scene.madeUp },
                { "title": "States", "cells": scene.states }
            ]

            Column {
                width: parent.width

                Label {
                    x: Theme.horizontalPageMargin
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeSmall
                    text: modelData.title
                }

                Flow {
                    width: parent.width

                    Repeater {
                        model: modelData.cells
                        delegate: folderCell
                    }
                }
            }
        }
    }
}
