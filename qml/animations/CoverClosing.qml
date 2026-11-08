// The closing effect over a cover closed in the switcher (docs/ANIMATIONS.md). SwitcherController.qml makes one at
// the cover's place when the stock close starts (SwitcherItem.close(), hooked), and it goes when the effect ends.
// The stock removes the cover's delegate after 200 ms, and a ShaderEffectSource loses its picture with its source
// item: so the frozen cover is copied once more, in the same frame, into a picture of our own, which is all the
// effect reads. Nothing it reads changes while it runs: a write from the GUI thread in the frame after a run ends puts
// the GUI side's progress, 0, back into the effect, and the cover shows whole for that frame.
import QtQuick 2.6
import "styles.js" as Styles
import "shaders.js" as Shaders

Item {
    id: closing

    // the cover as drawn (the stock delegate's contentItem)
    property Item cover
    property string style
    property int duration: 600
    property real radius
    property vector3d tint: Qt.vector3d(1, 1, 1)
    property real useTint
    property bool begun
    readonly property bool shards: Styles.has(style, "shards")
    // mipmaps for the blur of GLSL ES 3.00 (common.glsl), for the styles that blur
    readonly property bool blur: Shaders.es3 === true && Styles.has(style, "blur")

    // the moment starts, once, as soon as its shader is there
    function begin() {
        if (begun)
            return
        begun = true
        giveUp.stop()
        if (shards) {
            pieces.build()
            pieces.play(duration)
        } else {
            effect.play(duration)
        }
    }

    // the cover, frozen as it was; hidden itself until the stock takes it away. Only the copy below reads it
    ShaderEffectSource {
        id: frozen

        width: closing.width
        height: closing.height
        visible: false
        live: false
        hideSource: true
        sourceItem: closing.cover
    }

    // a copy of the frozen cover that outlives it
    Item {
        id: copyOf

        width: closing.width
        height: closing.height

        ShaderEffect {
            property variant source: frozen

            anchors.fill: parent
        }
    }

    ShaderEffectSource {
        id: kept

        width: closing.width
        height: closing.height
        visible: false
        live: false
        mipmap: closing.blur
        hideSource: true
        sourceItem: copyOf
    }

    NoiseTile {
        id: noise
    }

    Effect {
        id: effect

        anchors.fill: parent
        visible: ready && !closing.shards
        style: closing.shards ? "" : closing.style
        moment: "close"
        source: kept
        noiseTex: noise
        origin: Qt.point(0.5, 0.45)
        originRect: Qt.rect(0, 0, 1, 1)
        radiusPx: closing.radius
        tint: closing.tint
        useTint: closing.useTint
        onReadyChanged: {
            if (ready)
                closing.begin()
        }
        onEnded: closing.destroy()
    }

    Shards {
        id: pieces

        anchors.fill: parent
        visible: closing.shards && ready
        active: closing.shards
        rays: 9
        rings: [0.08, 0.2, 0.38, 0.6, 1.0]
        source: kept
        impact: Qt.point(0.5, 0.45)
        tint: closing.tint
        useTint: closing.useTint
        onReadyChanged: {
            if (ready)
                closing.begin()
        }
        onEnded: closing.destroy()
    }

    // a shader that never comes must not leave this behind; once the run has begun, its watchdog sees to that
    Timer {
        id: giveUp

        interval: 1500
        running: true
        onTriggered: closing.destroy()
    }

    Component.onCompleted: {
        // both grabs in the first frame: Qt brings a layer's inputs up to date before it draws one, so the copy's grab
        // takes the frozen cover's first
        frozen.scheduleUpdate()
        kept.scheduleUpdate()
        if (shards ? pieces.ready : effect.ready)
            begin()
    }
}
