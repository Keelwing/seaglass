// Stills developed one at a time (FrozenFrame.qml), with a gap of a frame or more between one's end and the next one's
// start, so that a page making many of them never draws two in a frame. An item is a FrozenFrame, or a function that
// makes one when its turn comes; a function that makes none is just a step of the queue. Paused, it starts no new
// one: one already drawing cannot be stopped.
import QtQuick 2.6

Item {
    id: queue

    property bool paused
    property var items: []
    property var current: null
    readonly property bool busy: current !== null || items.length > 0

    function add(item) {
        items = items.concat([item])
        if (current === null && !gap.running)
            next()
    }

    // the one drawing ends by itself, unheard
    function clear() {
        items = []
        gap.stop()
        current = null
    }

    function next() {
        while (!paused && current === null && items.length > 0) {
            var item = items[0]
            items = items.slice(1)
            var frame = typeof item === "function" ? item() : item
            if (frame)
                start(frame)
        }
    }

    function start(frame) {
        current = frame
        var finished = function () {
            frame.done.disconnect(finished)
            if (queue.current !== frame)
                return
            queue.current = null
            // a frame for each pass the still drew: a moment that bakes a field draws more than one
            gap.count(Math.max(1, frame.passes))
        }
        frame.done.connect(finished)
        frame.develop()
    }

    onPausedChanged: {
        if (!paused && !gap.running)
            next()
    }

    // the frames between one still's end and the next one's start (FrameCounter.qml)
    FrameCounter {
        id: gap

        onCounted: queue.next()
    }
}
