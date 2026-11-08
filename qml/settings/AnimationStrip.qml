// The viewer's strip (AnimationViewerPage.qml): seven stills of the moment shown, from its start to its end, and a
// playhead over the point the stage shows. A press puts the stage at the point under the finger and a drag moves it;
// where the finger lifts, the viewer makes its large still. The stills are drawn with a kit of their own at their small
// size (PreviewKit.qml), one texel a pixel, and made by the viewer's queue; until then a frame is dark.
import QtQuick 2.6
import Sailfish.Silica 1.0

SilicaItem {
    id: strip

    property Item kit
    // "stock" or a style, and "open", "load" or "close"
    property string style
    property string moment
    // the seconds a loading plays: its stills are at points of them
    property real loadSeconds
    property int frameWidth
    property int frameHeight
    property int gap
    // changes when every still is to be made again
    property int generation
    // the point of the moment the playhead stands at, 0 to 1
    property real head
    // the points of the moment the stills show: progress, or for a loading a fraction of its seconds
    readonly property var points: [0.05, 0.15, 0.28, 0.42, 0.58, 0.75, 0.92]
    // how many stills are made for what the strip shows, counted by the cells themselves: in the viewer's asynchronous
    // Loader the Repeater's cells come after its count, and a binding that asked itemAt() then is never asked again
    property int madeCount
    // every still made for what the strip shows: only then can it be dragged through
    readonly property bool ready: madeCount === points.length
    readonly property bool held: touch.pressed

    // pressed or dragged, at a point of the moment (0 to 1)
    signal scrubbed(real at)
    signal lifted(real at)
    signal canceled

    // a still, for the viewer's queue
    function still(index) {
        var cell = cells.itemAt(index)
        return cell ? cell.still : null
    }

    // what a still is made for: a change makes it again
    function keyOf(id, moment, at) {
        return kit === null ? "-" : [id, moment, at, kit.side, kit.tint, kit.useTint, generation].join(" ")
    }

    // the places along the strip that the points stand at: a still's middle at its point, and the ends at 0 and 1
    function marks() {
        var list = [[0, 0]]
        for (var i = 0; i < points.length; i++)
            list.push([points[i], i * (frameWidth + gap) + frameWidth / 2])
        list.push([1, width])
        return list
    }

    // where a point of the moment lies, in proportion between the marks
    function place(at) {
        var list = marks()
        for (var i = 1; i < list.length; i++) {
            var from = list[i - 1]
            var to = list[i]
            if (at <= to[0] || i === list.length - 1)
                return from[1] + (to[1] - from[1]) * (at - from[0]) / (to[0] - from[0])
        }
        return width
    }

    // and the point at a place
    function pointAt(x) {
        var list = marks()
        var along = Math.max(0, Math.min(width, x))
        for (var i = 1; i < list.length; i++) {
            var from = list[i - 1]
            var to = list[i]
            if (along <= to[1] || i === list.length - 1)
                return from[0] + (to[0] - from[0]) * (along - from[1]) / Math.max(1, to[1] - from[1])
        }
        return 1
    }

    width: points.length * frameWidth + (points.length - 1) * gap
    height: frameHeight

    Repeater {
        id: cells

        model: strip.points

        Item {
            readonly property Item still: frame
            readonly property bool made: frame.madeFor === frame.wanted

            x: index * (strip.frameWidth + strip.gap)
            width: strip.frameWidth
            height: strip.frameHeight
            onMadeChanged: strip.madeCount += made ? 1 : -1
            Component.onDestruction: {
                if (made)
                    strip.madeCount--
            }

            Rectangle {
                anchors.fill: parent
                visible: !frame.visible
                color: Theme.rgba("white", 0.06)
            }

            FrozenFrame {
                id: frame

                // what it was last made for, and is being made for
                property string madeFor
                property string making
                readonly property string wanted: strip.keyOf(style, moment, at)

                anchors.fill: parent
                // shown once it is made for what the strip shows; while it is made, the old one (a grab needs it shown)
                visible: parent.made || developing
                style: strip.style
                moment: strip.moment
                at: strip.moment === "load" ? modelData * strip.loadSeconds : modelData
                kit: strip.kit
                onDone: madeFor = making
            }
        }
    }

    // over the still at the playhead
    Rectangle {
        x: Math.max(0, Math.min(strip.width - width, strip.place(strip.head) - width / 2))
        width: strip.frameWidth
        height: strip.frameHeight
        visible: strip.ready
        color: "transparent"
        border.width: Math.round(2 * Theme.pixelRatio)
        border.color: strip.palette.highlightColor
    }

    // a press jumps, a drag scrubs; once the finger has gone sideways, the page's own swipe cannot take it
    MouseArea {
        id: touch

        property real pressX

        anchors.fill: parent
        enabled: strip.ready
        onPressed: {
            pressX = mouse.x
            strip.scrubbed(strip.pointAt(mouse.x))
        }
        onPositionChanged: {
            if (!preventStealing && Math.abs(mouse.x - pressX) > Theme.startDragDistance)
                preventStealing = true
            strip.scrubbed(strip.pointAt(mouse.x))
        }
        onReleased: {
            preventStealing = false
            strip.lifted(strip.pointAt(mouse.x))
        }
        onCanceled: {
            preventStealing = false
            strip.canceled()
        }
    }
}
