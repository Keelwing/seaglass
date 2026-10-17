// A still that hides a cover's redraw (docs/SWITCHER.md). In a switch between the task switcher's layouts the apps draw
// their covers again at the other layout's size, with their own fonts and spacing: drawn at once, the cover's look
// would jump. freeze() takes a still of source as it is now and lays it over the live cover; once the cover is drawn
// again (redrawn(), or after a timeout, as an app may never redraw), the still fades out. The live cover stays opaque
// under it: a cross-fade of two half-faded layers lets the wallpaper through.
//   source  what the still shows
//   fade    1: the still over the live cover .. 0: the live cover alone
//   busy    a still is up or waiting
//   pace    the fade's slowness (the harness's slow frames)
import QtQuick 2.6

Item {
    id: still

    property Item source
    property real fade
    property bool waiting
    property real pace: 1
    readonly property bool busy: waiting || fade > 0

    function freeze() {
        if (!source)
            return
        fadeIn.stop()
        shot.scheduleUpdate()
        fade = 1
        waiting = true
        late.restart()
    }

    function redrawn() {
        if (!waiting)
            return
        waiting = false
        late.stop()
        fadeIn.duration = Math.round(240 * pace)
        fadeIn.start()
    }

    ShaderEffectSource {
        id: shot

        anchors.fill: parent
        sourceItem: still.source
        live: false
        hideSource: false
        smooth: true
        visible: still.fade > 0
        opacity: still.fade
    }

    // an app that never draws again (or draws the same size): the live cover comes back anyway
    Timer {
        id: late

        interval: 700
        onTriggered: still.redrawn()
    }

    NumberAnimation {
        id: fadeIn

        target: still
        property: "fade"
        to: 0
        easing.type: Easing.InOutQuad
    }
}
