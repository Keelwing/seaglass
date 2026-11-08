// Shatter's shards (docs/ANIMATIONS.md): a pane broken at a point into triangles, which fall (closing) or burst out of
// the impact and fit together (opening, assemble). All of them are one ShaderEffect over a GridMesh:
// shaders/shards.vert works out each shard from a seed, then turns and moves it, and shaders/shards.frag draws it.
// build() makes a new break, at impact (0 to 1 over the pane). Show it only when ready.
import QtQuick 2.6
import "shaders.js" as Shaders

ShaderEffect {
    id: pane

    // its shaders are read only while active, and it is ready only then
    property bool active: true
    property variant source
    // in the vertex stage only: a uniform in both stages is not driven by an animator
    property real progress
    property bool assemble
    property point impact: Qt.point(0.5, 0.5)
    property vector3d tint: Qt.vector3d(1, 1, 1)
    property real useTint
    property real clipTop
    // the break: rays from the impact, and up to 8 rings further out (in pane heights)
    property real rays: 11
    property var rings: [0.05, 0.12, 0.22, 0.35, 0.52, 0.75, 1.05, 1.5]
    property vector4d seed: Qt.vector4d(0.37, 0.61, 0.13, 0.83)
    readonly property real mode: assemble ? 1 : 0
    readonly property point impactAt: Qt.point(impact.x * width / Math.max(1, height), impact.y)
    readonly property real side: Math.max(1, height)
    readonly property real aspect: width / Math.max(1, height)
    // three columns a shard, less one: a grid has one more column of vertices than its resolution says
    readonly property real columns: 3 * (rays + (rings.length - 1) * rays * 2) - 1
    readonly property vector4d ringsA: Qt.vector4d(ring(0), ring(1), ring(2), ring(3))
    readonly property vector4d ringsB: Qt.vector4d(ring(4), ring(5), ring(6), ring(7))
    property string vertexText
    property string fragmentText
    readonly property bool loaded: vertexText !== "" && fragmentText !== ""
    readonly property bool ready: active && loaded
    // plays the moment on the render thread, so that it keeps moving while the GUI thread is busy. progress keeps its
    // old value on the GUI side until the run ends. End a run with halt(): complete() does nothing on an animator.
    // ended comes after a run ends or is halted
    readonly property bool running: run !== null && run.running
    property int length
    // the run (runComponent below), from the first play() on
    property QtObject run: null
    signal ended

    function ring(at) {
        return at < rings.length ? rings[at] : 1
    }

    function build() {
        seed = Qt.vector4d(Math.random(), Math.random(), Math.random(), Math.random())
    }

    function play(ms) {
        length = ms
        progress = 0
        if (run === null)
            run = runComponent.createObject(pane)
        run.start()
        watchdog.restart()
    }

    function halt() {
        watchdog.stop()
        if (run !== null)
            run.stop()
    }

    function load() {
        if (!active)
            return
        var base = Qt.resolvedUrl("shaders/")
        Shaders.loadFile(base + "shards.vert", function (text) { pane.vertexText = text })
        Shaders.loadFile(base + "shards.frag", function (text) { pane.fragmentText = text })
    }

    blending: true
    mesh: GridMesh {
        resolution: Qt.size(pane.columns, 1)
    }
    // kept once read, also when it goes inactive: a run's animator holds its uniform's place in the program's list,
    // and Qt does not check it against the shorter list of its own shaders
    vertexShader: loaded ? vertexText : ""
    fragmentShader: loaded ? fragmentText : ""
    onActiveChanged: load()
    Component.onCompleted: load()

    // the run on the render thread, made at once by the first play(), so that it starts in that call, and kept. Shards
    // driven by hand (the settings' pages, the harness, the warm-up) never make it. Not a Loader, which makes its item
    // later inside an asynchronous creation
    Component {
        id: runComponent

        UniformAnimator {
            target: pane
            uniform: "progress"
            from: 0
            to: 1
            duration: pane.length
            onStopped: {
                watchdog.stop()
                pane.ended()
            }
        }
    }

    // a render thread that draws no frames, as with the display off, never ends a run: it ends here, on the GUI side
    Timer {
        id: watchdog

        interval: pane.length + 500
        onTriggered: pane.halt()
    }
}
