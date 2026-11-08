// Counts frames for the stills' pace (FrozenFrame.qml, FreezeQueue.qml): count(n) says counted n frames later, and
// stop() drops a count; started by a binding on running, it counts one frame. It is an animation, because the scene
// graph advances a running animation once a frame, right after the frame's sync, and each step of at is a frame. A
// Timer is no such measure: while no animation runs, Qt stops its animation driver and ends Timers by a clock of its
// own, so that a Timer of 1 ms ends a millisecond or two later, frame or not. With no window exposed Qt advances
// animations from a timer of its own, at the screen's refresh interval, and draws nothing.
import QtQuick 2.6

NumberAnimation {
    id: counter

    // the frames still to come
    property int frames: 1
    property real at

    signal counted

    function count(n) {
        frames = n
        restart()
    }

    target: counter
    property: "at"
    from: 0
    to: 1
    // far longer than any count, which stops it; one that reaches the end counts as done
    duration: 60000
    onAtChanged: {
        // a start sets at back to 0
        if (!running || at <= 0)
            return
        if (frames > 1 && at < 1) {
            frames -= 1
            return
        }
        frames = 0
        stop()
        counted()
    }
}
