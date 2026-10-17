// The widget gallery (docs/WIDGETS.md): a glass sheet that rises from the edit mode's Add widget capsule, with one
// section per kind and live previews of its sizes.
//   - a tap on a preview reports chosen(kind, size): the controller adds the widget at the top of the current page;
//   - a long press lifts the widget out of the sheet (the sheet slides away) and the finger carries it over the grid:
//     ghostStarted(ghost), ghostMoved(ghost), then ghostDropped(kind, size) where it is let go, or ghostCanceled();
//   - the sheet scrolls; it closes with a tap above it, or pulled down by its handle (or past its top).
//   glass      the GlassSource; without it a plain tint
//   sources    DataSources.qml (the previews are live)
//   settings   the widgets' settings, for the previews' faces
//   cellWidth, cellHeight  the app grid's cells: the previews have the widgets' proportions
//   controller HomeController.qml (or the harness scene): dataSizesOf(kind), the kind's sizes
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../../glass"

Item {
    id: gallery

    property Item glass
    // the harness: the previews' plain tint only
    property bool plainGlass
    property Item sources
    property QtObject settings
    property real cellWidth: Theme.iconSizeLauncher * 1.5
    property real cellHeight: Theme.iconSizeLauncher * 2
    property int columns: 5
    property Item controller
    property bool opened
    // 0 closed .. 1 open
    property real shown: 0
    // how far the sheet is pulled down by its handle
    property real pullOffset: 0
    // the widget lifted out of the sheet: its kind and size; 0 .. 1 as the sheet slides away under it
    property string ghostKind
    property string ghostSize
    readonly property bool ghosting: ghostKind !== ""
    property real ghostOut: 0
    readonly property Item ghost: ghostItem

    signal chosen(string kind, string size)
    signal ghostStarted(Item ghost)
    signal ghostMoved(Item ghost)
    signal ghostDropped(string kind, string size)
    signal ghostCanceled()

    // needs: what a kind whose source is missing on the phone would need
    readonly property var kinds: [
        { "kind": "clock", "name": qsTr("Clock"), "about": qsTr("The time, the date and the next alarm."),
          "needs": qsTr("Not available on this phone") },
        { "kind": "status", "name": qsTr("Status"),
          "about": qsTr("The battery, with switches for Wi-Fi, mobile data, Bluetooth and flight mode."),
          "needs": qsTr("Not available on this phone") },
        { "kind": "player", "name": qsTr("Now playing"),
          "about": qsTr("The current track, with the player's controls."),
          "needs": qsTr("Not available on this phone: it needs the media player support (Amber.Mpris).") },
        { "kind": "event", "name": qsTr("Next event"), "about": qsTr("The coming events from the calendar."),
          "needs": qsTr("Not available on this phone: it needs the Calendar app.") },
        { "kind": "weather", "name": qsTr("Weather"), "about": qsTr("Now and the forecast, from the Weather app."),
          "needs": qsTr("Not available on this phone: it needs the Weather app.") }
    ]
    readonly property real margin: Theme.horizontalPageMargin
    readonly property real flowWidth: width - 2 * margin
    // a card beside a shelf fills a line
    readonly property real previewScale: Math.min(0.6, (flowWidth - Theme.paddingLarge) / (7 * cellWidth))
    // pulled this far, the sheet closes when let go
    readonly property real pullToClose: Math.min(sheet.height * 0.25, Theme.itemSizeLarge * 1.5)

    function open() {
        closing.stop()
        settleBack.stop()
        pullOffset = 0
        ghostOut = 0
        opened = true
        opening.restart()
    }

    function close(now) {
        if (!opened)
            return
        opening.stop()
        if (now) {
            shown = 0
            pullOffset = 0
            opened = false
        } else {
            closing.restart()
        }
    }

    function sizeName(size) {
        return size === "card" ? qsTr("Card") : size === "shelf" ? qsTr("Shelf") : size === "panel" ? qsTr("Panel") : size
    }

    function spanWidth(size) {
        return size === "card" ? Math.min(2, columns) : columns
    }

    function spanHeight(size) {
        return size === "shelf" ? 1 : 2
    }

    // ---- the widget lifted out of the sheet: (x, y) is the finger in the gallery ----

    function startGhost(kind, size, x, y) {
        ghostKind = kind
        ghostSize = size
        placeGhost(x, y)
        ghostSlide.to = 1
        ghostSlide.restart()
        ghostStarted(ghostItem)
    }

    function moveGhost(x, y) {
        placeGhost(x, y)
        ghostMoved(ghostItem)
    }

    function placeGhost(x, y) {
        ghostItem.targetX = x - ghostItem.width / 2
        ghostItem.targetY = y - ghostItem.height / 2
    }

    // let go (drop) or lost: dropped, the gallery closes; lost, the sheet comes back
    function finishGhost(drop) {
        var kind = ghostKind
        var size = ghostSize
        ghostKind = ""
        if (drop) {
            ghostSlide.stop()
            ghostDropped(kind, size)
            close(true)
            ghostOut = 0
        } else {
            ghostCanceled()
            ghostSlide.to = 0
            ghostSlide.restart()
        }
    }

    visible: shown > 0

    NumberAnimation {
        id: opening

        target: gallery
        property: "shown"
        to: 1
        duration: 280
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: closing

        NumberAnimation { target: gallery; property: "shown"; to: 0; duration: 200; easing.type: Easing.InQuad }
        ScriptAction {
            script: {
                gallery.opened = false
                gallery.pullOffset = 0
            }
        }
    }

    NumberAnimation {
        id: settleBack

        target: gallery
        property: "pullOffset"
        to: 0
        duration: 200
        easing.type: Easing.OutQuad
    }

    NumberAnimation {
        id: ghostSlide

        target: gallery
        property: "ghostOut"
        duration: 220
        easing.type: Easing.InOutQuad
    }

    // the grid behind dims; a tap there closes the sheet
    MouseArea {
        anchors.fill: parent
        enabled: gallery.opened && !gallery.ghosting
        onClicked: gallery.close()

        Rectangle {
            anchors.fill: parent
            color: Theme.rgba("black", 0.45 * gallery.shown * (1 - gallery.ghostOut))
        }
    }

    Item {
        id: sheet

        width: parent.width
        height: Math.min(header.height + column.height + Theme.paddingLarge, parent.height * 0.86)
        y: parent.height - height * gallery.shown + gallery.pullOffset + height * gallery.ghostOut

        // the sheet swallows its own taps
        MouseArea {
            anchors.fill: parent
        }

        GlassPane {
            id: pane

            anchors.fill: parent
            glass: gallery.glass
            frost: 1
            color: gallery.glass ? gallery.glass.tintColor(3) : "transparent"
        }

        Rectangle {
            anchors.fill: parent
            visible: !pane.visible
            color: Theme.rgba(Theme.highlightDimmerColor, 0.94)

            Rectangle {
                width: parent.width
                height: Math.max(1, Math.round(Theme.pixelRatio))
                color: Theme.rgba(Theme.primaryColor, 0.3)
            }
        }

        // The header: the handle and the title; pulled down, the sheet follows and closes past pullToClose
        MouseArea {
            id: header

            property real startY

            width: parent.width
            height: grabber.height + title.height + Theme.paddingSmall
            preventStealing: true

            onPressed: {
                settleBack.stop()
                startY = mapToItem(null, mouse.x, mouse.y).y - gallery.pullOffset
            }
            onPositionChanged: gallery.pullOffset = Math.max(0, mapToItem(null, mouse.x, mouse.y).y - startY)
            onReleased: letGo()
            onCanceled: letGo()

            function letGo() {
                if (gallery.pullOffset > gallery.pullToClose)
                    gallery.close()
                else
                    settleBack.start()
            }

            // a grabber, as on Silica's sheets
            Item {
                id: grabber

                width: parent.width
                height: Theme.paddingLarge * 2

                Rectangle {
                    anchors.centerIn: parent
                    width: Theme.itemSizeSmall
                    height: Math.max(3, Math.round(3 * Theme.pixelRatio))
                    radius: height / 2
                    color: header.pressed ? Theme.highlightColor : Theme.rgba(Theme.primaryColor, 0.45)
                }
            }

            Label {
                id: title

                anchors.top: grabber.bottom
                x: gallery.margin
                width: gallery.flowWidth
                font.pixelSize: Theme.fontSizeLarge
                font.family: Theme.fontFamilyHeading
                color: Theme.highlightColor
                text: qsTr("Widgets")
            }
        }

        SilicaFlickable {
            id: flickable

            y: header.height
            width: parent.width
            height: parent.height - header.height
            contentHeight: column.height + Theme.paddingLarge
            clip: true
            // pulled down past its top, the sheet closes too
            onDraggingChanged: {
                if (!dragging && contentY < originY - gallery.pullToClose / 2)
                    gallery.close()
            }

            VerticalScrollDecorator {}

            Column {
                id: column

                width: parent.width

                Label {
                    x: gallery.margin
                    width: gallery.flowWidth
                    bottomPadding: Theme.paddingLarge
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryHighlightColor
                    text: qsTr("Tap a size to put the widget at the top of this page, or hold it and drag it where you "
                               + "want it.")
                }

                Repeater {
                    model: gallery.kinds

                    Column {
                        id: section

                        readonly property string kind: modelData.kind
                        readonly property bool unavailable: gallery.sources ? gallery.sources.failed(kind) : false

                        x: gallery.margin
                        width: gallery.flowWidth
                        bottomPadding: Theme.paddingLarge * 1.5
                        spacing: Theme.paddingSmall

                        Label {
                            width: parent.width
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.primaryColor
                            text: modelData.name
                        }

                        Label {
                            width: parent.width
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                            text: section.unavailable ? modelData.needs : modelData.about
                        }

                        Flow {
                            width: parent.width
                            topPadding: Theme.paddingMedium
                            spacing: Theme.paddingLarge
                            opacity: section.unavailable ? Theme.opacityLow : 1.0

                            Repeater {
                                model: gallery.controller ? gallery.controller.dataSizesOf(section.kind) : []

                                MouseArea {
                                    id: choice

                                    readonly property bool lifting: gallery.ghosting && gallery.ghostKind === section.kind
                                                                    && gallery.ghostSize === modelData

                                    width: gallery.spanWidth(modelData) * gallery.cellWidth * gallery.previewScale
                                    height: gallery.spanHeight(modelData) * gallery.cellHeight * gallery.previewScale
                                            + caption.height + Theme.paddingSmall
                                    enabled: !section.unavailable && gallery.opened
                                    // once lifted, the touch stays here (the sheet's flickable cannot take it)
                                    preventStealing: lifting
                                    onClicked: gallery.chosen(section.kind, modelData)
                                    onPressAndHold: {
                                        var p = choice.mapToItem(gallery, mouse.x, mouse.y)
                                        gallery.startGhost(section.kind, modelData, p.x, p.y)
                                    }
                                    onPositionChanged: {
                                        if (lifting) {
                                            var p = choice.mapToItem(gallery, mouse.x, mouse.y)
                                            gallery.moveGhost(p.x, p.y)
                                        }
                                    }
                                    onReleased: if (lifting) gallery.finishGhost(true)
                                    onCanceled: if (lifting) gallery.finishGhost(false)

                                    DataWidget {
                                        preview: true
                                        opacity: choice.lifting ? 0.3 : 1.0
                                        scale: gallery.previewScale
                                        transformOrigin: Item.TopLeft
                                        entry: ({ "id": "preview", "kind": section.kind, "size": modelData })
                                        sources: gallery.sources
                                        settings: gallery.settings
                                        plainGlass: gallery.plainGlass
                                        targetWidth: gallery.spanWidth(modelData) * gallery.cellWidth
                                        targetHeight: gallery.spanHeight(modelData) * gallery.cellHeight
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: parent.height - caption.height - Theme.paddingSmall
                                        radius: Theme.paddingLarge * gallery.previewScale
                                        visible: choice.pressed && choice.containsMouse && !choice.lifting
                                        color: Theme.rgba(Theme.highlightBackgroundColor, Theme.highlightBackgroundOpacity)
                                    }

                                    Label {
                                        id: caption

                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        font.pixelSize: Theme.fontSizeExtraSmall
                                        color: choice.pressed && choice.containsMouse ? Theme.highlightColor
                                                                                      : Theme.secondaryColor
                                        text: gallery.sizeName(modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // The widget lifted out of the sheet, under the finger, at full size
    DataWidget {
        id: ghostItem

        visible: gallery.ghosting
        z: 30
        preview: true
        floating: true
        entry: ({ "id": "ghost", "kind": gallery.ghostKind, "size": gallery.ghostSize })
        sources: gallery.sources
        settings: gallery.settings
        glassSource: gallery.glass
        plainGlass: gallery.plainGlass
        targetWidth: gallery.spanWidth(gallery.ghostSize) * gallery.cellWidth
        targetHeight: gallery.spanHeight(gallery.ghostSize) * gallery.cellHeight
    }
}
