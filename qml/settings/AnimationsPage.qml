// Settings: the effects with which apps open, load and close (docs/ANIMATIONS.md), as a sheet of still frames: a row
// for each style and Stock, a column for each moment, every frame caught at a telling point of its moment on a
// made-up home screen. Nothing on the page moves: the frames are made one at a time (AnimationSheetBuilder.qml), and
// then they are textures, which become one picture kept for the next visit. A tap on a frame, a style's name or a
// moment's head opens the viewer, which plays them (AnimationViewerPage.qml). Looking changes no setting; only the
// switch and the settings under the sheet do here.
//
// Nothing is made before the page is on top and the window knows its OpenGL version (started): a push draws only the
// header, the switch, the heads and the names, and compiles only what they need. Qt 5.6 compiles every type a file
// names, those in a Component written out in a Loader too, so the picture, Feel and the builder are files their
// Loaders name by URL, compiled when a Loader first becomes active. At started they come one after another, in that
// order: while a file compiles on the loader thread, whatever the GUI thread makes waits for it. Each Loader sets its
// source when it becomes active and empties it when it goes: one that goes while its file still compiles would make
// the item all the same once the file has compiled.
import QtQuick 2.6
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import "../animations/styles.js" as Styles
import "stills.js" as Stills

Page {
    id: page

    allowedOrientations: Orientation.All

    // whether the sheet may be made: only on top, with the Settings app in front (always in the harness, which has no
    // page stack and whose window is never the active one). A page in a stack has its pageContainer
    readonly property bool live: !page.pageContainer || (status === PageStatus.Active && Qt.application.active)
    // the page swiped back, which leaves it Active until the swipe ends, or turning: no still is made and nothing is
    // grabbed or saved meanwhile, as while the view moves
    readonly property bool navigating: page.pageContainer !== null && page.pageContainer.dragInProgress === true
                                       || page.orientationTransitionRunning
    // first true once the page is live and the window knows its GL version; the 0 ms wait lets a harness scene set
    // ambienceFile first
    property bool started
    // the window's GL version (until it has its OpenGL context, the default format's). Read here, on an Item: read in a
    // Timer, OpenGLInfo crashes Qt 5.6
    readonly property int glMajor: OpenGLInfo.majorVersion

    ConfigurationValue {
        id: ambiencePicture

        key: "/desktop/jolla/background/portrait/home_picture_filename"
    }
    // the ambience's picture, for the viewer (the harness sets a stock one). The sheet never shows it
    property string ambienceFile: ambiencePicture.value
    // false in the harness: no file is read or written, and the sheet is made on every visit
    property bool keepSheet: true
    property string sheetFolder: StandardPaths.home + "/.cache"
    // the picture the frames become (the Loader over the black panel) sets the last three: no frames are wanted, the
    // picture shows the sheet, and the picture is not made yet. Without it the frames are the sheet. bench page sets
    // flatten false, before the page starts, to compare the frames with the picture
    property bool flatten: true
    property bool framesHeld
    property bool pictured
    property bool pictureLoading

    // the sheet, the same size in portrait and landscape: a column of names, and 3 columns of frames to the right edge
    readonly property int sheetSide: Math.min(Screen.width, Screen.height)
    readonly property int gap: Math.max(2, Math.floor(3 * Theme.pixelRatio))
    readonly property int nameWidth: Math.round(sheetSide * 0.225)
    readonly property int cellWidth: Math.floor((sheetSide - nameWidth - 2 * gap) / 3)
    readonly property int cellHeight: Math.round(cellWidth * 2 / 3)
    readonly property int framesWidth: 3 * cellWidth + 2 * gap
    readonly property int framesHeight: Stills.ORDER.length * (cellHeight + gap) - gap
    // the columns: a moment, its key in the settings, and its head
    readonly property var moments: [{ "moment": "open", "key": "open", "text": qsTr("Opening") },
                                    { "moment": "load", "key": "loading", "text": qsTr("Loading") },
                                    { "moment": "close", "key": "close", "text": qsTr("Closing") }]

    // what the effects take of the ambience, as the home screen gives it to them
    readonly property vector3d tint: Qt.vector3d(Theme.highlightColor.r, Theme.highlightColor.g,
                                                 Theme.highlightColor.b)
    readonly property real useTint: settings.ambience ? 1 : 0
    // GLSL ES 3.00, which the stills are drawn with where the GPU has it: known by the time the page has started
    readonly property bool es3: OpenGLInfo.renderableType === OpenGLInfo.OpenGLES && glMajor >= 3
    // what the sheet is made for, its cells and gaps among it: a change makes it again
    readonly property string sheetKey: Stills.KEY + " " + tint.x.toFixed(3) + "," + tint.y.toFixed(3) + ","
                                       + tint.z.toFixed(3) + " " + cellWidth + "x" + cellHeight + "+" + gap + " "
                                       + es3 + " " + Theme.colorScheme + (settings.ambience ? " tinted" : " natural")
    // the sheet made for the present key: every frame, or the picture of them
    readonly property bool built: building.item !== null && building.item.built || pictured
    // the viewer's page, compiled at rest after the sheet is made, so that the first tap does not wait for it
    property var viewerComponent: null

    // a style's name, or Stock
    function styleName(id) {
        var style = Styles.find(id)
        return style ? style.name : qsTr("Stock")
    }

    // what a moment plays now, as its head names it
    function inUseName(key) {
        var used = Stills.inUse(settings, key)
        return used === "surprise" ? qsTr("Surprise me") : styleName(used)
    }

    // whether a style plays one of the moments
    function inUse(id) {
        for (var i = 0; i < moments.length; i++) {
            if (Stills.inUse(settings, moments[i].key) === id)
                return true
        }
        return false
    }

    // the group's name above the first style of a group
    function groupAbove(row) {
        var style = Styles.find(Stills.ORDER[row])
        var before = row > 0 ? Styles.find(Stills.ORDER[row - 1]) : null
        return style && (!before || before.group !== style.group) ? style.group : ""
    }

    // the viewer on a style and moment ("open", "load", "close"): "one" plays it, "round" plays the style's loading,
    // opening and closing, "tour" the moment in every style in turn
    function openViewer(style, moment, mode) {
        if (!page.pageContainer)
            return
        var viewer = viewerComponent !== null && viewerComponent.status === Component.Ready
                ? viewerComponent : Qt.resolvedUrl("AnimationViewerPage.qml")
        pageStack.push(viewer, { "style": style, "moment": moment, "mode": mode, "ambienceFile": page.ambienceFile })
    }

    AnimationSettings {
        id: settings
    }

    Timer {
        interval: 0
        running: page.live && !page.started && page.glMajor > 0
        onTriggered: page.started = true
    }

    Timer {
        interval: 500
        running: page.built && page.viewerComponent === null && page.live && !flick.moving
        onTriggered: page.viewerComponent = Qt.createComponent(Qt.resolvedUrl("AnimationViewerPage.qml"),
                                                               Component.Asynchronous)
    }

    // the frames, made one at a time once the page has started and Feel is made; paused while the page is not on top,
    // or it or the view moves. Its properties come with the source, so they are set before anything in it is made:
    // its kit is made at the cell's size
    Loader {
        id: building

        active: page.started && !page.framesHeld && (feel.status === Loader.Ready || feel.status === Loader.Error)
        asynchronous: true
        onActiveChanged: {
            if (!active) {
                source = ""
                return
            }
            setSource(Qt.resolvedUrl("AnimationSheetBuilder.qml"), {
                "cells": grid,
                "cellWidth": Qt.binding(function () { return page.cellWidth }),
                "cellHeight": Qt.binding(function () { return page.cellHeight }),
                "gap": Qt.binding(function () { return page.gap }),
                "tint": Qt.binding(function () { return page.tint }),
                "useTint": Qt.binding(function () { return page.useTint }),
                "key": Qt.binding(function () { return page.sheetKey }),
                "paused": Qt.binding(function () { return !page.live || flick.moving || page.navigating })
            })
        }
    }

    SilicaFlickable {
        id: flick

        anchors.fill: parent
        contentHeight: Math.max(sheet.y + sheet.height, feel.y + feel.height) + Theme.paddingLarge

        VerticalScrollDecorator {}

        Column {
            id: topPart

            width: page.isPortrait ? page.width : page.width - page.sheetSide

            PageHeader {
                title: qsTr("Animations")
            }

            TextSwitch {
                text: qsTr("App animations")
                description: qsTr("Off: the Sailfish fade.")
                checked: settings.enabled
                automaticCheck: false
                onClicked: settings.enabled = !settings.enabled
            }
        }

        // the heads, the names and the frames; at the right edge in landscape too, so that turning makes nothing new
        Item {
            id: sheet

            x: page.width - page.sheetSide
            y: page.isPortrait ? topPart.height : 0
            width: page.sheetSide
            height: heads.height + page.framesHeight

            // a tap plays the column, every style in turn
            Row {
                id: heads

                x: page.nameWidth
                spacing: page.gap

                Repeater {
                    model: page.moments

                    BackgroundItem {
                        width: page.cellWidth
                        height: headText.height + 2 * Theme.paddingMedium
                        onClicked: page.openViewer(Stills.ORDER[0], modelData.moment, "tour")

                        Column {
                            id: headText

                            x: Theme.paddingSmall
                            y: Theme.paddingMedium
                            width: parent.width - 2 * x

                            Label {
                                width: parent.width
                                truncationMode: TruncationMode.Fade
                                text: modelData.text
                            }

                            Label {
                                width: parent.width
                                truncationMode: TruncationMode.Fade
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: settings.enabled ? palette.highlightColor : palette.secondaryColor
                                text: page.inUseName(modelData.key)
                            }
                        }
                    }
                }
            }

            Repeater {
                model: Stills.ORDER

                Item {
                    y: heads.height + index * (page.cellHeight + page.gap)
                    width: page.nameWidth
                    height: page.cellHeight

                    Column {
                        x: Theme.horizontalPageMargin
                        width: parent.width - x - Theme.paddingMedium
                        anchors.verticalCenter: parent.verticalCenter

                        Label {
                            width: parent.width
                            visible: text !== ""
                            truncationMode: TruncationMode.Fade
                            font.pixelSize: Theme.fontSizeTiny
                            font.capitalization: Font.AllUppercase
                            color: palette.secondaryHighlightColor
                            text: page.groupAbove(index)
                        }

                        Label {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            fontSizeMode: Text.HorizontalFit
                            minimumPixelSize: Theme.fontSizeExtraSmall
                            font.pixelSize: Theme.fontSizeSmall
                            color: page.inUse(modelData) ? palette.highlightColor : palette.primaryColor
                            text: page.styleName(modelData)
                        }
                    }
                }
            }

            // behind the frames, and in the gaps between them
            Rectangle {
                x: page.nameWidth
                y: heads.height
                width: page.framesWidth
                height: page.framesHeight
                color: "black"
            }

            // the frames as one picture once they are made, and with keepSheet the picture kept in sheetFolder from an
            // earlier visit (AnimationSheetPicture.qml). Under the frames, so that a new build covers the old picture
            // cell by cell. Nothing else on the page names it. No frame is wanted from before the page starts until
            // the picture is made and has read its kept key; one that fails to load wants them
            Loader {
                id: sheetPicture

                readonly property bool wanted: page.keepSheet || page.flatten

                x: grid.x
                y: grid.y
                width: page.framesWidth
                height: page.framesHeight
                active: page.started && wanted
                asynchronous: true
                onActiveChanged: {
                    if (!active) {
                        source = ""
                        return
                    }
                    setSource(Qt.resolvedUrl("AnimationSheetPicture.qml"), {
                        "frames": grid,
                        "key": Qt.binding(function () { return page.sheetKey }),
                        "path": Qt.binding(function () {
                            return page.sheetFolder + "/seaglass-animations-"
                                    + (settings.ambience ? "tinted" : "natural")
                        }),
                        "keep": Qt.binding(function () { return page.keepSheet }),
                        "flatten": Qt.binding(function () { return page.flatten }),
                        "built": Qt.binding(function () { return building.item !== null && building.item.built }),
                        "still": Qt.binding(function () { return page.live && !flick.moving && !page.navigating })
                    })
                }

                Binding {
                    target: page
                    property: "framesHeld"
                    value: sheetPicture.wanted && sheetPicture.status !== Loader.Error
                           && (sheetPicture.item === null || sheetPicture.item.holds)
                }

                Binding {
                    target: page
                    property: "pictured"
                    value: sheetPicture.item !== null && sheetPicture.item.shows
                }

                // true until it is made, from before the page starts: Feel waits for it
                Binding {
                    target: page
                    property: "pictureLoading"
                    value: sheetPicture.wanted && sheetPicture.status !== Loader.Ready
                           && sheetPicture.status !== Loader.Error
                }
            }

            // the frames go here (AnimationSheetBuilder.qml), a cell and a gap apart
            Item {
                id: grid

                x: page.nameWidth
                y: heads.height
                width: page.framesWidth
                height: page.framesHeight
            }

            // the style each moment is set to; faint while the animations are off, as what would play, and gone for
            // a moment Surprise me picks. In the highlight of a light-on-dark palette, as the frames are light on dark
            // in any ambience
            SilicaControl {
                id: marks

                palette.colorScheme: Theme.LightOnDark

                Repeater {
                    model: page.moments

                    Rectangle {
                        readonly property string used: Stills.inUse(settings, modelData.key)

                        x: grid.x + index * (page.cellWidth + page.gap)
                        y: grid.y + Math.max(0, Stills.ORDER.indexOf(used)) * (page.cellHeight + page.gap)
                        width: page.cellWidth
                        height: page.cellHeight
                        visible: page.started && used !== "surprise"
                        opacity: settings.enabled ? 1 : 0.7
                        color: "transparent"
                        border.width: Math.round(2 * Theme.pixelRatio)
                        border.color: marks.palette.highlightColor
                    }
                }
            }

            Rectangle {
                x: touch.column < 0 ? 0 : grid.x + touch.column * (page.cellWidth + page.gap)
                y: grid.y + touch.row * (page.cellHeight + page.gap)
                width: touch.column < 0 ? page.nameWidth : page.cellWidth
                height: page.cellHeight
                visible: touch.pressed && touch.row >= 0
                color: Theme.rgba(page.palette.highlightBackgroundColor, Theme.highlightBackgroundOpacity)
            }

            // a frame plays its moment, a name the style's loading, opening and closing
            MouseArea {
                id: touch

                property int row: -1
                // -1 for the name
                property int column: -1

                y: grid.y
                width: parent.width
                height: page.framesHeight
                onPressed: {
                    row = Math.min(Stills.ORDER.length - 1, Math.floor(mouse.y / (page.cellHeight + page.gap)))
                    var across = Math.floor((mouse.x - grid.x) / (page.cellWidth + page.gap))
                    column = mouse.x < grid.x ? -1 : Math.min(2, across)
                }
                onClicked: {
                    if (column < 0)
                        page.openViewer(Stills.ORDER[row], "load", "round")
                    else
                        page.openViewer(Stills.ORDER[row], page.moments[column].moment, "one")
                }
            }
        }

        // Feel (AnimationFeel.qml), under the sheet; in landscape under the switch. Once the picture is made
        Loader {
            id: feel

            y: page.isPortrait ? sheet.y + sheet.height + Theme.paddingLarge : topPart.height
            width: topPart.width
            active: page.started && !page.pictureLoading
            asynchronous: true
            onActiveChanged: {
                if (!active) {
                    source = ""
                    return
                }
                setSource(Qt.resolvedUrl("AnimationFeel.qml"), {
                    "settings": settings,
                    "live": Qt.binding(function () { return page.live })
                })
            }
        }
    }

    // the moments' names over the frames, once the heads have gone up out of view; in portrait under the top cutout,
    // as a page header keeps its title
    Item {
        id: pinned

        readonly property real inset: page.orientation === Orientation.Portrait ? Screen.topCutout.height : 0

        x: sheet.x + page.nameWidth
        width: page.framesWidth
        height: inset + Theme.itemSizeExtraSmall
        visible: flick.contentY > sheet.y + heads.height - height

        Rectangle {
            anchors.fill: parent
            color: Theme.rgba("black", 0.7)
        }

        Row {
            y: pinned.inset
            spacing: page.gap

            Repeater {
                model: page.moments

                Label {
                    width: page.cellWidth
                    height: Theme.itemSizeExtraSmall
                    leftPadding: Theme.paddingSmall
                    verticalAlignment: Text.AlignVCenter
                    truncationMode: TruncationMode.Fade
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: "white"
                    text: modelData.text
                }
            }
        }
    }
}
