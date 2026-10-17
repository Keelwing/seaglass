// The reel scene (docs/ANIMATIONS.md): styles one after the other on the app grid over the stock picture, for the
// docs' and the site's WebP. For each style, Notes is tapped, opens from its icon, stays a moment and closes, with the
// style's name on a chip; the same Effect.qml and Shards.qml as on the home screen, on the made-up Notes app of the
// settings page (NotesPreview.qml). Slowed down for frames (scripts/harness.sh --frames).
// Argument: "STYLE,STYLE,... [slow=3]", e.g. "reel seaglass,tide,aurora".
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../qml/animations"
import "../qml/settings"
import "../qml/animations/styles.js" as Styles

Item {
    id: scene

    property Item harness
    property var styles: []
    property real slow: 3

    readonly property int columns: harness ? harness.grid.columns : 5
    readonly property real cellWidth: width / columns
    readonly property real cellHeight: harness ? harness.grid.cellHeight : 250
    readonly property real gridTop: Theme.itemSizeLarge
    readonly property int notesAt: 12
    readonly property var gridApps: [["phone", "Phone"], ["messaging", "Messages"], ["people", "People"],
                                     ["browser", "Browser"], ["email", "Email"], ["camera", "Camera"],
                                     ["gallery", "Gallery"], ["clock", "Clock"], ["calendar", "Calendar"],
                                     ["weather", "Weather"], ["settings", "Settings"], ["store", "Store"],
                                     ["notes", "Notes"], ["calculator", "Calculator"], ["map", "Maps"],
                                     ["mediaplayer", "Media"], ["file-manager", "Files"], ["todo", "Tasks"],
                                     ["office", "Documents"], ["shell", "Terminal"]]
    // where Notes opens from, 0 to 1 over the screen
    readonly property rect iconRect: Qt.rect(((notesAt % columns) * cellWidth + (cellWidth - Theme.iconSizeLauncher) / 2)
                                             / Math.max(1, width),
                                             (gridTop + Math.floor(notesAt / columns) * cellHeight + Theme.paddingMedium)
                                             / Math.max(1, height),
                                             Theme.iconSizeLauncher / Math.max(1, width),
                                             Theme.iconSizeLauncher / Math.max(1, height))

    // the reel: [style, step] pairs, and how long a step without an effect takes (ms, before slowing down)
    property var steps: []
    readonly property var lengths: ({ "rest": 300, "tap": 250, "hold": 600 })
    property int step: -1
    property string phase
    property string style
    property real t
    property bool shards
    // Shatter's shards drawn once, nearly clear, before the reel starts
    property bool warmShards

    readonly property real press: phase === "tap" ? Math.sin(Math.PI * t) : 0
    readonly property real chipShown: phase === "rest" ? Math.min(1, t * 2)
                                      : phase === "close" ? 1 - Math.max(0, Math.min(1, (t - 0.75) / 0.25))
                                      : 1

    onHarnessChanged: {
        var words = harness.sceneArgument.split(" ")
        for (var i = 1; i < words.length; i++) {
            var w = words[i].split("=")
            if (w[0] === "slow" && w.length === 2)
                slow = parseFloat(w[1]) || slow
        }
        styles = (words[0] || "seaglass,tide,aurora").split(",").filter(function (name) {
            return Styles.find(name) !== null
        })
        var plan = []
        for (i = 0; i < styles.length; i++) {
            var moments = ["rest", "tap", "open", "hold", "close"]
            for (var j = 0; j < moments.length; j++)
                plan.push([styles[i], moments[j]])
        }
        plan.push(["", "rest"])
        steps = plan
        console.log("harness: reel", styles.join(","), "slow", slow, "steps", steps.length)
        start.start()
    }

    function begin(index) {
        step = index
        if (index >= steps.length) {
            harness.stopFrames()
            phase = ""
            return
        }
        style = steps[index][0]
        phase = steps[index][1]
        var ms = lengths[phase] || 300
        if (phase === "open" || phase === "close") {
            shards = Styles.has(style, "shards")
            var point = phase === "close" ? Qt.point(0.5, 0.3)
                                          : Qt.point(iconRect.x + iconRect.width / 2, iconRect.y + iconRect.height / 2)
            effect.moment = phase
            effect.style = shards ? "" : style
            effect.originRect = phase === "close" ? Qt.rect(0, 0, 1, 1) : iconRect
            effect.origin = point
            if (shards) {
                pieces.assemble = phase === "open"
                pieces.impact = point
                pieces.build()
            }
            ms = Styles.duration(style, phase, 1)
            if (!(shards ? pieces.ready : effect.ready))
                console.log("harness: reel", style, phase, "not ready")
        }
        run.duration = ms * slow
        run.restart()
    }

    Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: scene.harness ? "file://" + scene.harness.picture : ""
    }

    // the app grid (the clear look: the wallpaper under a dimming veil)
    Rectangle {
        anchors.fill: parent
        color: Theme.rgba("black", 0.35)
    }

    Repeater {
        model: scene.gridApps

        Item {
            readonly property real pressed: index === scene.notesAt ? scene.press : 0

            x: (index % scene.columns) * scene.cellWidth
            y: scene.gridTop + Math.floor(index / scene.columns) * scene.cellHeight
            width: scene.cellWidth
            height: scene.cellHeight

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.paddingMedium + (Theme.iconSizeLauncher - height) / 2
                width: Math.round(Theme.iconSizeLauncher * 1.3)
                height: width
                radius: width / 2
                visible: parent.pressed > 0
                opacity: parent.pressed * 0.5
                color: Theme.highlightBackgroundColor
            }

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.paddingMedium
                width: Theme.iconSizeLauncher
                height: width
                scale: 1 - 0.08 * parent.pressed
                sourceSize: Qt.size(width, height)
                source: "image://theme/icon-launcher-" + modelData[0]
            }

            Label {
                x: Theme.paddingSmall
                y: 2 * Theme.paddingMedium + Theme.iconSizeLauncher
                width: parent.width - 2 * x
                horizontalAlignment: Text.AlignHCenter
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeTiny
                color: parent.pressed > 0.3 ? Theme.highlightColor : Theme.primaryColor
                text: modelData[1]
            }
        }
    }

    // the made-up app, drawn only through its texture
    NotesPreview {
        id: app

        anchors.fill: parent
        picture: scene.harness ? scene.harness.picture : ""
    }

    ShaderEffectSource {
        id: appTexture

        width: scene.width
        height: scene.height
        visible: false
        hideSource: true
        mipmap: effect.es3 && Styles.has(scene.style, "blur")
        sourceItem: app
    }

    NoiseTile {
        id: noise
    }

    ShaderEffect {
        property variant source: appTexture

        anchors.fill: parent
        visible: scene.phase === "hold"
    }

    Effect {
        id: effect

        anchors.fill: parent
        visible: (scene.phase === "open" || scene.phase === "close") && !scene.shards && ready
        source: appTexture
        noiseTex: noise
        progress: scene.t
        tint: Qt.vector3d(Theme.highlightColor.r, Theme.highlightColor.g, Theme.highlightColor.b)
    }

    Shards {
        id: pieces

        anchors.fill: parent
        visible: ((scene.phase === "open" || scene.phase === "close") && scene.shards || scene.warmShards) && ready
        opacity: scene.warmShards ? 0.02 : 1
        active: scene.styles.indexOf("shatter") >= 0
        onReadyChanged: {
            if (ready && scene.step < 0) {
                build()
                scene.warmShards = true
            }
        }
        source: appTexture
        progress: scene.t
        tint: Qt.vector3d(Theme.highlightColor.r, Theme.highlightColor.g, Theme.highlightColor.b)
    }

    // the style's name
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - Theme.itemSizeExtraLarge * 1.5
        width: chipLabel.width + 2 * Theme.paddingLarge * 1.5
        height: chipLabel.height + 2 * Theme.paddingMedium
        radius: height / 2
        visible: scene.style !== "" && opacity > 0
        opacity: scene.chipShown
        color: Theme.rgba("black", 0.45)
        border.color: Theme.rgba("white", 0.25)

        Label {
            id: chipLabel

            anchors.centerIn: parent
            font.pixelSize: Theme.fontSizeLarge
            color: "white"
            text: scene.style !== "" ? Styles.find(scene.style).name : ""
        }
    }

    // every shader of the reel drawn once, a pixel large, before it starts: compiling one stalls a frame
    Row {
        visible: scene.step < 0
        opacity: 0.02

        Repeater {
            model: {
                var list = []
                for (var i = 0; i < scene.styles.length; i++) {
                    if (!Styles.has(scene.styles[i], "shards"))
                        list.push(scene.styles[i] + "/open", scene.styles[i] + "/close")
                }
                return list
            }

            Effect {
                width: 1
                height: 1
                style: modelData.split("/")[0]
                moment: modelData.split("/")[1]
                source: appTexture
                noiseTex: noise
                progress: 0.5
            }
        }
    }

    NumberAnimation {
        id: run

        target: scene
        property: "t"
        from: 0
        to: 1
        onStopped: next.start()
    }

    Timer {
        id: next

        interval: 0
        onTriggered: scene.begin(scene.step + 1)
    }

    // the frames start once the shaders have drawn
    Timer {
        id: start

        interval: 2500
        onTriggered: {
            scene.warmShards = false
            scene.harness.frameSlow = scene.slow
            scene.harness.frameSize = Qt.size(540, Math.round(540 * scene.height / scene.width))
            scene.harness.startFrames()
            scene.begin(0)
        }
    }
}
