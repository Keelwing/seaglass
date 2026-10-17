// One effect: a style's shader for a moment (shaders/STYLE-MOMENT.frag, behind shaders/common.glsl and the style's
// libraries) with the inputs every effect has (docs/ANIMATIONS.md). Show it only when ready: until its shader is
// loaded it would draw its source plainly. A shader that does not compile draws nothing, and Qt says so in the log
// ("QOpenGLShader::compile"). ShaderEffect's status cannot tell: on Sailfish OS 5.2 it reads Error for shaders that
// compiled and draw.
import QtQuick 2.6
import "shaders.js" as Shaders
import "styles.js" as Styles

ShaderEffect {
    id: effect

    property string style
    // "open", "close" or "load"
    property string moment
    // what it draws (a layer, a cover or an icon), and the noise tile (NoiseTile.qml)
    property variant source
    property variant noiseTex
    property real progress
    property real time
    // in the effect's own coordinates, 0 to 1 with y down
    property point origin: Qt.point(0.5, 0.5)
    property rect originRect: Qt.rect(0.35, 0.4, 0.3, 0.2)
    property real aspect: width / Math.max(1, height)
    property size resolution: Qt.size(width, height)
    property vector3d tint: Qt.vector3d(1, 1, 1)
    property real useTint
    property real radiusPx
    // closing: the window's top edge as the swipe left it (0 to 1)
    property real clipTop

    readonly property string shaderName: style !== "" && moment !== "" ? style + "-" + moment : ""
    // GLSL ES 3.00 where the GPU has it (the Jolla Phone's Mali-G610 does): a blur from mipmaps. Known once the
    // window has its OpenGL context. (An effect needs a source: with no sampler, Qt 5.6 draws a GLSL ES 3.00 effect
    // nowhere.)
    readonly property int glMajor: OpenGLInfo.majorVersion
    readonly property bool es3: OpenGLInfo.renderableType === OpenGLInfo.OpenGLES && glMajor >= 3
    property bool loaded
    readonly property bool ready: loaded
    property bool gone

    function load() {
        loaded = false
        var name = shaderName
        var es3 = effect.es3
        if (name === "" || glMajor === 0)
            return
        Shaders.load(Qt.resolvedUrl("shaders/"), name, Styles.libs(style), es3, function (text) {
            if (effect.gone || effect.shaderName !== name || effect.es3 !== es3 || text === "")
                return
            effect.vertexShader = es3 ? Shaders.ES3_VERTEX : ""
            effect.fragmentShader = text
            effect.loaded = true
        })
    }

    // the heaviest styles (the grains) are drawn at half the resolution and scaled up
    readonly property bool half: Styles.has(style, "half")
    layer.enabled: half
    layer.smooth: true
    layer.textureSize: Qt.size(Math.ceil(width / 2), Math.ceil(height / 2))

    blending: true
    onShaderNameChanged: load()
    onGlMajorChanged: {
        if (glMajor > 0)
            Shaders.es3 = es3
        load()
    }
    Component.onCompleted: {
        if (glMajor > 0)
            Shaders.es3 = es3
        load()
    }
    Component.onDestruction: gone = true
}
