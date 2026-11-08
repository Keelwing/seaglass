// Makes the Animations page's sheet (AnimationsPage.qml): the kit of textures (PreviewKit.qml), then a still of every
// style's opening, loading and closing (FrozenFrame.qml), row by row, each made only when its turn comes, right over
// its cell of the page's grid, and developed one at a time (FreezeQueue.qml). The frames are the sheet, and they read
// the kit's textures, so this stays loaded for as long as they show. A new key makes the stills again, over the old
// ones.
import QtQuick 2.6
import "stills.js" as Stills

Item {
    id: builder

    // the page's Item the frames go in, a cell's size and the gap between cells
    property Item cells
    property int cellWidth
    property int cellHeight
    property int gap
    property vector3d tint: Qt.vector3d(1, 1, 1)
    property real useTint
    // no new still while true: the page is not on top, or its view moves
    property bool paused
    // what the stills are made for: their colours and size
    property string key
    property string builtKey
    readonly property bool built: builtKey !== "" && builtKey === key
    readonly property Item kit: kitLoader.item
    readonly property bool kitReady: kit !== null && kit.ready
    // the frames, by row and column
    property var frames: []

    signal done

    function build() {
        queue.clear()
        builtKey = ""
        var key = builder.key
        for (var row = 0; row < Stills.ORDER.length; row++) {
            for (var column = 0; column < 3; column++)
                queue.add(cell(row, column))
        }
        queue.add(function () {
            builder.builtKey = key
            builder.done()
            return null
        })
    }

    // a cell's turn: its frame, made the first time
    function cell(row, column) {
        return function () {
            var list = builder.frames
            var index = row * 3 + column
            if (!list[index]) {
                list[index] = make(row, column)
                builder.frames = list
            }
            return list[index]
        }
    }

    // an opening or closing shows a band of the screen as high as the cell, a loading the cover at the cell's shape
    function make(row, column) {
        var style = Stills.ORDER[row]
        var moment = ["open", "load", "close"][column]
        var cut = Qt.rect(0, 0, 0, 0)
        if (moment !== "load") {
            var high = kit.sideHeight
            var centre = Stills.band(style, moment, kit.iconRect.y + kit.iconRect.height / 2)
            var top = Math.round(Math.max(0, Math.min(high - cellHeight, centre * high - cellHeight / 2)))
            cut = Qt.rect(0, top, cellWidth, cellHeight)
        }
        return frameMaker.createObject(cells, {
            "x": column * (cellWidth + gap), "y": row * (cellHeight + gap), "width": cellWidth, "height": cellHeight,
            "style": style, "moment": moment, "at": Stills.at(style, moment), "cut": cut, "wideLoad": true
        })
    }

    onKitReadyChanged: {
        if (kitReady)
            build()
    }
    onKeyChanged: {
        if (kitReady)
            build()
    }
    // the kit goes with this item, after this handler, and the frames a turn later. A frame still in the window
    // between the two is synced with its textures gone, hidden or not, and Qt warns for each: out of it first
    Component.onDestruction: {
        queue.clear()
        for (var i = 0; i < frames.length; i++) {
            if (frames[i]) {
                frames[i].parent = null
                frames[i].destroy()
            }
        }
    }

    Loader {
        id: kitLoader

        asynchronous: true
        sourceComponent: Component {
            PreviewKit {
                side: builder.cellWidth
                picture: ""
                tint: builder.tint
                useTint: builder.useTint
            }
        }
    }

    FreezeQueue {
        id: queue

        paused: builder.paused
    }

    Component {
        id: frameMaker

        FrozenFrame {
            kit: builder.kit
        }
    }
}
