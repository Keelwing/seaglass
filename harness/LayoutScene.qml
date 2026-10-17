// The layout scene: the app grid's first page laid out by qml/core/grid.js, with group widgets between the icons, over
// the ambience picture; normal or in the launcher's edit mode. Argument: "MODE WIDGETS [drag=TITLE] [drop=TITLE]"
//   MODE     normal | edit
//   WIDGETS  "Title=type@index,...": the folder moves to that place in the grid's order and shows as that type
//            (card, shelf, panel, or icon: a plain folder icon there)
//   drag     edit mode: that widget is lifted, as while it is dragged, and its place is outlined
//   drop     edit mode: an app is held over that widget
// e.g. "edit Media=card@5,Office=panel@12,Tools=shelf@40 drag=Media"
import QtQuick 2.6
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import Nemo.Configuration 1.0
import org.nemomobile.lipstick 0.1
import "../qml/widgets/group"
import "../qml/core/grid.js" as Grid

Item {
    id: scene

    property Item harness
    property bool edit
    property string dragged
    property string dropOn
    // [{item, type}] in the grid's order, and where grid.js puts them
    property var order: []
    property var result: ({ "cells": [], "rows": 0 })
    readonly property real cellWidth: harness ? harness.grid.cellWidth : 200
    readonly property real cellHeight: harness ? harness.grid.cellHeight : 250
    readonly property int columns: harness ? harness.grid.columns : 5
    readonly property int pageRows: harness ? harness.grid.rows : 9

    onHarnessChanged: {
        var words = (harness.sceneArgument || "normal Media=card@5,Office=panel@12,Tools=shelf@40").split(" ")
        edit = words[0] === "edit"
        var widgets = []
        for (var w = 1; w < words.length; w++) {
            var word = words[w]
            if (word.indexOf("drag=") === 0) {
                dragged = word.slice(5)
            } else if (word.indexOf("drop=") === 0) {
                dropOn = word.slice(5)
            } else {
                var specs = word.split(",")
                for (var s = 0; s < specs.length; s++) {
                    // "icon": a folder moved there as a plain folder icon
                    var m = specs[s].match(/^(.+)=(card|shelf|panel|icon)@(\d+)$/)
                    if (m)
                        widgets.push({ "title": m[1], "type": m[2], "at": parseInt(m[3], 10) })
                }
            }
        }
        // the grid's order with the widget folders moved to their places
        var items = []
        var model = harness.launcherModel
        for (var i = 0; i < model.itemCount; i++) {
            var item = model.get(i)
            var isWidget = false
            for (w = 0; w < widgets.length; w++)
                isWidget = isWidget || item.title === widgets[w].title
            if (!isWidget)
                items.push({ "item": item, "type": "icon" })
        }
        widgets.sort(function (a, b) { return a.at - b.at })
        for (w = 0; w < widgets.length; w++) {
            var folder = harness.folderNamed(widgets[w].title)
            if (folder)
                items.splice(Math.min(widgets[w].at, items.length), 0, { "item": folder, "type": widgets[w].type })
        }
        var spans = items.map(function (entry) { return Grid.spanOf(entry.type, scene.columns) })
        result = Grid.layout(spans, columns, pageRows, 0)
        order = items
        console.log("harness: layout", columns + "x" + pageRows, "rows used", result.rows, "items", items.length)
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

    Rectangle {
        anchors.fill: parent
        color: Theme.rgba(Theme.overlayBackgroundColor, 0.45)
    }

    Item {
        id: page

        x: (parent.width - width) / 2
        y: Theme.paddingLarge * 2
        width: scene.columns * scene.cellWidth
        height: scene.pageRows * scene.cellHeight

        Repeater {
            model: scene.order.length

            Item {
                id: cell

                readonly property var entry: scene.order[index]
                readonly property var block: scene.result.cells[index]
                readonly property bool isWidget: entry.type !== "icon"
                readonly property bool isFolder: entry.item.itemCount !== undefined

                visible: block.row < scene.pageRows
                x: block.col * scene.cellWidth
                y: block.row * scene.cellHeight
                width: block.w * scene.cellWidth
                height: block.h * scene.cellHeight

                // a widget's place while it is dragged
                Rectangle {
                    visible: cell.isWidget && scene.edit && cell.entry.item.title === scene.dragged
                    anchors.fill: parent
                    anchors.margins: Theme.paddingSmall
                    radius: Theme.paddingLarge
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
                    border.width: Math.max(1, Math.round(2 * Theme.pixelRatio))
                    border.color: Theme.rgba(Theme.highlightColor, 0.45)
                }

                GroupWidget {
                    readonly property bool isLifted: scene.edit && cell.entry.item.title === scene.dragged

                    visible: cell.isWidget
                    x: isLifted ? Theme.paddingLarge * 2 : 0
                    y: isLifted ? -Theme.paddingLarge * 3 : 0
                    z: isLifted ? 10 : 0
                    scale: isLifted ? 1.04 : 1.0
                    width: parent.width
                    height: parent.height
                    folder: cell.isWidget ? cell.entry.item : null
                    type: cell.entry.type
                    editMode: scene.edit
                    lifted: isLifted
                    dropTarget: scene.edit && cell.entry.item.title === scene.dropOn
                    plainGlass: true
                }

                // an app held over the drop target, as the stock drag scales it
                LauncherIcon {
                    visible: cell.isWidget && scene.edit && cell.entry.item.title === scene.dropOn
                    x: parent.width * 0.62
                    y: parent.height * 0.42
                    z: 20
                    scale: 1.3
                    icon: "icon-launcher-browser"
                }

                Item {
                    visible: !cell.isWidget
                    anchors.fill: parent

                    LauncherIcon {
                        id: launcherIcon

                        anchors.horizontalCenter: parent.horizontalCenter
                        y: (parent.height - height - label.height - Theme.paddingSmall) / 2
                        icon: cell.entry.item.iconId

                        Loader {
                            property QtObject folder: cell.isFolder ? cell.entry.item : null

                            anchors.fill: parent
                            active: cell.isFolder && !cell.isWidget
                            source: Qt.resolvedUrl("../qml/folders/FolderPreview.qml")
                        }
                    }

                    WidgetBadge {
                        visible: scene.edit && cell.isFolder
                        anchors {
                            horizontalCenter: launcherIcon.right
                            verticalCenter: launcherIcon.top
                            horizontalCenterOffset: -Theme.paddingSmall
                            verticalCenterOffset: Theme.paddingSmall
                        }
                    }

                    Label {
                        id: label

                        anchors {
                            top: launcherIcon.bottom
                            topMargin: Theme.paddingSmall
                            left: parent.left
                            right: parent.right
                            leftMargin: Theme.paddingSmall / 2
                            rightMargin: Theme.paddingSmall / 2
                        }
                        horizontalAlignment: Text.AlignHCenter
                        truncationMode: TruncationMode.Fade
                        font.pixelSize: Theme.fontSizeTiny
                        text: cell.entry.item.title
                        // the stock edit mode hides the app names
                        visible: !scene.edit || cell.isFolder
                    }
                }
            }
        }
    }
}
