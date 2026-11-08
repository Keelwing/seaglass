// One effect: a style's shader for a moment (shaders/STYLE-MOMENT.frag, behind shaders/common.glsl and the style's
// libraries) with the inputs every effect has (docs/ANIMATIONS.md). Show it only when ready: until its shader is
// loaded it would draw its source plainly, or, where the window uses GLSL ES 3.00, fail in the batcher ("Problematic
// Vertex shader") and draw a blank. A shader that does not compile draws nothing, and Qt says so in the log
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
    // seconds: of the effect itself for an opening or closing (its progress times its length), a running clock for
    // a loading
    property real time
    // in the effect's own coordinates, 0 to 1 with y down
    property point origin: Qt.point(0.5, 0.5)
    property rect originRect: Qt.rect(0.35, 0.4, 0.3, 0.2)
    property real aspect: width / Math.max(1, height)
    property size resolution: Qt.size(width, height)
    property vector3d tint: Qt.vector3d(1, 1, 1)
    property real useTint
    // the corners, in pixels: of the cover a loading plays on, of the cover closing, or of what an app opens from
    // (an icon is round; 0 from the middle of the screen)
    property real radiusPx
    // closing: the window's top edge as the swipe left it (0 to 1)
    property real clipTop
    // what a moment with a field reads of it (FrostField.qml): the frost pattern, and a closing's blurred picture. The
    // noise tile stands in without one: a texture input that goes from an item to null makes Qt warn
    readonly property variant fieldTex: fieldLoader && fieldLoader.item ? fieldLoader.item.pattern : noiseTex
    readonly property variant blurTex: fieldLoader && fieldLoader.item && fieldLoader.item.blurred
                                       ? fieldLoader.item.blurred : noiseTex
    // the field's Loader (fieldComponent), made by fit() for a moment with a field only. Not named field: a binding on
    // an Effect finds the Effect's own properties before the ids of an outer component, and FrostField.qml's blur pass
    // reads its root by the id field
    property Item fieldLoader: null

    // plays the moment on the render thread, so that it keeps moving while the GUI thread is busy, as it is in the
    // compositor while an app starts. progress and time keep their old values on the GUI side until the run ends, when
    // they get the last ones. End a run with halt(): complete() does nothing on an animator. ended comes after a run of
    // play() ends or is halted, so call halt() before changing what the handler clears; running still reads true inside
    // it. A loading's clock (runClock()) ends without it, whether halted or run out.
    readonly property bool running: animators !== null && animators.running
    property int length
    property real clockSeconds
    // the runs (animatorsComponent below), from the first play() or runClock() on
    property Item animators: null

    signal ended

    readonly property string shaderName: style !== "" && moment !== "" ? style + "-" + moment : ""
    // GLSL ES 3.00 where the GPU has it (the Jolla Phone's Mali-G610 does): a blur from mipmaps. Known once the
    // window has its OpenGL context. (An effect needs a source: with no sampler, Qt 5.6 draws a GLSL ES 3.00 effect
    // nowhere.)
    readonly property int glMajor: OpenGLInfo.majorVersion
    readonly property bool es3: OpenGLInfo.renderableType === OpenGLInfo.OpenGLES && glMajor >= 3
    property bool loaded
    // the shader and GLSL version whose text is set. Qt reads a text again each time it is set, on this pass and on
    // the grains pass, so load() sets each one once
    property string loadedAs
    readonly property bool ready: loaded
    property bool gone

    function play(ms) {
        length = ms
        progress = 0
        time = 0
        animate().start(split)
        watchdog.restart()
    }

    // a loading: time runs on, for seconds
    function runClock(seconds) {
        clockSeconds = seconds
        time = 0
        animate().startClock()
    }

    function halt() {
        watchdog.stop()
        if (animators !== null)
            animators.stop()
    }

    function animate() {
        if (animators === null)
            animators = animatorsComponent.createObject(effect)
        return animators
    }

    // what only some moments have: a split moment's grains pass, and the field's Loader of a moment with a field. Made
    // when the style or moment changes to one with it and dropped when it changes to one without, so that a make (a
    // cover makes one each time it closes) holds only what its moment draws. Before load(), which sets a grains pass's
    // texts, so that an Effect played as soon as it is ready (a cover's closing) finds them. By Component, as the runs
    // below
    function fit() {
        var splits = Styles.split(style, moment)
        if (splits && grains === null)
            grains = grainsComponent.createObject(effect)
        if (!splits && grains !== null) {
            var pass = grains
            grains = null
            pass.destroy()
        }
        var fields = Styles.listed(style, "field", moment)
        if (fields && fieldLoader === null)
            fieldLoader = fieldComponent.createObject(effect)
        if (!fields && fieldLoader !== null) {
            var loader = fieldLoader
            fieldLoader = null
            loader.destroy()
        }
    }

    // a make calls this up to three times (from the GL version, the name and the completion), and a text still being
    // read answers each call: only the first sets it. Reading a binding not yet run runs it, and its change handler
    // can call this from inside the read: so all three are read before the check
    function load() {
        var name = shaderName
        var es3 = effect.es3
        var major = glMajor
        var key = name + es3
        if (loaded && loadedAs === key)
            return
        loaded = false
        if (name === "" || major === 0)
            return
        var base = Qt.resolvedUrl("shaders/")
        var libs = Styles.libs(style)
        var loadOwn = function () {
            Shaders.load(base, name, libs, es3, function (text) {
                if (effect.gone || effect.shaderName !== name || effect.es3 !== es3 || text === "")
                    return
                if (effect.loaded && effect.loadedAs === key)
                    return
                effect.vertexShader = es3 ? Shaders.ES3_VERTEX : ""
                effect.fragmentShader = text
                // and the grains pass's, set here and not bound: a pass made for a new moment would read the old
                // moment's text first, and one being dropped would read the new one
                if (effect.grains !== null) {
                    effect.grains.vertexShader = effect.vertexShader
                    effect.grains.fragmentShader = effect.fragmentShader
                }
                effect.loadedAs = key
                effect.loaded = true
            })
        }
        // the field's text first: once this is ready, a field made for it is ready at once and bakes in the first frame
        if (Styles.listed(style, "field", moment))
            Shaders.load(base, style + "-field", libs, es3, loadOwn)
        else
            loadOwn()
    }

    // the heaviest moments (the grains) are drawn at half the resolution and scaled up (styles.js half). A split
    // moment draws its picture here, at full resolution, and only its flying grains at half, in the pass below: the
    // shader draws what part asks for (0 all of it, 1 the picture, 2 the grains)
    readonly property bool split: Styles.split(style, moment)
    readonly property bool half: Styles.half(style, moment) && !split
    property real part: split ? 1 : 0
    // driven by hand, the second pass waits for its first grains (styles.js grainsFrom). A run shows it from the start,
    // and the shader draws nothing in it before then: the GUI side does not see progress during a run, and anything it
    // timed would come late, or after the run, while the GUI thread is busy
    readonly property bool grainsShown: split && (running || progress >= Styles.grainsFrom(style))
    // the second pass (grainsComponent), for an animator on one of its uniforms: made by fit() for a split moment only,
    // null otherwise, and an animator with no target does nothing
    property Item grains: null
    layer.enabled: half
    layer.smooth: true
    layer.textureSize: Qt.size(Math.ceil(width / 2), Math.ceil(height / 2))

    blending: true
    onShaderNameChanged: {
        fit()
        load()
    }
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

    // a split moment's flying grains: the same shader at half the resolution, over the picture
    Component {
        id: grainsComponent

        ShaderEffect {
            readonly property variant source: effect.source
            readonly property variant noiseTex: effect.noiseTex
            readonly property real progress: effect.progress
            readonly property real time: effect.time
            readonly property point origin: effect.origin
            readonly property rect originRect: effect.originRect
            readonly property real aspect: effect.aspect
            readonly property size resolution: effect.resolution
            readonly property vector3d tint: effect.tint
            readonly property real useTint: effect.useTint
            readonly property real radiusPx: effect.radiusPx
            readonly property real clipTop: effect.clipTop
            readonly property variant fieldTex: effect.fieldTex
            readonly property variant blurTex: effect.blurTex
            readonly property real part: 2

            anchors.fill: parent
            visible: effect.grainsShown
            blending: true
            // the texts: load() sets them
            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(Math.ceil(width / 2), Math.ceil(height / 2))
        }
    }

    // baked at the start of each run and gone after it: two Effects of a style with a field would otherwise hold its
    // textures for as long as the style is chosen. By URL, because a type cannot contain itself
    Component {
        id: fieldComponent

        Loader {
            anchors.fill: parent
            active: effect.visible || effect.running
            source: "FrostField.qml"
            onLoaded: item.owner = effect
        }
    }

    // the runs on the render thread, made at once by the first play() or runClock(), so that the run starts in that
    // call, and kept. An Effect driven by hand (the settings' pages, the harness, the warm-up) never makes them. Not a
    // Loader: inside an asynchronous creation, as a cover's loading can be made in one, a Loader makes its item later
    Component {
        id: animatorsComponent

        Item {
            readonly property bool running: run.running || clock.running

            function start(split) {
                run.start()
                if (split)
                    grainsRun.start()
            }

            function startClock() {
                clock.start()
            }

            // the run last, so that whoever gets ended finds all of it stopped
            function stop() {
                grainsRun.stop()
                clock.stop()
                run.stop()
            }

            ParallelAnimation {
                id: run

                onStopped: {
                    watchdog.stop()
                    effect.ended()
                }

                UniformAnimator {
                    target: effect
                    uniform: "progress"
                    from: 0
                    to: 1
                    duration: effect.length
                }
                UniformAnimator {
                    target: effect
                    uniform: "time"
                    from: 0
                    to: effect.length / 1000
                    duration: effect.length
                }
            }

            // an animator on the first pass alone would leave the grains frozen at their start
            ParallelAnimation {
                id: grainsRun

                UniformAnimator {
                    target: effect.grains
                    uniform: "progress"
                    from: 0
                    to: 1
                    duration: effect.length
                }
                UniformAnimator {
                    target: effect.grains
                    uniform: "time"
                    from: 0
                    to: effect.length / 1000
                    duration: effect.length
                }
            }

            UniformAnimator {
                id: clock

                target: effect
                uniform: "time"
                from: 0
                to: effect.clockSeconds
                duration: effect.clockSeconds * 1000
            }
        }
    }

    // a render thread that draws no frames, as with the display off, never ends a run: it ends here, on the GUI side
    Timer {
        id: watchdog

        interval: effect.length + 500
        onTriggered: effect.halt()
    }
}
