// The viewer's live scene (AnimationViewerPage.qml): one moment of a style on the made-up home screen of the kit
// (PreviewKit.qml), at the stage's size. It is hidden at rest, when the viewer's still of the moment shows instead.
//
// A run is driven from the GUI thread by one animation on p, so that pausing, scrubbing and Slow are one value; Slow
// makes the run longer and never changes what a frame looks like. An opening or closing draws at a fraction of the
// stage (rung) and is scaled up, so that its resolution is the pixels it draws, and it reads the app grabbed at that
// same size (kit.runApp), as a run on the home screen reads its window. A loading draws at full size on its cover.
// Stock is drawn with plain items. What a run plays is fixed when it starts.
//
// The viewer grabs runApp and draws any program a run will switch to before the run (warmer, through its queue), so
// that a run itself grabs and compiles nothing.
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../animations"
import "../animations/styles.js" as Styles
import "stills.js" as Stills

SilicaControl {
    id: stage

    property Item kit
    // what a run plays: "stock" or a style, and "open", "load" or "close"
    property string style: "ember"
    property string moment: "open"
    // a round: the style's loading for 1.5 s, its opening from the cover it loaded on, 0.6 s of the app, its closing
    property bool round
    // the speed setting (0 relaxed, 1 normal, 2 quick), and Slow: 4 times as long, for looking only
    property int speed: 1
    property bool slow
    // the size an opening or closing draws at, a fraction of the stage; kit.runApp must be grabbed at it
    property real rung: 0.62

    // 0 to 1 over the moment playing
    property real p
    // rest: hidden. running, then holding (its end without the effect, 400 ms) and fading (back to the still, 200 ms).
    // scrubbing: the strip is pressed. lifted: the strip's point, until the still is made at it
    property string phase: "rest"
    // what plays, set when it starts
    property string playingStyle
    property string playingMoment
    // an opening from the cover a loading played on, rather than from the icon
    property bool fromCover
    // the round's 0.6 s of the app between its opening and closing
    property bool appHeld
    // the moment's real length in ms, the seconds a loading plays, and the rung it draws at: a rung lowered while it
    // plays counts from the next run, whose app is grabbed at it
    property int length
    property real loadSeconds
    property real playingRung: 0.62
    // the frame intervals of the last moment played, in ms, from the animation's own ticks
    property var intervals: []
    property var stamps: []
    property var steps: []
    property bool halting

    readonly property bool shown: phase !== "rest"
    // the still under the stage is covered
    readonly property bool coversStill: phase === "running" || phase === "holding" || phase === "scrubbing"
    // something on the stage moves, or will in a moment
    readonly property bool moving: phase === "running" || phase === "holding" || phase === "fading"
                                   || phase === "scrubbing"
    readonly property bool ending: phase === "holding" || phase === "fading"
    // the moment itself is drawn: running, or at a point of the strip
    readonly property bool drawn: phase === "running" && !appHeld || phase === "scrubbing" || phase === "lifted"
    readonly property string kind: playingStyle === "stock" ? "stock"
                                   : playingMoment !== "load" && Styles.has(playingStyle, "shards") ? "shards"
                                   : "effect"
    // a scrub reads the moment at the normal speed, as the stills do, so that the still made where the finger lifts
    // looks the same
    readonly property real seconds: playingMoment === "load" ? p * loadSeconds
                                    : p * (phase === "scrubbing" || phase === "lifted"
                                           ? Styles.duration(playingStyle, playingMoment, 1) : length) / 1000
    // what an opening comes from, 0 to 1 over the screen
    readonly property rect opensFrom: !kit ? Qt.rect(0.35, 0.4, 0.3, 0.2) : fromCover ? kit.coverRect : kit.iconRect
    readonly property point opensAt: Qt.point(opensFrom.x + opensFrom.width / 2, opensFrom.y + opensFrom.height / 2)
    readonly property bool appShown: ending && playingMoment === "open" || phase === "running" && appHeld
    // the app's grab for the run, never null once there is a kit: a texture input going to null makes Qt warn
    readonly property Item app: !kit ? null : kit.runApp ? kit.runApp : kit.app
    readonly property Item warmer: warming

    // a moment of a run has ended by itself (the viewer's step-down rule reads its intervals)
    signal ran(string ranStyle, string ranMoment, var frames)
    // the run is over: whole after its end and fade, or not when it was halted
    signal ended(bool whole)

    function easeIn(x) {
        return x * x * x
    }

    function easeInOut(x) {
        return x * x * (3 - 2 * x)
    }

    // plays what the stage is pointed at, from its start
    function play() {
        halt()
        playingStyle = style
        playingRung = rung
        steps = round ? ["load", "open", "hold", "close"] : [moment]
        next()
    }

    function next() {
        if (steps.length === 0) {
            phase = "holding"
            hold.restart()
            return
        }
        var what = steps[0]
        steps = steps.slice(1)
        scene.opacity = 1
        if (what === "hold") {
            appHeld = true
            phase = "running"
            roundHold.restart()
            return
        }
        appHeld = false
        prime(what, round && what === "load" ? 1.5 : 0)
        fromCover = round && what === "open"
        stamps = [Date.now()]
        phase = "running"
        run.duration = length * (slow ? 4 : 1)
        run.start()
    }

    // the moment and its lengths, from its start
    function prime(what, clip) {
        playingMoment = what
        loadSeconds = what !== "load" ? 0 : clip > 0 ? clip : Stills.STILLS[playingStyle].clip
        length = what === "load" ? Math.round(loadSeconds * 1000)
                 : playingStyle === "stock" ? (what === "open" ? 450 : 300)
                 : Styles.duration(playingStyle, what, speed)
        p = 0
    }

    // stops whatever plays: the stage hides at once, and the still shows
    function halt() {
        halting = true
        run.stop()
        onward.stop()
        hold.stop()
        roundHold.stop()
        fade.stop()
        fadeGuard.stop()
        halting = false
        steps = []
        appHeld = false
        var was = phase
        phase = "rest"
        if (was !== "rest")
            ended(false)
    }

    // the strip pressed or dragged: the moment shown at that point (0 to 1), until it is lifted
    function scrub(at) {
        if (phase !== "scrubbing") {
            halt()
            playingStyle = style
            playingRung = rung
            prime(moment, 0)
            fromCover = false
            scene.opacity = 1
            phase = "scrubbing"
        }
        p = Math.max(0, Math.min(1, at))
    }

    // the finger lifted: the stage holds the point until the viewer has made its still there (settle)
    function lift() {
        if (phase === "scrubbing")
            phase = "lifted"
    }

    function settle() {
        if (phase === "lifted")
            phase = "rest"
    }

    // back at rest after a whole run
    function faded() {
        if (phase !== "fading")
            return
        fadeGuard.stop()
        phase = "rest"
        ended(true)
    }

    // the frames of a moment that ended by itself
    function measured() {
        var list = []
        for (var i = 1; i < stamps.length; i++)
            list.push(stamps[i] - stamps[i - 1])
        intervals = list
        stamps = []
        return list
    }

    // the busy ring takes a SilicaControl's palette (a SilicaItem's it does not), as in the stills
    palette.colorScheme: Theme.LightOnDark
    onPChanged: {
        if (run.running)
            stamps.push(Date.now())
    }

    NumberAnimation {
        id: run

        target: stage
        property: "p"
        from: 0
        to: 1
        onStopped: {
            if (stage.halting)
                return
            stage.ran(stage.playingStyle, stage.playingMoment, stage.measured())
            onward.start()
        }
    }

    // the round's next moment, out of the last one's handler
    Timer {
        id: onward

        interval: 0
        onTriggered: stage.next()
    }

    // the round's app between its opening and closing
    Timer {
        id: roundHold

        interval: 600
        onTriggered: stage.next()
    }

    // the end of the run, without the effect
    Timer {
        id: hold

        interval: 400
        onTriggered: {
            stage.phase = "fading"
            fade.start()
            fadeGuard.restart()
        }
    }

    FadeAnimator {
        id: fade

        target: scene
        from: 1
        to: 0
        onStopped: {
            if (!stage.halting)
                stage.faded()
        }
    }

    // a render thread that draws no frames never ends the fade: it ends here, on the GUI side
    Timer {
        id: fadeGuard

        interval: fade.duration + 300
        onTriggered: {
            fade.stop()
            stage.faded()
        }
    }

    Item {
        id: scene

        anchors.fill: parent
        visible: stage.shown
        clip: true

        // the home screen behind an opening from the icon, the switcher's wallpaper behind the rest
        ShaderEffect {
            property variant source: !stage.kit ? null
                                     : stage.playingMoment === "open" && !stage.fromCover ? stage.kit.home
                                     : stage.kit.plain

            anchors.fill: parent
            visible: source !== null
        }

        // the app: the end of an opening, the round's hold, and the stock opening (a fade) and closing (a slide)
        ShaderEffect {
            readonly property bool stockOpen: stage.kind === "stock" && stage.drawn && stage.playingMoment === "open"
            readonly property bool stockClose: stage.kind === "stock" && stage.drawn && stage.playingMoment === "close"
            property variant source: stage.kit ? stage.kit.app : null

            y: stockClose ? 0.25 * stage.easeIn(stage.p) * height : 0
            width: parent.width
            height: parent.height
            visible: source !== null && opacity > 0
            opacity: stage.appShown ? 1 : stockOpen ? stage.p : stockClose ? 1 - stage.easeInOut(stage.p) : 0
        }

        // a loading's cover, at its true size and place; Stock's has the busy ring, turning with the run
        Rectangle {
            id: cover

            x: stage.kit ? stage.kit.coverRect.x * stage.width : 0
            y: stage.kit ? stage.kit.coverRect.y * stage.height : 0
            width: stage.kit ? stage.kit.coverRect.width * stage.width : 0
            height: stage.kit ? stage.kit.coverRect.height * stage.height : 0
            radius: stage.kit ? stage.kit.coverRadius : 0
            visible: stage.playingMoment === "load"
            color: "#101520"

            ShaderEffect {
                property variant source: stage.kit ? stage.kit.icon : null

                anchors.centerIn: parent
                width: Math.round(Math.min(parent.width, parent.height) * 0.5)
                height: width
                visible: source !== null && (stage.kind === "stock" && stage.drawn || stage.ending)
            }

            ProgressCircle {
                anchors.centerIn: parent
                width: Math.round(Math.min(parent.width, parent.height) * 0.8)
                height: width
                visible: stage.kind === "stock" && stage.drawn
                value: 0.7
                rotation: stage.seconds * 360
            }
        }

        // the effect at a fraction of the stage, scaled up: its resolution is the pixels it draws
        Item {
            id: scaled

            readonly property real k: stage.playingMoment === "load" ? 1 : stage.playingRung

            width: stage.width * k
            height: stage.height * k
            scale: 1 / k
            transformOrigin: Item.TopLeft
            visible: stage.drawn && stage.kind !== "stock"
            layer.enabled: k < 1 && visible
            layer.smooth: true

            Effect {
                id: effect

                x: stage.playingMoment === "load" ? cover.x : 0
                y: stage.playingMoment === "load" ? cover.y : 0
                width: stage.playingMoment === "load" ? cover.width : parent.width
                height: stage.playingMoment === "load" ? cover.height : parent.height
                visible: ready && stage.kind === "effect"
                style: stage.kind === "effect" ? stage.playingStyle : ""
                moment: stage.playingMoment
                source: !stage.kit ? null : stage.playingMoment === "load" ? stage.kit.icon : stage.app
                noiseTex: stage.kit ? stage.kit.noise : null
                progress: stage.playingMoment === "load" ? 0 : stage.p
                time: stage.seconds
                // an opening from the icon or the cover, a closing let go at the upper third, a loading on its cover
                origin: stage.playingMoment === "open" ? stage.opensAt
                        : stage.playingMoment === "close" ? Qt.point(0.5, 0.3) : Qt.point(0.5, 0.5)
                originRect: stage.playingMoment === "open" ? stage.opensFrom
                            : stage.playingMoment === "close" ? Qt.rect(0, 0, 1, 1) : Qt.rect(0.35, 0.4, 0.3, 0.2)
                radiusPx: !stage.kit ? 0
                          : stage.playingMoment === "open" ? (stage.fromCover ? stage.kit.coverRadius
                                                                              : stage.kit.iconRadius) * scaled.k
                          : stage.playingMoment === "load" ? stage.kit.coverRadius : 0
                tint: stage.kit ? stage.kit.tint : Qt.vector3d(1, 1, 1)
                useTint: stage.kit ? stage.kit.useTint : 0
            }

            // as the stills break it
            Shards {
                anchors.fill: parent
                active: stage.kind === "shards"
                visible: ready && stage.kind === "shards"
                rays: 9
                rings: [0.08, 0.2, 0.38, 0.6, 1.0]
                seed: Qt.vector4d(Stills.SEED[0], Stills.SEED[1], Stills.SEED[2], Stills.SEED[3])
                source: stage.app
                assemble: stage.playingMoment === "open"
                impact: stage.playingMoment === "open" ? stage.opensAt : Qt.point(0.5, 0.3)
                progress: stage.p
                tint: stage.kit ? stage.kit.tint : Qt.vector3d(1, 1, 1)
                useTint: stage.kit ? stage.kit.useTint : 0
            }
        }
    }

    // What the viewer draws at rest before a run, a pixel large, one at a time through its queue (FreezeQueue.qml):
    // the app at the run's size ("app"), so that it is grabbed now, or a program the run will switch to ({style,
    // moment}, or "shards"), so that it is compiled now
    Item {
        id: warming

        property var program: null
        readonly property int passes: 1
        readonly property bool loaded: program === "app" ? stage.app !== null
                                       : program === "shards" ? warmShards.ready : warmEffect.ready

        signal done

        function develop() {
            var what = program
            warmApp.visible = what === "app"
            warmShards.active = what === "shards"
            if (what !== null && typeof what === "object") {
                warmEffect.moment = what.moment
                warmEffect.style = what.style
            }
            if (loaded)
                warmSettle.restart()
            else
                warmPatience.restart()
        }

        onLoadedChanged: {
            if (loaded && warmPatience.running) {
                warmPatience.stop()
                warmSettle.restart()
            }
        }

        // drawn for a few frames, then cleared
        Timer {
            id: warmSettle

            interval: 50
            onTriggered: {
                warmApp.visible = false
                warmShards.active = false
                warmEffect.style = ""
                warming.done()
            }
        }

        // a program that does not come holds the queue up no longer than this
        Timer {
            id: warmPatience

            interval: 2000
            onTriggered: warmSettle.restart()
        }
    }

    ShaderEffect {
        id: warmApp

        property variant source: stage.app

        x: -2
        y: -2
        width: 1
        height: 1
        opacity: 0.02
        visible: false
    }

    Effect {
        id: warmEffect

        x: -2
        y: -2
        width: 1
        height: 1
        opacity: 0.02
        visible: ready
        source: stage.kit ? stage.kit.icon : null
        noiseTex: stage.kit ? stage.kit.noise : null
        progress: 0.5
        time: 0.5
    }

    Shards {
        id: warmShards

        x: -2
        y: -2
        width: 1
        height: 1
        opacity: 0.02
        active: false
        visible: ready
        progress: 0.5
        rays: 9
        rings: [0.08, 0.2, 0.38, 0.6, 1.0]
        source: stage.kit ? stage.kit.noise : null
    }
}
