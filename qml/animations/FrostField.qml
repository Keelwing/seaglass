// What Frost's opening and closing read instead of working it out per pixel and frame (docs/ANIMATIONS.md): a pattern
// that does not change, and for a closing, whose picture holds still, the picture blurred. Each is one pass of
// shaders/frost-field.frag, drawn once into a texture of its own, the size of the Effect that owns it. Effect.qml loads
// this while such a moment is shown or runs, so that the first frame draws it and the textures go when the moment does.
// The blur is of the picture as it is then: an Effect driven by hand gets a new one by being hidden and shown again.
import QtQuick 2.6

Item {
    id: field

    // the Effect it is for
    property Item owner
    readonly property Item pattern: patternCopy
    readonly property Item blurred: blur.item ? blur.item.copy : null

    Effect {
        id: patternPass

        anchors.fill: parent
        visible: ready
        style: "frost"
        moment: "field"
        blending: false
        time: 0
        source: field.owner ? field.owner.noiseTex : null
        noiseTex: field.owner ? field.owner.noiseTex : null
    }

    ShaderEffectSource {
        id: patternCopy

        anchors.fill: parent
        visible: false
        // read texel by texel. Smooth, a GPU's rounding at the texels' centres lets in some of a neighbour's rime
        smooth: false
        live: false
        hideSource: true
        // setting the source grabs once; before the shader is there it would grab nothing
        sourceItem: patternPass.ready ? patternPass : null
        onWidthChanged: scheduleUpdate()
        onHeightChanged: scheduleUpdate()
    }

    Loader {
        id: blur

        anchors.fill: parent
        active: field.owner !== null && field.owner.moment === "close"

        sourceComponent: Item {
            readonly property Item copy: blurCopy

            Effect {
                id: blurPass

                anchors.fill: parent
                visible: ready
                style: "frost"
                moment: "field"
                part: 1
                blending: false
                time: 0
                source: field.owner ? field.owner.source : null
                noiseTex: field.owner ? field.owner.noiseTex : null
            }

            ShaderEffectSource {
                id: blurCopy

                anchors.fill: parent
                visible: false
                smooth: false
                live: false
                hideSource: true
                sourceItem: blurPass.ready ? blurPass : null
                onWidthChanged: scheduleUpdate()
                onHeightChanged: scheduleUpdate()
            }
        }
    }
}
