// The closing effect over a cover closed in the switcher (docs/ANIMATIONS.md). SwitcherController.qml makes one at
// the cover's place when the stock close starts (SwitcherItem.close(), hooked), and it goes when the effect ends.
// The stock removes the cover's delegate after 200 ms, and a ShaderEffectSource loses its picture with its source
// item: so the frozen cover is copied once more, a moment later, into a picture of our own.
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
    property real progress
    property bool copied
    readonly property bool shards: Styles.has(style, "shards")
    // mipmaps for the blur of GLSL ES 3.00 (common.glsl), for the styles that blur
    readonly property bool blur: Shaders.es3 === true && Styles.has(style, "blur")

    // the cover, frozen as it was; hidden itself until the stock takes it away
    ShaderEffectSource {
        id: frozen

        width: closing.width
        height: closing.height
        visible: false
        live: false
        mipmap: closing.blur
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

    Timer {
        id: keep

        interval: 60
        onTriggered: {
            kept.scheduleUpdate()
            closing.copied = true
        }
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
        source: closing.copied ? kept : frozen
        noiseTex: noise
        progress: closing.progress
        origin: Qt.point(0.5, 0.45)
        originRect: Qt.rect(0, 0, 1, 1)
        radiusPx: closing.radius
        tint: closing.tint
        useTint: closing.useTint
    }

    Shards {
        id: pieces

        anchors.fill: parent
        visible: closing.shards && ready
        active: closing.shards
        capacity: 70
        rays: 9
        rings: [0.08, 0.2, 0.38, 0.6, 1.0]
        source: closing.copied ? kept : frozen
        progress: closing.progress
        impact: Qt.point(0.5, 0.45)
        tint: closing.tint
        useTint: closing.useTint
        onReadyChanged: {
            if (ready && closing.shards)
                build()
        }
    }

    NumberAnimation {
        id: run

        target: closing
        property: "progress"
        from: 0
        to: 1
        duration: closing.duration
        onStopped: closing.destroy()
    }

    Component.onCompleted: {
        frozen.scheduleUpdate()
        keep.start()
        run.start()
    }
}
