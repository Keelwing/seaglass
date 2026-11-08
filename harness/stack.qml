// A real ApplicationWindow and PageStack, for what only a page push shows: scripts/harness.sh --stack runs this
// instead of harness.qml. It reads the scene and picture files next to it as harness.qml does, and grabs itself into
// harness.png for --shot: when the grab file says (--grab SECS, from the start), or else at the end of the scene's
// first rest. Each step logs "harness: stack step NAME begin" and "end" for scripts/bench-frames.py, and the run ends
// with "harness: stack done" (scripts/harness.sh --until).
//
// The scene file holds "NAME [OPTION=VALUE ...]". The scenes:
//   push     the Animations page pushed with the stock picture, a rest, a pop, and a second push in the same process.
//            Options: page=stripped (a page with only a PageHeader instead, whose first frame sets the real one's
//            limit), rest=8 (seconds), from=hub (the Settings app's way, beside the cold push from an empty first
//            page: the settings' first page, SettingsPage.qml as scripts/harness.sh writes it, pushed first and left
//            at rest, then each push of the Animations page made by its open(), as a tap on its Animations row makes
//            it, after a line "hub page compiled", "compiling" or "not requested" on how far the hub has compiled the
//            page; with page=stripped the stripped page is pushed over it, with no such line),
//            hubrest=3 (seconds; at 0.2 the push comes before the hub's compile, which starts 1 s after it is made)
//   viewer STYLE MOMENT
//            the Animations page pushed and made, then its viewer pushed on that style and moment (ember open by
//            default), as a tap on a frame pushes it: its first run, 10 s at rest, a tap on the stage, a swipe to the
//            next style (mouse events, a move each frame, as harness/FilmScene.qml's glide sends them; the release
//            logs "drag released after N moves in M ms"), a rest, a pop. After the push and after the swipe, a line
//            "about STYLE MOMENT lines N whole|cut" on the line about the style. Option: rest=8 (seconds)
// In any scene orientation=landscape sets the window's allowedOrientations; it is portrait by default.
import QtQuick 2.6
import QtTest 1.0
import Sailfish.Silica 1.0

ApplicationWindow {
    id: root

    // a stock ambience, as in harness.qml, never the phone's own wallpaper
    readonly property string picture: readFile("picture") || "/usr/share/ambience/water/images/ambience_water.jpg"
    readonly property var words: readFile("scene").split(" ")
    readonly property string scene: words[0] || "push"
    readonly property real grabAt: parseFloat(readFile("grab")) || 0
    // with from=hub, the settings' first page (SettingsHub.qml) the pushes come from
    property Item hub: null

    allowedOrientations: option("orientation", "") === "landscape" ? Orientation.Landscape : Orientation.Portrait
    cover: undefined

    function readFile(name) {
        var xhr = new XMLHttpRequest()
        try {
            xhr.open("GET", Qt.resolvedUrl(name), false)
            xhr.send()
            return xhr.responseText.replace(/\s+$/, "")
        } catch (e) {
            return ""
        }
    }

    function option(name, fallback) {
        for (var i = 1; i < words.length; i++) {
            var pair = words[i].split("=")
            if (pair[0] === name)
                return pair[1]
        }
        return fallback
    }

    // an option in seconds: 0 is a time like any other, and a value that is not a number gives the fallback
    function seconds(name, fallback) {
        var value = parseFloat(option(name, ""))
        return isNaN(value) ? fallback : value
    }

    function log() {
        console.log("harness: stack " + Array.prototype.slice.call(arguments).join(" "))
    }

    function step(name, edge) {
        log("step", name, edge)
    }

    // how a kit (PreviewKit.qml) came to grab its textures: once its pictures had come, or by its 1.5 s giveUp, and
    // what it waited for
    function kitWait(kit) {
        return kit === null ? "none" : !kit.ready ? "not grabbed yet"
                : kit.gaveUpOn === "" ? "shot once its pictures came" : "gave up waiting for " + kit.gaveUpOn
    }

    // the viewer's line about its style: the lines it took, and whether Qt cut it to fit its two
    function logAbout(viewer) {
        var line = viewer.aboutLine
        log("about", viewer.style, viewer.moment, "lines", line.lineCount, line.truncated ? "cut" : "whole")
    }

    function after(ms, then) {
        later.then = then
        later.interval = ms
        later.restart()
    }

    // each function gets the one to call when it is done
    function sequence(list) {
        var at = 0
        var next = function () {
            if (at < list.length)
                list[at++](next)
        }
        next()
    }

    function grab() {
        var path = Qt.resolvedUrl("harness.png").toString().replace(/^file:\/\//, "")
        backing.visible = true
        root.grabToImage(function (result) {
            backing.visible = false
            console.log("harness: screenshot", result.saveToFile(path) ? path : "failed")
        })
    }

    // how far the hub has come with the Animations page's compile (its animationsPage)
    function hubCompile() {
        var compile = hub.animationsPage
        return compile === null ? "not requested" : compile.status === Component.Ready ? "compiled"
                : compile.status === Component.Loading ? "compiling" : "failed"
    }

    // the step ends when the page is Active, which is when a page's "started" comes. With from=hub the Animations
    // page is pushed by the hub's open() and given the stock picture at once, before its start reads it
    function pushPage(name, done) {
        var stripped = option("page", "") === "stripped"
        if (hub !== null && !stripped)
            log("hub page", hubCompile())
        step(name, "begin")
        var since = Date.now()
        var page
        if (stripped) {
            page = pageStack.push(strippedPage)
        } else if (hub !== null) {
            hub.open("AnimationsPage")
            page = pageStack.currentPage
            page.ambienceFile = picture
        } else {
            page = pageStack.push(Qt.resolvedUrl("../qml/settings/AnimationsPage.qml"), { "ambienceFile": picture })
        }
        log("push call took", Date.now() - since)
        whenActive(page, function () {
            step(name, "end")
            log("page orientation", page.orientation, page.width + "x" + page.height)
            done()
        })
    }

    function whenActive(page, done) {
        if (page.status === PageStatus.Active) {
            done()
            return
        }
        var check = function () {
            if (page.status === PageStatus.Active) {
                page.statusChanged.disconnect(check)
                done()
            }
        }
        page.statusChanged.connect(check)
    }

    // a rest of the seconds given, or of the scene's rest= when none are
    function rest(name, done, secs) {
        step(name, "begin")
        after((secs === undefined ? seconds("rest", 8) : secs) * 1000, function () {
            step(name, "end")
            done()
        })
    }

    // calls done once test() holds, looking every 100 ms, or after ms with a line that it gave up
    function waitFor(test, ms, done, what) {
        var since = Date.now()
        var look = function () {
            if (test()) {
                done()
            } else if (Date.now() - since > ms) {
                log("gave up waiting for", what, "after", ms, "ms")
                done()
            } else {
                poll.then = look
                poll.restart()
            }
        }
        look()
    }

    function tap(item, x, y, done) {
        events.mousePress(item, x, y, Qt.LeftButton, Qt.NoModifier, -1)
        after(60, function () {
            events.mouseRelease(item, x, y, Qt.LeftButton, Qt.NoModifier, -1)
            done()
        })
    }

    // a finger drawn by dx, dy over 200 ms: a move on each tick of an animation (finger, below), which comes once a
    // frame, so that every frame has a move to draw, as under a real finger. A Timer keeps a clock of its own, apart
    // from the display's, and the frames would come at its rate instead
    function drag(item, x, y, dx, dy, done) {
        finger.item = item
        finger.startX = x
        finger.startY = y
        finger.byX = dx
        finger.byY = dy
        finger.then = done
        finger.moves = 0
        events.mousePress(item, x, y, Qt.LeftButton, Qt.NoModifier, -1)
        finger.since = Date.now()
        finger.start()
    }

    // with from=hub, the settings' first page pushed and left at rest, as the Settings app shows it before a tap on
    // a row; nothing otherwise
    function pushHub(done) {
        if (option("from", "") !== "hub") {
            done()
            return
        }
        step("hub-push", "begin")
        var page = pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
        whenActive(page, function () {
            step("hub-push", "end")
            for (var i = 0; i < page.children.length && hub === null; i++) {
                if (page.children[i].animationsPage !== undefined)
                    hub = page.children[i]
            }
            log("hub", hub !== null)
            rest("hub-rest", done, seconds("hubrest", 3))
        })
    }

    function runPush() {
        sequence([
            function (next) { pushHub(next) },
            function (next) { pushPage("first-push", next) },
            function (next) { rest("first-rest", next) },
            function (next) {
                // outside the steps: saving a picture holds up the GUI thread for about a second
                if (!grabAt)
                    grab()
                after(2000, next)
            },
            function (next) {
                step("pop", "begin")
                pageStack.pop()
                after(2000, function () {
                    step("pop", "end")
                    next()
                })
            },
            function (next) { pushPage("second-push", next) },
            function (next) { rest("second-rest", next) },
            function () { log("done") }
        ])
    }

    // the sheet built and the viewer's page compiled at rest, then the viewer pushed as a tap on a frame pushes it.
    // The viewer plays once by itself; its played and settled say when a run and what follows it are over
    function runViewer() {
        var named = words.slice(1).filter(function (word) { return word.indexOf("=") < 0 })
        var styleId = named[0] || "ember"
        var momentId = named[1] || "open"
        var sheet = null
        var viewer = null
        // a page in a stack makes nothing until the application is active
        log("application active", Qt.application.active)
        sequence([
            function (next) {
                step("sheet-push", "begin")
                sheet = pageStack.push(Qt.resolvedUrl("../qml/settings/AnimationsPage.qml"),
                                       { "ambienceFile": picture })
                whenActive(sheet, function () {
                    step("sheet-push", "end")
                    next()
                })
            },
            function (next) {
                step("sheet-build", "begin")
                waitFor(function () {
                    return sheet.built && sheet.viewerComponent !== null
                            && sheet.viewerComponent.status !== Component.Loading
                }, 60000, function () {
                    log("sheet built", sheet.built, "viewer component",
                        sheet.viewerComponent ? sheet.viewerComponent.status : "none")
                    step("sheet-build", "end")
                    next()
                }, "the sheet")
            },
            function (next) {
                step("viewer-push", "begin")
                var compiled = sheet.viewerComponent !== null && sheet.viewerComponent.status === Component.Ready
                var since = Date.now()
                sheet.openViewer(styleId, momentId, "one")
                log("push call took", Date.now() - since, "from", compiled ? "the compiled component" : "the file")
                waitFor(function () { return pageStack.currentPage !== sheet }, 5000, function () {
                    viewer = pageStack.currentPage
                    whenActive(viewer, function () {
                        step("viewer-push", "end")
                        log("viewer", viewer.style, viewer.moment, "live", viewer.live, "orientation",
                            viewer.orientation, "stage", viewer.stageWidth + "x" + viewer.stageHeight)
                        logAbout(viewer)
                        next()
                    })
                }, "the viewer")
            },
            function (next) {
                step("viewer-first", "begin")
                waitFor(function () { return viewer.played >= 1 && viewer.settled }, 30000, function () {
                    log("first run", viewer.played, "strip", viewer.strip !== null && viewer.strip.ready)
                    step("viewer-first", "end")
                    log("viewer kit", kitWait(viewer.kit), "strip kit", kitWait(viewer.stripKit))
                    next()
                }, "the first run")
            },
            function (next) { rest("viewer-rest", next, 10) },
            function (next) {
                // outside the steps: saving a picture holds up the GUI thread for about a second
                if (!grabAt)
                    grab()
                after(2000, next)
            },
            function (next) {
                step("run", "begin")
                var at = viewer.stage.mapToItem(viewer, viewer.stageWidth / 2, viewer.stageHeight / 2)
                tap(viewer, at.x, at.y, function () {
                    waitFor(function () { return viewer.played >= 2 && viewer.settled }, 30000, function () {
                        step("run", "end")
                        next()
                    }, "the run")
                })
            },
            function (next) {
                step("swipe", "begin")
                var before = viewer.style
                var at = viewer.stage.mapToItem(viewer, viewer.stageWidth * 0.8, viewer.stageHeight / 2)
                drag(viewer, at.x, at.y, -viewer.stageWidth * 0.6, 0, function () {
                    waitFor(function () { return viewer.style !== before && viewer.played >= 3 && viewer.settled },
                            30000, function () {
                        log("swiped from", before, "to", viewer.style)
                        logAbout(viewer)
                        step("swipe", "end")
                        next()
                    }, "the swipe's run")
                })
            },
            function (next) { rest("rest", next) },
            function (next) {
                step("pop", "begin")
                pageStack.pop()
                after(2000, function () {
                    step("pop", "end")
                    next()
                })
            },
            function () { log("done") }
        ])
    }

    initialPage: Component {
        Page {
            allowedOrientations: Orientation.All
        }
    }

    Component {
        id: strippedPage

        Page {
            allowedOrientations: Orientation.All

            PageHeader {
                title: "Stripped"
            }
        }
    }

    // the wallpaper is a window of its own, which a grab of this one leaves out: without this the shot is transparent
    Rectangle {
        id: backing

        anchors.fill: parent
        z: -1
        visible: false
        color: Theme.overlayBackgroundColor
    }

    TestEvent {
        id: events
    }

    // drag()'s finger: at goes from 0 to 1, and each tick moves the finger there; the release, at the end, says how
    // many moves it took
    NumberAnimation {
        id: finger

        property Item item
        property real startX
        property real startY
        property real byX
        property real byY
        property var then
        property int moves
        property double since
        property real at

        target: finger
        property: "at"
        from: 0
        to: 1
        duration: 200
        onAtChanged: {
            if (at <= 0)
                return
            moves++
            events.mouseMove(item, startX + byX * at, startY + byY * at, -1, Qt.LeftButton)
        }
        onStopped: {
            events.mouseRelease(item, startX + byX, startY + byY, Qt.LeftButton, Qt.NoModifier, -1)
            root.log("drag released after", moves, "moves in", Date.now() - since, "ms")
            then()
        }
    }

    Timer {
        id: later

        property var then

        onTriggered: then()
    }

    Timer {
        id: poll

        property var then

        interval: 100
        onTriggered: then()
    }

    Timer {
        interval: root.grabAt * 1000
        running: root.grabAt > 0
        onTriggered: root.grab()
    }

    // once the window has settled
    Timer {
        interval: 5000
        running: true
        onTriggered: {
            root.log("scene", root.words.join(" "), "screen", Screen.width + "x" + Screen.height, "pixelRatio",
                     Theme.pixelRatio)
            if (root.scene === "push") {
                root.runPush()
            } else if (root.scene === "viewer") {
                root.runViewer()
            } else {
                root.log("no such scene", root.scene)
                root.log("done")
            }
        }
    }
}
