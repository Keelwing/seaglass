// The widgets scene (docs/WIDGETS.md): the app grid's first page with data widgets among the icons, laid out by
// qml/core/grid.js over the ambience picture, with sample data (never the phone's own events, places or music); normal,
// in the launcher's edit mode with the "+ Widget" capsule, or with the gallery open. Argument: "MODE [face=analogue]
// [glass] [STATE...] WIDGETS"
//   glass    the widgets on our glass (GlassSource.qml with glass cards on, as on the phone) over a frosted picture
//            (try a light one: --picture /usr/share/ambience/airy/images/ambience_airy.jpg), not the plain tint
//   MODE     normal | edit | gallery | ghost (a status card lifted out of the gallery, over the grid)
//   STATE    the sample data's other states: idle (nothing playing), empty (no events), none (no weather
//            location), stale (old weather); and settings: noart, hideidle, private, noallday, today, hourly, daily,
//            nofeels
//   WIDGETS  "kind=size@slot,...": clock (card, shelf), status, player, event, weather (card, shelf, panel)
// e.g. "edit clock=card@0,status=shelf@7", "normal player=card@0,event=card@2,weather=panel@10"
import QtQuick 2.6
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import org.nemomobile.lipstick 0.1
import "../qml/glass"
import "../qml/widgets/data"
import "../qml/core/grid.js" as Grid

Item {
    id: scene

    property Item harness
    property string mode: "normal"
    property var widgets: []
    // the grid's order and where grid.js puts it
    property var order: []
    property var result: ({ "cells": [], "extra": {}, "rows": 0 })
    readonly property real cellWidth: harness ? harness.grid.cellWidth : 200
    readonly property real cellHeight: harness ? harness.grid.cellHeight : 250
    readonly property int columns: harness ? harness.grid.columns : 5
    readonly property int pageRows: harness ? harness.grid.rows : 9
    readonly property bool edit: mode !== "normal"
    property bool useGlass

    // what DataWidget.qml and WidgetGallery.qml ask of a controller
    function dataSizesOf(kind) {
        return store.sizesOf(kind)
    }
    function dataLift(widget) {}
    function dataMoved(widget) {}
    function dataDrop(widget) {}
    function dataResize(id, size) {}
    function dataRemove(id) {}
    function dataDragContainer() { return null }
    function enterEditMode() {}
    function dataRequest(what, argument) { console.log("harness: widget request", what, argument) }

    DataWidgets {
        id: store

        persistent: false
    }

    // the settings the faces read (never the phone's dconf)
    QtObject {
        id: demoSettings

        property string clockFace: "digital"
        property bool clockAlarm: true
        property bool statusSwitches: true
        property string playerIdle: "last"
        property bool playerArt: true
        property string lastPlayer: "jolla-mediaplayer"
        property int eventDays: 6
        property bool eventPrivate
        property bool eventAllDay: true
        property bool weatherFeels: true
        property string weatherForecast: "auto"
    }

    DataSources {
        id: demoSources

        demo: true
        wanted: ({ "clock": true, "status": true, "player": true, "event": true, "weather": true })
        eventDays: demoSettings.eventDays
        eventAllDay: demoSettings.eventAllDay
        weatherHourly: demoSettings.weatherForecast !== "daily"
    }

    onHarnessChanged: {
        var words = (harness.sceneArgument || "normal clock=card@0,status=shelf@7").split(" ")
        mode = words[0] || "normal"
        var list = []
        for (var w = 1; w < words.length; w++) {
            var word = words[w]
            if (word === "face=analogue") {
                demoSettings.clockFace = "analogue"
                continue
            }
            if (word === "glass") {
                useGlass = true
                continue
            }
            if (["idle", "empty", "none", "stale"].indexOf(word) >= 0) {
                demoSources.demoState += " " + word
                continue
            }
            if (scene.setOption(word))
                continue
            var specs = word.split(",")
            for (var s = 0; s < specs.length; s++) {
                var m = specs[s].match(/^(clock|status|player|event|weather)=(card|shelf|panel)@(\d+)$/)
                if (m)
                    list.push({ "id": "w" + (list.length + 1), "kind": m[1], "size": m[2], "at": parseInt(m[3], 10) })
            }
        }
        widgets = list
        var model = harness.launcherModel
        var spans = []
        for (var i = 0; i < model.itemCount; i++)
            spans.push({ "w": 1, "h": 1 })
        var xspans = {}
        for (w = 0; w < list.length; w++)
            xspans[list[w].id] = Grid.spanOf(list[w].size, columns)
        order = Grid.compose(model.itemCount, list)
        result = Grid.layoutOrder(order, spans, xspans, columns, pageRows, 0, 0)
        console.log("harness: widgets", JSON.stringify(list), "rows used", result.rows)
        if (mode === "gallery" || mode === "ghost")
            galleryTimer.start()
    }

    // a setting word of the argument
    function setOption(word) {
        if (word === "noart")
            demoSettings.playerArt = false
        else if (word === "hideidle")
            demoSettings.playerIdle = "hide"
        else if (word === "private")
            demoSettings.eventPrivate = true
        else if (word === "noallday")
            demoSettings.eventAllDay = false
        else if (word === "today")
            demoSettings.eventDays = 0
        else if (word === "hourly" || word === "daily")
            demoSettings.weatherForecast = word
        else if (word === "nofeels")
            demoSettings.weatherFeels = false
        else
            return false
        return true
    }

    // the sample player's numbers, once (a check of the progress)
    Timer {
        interval: 2000
        running: true
        onTriggered: {
            var player = demoSources.player
            if (player)
                console.log("harness: player sample", player.position, player.length, player.playing, player.present)
        }
    }

    Timer {
        id: galleryTimer

        interval: 300
        onTriggered: {
            gallery.open()
            if (scene.mode === "ghost")
                ghostTimer.start()
        }
    }

    Timer {
        id: ghostTimer

        interval: 700
        onTriggered: gallery.startGhost("status", "card", scene.width * 0.55, scene.height * 0.45)
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
        visible: !scene.useGlass
        color: Theme.rgba(Theme.overlayBackgroundColor, 0.45)
    }

    // our glass, as on the phone: Silica's square picture in a centred square frame (Lipstick's transformItem)
    Image {
        id: homePicture

        visible: false
        sourceSize.height: Screen.height
        source: scene.useGlass && scene.harness
                ? "image://silica-square/" + encodeURIComponent("file://" + scene.harness.picture) : ""
    }

    Item {
        id: stockFrame

        anchors.centerIn: parent
        width: Math.max(scene.width, scene.height)
        height: width
    }

    GlassSource {
        id: demoGlass

        home: homePicture.status === Image.Ready ? homePicture : null
        frameParent: stockFrame
        preset: ({ "look": "glass", "picture": "home", "image": "", "frost": 1, "tint": "auto", "dim": 0.25,
                   "edge": true, "folders": true, "openFolder": true, "cards": true, "parallax": 1,
                   "depth": false, "tilt": false, "drift": false })
    }

    Item {
        id: page

        x: (parent.width - width) / 2
        y: Theme.paddingLarge * 2
        width: scene.columns * scene.cellWidth
        height: scene.pageRows * scene.cellHeight

        // the icons
        Repeater {
            model: scene.order.length

            Item {
                id: cell

                readonly property var entry: scene.order[index]
                readonly property var block: entry.m !== undefined ? scene.result.cells[entry.m] : null
                readonly property QtObject item: entry.m !== undefined ? scene.harness.launcherModel.get(entry.m) : null
                readonly property bool isFolder: item !== null && item.type === LauncherModel.Folder

                visible: block !== null && block.row < scene.pageRows
                x: block ? block.col * scene.cellWidth : 0
                y: block ? block.row * scene.cellHeight : 0
                width: scene.cellWidth
                height: scene.cellHeight

                LauncherIcon {
                    id: launcherIcon

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: (parent.height - height - label.height - Theme.paddingSmall) / 2
                    icon: cell.item ? cell.item.iconId : ""

                    Loader {
                        property QtObject folder: cell.isFolder ? cell.item : null

                        anchors.fill: parent
                        active: cell.isFolder
                        source: Qt.resolvedUrl("../qml/folders/FolderPreview.qml")
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
                    text: cell.item ? cell.item.title : ""
                    // the stock edit mode hides the app names
                    visible: !scene.edit || cell.isFolder
                }
            }
        }

        // the data widgets
        Repeater {
            model: scene.widgets

            DataWidget {
                readonly property var block: scene.result.extra[modelData.id]

                visible: block !== undefined && block.row < scene.pageRows
                entry: modelData
                controller: scene
                sources: demoSources
                settings: demoSettings
                editMode: scene.edit
                plainGlass: !scene.useGlass
                glassSource: scene.useGlass ? demoGlass : null
                targetX: block ? block.col * scene.cellWidth : 0
                targetY: block ? block.row * scene.cellHeight : 0
                targetWidth: block ? block.w * scene.cellWidth : 0
                targetHeight: block ? block.h * scene.cellHeight : 0
            }
        }
    }

    AddWidget {
        glass: scene.useGlass ? demoGlass : null
        visible: scene.edit && !gallery.opened
        x: (parent.width - width) / 2
        y: parent.height - height - Theme.paddingSmall
    }

    WidgetGallery {
        id: gallery

        anchors.fill: parent
        sources: demoSources
        settings: demoSettings
        plainGlass: true
        controller: scene
        cellWidth: scene.cellWidth
        cellHeight: scene.cellHeight
        columns: scene.columns
        onChosen: console.log("harness: chosen", kind, size)
    }
}
