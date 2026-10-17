// The pinch between the task switcher's two layouts (docs/SWITCHER.md). It turns a pinch's scale into progress: 0 where
// the pinch started, 1 at the other layout. Pinching in goes from the card row to the grid, pinching out from the grid
// to the card row; halving or doubling the fingers' distance is the whole way (span), on a log scale, so that both feel
// alike. The other way only gives a little (stretch). Let go past the point of no return, or after a quick pinch, and
// progress runs on to 1; else back to 0, without a vibration. The controller (SwitcherController.qml) and the harness
// feed it a PinchArea's pinches:
//   begin(toGrid)  a pinch starts: towards the grid (from the card row) or towards the cards (from the grid)
//   update(scale)  the pinch's scale, 1 at its start
//   end()          the fingers let go: released(switching), then progress runs on or back
// It tells:
//   progress       0 .. 1, animated after end()
//   stretch        0 .. 1: how far the pinch went the other way; back to 0 after end()
//   active         from begin() until progress and stretch have settled; then finished(switched)
//   pace           the animations' slowness (the harness's slow frames)
import QtQuick 2.6

Item {
    id: gesture

    // the whole way, in doublings of the fingers' distance
    property real span: 1
    property real commitAt: 1 / 3
    property real pace: 1

    property bool toGrid
    property real progress
    property real stretch
    readonly property bool armed: progress >= commitAt
    property bool active
    property bool pinching
    readonly property bool settling: settle.running || unstretch.running

    // progress per second, from the last moves
    property real speed
    property double lastTime
    property real lastProgress

    signal released(bool switching)
    signal finished(bool switched)

    function begin(grid) {
        pinching = true
        settle.stop()
        unstretch.stop()
        toGrid = grid
        progress = 0
        stretch = 0
        speed = 0
        lastTime = Date.now()
        lastProgress = 0
        active = true
    }

    function update(scale) {
        if (!pinching)
            return
        // +1: the fingers twice as far apart, -1: half as far
        var doublings = Math.log(Math.max(0.01, scale)) / Math.LN2
        var way = toGrid ? -doublings : doublings
        var p = Math.max(0, Math.min(1, way / span))
        var now = Date.now()
        if (now > lastTime)
            speed = 0.6 * (p - lastProgress) / (now - lastTime) * 1000 + 0.4 * speed
        lastTime = now
        lastProgress = p
        progress = p
        // the other way gives a little, less and less
        var back = Math.max(0, -way) * 3
        stretch = back / (1 + back)
    }

    function end() {
        if (!pinching)
            return
        pinching = false
        // held still before letting go: no quick pinch
        if (Date.now() - lastTime > 120)
            speed = 0
        var go = progress > 0.04 && (armed ? speed > -1.5 : speed > 2.5)
        var left = Math.abs((go ? 1 : 0) - progress)
        settle.to = go ? 1 : 0
        settle.duration = Math.round((140 + (go ? 260 : 220) * left) * pace)
        unstretch.duration = Math.round(300 * pace)
        released(go)
        settle.start()
        if (stretch > 0)
            unstretch.start()
    }

    function settled() {
        if (pinching || settle.running || unstretch.running || !active)
            return
        active = false
        finished(progress >= 0.5)
    }

    NumberAnimation {
        id: settle

        target: gesture
        property: "progress"
        easing.type: Easing.OutCubic
        onRunningChanged: if (!running) gesture.settled()
    }

    NumberAnimation {
        id: unstretch

        target: gesture
        property: "stretch"
        to: 0
        easing.type: Easing.OutCubic
        onRunningChanged: if (!running) gesture.settled()
    }
}
