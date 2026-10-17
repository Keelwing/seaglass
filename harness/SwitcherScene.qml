// The switcher scene: the home screen's task switcher with made-up covers (the harness has no live app windows), in the
// two layouts: the stock grid of covers with name chips (SwitcherChip.qml) under them, or the card row
// (SwitcherCard.qml, the hint SwitcherHint.qml); on the wallpaper as it is, or frosted (glass=1); the apps closed last
// (RecentApps.qml). In the grid closing stays stock; in the card row a card pushed up shows how it closes: the run
// pushes one half way and lets go (it springs back), then past the point of closing. pinch (docs/SWITCHER.md): both
// layouts in a pinch area, with the switch between them (SwitcherPinch.qml, SwitcherMorph.qml); the cards in another
// order than the grid, as the stock's most recently used order. The run pinches in a quarter of the way (it springs
// back), then past the point (the grid), then out on the fourth cover (the cards, that one in front). With --keep it
// stays, to pinch with real fingers. Argument: "[mode=grid|cards|pinch] [glass=0|1] [chips=0|1] [recent=0|1] [slow=4]"
// grid: a still picture (--shot); cards, pinch: the run (--frames)
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import "../qml/glass"
import "../qml/switcher"

Item {
    id: scene

    property Item harness
    property string mode: "grid"
    // mode=pinch: the layout shown is mode, and a pinch switches it
    property bool pinchMode
    property bool glassOn: false
    // the card in front pushed up: 0 .. 1 (the point of closing) and on
    property real push: 0
    onPushChanged: if (cards.currentItem) cards.currentItem.pushUp(push)
    property bool chips: true
    property bool recentOn: true
    property real slow: 4
    property var apps: []
    property var running: []
    // the apps in the card row's order
    property var mruApps: []
    property var closed: []

    readonly property real topMargin: Math.max(Screen.topCutout.height, Theme.paddingLarge) + Theme.paddingLarge
    readonly property real chipSpace: chips ? Theme.iconSizeSmall + 2 * Theme.paddingSmall + Theme.paddingMedium : 0
    readonly property var palette: ["#2f6f9f", "#7a3f8f", "#2f8f6a", "#a8562b", "#3d4f9a", "#8f2f4f"]

    onHarnessChanged: {
        var words = (harness.sceneArgument || "").split(" ")
        for (var i = 0; i < words.length; i++) {
            var w = words[i].split("=")
            if (w[0] === "mode" && w[1] === "pinch") { pinchMode = true; mode = "cards" }
            else if (w[0] === "mode") mode = w[1]
            else if (w[0] === "glass") glassOn = w[1] === "1"
            else if (w[0] === "chips") chips = w[1] === "1"
            else if (w[0] === "recent") recentOn = w[1] === "1"
            else if (w[0] === "slow") slow = parseFloat(w[1])
        }
        apps = harness.apps(harness.launcherModel, [])
        var picks = ["Messages", "Web Browser", "Settings", "Camera", "Notes"]
        var gone = ["Phone", "Calendar", "Gallery", "Clock"]
        var r = []
        var c = []
        for (var a = 0; a < apps.length; a++) {
            if (picks.indexOf(apps[a].title) >= 0)
                r.push(apps[a])
            if (gone.indexOf(apps[a].title) >= 0)
                c.push(apps[a])
        }
        // the grid shows four covers, so that the row of closed apps after them fits on the screen
        running = pinchMode ? r.slice(0, 6) : mode === "grid" ? r.slice(0, 4) : r
        // the card row's order, as the stock's most recently used: another order than the grid's
        var order = pinchMode ? [2, 0, 4, 1, 5, 3] : []
        var m = []
        for (var k = 0; k < running.length; k++)
            m.push(running[order.length > k && order[k] < running.length ? order[k] : k])
        mruApps = m
        closed = recentOn ? c : []
        console.log("harness: switcher", mode, "covers", running.length, "closed", closed.length)
        if (pinchMode)
            pinchScript.start()
        else if (mode === "cards")
            script.start()
    }

    // The home screen's wallpaper, and the glass over it (frosted while there are covers)
    Image {
        id: homePicture

        visible: false
        sourceSize.height: Screen.height
        source: scene.harness ? "image://silica-square/" + encodeURIComponent("file://" + scene.harness.picture) : ""
    }

    Image {
        anchors.fill: parent
        source: scene.harness ? "file://" + scene.harness.picture : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.height: height
    }

    Item {
        id: stockFrame

        anchors.centerIn: parent
        width: Math.max(scene.width, scene.height)
        height: width
    }

    GlassSource {
        id: glass

        home: homePicture.status === Image.Ready ? homePicture : null
        frameParent: stockFrame
        preset: ({ "look": "glass", "picture": "home", "image": "", "frost": 1, "tint": "auto", "dim": 0.25,
                   "edge": true, "folders": true, "openFolder": true, "cards": true, "parallax": 0,
                   "depth": false, "tilt": false, "drift": false })
    }

    GlassPane {
        anchors.fill: parent
        visible: scene.glassOn && glass.ready
        glass: glass
        frost: scene.running.length > 0 ? 1 : 0
        color: glass.tintColor(0)
        edgeLight: false
    }

    // A made-up cover: the app's colours, its name and icon, a few lines of "content"
    Component {
        id: coverComponent

        Rectangle {
            property var app
            property int tint

            radius: Theme.paddingMedium
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(scene.palette[tint % scene.palette.length], 1.25) }
                GradientStop { position: 1.0; color: Qt.darker(scene.palette[tint % scene.palette.length], 1.6) }
            }

            Label {
                x: Theme.paddingMedium
                y: Theme.paddingMedium
                width: parent.width - 2 * x
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeSmall
                color: "white"
                text: app ? app.title : ""
            }

            Column {
                x: Theme.paddingMedium
                y: parent.height * 0.3
                spacing: Theme.paddingSmall

                Repeater {
                    model: 3

                    Rectangle {
                        width: (parent.parent.width - 2 * Theme.paddingMedium) * (index === 2 ? 0.5 : 0.85)
                        height: Theme.paddingSmall
                        radius: height / 2
                        color: Theme.rgba("white", 0.35)
                    }
                }
            }

            LauncherIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.paddingLarge
                size: Theme.iconSizeMedium
                icon: app ? app.iconId : ""
                opacity: 0.85
            }
        }
    }

    // The stock layout: the grid of covers (SwitcherGrid's sizes), each with its chip under it
    // mode=pinch: both layouts in a pinch area, which a pinch switches (as the hook's seaglassPinch in Switcher.qml)
    PinchArea {
        id: pinchArea

        anchors.fill: parent
        enabled: scene.pinchMode
        // the other way gives a little, around the fingers
        transform: Scale {
            origin.x: scene.pinchCentre.x
            origin.y: scene.pinchCentre.y
            xScale: 1 + (gesture.toGrid ? 0.04 : -0.04) * gesture.stretch
            yScale: xScale
        }

        onPinchStarted: {
            if (gesture.active || scene.running.length === 0) {
                pinch.accepted = false
                return
            }
            scene.startPinch(pinch.startCenter)
        }
        onPinchUpdated: gesture.update(pinch.scale)
        onPinchFinished: gesture.end()
    }

    Grid {
        id: grid

        parent: pinchArea

        readonly property real spacingX: Theme.paddingLarge
        readonly property int largeColumns: Math.floor((scene.width - 2 * Theme.paddingLarge + spacingX)
                                                       / (Theme.coverSizeLarge.width + spacingX))

        visible: scene.mode === "grid" && !scene.morphing
        x: (scene.width - width) / 2
        y: scene.topMargin
        // the covers' height, laid out or not
        readonly property real rowsHeight: Math.max(0, Math.ceil(scene.running.length / columns)
                                                       * (Theme.coverSizeLarge.height + rowSpacing) - rowSpacing)

        columns: largeColumns
        columnSpacing: spacingX
        rowSpacing: Theme.paddingLarge + scene.chipSpace

        Repeater {
            id: gridCovers

            model: scene.mode === "grid" || scene.pinchMode ? scene.running : []

            Item {
                width: Theme.coverSizeLarge.width
                height: Theme.coverSizeLarge.height

                Loader {
                    anchors.fill: parent
                    sourceComponent: coverComponent
                    onLoaded: { item.app = modelData; item.tint = index }
                }

                SwitcherChip {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: Theme.paddingMedium
                    glass: glass
                    launcherItem: modelData
                    visible: scene.chips
                }
            }
        }
    }

    // The other layout: the card row, the card in front in the middle of the free room
    readonly property real cardWidth: Math.round(scene.width * 0.56)
    readonly property real pitch: Math.round(cardWidth * 0.62)
    readonly property real cardHeight: Math.round(cardWidth * Theme.coverSizeLarge.height / Theme.coverSizeLarge.width)
    readonly property real pushed: cards.currentItem ? Math.min(1, cards.currentItem.progress) : 0

    Rectangle {
        parent: pinchArea
        anchors.fill: parent
        visible: scene.mode === "cards" && opacity > 0
        color: "black"
        opacity: 0.45 * scene.pushed
    }

    ListView {
        id: cards

        parent: pinchArea

        visible: scene.mode === "cards" && !scene.morphing
        y: scene.topMargin + (scene.height * 0.78 - scene.topMargin - height) / 2
        width: scene.width
        height: scene.cardHeight + scene.chipSpace + Theme.paddingLarge * 2
        orientation: ListView.Horizontal
        spacing: scene.pitch - scene.cardWidth
        snapMode: ListView.SnapToItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width - scene.cardWidth) / 2
        preferredHighlightEnd: (width + scene.cardWidth) / 2
        highlightMoveDuration: 240 * scene.slow
        maximumFlickVelocity: 5000 * Theme.pixelRatio
        flickDeceleration: 1800 * Theme.pixelRatio / scene.slow
        model: scene.mode === "cards" || scene.pinchMode ? scene.mruApps : []
        displaced: Transition {
            NumberAnimation { properties: "x"; duration: 260; easing.type: Easing.OutCubic }
        }

        delegate: SwitcherCard {
            id: slot

            readonly property real away: Math.abs((x - cards.contentX + width / 2) - cards.width / 2) / scene.pitch

            z: 10 - away
            scale: 1 - 0.17 * Math.min(1, away) - 0.08 * Math.max(0, Math.min(1, away - 1))
            dim: Math.min(0.72, 0.5 * away)
            front: away < 0.5
            opacity: away < 2 ? 1 : Math.max(0, 1 - (away - 2) * 2)
            cardWidth: scene.cardWidth
            cardHeight: scene.cardHeight
            glass: glass
            launcherItem: modelData
            chips: scene.chips
            cover: Component {
                Loader {
                    sourceComponent: coverComponent
                    onLoaded: { item.app = modelData; item.tint = scene.running.indexOf(modelData) }
                }
            }
            onCloseRequested: scene.closeCard(index)
        }
    }

    // ---- mode=pinch: the switch (as SwitcherController.qml does it on the stock pieces) ----

    // the switch layer shows from the first move until the new layout is in place
    readonly property bool morphing: (gesture.active && gesture.progress > 0) || holding
    property bool holding
    property point pinchCentre
    // a pinch run by the script: its scale
    property real fakeScale: 1
    onFakeScaleChanged: gesture.update(fakeScale)

    SwitcherPinch {
        id: gesture

        pace: scene.slow
        onReleased: scene.askCovers(switching ? scene.targetSize : scene.startSize)
        onFinished: {
            console.log("harness: pinch", toGrid ? "to grid" : "to cards", switched ? "switched" : "sprang back")
            scene.switched = switched
            if (switched)
                scene.mode = toGrid ? "grid" : "cards"
            scene.holding = true
            hold.ticks = 0
            hold.restart()
        }
    }

    property bool switched

    // The "apps": they draw the covers at the size asked (as Lipstick's covers do), a little later; the switch asks
    // at the first move and when the fingers let go, after a still of each cover (CoverFade.qml)
    property size startSize
    property size targetSize
    property size askedSize
    property size drawnSize

    onMorphingChanged: if (morphing && gesture.pinching) askCovers(targetSize)

    function askCovers(size) {
        if (size.width === askedSize.width && size.height === askedSize.height)
            return
        askedSize = size
        morph.refresh()
        askTimer.restart()
    }

    Timer {
        id: askTimer

        interval: 40
        onTriggered: appTimer.restart()
    }

    Timer {
        id: appTimer

        interval: 90 * scene.slow
        onTriggered: scene.drawnSize = scene.askedSize
    }

    // the new layout settles under the switch layer's last frame, and the covers' stills fade
    Timer {
        id: hold

        property int ticks

        interval: 40
        repeat: true
        onTriggered: {
            ticks++
            if (ticks < 2 || ((morph.busy() || askTimer.running || appTimer.running) && ticks < 25 * scene.slow))
                return
            stop()
            if (scene.switched)
                scene.checkFit()
            scene.holding = false
        }
    }

    SwitcherMorph {
        id: morph

        anchors.fill: parent
        z: 10
        visible: scene.morphing
        progress: gesture.progress
        toGrid: gesture.toGrid
        glass: glass
        chips: scene.chips
        pace: scene.slow
        cover: Component {
            Item {
                id: flyingCover

                property var spec

                signal redrawn()

                onSpecChanged: drawing.show()

                // the "app's" drawing at the size it was asked, scaled to the flying cover, as a window pixmap is
                Item {
                    id: buffer

                    width: scene.drawnSize.width
                    height: scene.drawnSize.height
                    transform: Scale {
                        xScale: flyingCover.width / Math.max(1, buffer.width)
                        yScale: flyingCover.height / Math.max(1, buffer.height)
                    }
                    onWidthChanged: flyingCover.redrawn()

                    Loader {
                        id: drawing

                        function show() {
                            if (item && flyingCover.spec) {
                                item.app = flyingCover.spec.app
                                item.tint = scene.running.indexOf(flyingCover.spec.app)
                            }
                        }

                        anchors.fill: parent
                        sourceComponent: coverComponent
                        onLoaded: show()
                    }
                }
            }
        }
    }

    // A card's place in the row, the row scrolled to contentX: as the delegate draws it (scaled about its centre)
    function cardPlace(row, contentX) {
        var delegateHeight = scene.cardHeight + Theme.iconSizeSmall + 2 * Theme.paddingSmall + 2 * Theme.paddingMedium
        var cx = row * scene.pitch - contentX + scene.cardWidth / 2
        var away = Math.abs(cx - cards.width / 2) / scene.pitch
        var s = 1 - 0.17 * Math.min(1, away) - 0.08 * Math.max(0, Math.min(1, away - 1))
        var cy = cards.y + delegateHeight / 2
        return { "x": cx - scene.cardWidth * s / 2, "y": cy + (cards.y - cy) * s,
                 "w": scene.cardWidth * s, "h": scene.cardHeight * s,
                 "dim": Math.min(0.72, 0.5 * away), "opacity": away < 2 ? 1 : Math.max(0, 1 - (away - 2) * 2),
                 "z": 10 - away, "front": away < 0.5 }
    }

    // The row's scroll with card row in front
    function frontContentX(row) {
        return row * scene.pitch - (cards.width - scene.cardWidth) / 2
    }

    // A cover's place in the grid, computed (the controller computes the stock grid's)
    function gridPlace(index) {
        var w = Theme.coverSizeLarge.width
        var h = Theme.coverSizeLarge.height
        var col = index % grid.columns
        return { "x": grid.x + col * (w + grid.columnSpacing),
                 "y": grid.y + Math.floor(index / grid.columns) * (h + grid.rowSpacing), "w": w, "h": h }
    }

    function startPinch(centre) {
        var toGrid = scene.mode === "cards"
        var focal = -1
        if (toGrid) {
            focal = cards.currentIndex
        } else {
            // the cover under the fingers, or the nearest
            var best = 1e9
            for (var i = 0; i < scene.running.length; i++) {
                var g = gridPlace(i)
                var dx = centre.x - Math.max(g.x, Math.min(g.x + g.w, centre.x))
                var dy = centre.y - Math.max(g.y, Math.min(g.y + g.h, centre.y))
                if (dx * dx + dy * dy < best) {
                    best = dx * dx + dy * dy
                    focal = scene.mruApps.indexOf(scene.running[i])
                }
            }
            cards.currentIndex = focal
            cards.positionViewAtIndex(focal, ListView.Center)
        }
        var contentX = toGrid ? cards.contentX : frontContentX(focal)
        var list = []
        for (var r = 0; r < scene.mruApps.length; r++) {
            var app = scene.mruApps[r]
            list.push({ "app": app, "cards": cardPlace(r, contentX), "grid": gridPlace(scene.running.indexOf(app)),
                        "lag": Math.min(1, Math.abs(r - focal) / 3) })
        }
        morph.covers = list
        scene.pinchCentre = centre
        var cardSize = Qt.size(scene.cardWidth, scene.cardHeight)
        startSize = toGrid ? cardSize : Theme.coverSizeLarge
        targetSize = toGrid ? Theme.coverSizeLarge : cardSize
        askedSize = startSize
        drawnSize = startSize
        console.log("harness: pinch from", scene.mode, "focal", focal, scene.mruApps[focal].title)
        gesture.begin(toGrid)
    }

    // After a switch: how far the switch layer's last frame was from the layout now shown (0: no jump)
    function checkFit() {
        var worst = 0
        for (var r = 0; r < morph.covers.length; r++) {
            var spec = morph.covers[r]
            var want = gesture.toGrid ? spec.grid : spec.cards
            var got
            if (gesture.toGrid) {
                var item = gridCovers.itemAt(scene.running.indexOf(spec.app))
                var p = item.mapToItem(scene, 0, 0)
                got = { "x": p.x, "y": p.y, "w": item.width, "h": item.height }
            } else {
                got = cardPlace(r, cards.contentX)
            }
            worst = Math.max(worst, Math.abs(want.x - got.x), Math.abs(want.y - got.y),
                             Math.abs(want.w - got.w), Math.abs(want.h - got.h))
        }
        console.log("harness: pinch fit", Math.round(worst * 10) / 10, "px, contentX", cards.contentX,
                    "front", cards.currentIndex)
    }

    // The run: pinch in a quarter of the way and let go (springs back), then past the point (the grid), then out
    // on the fourth cover (the cards, with that one in front)
    SequentialAnimation {
        id: pinchScript

        PauseAnimation { duration: 1200 }
        ScriptAction { script: { scene.harness.frameSlow = scene.slow; scene.harness.startFrames() } }
        PauseAnimation { duration: 300 * scene.slow }
        ScriptAction { script: { scene.fakeScale = 1; scene.startPinch(Qt.point(scene.width / 2, cards.y + cards.height / 2)) } }
        NumberAnimation { target: scene; property: "fakeScale"; to: 0.84; duration: 400 * scene.slow; easing.type: Easing.InOutQuad }
        PauseAnimation { duration: 200 * scene.slow }
        ScriptAction { script: gesture.end() }
        PauseAnimation { duration: 700 * scene.slow }
        ScriptAction { script: { scene.fakeScale = 1; scene.startPinch(Qt.point(scene.width / 2, cards.y + cards.height / 2)) } }
        NumberAnimation { target: scene; property: "fakeScale"; to: 0.68; duration: 500 * scene.slow; easing.type: Easing.InOutQuad }
        PauseAnimation { duration: 150 * scene.slow }
        ScriptAction { script: gesture.end() }
        PauseAnimation { duration: 1100 * scene.slow }
        ScriptAction {
            script: {
                var g = scene.gridPlace(3)
                scene.fakeScale = 1
                scene.startPinch(Qt.point(g.x + g.w / 2, g.y + g.h / 2))
            }
        }
        NumberAnimation { target: scene; property: "fakeScale"; to: 1.5; duration: 500 * scene.slow; easing.type: Easing.InOutQuad }
        PauseAnimation { duration: 150 * scene.slow }
        ScriptAction { script: gesture.end() }
        PauseAnimation { duration: 1200 * scene.slow }
        ScriptAction { script: scene.harness.stopFrames() }
    }

    function closeCard(i) {
        var order = scene.mruApps.slice()
        var gone = order.splice(i, 1)[0]
        var list = scene.running.slice()
        list.splice(list.indexOf(gone), 1)
        scene.running = list
        scene.mruApps = order
        scene.closed = [gone].concat(scene.closed).slice(0, 5)
        scene.push = 0
    }

    // a dot per card
    Row {
        id: dots

        parent: pinchArea
        opacity: scene.morphing ? 1 - morph.gridness : 1

        visible: (scene.mode === "cards" || scene.morphing) && scene.pushed === 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: cards.y + cards.height + Theme.paddingMedium
        spacing: Theme.paddingMedium

        Repeater {
            model: scene.running.length

            Rectangle {
                width: Theme.paddingSmall * 1.5
                height: width
                radius: width / 2
                color: index === cards.currentIndex ? Theme.highlightColor : Theme.rgba(Theme.primaryColor, 0.4)
            }
        }
    }

    SwitcherHint {
        parent: pinchArea
        opacity: scene.morphing ? 1 - morph.gridness : 1
        visible: (scene.mode === "cards" || scene.morphing) && scene.pushed === 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: dots.y + Theme.paddingLarge * 2
        glass: glass
    }

    // The apps closed last: at the bottom, or in the grid after the covers when they reach further down
    RecentApps {
        parent: pinchArea
        // gliding between its two places in a switch
        y: scene.morphing ? gridY + (cardsY - gridY) * (1 - morph.gridness) : scene.mode === "grid" ? gridY : cardsY
        readonly property real gridY: Math.max(grid.y + grid.rowsHeight + scene.chipSpace + Theme.paddingLarge * 2,
                                               cardsY)
        readonly property real cardsY: scene.height - height - Theme.paddingLarge * 3
        glass: glass
        apps: scene.closed
    }

    // The run (cards): turn a card, push it up half way and let go (it springs back), then past the point of
    // closing and let go (it closes)
    SequentialAnimation {
        id: script

        PauseAnimation { duration: 800 }
        ScriptAction { script: { scene.harness.frameSlow = scene.slow; scene.harness.startFrames() } }
        PauseAnimation { duration: 300 * scene.slow }
        // a fast fling runs over several cards, and snaps to one in front
        ScriptAction { script: cards.flick(-2600 * Theme.pixelRatio / scene.slow, 0) }
        PauseAnimation { duration: 900 * scene.slow }
        ScriptAction { script: cards.currentIndex = 1 }
        PauseAnimation { duration: 500 * scene.slow }
        NumberAnimation { target: scene; property: "push"; from: 0; to: 0.6; duration: 300 * scene.slow }
        PauseAnimation { duration: 300 * scene.slow }
        ScriptAction { script: cards.currentItem.release() }
        PauseAnimation { duration: 500 * scene.slow }
        NumberAnimation { target: scene; property: "push"; from: 0; to: 1.3; duration: 450 * scene.slow }
        PauseAnimation { duration: 450 * scene.slow }
        ScriptAction { script: cards.currentItem.release() }
        PauseAnimation { duration: 800 * scene.slow }
        ScriptAction { script: scene.harness.stopFrames() }
    }
}
