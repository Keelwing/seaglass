// The bench scene: what the animations cost on this phone, with the home screen's own files. Everything it finds goes
// to the log as "harness: bench ...", and the run ends with "harness: bench done" (scripts/harness.sh --until). What it
// draws lies between "harness: bench step NAME begin" and "end", so that scripts/bench-frames.py can read the frames
// and compiles of each stretch from a log with the scene graph's timing rules on.
//
// Vsync hides whatever fits in a frame, so a cost is read from a slope: the effect is drawn K times a frame, blended,
// so that nothing is culled, and K grows until the frames come far apart. Past that point the time between frames is
// about K times the cost. Two such K give the cost, with the phone's vsync steps, the compositor and everything else
// that does not grow with K left out of it. The GPU runs at the top of its clocks then, so the number is the cost at
// full speed, and K stacked layers share the texture cache tile by tile, so it may read low (layered=1 puts every
// copy in a render pass of its own, which breaks that; it adds a blit). A run at a real moment's length (play) shows
// what is left of it from an idle GPU. A cost line that ends in "suspect" is not a cost: its slope falls, or its rest
// (the frame time the line gives at K=0) is under -3 or over 20 ms, so the phone changed state between its samples or
// they do not lie on a line.
//
// Modes, the first word of the argument:
//   cost     every style and moment held at a few progress values. Options: size=100,55 (percent of the screen's
//            width, and 0 for one pixel: the CPU's share per copy), at=0.15,0.5,0.85, only=ember-close,blit,
//            ks=1,2,4 (these K instead of the search), kmax=160 (the largest K; given, the search climbs to it
//            however many samples that takes, where it otherwise stops at eight), layered=1
//   play     every style and moment once at its length from an idle GPU, each frame counted, played as the home
//            screen plays it: Effect.qml's play() (a loading's runClock()) and Shards.qml's, on the render thread. A
//            loading has no end of its own there; here its clock runs for 3 s. Each run is the first play() of a new
//            Effect or Shards, which makes its animators in that call (logged as "play call"). Options: size, only,
//            rounds=3, driver=gui (progress and time set from the GUI thread instead, by an animation, for comparison)
//   compile  the longest frame when each shader first draws, twice over: the second time Qt has it already. Options:
//            size=100 (drawn at that size instead of the warm-up's one pixel), only
//   page     the settings' Animations page, in this order: the spare time per frame over the empty window, before any
//            page exists (empty: blits drawn over it until the frames slip); the page made and its sheet built (build:
//            its frames, the whole time, the longest frames; then flatten: the frames grabbed into one picture); at
//            rest at the top and at the bottom (rest, quiet); flicked for 14 s (flick); the spare time over it at the
//            top (spare); a page that keeps its sheet in a file, made and saved (saved: the grab and the save after
//            the frames); a second one, which must show that file and make no frame (cached: its frames from the
//            start); and the viewer's stage (viewer: every style and moment as the viewer plays it, through
//            AnimationStage.qml, at the size the viewer draws it at, the frames of each run by the stage's own
//            intervals). Only saved and cached keep a file, and in the harness's own folder. It ends with a table of
//            what each step saw against its limit. Options: steps=empty,build,rest,flick,spare,saved,cached,viewer
//            (any of them; the page is made and built for build, rest, flick and spare), ks=0,16,18,20,22,24,26,28,30,
//            32,40 (the blits), rest=10 (seconds at each place), flick=1 (flicked while the sheet is built, which
//            pauses the build), tick=0 (the tick stopped while the sheet is built, as in the Settings app, so that
//            only the page asks for frames: a poll watches the build, and its frames are the frame log's), flatten=0
//            (the frames stay the sheet: no picture is made, and rest, flick and spare run on the frames); for viewer
//            rounds=3 (runs of a moment at one size), only=ember-open,... (those moments), speed=2 (the speed
//            setting: 0 relaxed, 1 normal, 2 quick), stage=WIDTH (the stage's width in pixels, in a phone's shape; by
//            default the viewer page's own stage in portrait), rungs=table (each moment only at the size stills.js
//            gives it) or rungs=1,0.8 (at those sizes). By default an opening or closing runs at its size in
//            stills.js, then at the next larger size while it passes, or the next smaller while it fails, so that the
//            log names the largest that passes
//   quiet    nothing drawn and the tick stopped, as at the page's rest: what the scene itself renders, which should be
//            no frames. Options: rest=10 (seconds)
//   animators  a moment on the render thread (Effect.qml's play), with the tick stopped: the frames it draws during a
//            400 ms block of the GUI thread (the frames of the step "animators block"), a closing window's way back
//            to whole through a block, how often ended comes after a natural end, a halt() and a halt() and play()
//            again, a split moment's grains, an Effect and the covers' two files going while or after they run, a
//            cover's closing after its cover went and through a block, the mean time to make an Effect, over 20, and
//            of its first play(), which makes its animators. Each function says what to expect. Its pictures go to
//            harness/frames/, on the stock picture, and "differ" compares them. Options: split=dust (the split
//            closing whose grains are grabbed and whose make is timed: dust or frost), back=contour (the closing that
//            comes back: dust or frost bring their grains pass back with it)
//
// The tick asks for a frame all the time, and the scene measures its stretches by it. A rest stops it (quiet), so that
// what still gets rendered can be counted from the log. A build with tick=0 stops it too, as in the Settings app, where
// only the page's own animations run: any running animation keeps every Timer to frames.
//
// salt=1, in any mode, puts a comment at the end of every shader's text, new on each run: Qt's program store
// ($XDG_RUNTIME_DIR/qsg-pb-store) has not seen that program, so its first draw is a cold compile. Use it sparingly: the
// store stays in tmpfs until reboot, and grows with each salted run.
//
// A shader's moment is drawn as Effect.qml draws it, half and split included; an opening's or closing's time is its
// progress times its length, a loading's a running clock (at 0.5: 6 s). "blit" is a plain textured quad, the scale for
// the rest, and comes back during a run: if it grows, the phone has slowed down. "capture" is a live layer over a
// window-sized picture (ShaderEffectSource, a pass per copy), "capture-mip" the same with mipmaps: what an opening
// adds when the window changes while it plays.
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../qml/animations"
import "../qml/animations/styles.js" as Styles
import "../qml/animations/shaders.js" as Shaders
import "../qml/settings"
import "../qml/settings/stills.js" as Stills

Item {
    id: scene

    property Item harness
    readonly property var words: harness ? harness.sceneArgument.split(" ") : []
    readonly property string mode: words[0] || "cost"
    readonly property real iconSide: Theme.iconSizeLauncher

    // what is drawn now, how many times a frame, and at what size (a fraction of the screen's)
    property string style
    property string moment
    property int copies
    property real fraction: 1
    readonly property int drawWidth: Math.max(1, Math.round(width * fraction))
    readonly property int drawHeight: Math.max(1, Math.round(height * fraction))
    readonly property string kind: style === "blit" ? "blit"
                                   : style === "capture" || style === "capture-mip" ? "capture"
                                   : style === "shatter" && moment !== "load" ? "shards"
                                   : style !== "" ? "effect" : ""
    readonly property bool layered: option("layered", "0") === "1"
    property bool shown: true

    // the progress it is held at, or a run from 0 to 1. Held, it moves a hair every frame, so that every frame redraws
    property real held: 0.5
    property bool moving
    property bool flip
    property real played
    readonly property real moved: moving && flip ? 0.0005 : 0
    readonly property real progressNow: run.running ? played : held + moved
    readonly property real timeNow: moment === "load" ? (run.running ? played * 3 : held * 12 + moved)
                                                      : progressNow * Styles.duration(style, moment, 1) / 1000

    // bench.watch(interval, now) gets every frame; bench.then waits for the timer below
    property var bench: ({ "watch": null, "then": null })
    property double lastFrame
    property real tick
    property bool quiet
    // the poll below calls frame() instead of the tick
    property bool polling
    property real budget: 16.67
    // where the search for K starts: the last point's, since most points are close to it
    property int startK: 1
    property string lastKind
    property real lastFraction
    // how often the animated Effect's ended came, and what to do at the next
    property int endedCount
    property var atEnded: null
    // page: what each step saw, for the table at the end
    property var pageChecks: ({})
    // the viewer step: what to do when the stage's moment has run, when its run is over, and when its warmer is done
    property var atRan: null
    property var atRunEnded: null
    property var atWarmed: null

    onTickChanged: frame()
    // a rest is not one long frame
    onQuietChanged: lastFrame = Date.now()
    onHarnessChanged: {
        if (harness)
            start()
    }

    // a tick, or a look of the poll, which changes nothing that draws: flip would ask for a frame
    function frame(polled) {
        var now = Date.now()
        var interval = now - lastFrame
        lastFrame = now
        if (!polled)
            flip = !flip
        if (bench.watch)
            bench.watch(interval, now)
    }

    function option(name, fallback) {
        for (var i = 1; i < words.length; i++) {
            var pair = words[i].split("=")
            if (pair[0] === name)
                return pair[1]
        }
        return fallback
    }

    function numbers(name, fallback) {
        return option(name, fallback).split(",").map(parseFloat)
    }

    function after(ms, then) {
        bench.then = then
        later.interval = ms
        later.restart()
    }

    function each(list, step, done) {
        var at = 0
        var next = function () {
            if (at >= list.length)
                done()
            else
                step(list[at++], next)
        }
        next()
    }

    function stats(list) {
        var sorted = list.slice().sort(function (a, b) { return a - b })
        var sum = 0
        for (var i = 0; i < sorted.length; i++)
            sum += sorted[i]
        var percentile = function (p) { return sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * p))] }
        var over = function (ms) { return sorted.filter(function (x) { return x > ms }).length }
        return { "frames": sorted.length, "mean": sorted.length ? sum / sorted.length : 0, "median": percentile(0.5),
                 "p95": percentile(0.95), "p99": percentile(0.99), "max": sorted[sorted.length - 1] || 0,
                 "over1": over(budget * 1.5), "over2": over(budget * 2.5), "over3": over(budget * 3.5),
                 "over16": over(16.7), "over33": over(33) }
    }

    function statsText(s) {
        return "frames=" + s.frames + " mean=" + s.mean.toFixed(1) + " median=" + s.median + " p95=" + s.p95
                + " p99=" + s.p99 + " max=" + s.max + " over1.5=" + s.over1 + " over2.5=" + s.over2
                + " over3.5=" + s.over3
    }

    // the words given, but for empty ones
    function log() {
        console.log("harness: bench " + Array.prototype.slice.call(arguments).filter(function (word) {
            return word !== ""
        }).join(" "))
    }

    function step(name, edge) {
        log("step", name.replace(/ /g, "-"), edge)
    }

    // a stretch with the tick stopped, to be read from the log
    function quietly(name, ms, done) {
        quiet = true
        step(name, "begin")
        after(ms, function () {
            step(name, "end")
            quiet = false
            done()
        })
    }

    // every style and moment: [{style, moment}], Shatter's shards among them
    function allEffects() {
        var list = []
        var shaders = Styles.shaders()
        for (var i = 0; i < shaders.length; i++) {
            if (shaders[i].style === "shatter") {
                list.push({ "style": "shatter", "moment": "open" }, { "style": "shatter", "moment": "close" })
            }
            list.push(shaders[i])
        }
        var only = option("only", "")
        return only === "" ? list : list.filter(function (item) {
            return only.split(",").indexOf(item.style + "-" + item.moment) >= 0
        })
    }

    function pointName(point) {
        return point.style + (point.moment ? "-" + point.moment : "")
                + " size=" + Math.round(point.fraction * 100) + " at=" + point.at
    }

    function start() {
        var base = Qt.resolvedUrl("../qml/animations/shaders/")
        // past the harness's own screenshot, and by then the window knows its GL version
        after(4500, function () {
            var shaders = Styles.shaders()
            var salt = option("salt", "0") === "1"
            var left = shaders.length + (salt ? 2 : 0)
            var loaded = function () {
                if (--left > 0)
                    return
                if (salt)
                    saltShaders()
                log("start", harness.sceneArgument, "screen", width + "x" + height, "es3", warm.es3, "pixelRatio",
                    Theme.pixelRatio)
                measureIdle(function () {
                    if (mode === "cost")
                        each(costList(), costPoint, finish)
                    else if (mode === "play")
                        playAll()
                    else if (mode === "compile")
                        runCompile()
                    else if (mode === "page")
                        runPage()
                    else if (mode === "quiet")
                        quietly("quiet", parseInt(option("rest", "10"), 10) * 1000, finish)
                    else if (mode === "animators")
                        runAnimators()
                    else
                        log("no such mode", mode)
                })
            }
            for (var i = 0; i < shaders.length; i++)
                Shaders.load(base, shaders[i].style + "-" + shaders[i].moment, Styles.libs(shaders[i].style), warm.es3,
                             loaded)
            if (salt) {
                Shaders.loadFile(base + "shards.vert", loaded)
                Shaders.loadFile(base + "shards.frag", loaded)
            }
        })
    }

    // Every Effect reads its text from Shaders when it is given a style, and every Shards when it is active, so this
    // reaches them all
    function saltShaders() {
        var salt = "\n// salt " + Date.now() + "\n"
        var stores = [Shaders.texts, Shaders.files]
        for (var i = 0; i < stores.length; i++) {
            for (var key in stores[i]) {
                if (stores[i][key] !== "")
                    stores[i][key] += salt
            }
        }
    }

    function finish() {
        bench.watch = null
        copies = 0
        moving = false
        log("done")
    }

    // the frame time with next to nothing drawn: the budget
    function measureIdle(done) {
        moving = true
        var list = []
        step("idle", "begin")
        bench.watch = function (interval) {
            list.push(interval)
            if (list.length >= 180) {
                bench.watch = null
                step("idle", "end")
                var s = stats(list)
                budget = s.mean
                log("idle", statsText(s), "all=" + list.slice(100, 160).join(","))
                done()
            }
        }
    }

    // ---- cost: the slope of the frame time over K

    function costList() {
        var sizes = numbers("size", "100")
        var ats = numbers("at", "0.15,0.5,0.85")
        var effects = allEffects()
        var only = option("only", "").split(",")
        var list = []
        var count = 0
        for (var n = 0; n < sizes.length; n++) {
            var fraction = sizes[n] / 100
            var refs = ["blit", "capture", "capture-mip"]
            for (var r = 0; r < refs.length; r++) {
                if (option("only", "") === "" || only.indexOf(refs[r]) >= 0)
                    list.push({ "style": refs[r], "moment": "", "fraction": fraction, "at": 0.5 })
            }
            for (var i = 0; i < effects.length; i++) {
                for (var a = 0; a < ats.length; a++) {
                    list.push({ "style": effects[i].style, "moment": effects[i].moment, "fraction": fraction,
                                "at": ats[a] })
                    if (option("only", "") === "" && ++count % 21 === 0)
                        list.push({ "style": "blit", "moment": "", "fraction": 1, "at": 0.5 })
                }
            }
        }
        return list
    }

    // the frame time at K copies, once the new copies have settled
    function measure(name, k, done) {
        step(name, "begin")
        copies = k
        var skip = 4
        var list = []
        var since = 0
        bench.watch = function (interval, now) {
            if (skip-- > 0) {
                since = now
                return
            }
            list.push(interval)
            if (list.length >= 16 || (list.length >= 5 && now - since > 1500)) {
                bench.watch = null
                step(name, "end")
                done(stats(list))
            }
        }
    }

    function costPoint(point, done) {
        copies = 0
        style = point.style
        moment = point.moment
        fraction = point.fraction
        held = point.at
        moving = true
        var name = pointName(point)
        var kind = scene.kind
        var kmaxGiven = option("kmax", "") !== ""
        var kmax = parseInt(option("kmax", "400"), 10)
        var fixed = option("ks", "") !== "" ? numbers("ks", "") : null
        // far from vsync, and not so far that the driver steps in (above about 300 ms a frame the times stop growing
        // with K)
        var floor = 50
        var ceiling = 170
        var samples = []
        // how many samples the climb to the floor took, when a given kmax lets it go on past eight
        var climbed = 0
        var report = function () {
            var usable = samples.filter(function (s) { return s.mean >= budget * 2 && s.mean <= ceiling })
            usable.sort(function (a, b) { return a.k - b.k })
            if (usable.length >= 2 && usable[0].k !== usable[usable.length - 1].k) {
                var a = usable[0], b = usable[usable.length - 1]
                var ms = (b.mean - a.mean) / (b.k - a.k)
                var rest = a.mean - a.k * ms
                var line = ["cost", name, "ms=" + ms.toFixed(2), "k=" + a.k + "," + b.k,
                            "mean=" + a.mean.toFixed(1) + "," + b.mean.toFixed(1), "rest=" + rest.toFixed(1)]
                if (ms < 0 || rest < -3 || rest > 20)
                    line.push("suspect")
                log.apply(scene, line)
            } else {
                log("cost", name, "ms<" + (budget / samples[samples.length - 1].k).toFixed(2), "k="
                    + samples[samples.length - 1].k, "no slope")
            }
            copies = 0
            startK = Math.max(1, Math.floor((usable.length ? usable[0].k : 1) * 0.6))
            done()
        }
        var tryK = function (k) {
            measure(name + " k=" + k, k, function (result) {
                result.k = k
                samples.push(result)
                log("sample", name, "k=" + k, statsText(result))
                if (fixed) {
                    if (samples.length < fixed.length)
                        tryK(fixed[samples.length])
                    else
                        report()
                    return
                }
                var top = samples.reduce(function (a, b) { return b.mean > a.mean ? b : a })
                var usable = samples.filter(function (s) { return s.mean >= budget * 2 && s.mean <= ceiling })
                // K only grows on the climb, and stops at kmax, so it ends without the limit of eight; the eight
                // count from where it ends
                if (kmaxGiven && top.mean < floor)
                    climbed = samples.length
                if (samples.length - climbed >= 8) {
                    report()
                } else if (top.mean < floor) {
                    if (k >= kmax)
                        report()
                    else if (result.mean < budget * 1.3)
                        tryK(Math.min(kmax, k * 2))
                    else
                        tryK(Math.min(kmax, Math.max(k + 1, Math.ceil(k * floor / result.mean * 1.1))))
                } else if (usable.length >= 2) {
                    report()
                } else if (top.mean > ceiling && top.k > 1) {
                    tryK(Math.max(1, Math.round(top.k * 0.5)))
                } else if (kmaxGiven && top.k >= kmax) {
                    report()
                } else {
                    var up = Math.max(top.k + 1, Math.ceil(top.k * 1.8))
                    tryK(kmaxGiven ? Math.min(kmax, up) : up)
                }
            })
        }
        if (kind !== lastKind || point.fraction !== lastFraction)
            startK = 1
        lastKind = kind
        lastFraction = point.fraction
        tryK(fixed ? fixed[0] : startK)
    }

    // ---- play: every moment at its length, from an idle GPU

    function playAll() {
        log("play driver", option("driver", "render") === "gui" ? "gui: progress set from the GUI thread"
                                                               : "render: play() and runClock(), on the render thread")
        each(playList(), playPoint, finish)
    }

    function playList() {
        var sizes = numbers("size", "100")
        var effects = allEffects()
        var rounds = parseInt(option("rounds", "3"), 10)
        var list = []
        for (var n = 0; n < sizes.length; n++) {
            for (var i = 0; i < effects.length; i++) {
                // a field is baked, and has no length
                if (effects[i].moment === "field")
                    continue
                for (var r = 1; r <= rounds; r++)
                    list.push({ "style": effects[i].style, "moment": effects[i].moment, "fraction": sizes[n] / 100,
                                "round": r })
            }
        }
        return list
    }

    function playPoint(point, done) {
        var name = point.style + "-" + point.moment + " size=" + Math.round(point.fraction * 100)
                + " round=" + point.round
        copies = 0
        shown = false
        moving = false
        style = ""
        step("warm " + name, "begin")
        warmUp(point, true)
        after(300, function () {
            step("warm " + name, "end")
            warmUp(point, false)
            style = point.style
            moment = point.moment
            fraction = point.fraction
            copies = 1
            // the idle GPU: nothing changes on the screen for most of a second
            after(900, function () {
                var length = point.moment === "load" ? 3000 : Styles.duration(point.style, point.moment, 1)
                var list = []
                var byGui = option("driver", "render") === "gui"
                var piece = (kind === "shards" ? shardsCopies : effectCopies).itemAt(0)
                var call = ""
                if (byGui) {
                    run.duration = length
                    shown = true
                    played = 0
                    step("play " + name, "begin")
                    run.restart()
                } else {
                    // its animators come with its first play(), and this one is new
                    var made = (kind === "shards" ? piece.run : piece.animators) === null
                    shown = true
                    step("play " + name, "begin")
                    var since = Date.now()
                    if (point.moment === "load")
                        piece.runClock(length / 1000)
                    else
                        piece.play(length)
                    call = (Date.now() - since) + " ms" + (made ? ", its animators made in it" : "")
                }
                var started = Date.now()
                bench.watch = function (interval, now) {
                    if (byGui ? run.running : piece.running) {
                        list.push(interval)
                        // a clock has no watchdog of its own
                        if (!byGui && now - started > length + 2000) {
                            log("play", name, "did not end, halted")
                            piece.halt()
                        }
                        return
                    }
                    bench.watch = null
                    step("play " + name, "end")
                    log("play", name, "length=" + length, statsText(stats(list)), "first="
                        + list.slice(0, 8).join(","))
                    if (!byGui)
                        log("play call", name, call, piece.ready ? "" : "(not ready: nothing was drawn)")
                    shown = false
                    copies = 0
                    after(200, done)
                }
            })
        })
    }

    // ---- compile: the longest frame when a shader first draws

    function warmUp(point, on) {
        var shards = point.style === "shatter" && point.moment !== "load"
        warmShards.active = on && shards
        warm.style = ""
        if (on && !shards) {
            warm.moment = point.moment
            warm.style = point.style
        }
    }

    function compilePoint(point, done) {
        warmUp(point, false)
        after(250, function () {
            var list = []
            var since = Date.now()
            var name = point.style + "-" + point.moment + " pass=" + point.pass
            step("compile " + name, "begin")
            warmUp(point, true)
            bench.watch = function (interval, now) {
                list.push(interval)
                if (now - since > 500) {
                    bench.watch = null
                    step("compile " + name, "end")
                    warmUp(point, false)
                    log("compile", name, "longest=" + Math.max.apply(null, list), "frames=" + list.length,
                        "all=" + list.join(","))
                    done()
                }
            }
        })
    }

    function runCompile() {
        moving = true
        var list = []
        for (var pass = 1; pass <= 2; pass++) {
            var effects = allEffects()
            for (var i = 0; i < effects.length; i++) {
                if (effects[i].style !== "shatter" || effects[i].moment !== "close") {
                    effects[i].pass = pass
                    list.push(effects[i])
                }
            }
        }
        each(list, compilePoint, finish)
    }

    // ---- animators: the moments on the render thread

    function runAnimators() {
        moving = false
        quiet = true
        each([animatorsBlock, animatorsComeBack, animatorsEnd, animatorsHalt, animatorsRestart, animatorsSplit,
              animatorsGoing, animatorsCoverClosing, animatorsCoverLoading, animatorsMade],
             function (part, next) { part(next) }, finish)
    }

    // the animated Effect on this moment, its program compiled the warm-up's way, so that no run starts with a compile
    function cue(style, moment, then) {
        warmUp({ "style": style, "moment": moment }, true)
        after(300, function () {
            warmUp({ "style": style, "moment": moment }, false)
            animated.moment = moment
            animated.style = style
            endedCount = 0
            after(200, then)
        })
    }

    function whenEnded(then) {
        if (animated.running)
            atEnded = then
        else
            then()
    }

    function grabAs(name, item, done) {
        var path = Qt.resolvedUrl("frames/" + name + ".jpg").toString().replace(/^file:\/\//, "")
        item.grabToImage(function (result) {
            log("animators grab", name, result.saveToFile(path) ? "saved" : "FAILED")
            if (done)
                done()
        }, Qt.size(Math.round(width / 2), Math.round(height / 2)))
    }

    // two saved pictures are the same file when nothing moved between them
    function differ(what, first, second) {
        var a = harness.readFile("frames/" + first + ".jpg")
        var b = harness.readFile("frames/" + second + ".jpg")
        log("animators differ", what, first, second, "sizes=" + a.length + "," + b.length, "differ=" + (a !== b))
    }

    function grainsOf(effect) {
        for (var i = 0; i < effect.children.length; i++) {
            if (effect.children[i].part === 2)
                return effect.children[i]
        }
        return null
    }

    // expect 20 or more frames in the step "animators block", against a stretch of the same run without the block
    function animatorsBlock(done) {
        cue("ember", "close", function () {
            log("animators block: a 2000 ms run, expect ended=1 at its end")
            step("animators run", "begin")
            animated.play(2000)
            after(300, function () {
                step("animators free", "begin")
                after(400, function () {
                    step("animators free", "end")
                    var since = Date.now()
                    step("animators block", "begin")
                    while (Date.now() - since < 400) {}
                    step("animators block", "end")
                    log("animators blocked", Date.now() - since, "ms")
                    whenEnded(function () {
                        step("animators run", "end")
                        log("animators block ended=" + endedCount)
                        done()
                    })
                })
            })
        })
    }

    // a Contour closing (or back=) at Quick, from a swipe let go at 0.4 of the height with the window faded to 0.5,
    // and the GUI thread blocked from 50 to 300 ms: the window comes back as the home screen brings it back, on the
    // render thread. Contour has no grains pass, and the come-back's animator for one has no target; a split closing
    // logs grains pass=true. Expect frames in the step "animators come back block", "animators-back-blocked" (the
    // first frame after the block) with what is left of the window, grains too, neither cut off at the top nor faded,
    // "animators-back-end" and "animators-back-after" with nothing of it, and ended=1 clipTop=0 opacity=1
    function animatorsComeBack(done) {
        var style = option("back", "contour")
        cue(style, "close", function () {
            log("animators come back", style, "grains pass=" + (grainsOf(animated) !== null))
            step("animators come back", "begin")
            animated.clipTop = 0.4
            animated.opacity = 0.5
            animated.play(Styles.duration(style, "close", 2))
            comeBack.start()
            after(50, function () {
                var since = Date.now()
                step("animators come back block", "begin")
                while (Date.now() - since < 250) {}
                step("animators come back block", "end")
                grabAs("animators-back-blocked", scene)
                whenEnded(function () {
                    grabAs("animators-back-end", scene, function () {
                        after(100, function () {
                            grabAs("animators-back-after", scene, function () {
                                step("animators come back", "end")
                                log("animators come back ended=" + endedCount, "clipTop=" + animated.clipTop,
                                    "opacity=" + animated.opacity)
                                // whole for the steps after, whatever the come-back did
                                comeBack.stop()
                                animated.clipTop = 0
                                animated.opacity = 1
                                done()
                            })
                        })
                    })
                })
            })
        })
    }

    // expect ended=1, running=false, progress=1, time=0.6 (ended itself comes before running goes false)
    function animatorsEnd(done) {
        cue("ember", "close", function () {
            step("animators end", "begin")
            animated.play(600)
            whenEnded(function () {
                after(300, function () {
                    step("animators end", "end")
                    log("animators end ended=" + endedCount, "running=" + animated.running,
                        "progress=" + animated.progress, "time=" + animated.time)
                    done()
                })
            })
        })
    }

    // expect ended=1 at once and still 300 ms later, running=false, and progress where the run was
    function animatorsHalt(done) {
        cue("ember", "close", function () {
            step("animators halt", "begin")
            animated.play(2000)
            after(500, function () {
                animated.halt()
                log("animators halt at once ended=" + endedCount)
                after(300, function () {
                    step("animators halt", "end")
                    log("animators halt ended=" + endedCount, "running=" + animated.running,
                        "progress=" + animated.progress)
                    done()
                })
            })
        })
    }

    // expect ended=1 at once, a run of 800 ms from there, and ended=2 after it, running=false, progress=1
    function animatorsRestart(done) {
        cue("ember", "close", function () {
            step("animators restart", "begin")
            animated.play(2000)
            after(500, function () {
                animated.halt()
                animated.play(800)
                log("animators restart at once ended=" + endedCount, "running=" + animated.running)
                whenEnded(function () {
                    after(300, function () {
                        step("animators restart", "end")
                        log("animators restart ended=" + endedCount, "running=" + animated.running,
                            "progress=" + animated.progress)
                        done()
                    })
                })
            })
        })
    }

    // the grains pass alone, three times during a run, a second apart: expect differ=true (the same file means grains
    // frozen at their start), and ended=1. split=frost runs 4 s, and its first grab, at t 0.25, comes before its snow
    // (grainsFrom): empty
    function animatorsSplit(done) {
        var style = option("split", "dust")
        cue(style, "close", function () {
            var grains = grainsOf(animated)
            log("animators split", style, "split=" + animated.split, "grains pass=" + (grains !== null))
            step("animators split", "begin")
            animated.play(style === "dust" ? 6000 : 4000)
            each([1, 2, 3], function (at, next) {
                after(1000, function () {
                    grabAs("animators-whole-" + at, scene)
                    grabAs("animators-grains-" + at, grains, next)
                })
            }, function () {
                whenEnded(function () {
                    step("animators split", "end")
                    differ("grains", "animators-grains-1", "animators-grains-2")
                    differ("grains", "animators-grains-2", "animators-grains-3")
                    log("animators split ended=" + endedCount)
                    done()
                })
            })
        })
    }

    // an Effect that goes in its own ended, after a natural end, a halt and a split moment: expect a "gone" line for
    // each, and no crash
    function animatorsGoing(done) {
        var cases = [{ "style": "ember", "moment": "close", "ms": 600, "haltAt": 0 },
                     { "style": "ember", "moment": "close", "ms": 2000, "haltAt": 300 },
                     { "style": "dust", "moment": "close", "ms": 600, "haltAt": 0 }]
        each(cases, function (going, next) {
            var effect = ownEffect.createObject(scene, { "style": going.style, "moment": going.moment })
            log("animators going", going.style + "-" + going.moment, "ms=" + going.ms, "halted=" + (going.haltAt > 0),
                "ready=" + effect.ready)
            effect.play(going.ms)
            after(going.haltAt > 0 ? going.haltAt : going.ms + 300, function () {
                if (going.haltAt > 0)
                    effect.halt()
                after(300, next)
            })
        }, done)
    }

    // the covers' own closing, the Effect's way and the shards', over a stand-in that goes after 200 ms as the stock
    // delegate does. Expect differ=true for "start" (100 ms in) and "kept" (400 ms in, after the stand-in went): the
    // copy is made in the first frame and outlives it. Then the same through a block of the GUI thread from 50 to 850
    // ms, across the end of the run: expect differ=false for "blocked", the first frame after the block, where the
    // stand-in whole would be the GUI side's progress, 0, put back into the effect. And a "gone" line for each, and no
    // crash
    function animatorsCoverClosing(done) {
        var over = function (style) {
            var cover = standIn.createObject(scene)
            coverClosing.createObject(scene, { "cover": cover, "style": style, "x": 100, "y": 200,
                                               "width": cover.width, "height": cover.height,
                                               "radius": Theme.paddingMedium, "duration": 600 })
            return cover
        }
        each(["ember", "shatter"], function (style, next) {
            var name = "animators-cover-" + style
            warmUp({ "style": style, "moment": "close" }, true)
            after(300, function () {
                warmUp({ "style": style, "moment": "close" }, false)
                grabAs(name + "-none", scene, function () {
                    step("animators cover closing " + style, "begin")
                    var cover = over(style)
                    after(100, function () {
                        grabAs(name + "-start", scene)
                        after(100, function () {
                            cover.destroy()
                            after(200, function () {
                                grabAs(name + "-kept", scene)
                                after(800, function () {
                                    step("animators cover closing " + style, "end")
                                    step("animators cover closing " + style + " blocked", "begin")
                                    var blocked = over(style)
                                    after(50, function () {
                                        var since = Date.now()
                                        while (Date.now() - since < 800) {}
                                        grabAs(name + "-blocked", scene, function () {
                                            blocked.destroy()
                                            step("animators cover closing " + style + " blocked", "end")
                                            differ("cover start", name + "-none", name + "-start")
                                            differ("cover kept", name + "-none", name + "-kept")
                                            differ("cover blocked", name + "-none", name + "-blocked")
                                            after(500, next)
                                        })
                                    })
                                })
                            })
                        })
                    })
                })
            })
        }, done)
    }

    // the covers' loading at Dust, whose half layer the clock and the fade run through: expect playing=true and
    // differ=true (its clock moves), and no crash when it goes with its clock running, as a cover swiped away
    function animatorsCoverLoading(done) {
        warmUp({ "style": "dust", "moment": "load" }, true)
        after(300, function () {
            warmUp({ "style": "dust", "moment": "load" }, false)
            step("animators cover loading", "begin")
            var holder = coverLoading.createObject(scene)
            var loading = holder.children[0]
            loading.style = "dust"
            after(100, function () {
                grabAs("animators-loading-fade", scene)
                log("animators cover loading playing=" + loading.playing)
                after(1000, function () {
                    grabAs("animators-loading-1", scene, function () {
                        after(1000, function () {
                            grabAs("animators-loading-2", scene, function () {
                                step("animators cover loading", "end")
                                differ("loading", "animators-loading-1", "animators-loading-2")
                                holder.destroy()
                                after(300, done)
                            })
                        })
                    })
                })
            })
        })
    }

    // the mean time to make one, with its shader's text at hand, as a still makes it, and with no shader at all, which
    // is about the objects alone: neither makes the animators, which come with the first play(). Then that first play()
    // on 20 new ones, halted at once, and a second play() on the same, which makes nothing
    function animatorsMade(done) {
        var mean = function (style, moment) {
            var made = []
            var since = Date.now()
            for (var i = 0; i < 20; i++)
                made.push(plainEffect.createObject(scene, { "style": style, "moment": moment }))
            var ms = (Date.now() - since) / made.length
            for (i = 0; i < made.length; i++)
                made[i].destroy()
            return ms
        }
        var bare = mean("", "")
        var real = mean("ember", "close")
        // the split closing, played before, so that its text is at hand: it makes the grains pass, and Frost's the
        // field's Loader too
        var split = mean(option("split", "dust"), "close")
        log("animators made over=20 mean=" + real.toFixed(2) + " ms, without a shader " + bare.toFixed(2)
            + " ms, split " + split.toFixed(2) + " ms (" + option("split", "dust") + " close)")
        var played = []
        for (var i = 0; i < 20; i++)
            played.push(plainEffect.createObject(scene, { "style": "ember", "moment": "close" }))
        var playAll = function () {
            var since = Date.now()
            for (var j = 0; j < played.length; j++)
                played[j].play(600)
            var ms = (Date.now() - since) / played.length
            for (j = 0; j < played.length; j++)
                played[j].halt()
            return ms
        }
        var first = playAll()
        var second = playAll()
        for (i = 0; i < played.length; i++)
            played[i].destroy()
        log("animators first play over=20 mean=" + first.toFixed(2) + " ms, a second play " + second.toFixed(2) + " ms")
        after(300, done)
    }

    // ---- page: the settings' Animations page

    // the page's view: the first flickable in it with any content
    function findFlickable(item) {
        if (!item || !item.children)
            return null
        for (var i = 0; i < item.children.length; i++) {
            var child = item.children[i]
            if (child.contentY !== undefined && child.contentHeight > 0)
                return child
            var found = findFlickable(child)
            if (found)
                return found
        }
        return null
    }

    // the made-up home screen the page's stills are drawn from (PreviewKit.qml), while the page has one
    function findKit(item) {
        if (!item || !item.children)
            return null
        for (var i = 0; i < item.children.length; i++) {
            var child = item.children[i]
            if (child.gaveUpOn !== undefined)
                return child
            var found = findKit(child)
            if (found)
                return found
        }
        return null
    }

    // how a kit came to grab its textures: once its pictures had come, or by its 1.5 s giveUp, and what it waited for
    function kitWait(kit) {
        return kit === null ? "not found" : !kit.ready ? "not grabbed yet"
                : kit.gaveUpOn === "" ? "shot once its pictures came" : "gave up waiting for " + kit.gaveUpOn
    }

    // the frames of a phase, with its longest ones at their ms from its start; done gets their stats
    function phase(name, ms, done) {
        var list = []
        var since = Date.now()
        var marks = []
        step(name, "begin")
        bench.watch = function (interval, now) {
            list.push(interval)
            marks.push([interval, now - since])
            if (now - since >= ms) {
                bench.watch = null
                step(name, "end")
                marks.sort(function (a, b) { return b[0] - a[0] })
                var s = stats(list)
                log("page", name, statsText(s), "longest=" + marks.slice(0, 8).map(function (m) {
                    return m[0] + "@" + m[1]
                }).join(","))
                done(s)
            }
        }
    }

    // the page in a Loader with no page stack, so its status never becomes Active, as the settings scene makes it:
    // it is live from the start, and its sheet is built once the window knows its GL version. What it is told here
    // comes before it starts. One page at a time: a new one replaces the last
    function makePage(kept) {
        pageLoader.active = false
        var since = Date.now()
        pageLoader.active = true
        var page = pageLoader.item
        log("page made in", Date.now() - since, "ms")
        page.visible = true
        page.opacity = 1
        page.ambienceFile = harness.picture
        // saved and cached are about the picture: flatten=0 is for the steps on the frames
        page.flatten = kept || option("flatten", "1") !== "0"
        // only those two keep a file, and in the harness's own folder, whatever the page's copy says: the folder first,
        // so that no page here ever keeps a sheet with the copy's folder
        page.sheetFolder = keptFolder()
        page.keepSheet = kept
        // the making is the push's to measure (the stack scene), not a frame of the build or of the start after it
        lastFrame = Date.now()
        return page
    }

    // where saved and cached keep the sheet: the harness's own folder, which scripts/harness.sh removes on every run
    function keptFolder() {
        return Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, "")
    }

    function keptFile(ambience, extension) {
        return keptFolder() + "/seaglass-animations-" + (ambience ? "tinted" : "natural") + extension
    }

    function readKept(file) {
        var request = new XMLHttpRequest()
        try {
            request.open("GET", "file://" + file, false)
            request.send()
            return request.responseText
        } catch (e) {
            return ""
        }
    }

    // the page's picture of its frames (AnimationSheetPicture.qml), once the page has started
    function findPicture(item) {
        if (!item || !item.children)
            return null
        for (var i = 0; i < item.children.length; i++) {
            var child = item.children[i]
            if (child.holds !== undefined && child.keeps !== undefined)
                return child
            var found = findPicture(child)
            if (found)
                return found
        }
        return null
    }

    // the frames made into one picture, after the build: the frames from the end of the build until it shows
    function flattenPage(page, logged, done) {
        var list = []
        var marks = []
        var since = Date.now()
        if (logged)
            step("flatten", "begin")
        bench.watch = function (interval, now) {
            list.push(interval)
            marks.push([interval, now - since])
            var over = now - since > 10000
            if (!page.pictured && !over)
                return
            bench.watch = null
            if (logged)
                step("flatten", "end")
            marks.sort(function (a, b) { return b[0] - a[0] })
            log("page flatten", over ? "no picture" : "pictured", "ms=" + (now - since), statsText(stats(list)),
                "longest=" + marks.slice(0, 4).map(function (m) { return m[0] + "@" + m[1] }).join(","))
            done()
        }
    }

    // saved: a page that keeps its sheet, with no file to read, makes its frames, grabs them and saves the picture.
    // Expect the grab and the save (grab= and save=, in ms from the last frame made) within 300 ms together, and the
    // key file to hold the key. cached: a second page reads that file; expect wanted=0 (no frame wanted at any time,
    // so no Effect made), fromFile=true, and its first frames after the start (afterStart=) at 33 ms or less
    function keptPage(name, done) {
        if (name === "saved") {
            var forget = function (file) {
                var request = new XMLHttpRequest()
                request.open("PUT", "file://" + file, false)
                try {
                    request.send("")
                } catch (e) {
                    log("page", name, "could not empty", file)
                }
            }
            forget(keptFile(true, ".key"))
            forget(keptFile(false, ".key"))
        }
        var page = makePage(true)
        var list = []
        var marks = []
        var since = Date.now()
        var startedAt = -1
        var builtAt = -1
        var shownAt = -1
        var savedAt = -1
        var wanted = false
        var picture = null
        step(name, "begin")
        bench.watch = function (interval, now) {
            list.push(interval)
            marks.push([interval, now - since])
            if (!page.started)
                return
            if (startedAt < 0)
                startedAt = now - since
            if (picture === null)
                picture = findPicture(page)
            if (shownAt < 0 && !page.framesHeld)
                wanted = true
            if (builtAt < 0 && picture && picture.built)
                builtAt = now - since
            if (shownAt < 0 && page.pictured)
                shownAt = now - since
            if (savedAt < 0 && picture && picture.saved !== "" && picture.saved === picture.key)
                savedAt = now - since
            var over = now - since > 120000
            var failed = picture !== null && picture.failed !== "" && picture.failed === picture.key
            // a save runs once the picture shows, and then nothing is left to save or to read back, whether it
            // worked or not
            var end = failed || (name === "saved" ? shownAt >= 0 && picture !== null && picture.unsaved === ""
                                                    && picture.writing === null
                                                  : shownAt >= 0 && now - since > shownAt + 500)
            if (!end && !over)
                return
            bench.watch = null
            step(name, "end")
            var fromStart = list.slice(marks.filter(function (m) { return m[1] < startedAt }).length)
            marks.sort(function (a, b) { return b[0] - a[0] })
            log("page", name, over ? "did not end" : failed ? "the grab failed" : "ended", "started=" + startedAt,
                "built=" + builtAt, "shown=" + shownAt, "saved=" + savedAt,
                "grab=" + (builtAt >= 0 && shownAt >= 0 ? shownAt - builtAt : -1),
                "save=" + (shownAt >= 0 && savedAt >= 0 ? savedAt - shownAt : -1),
                "wanted=" + (wanted ? 1 : 0), "fromFile=" + (picture ? picture.fromFile : "-"),
                "keeps=" + (picture ? picture.keeps : "-"), "afterStart=" + fromStart.slice(0, 4).join(","),
                statsText(stats(list)),
                "longest=" + marks.slice(0, 6).map(function (m) { return m[0] + "@" + m[1] }).join(","))
            if (picture && !picture.keeps)
                log("page", name, "keeps nothing: Stills.KEY is empty")
            var holds = picture !== null && readKept(picture.path + ".key") === picture.key
            if (picture)
                log("page", name, "key file", picture.path + ".key", "holds the key:", holds, "picture",
                    picture.path + ".jpg")
            pageChecks[name] = { "ended": !over && !failed, "wanted": wanted, "holds": holds,
                                 "grab": builtAt >= 0 && shownAt >= 0 ? shownAt - builtAt : -1,
                                 "save": shownAt >= 0 && savedAt >= 0 ? savedAt - shownAt : -1,
                                 "fromFile": picture !== null && picture.fromFile, "afterStart": fromStart.slice(0, 4) }
            done()
        }
    }

    // until the sheet is built: the frames, the time from the page's start and in all, the longest frames at their ms
    // from the start. With flick=1 the page is flicked meanwhile, which pauses the build
    function buildPage(page, logged, done) {
        var list = []
        var marks = []
        var since = Date.now()
        // tick=0: the tick stopped while the sheet is built, as in the Settings app, where nothing else moves. A poll
        // watches the build instead; it asks for no frame
        var tickless = option("tick", "1") === "0"
        if (tickless) {
            quiet = true
            polling = true
        }
        var startedAt = page.started ? 0 : -1
        var flicked = option("flick", "0") === "1"
        var flickable = null
        if (logged)
            step("build", "begin")
        bench.watch = function (interval, now) {
            list.push(interval)
            marks.push([interval, now - since])
            if (startedAt < 0 && page.started)
                startedAt = now - since
            if (flicked && flickable === null) {
                flickable = findFlickable(page)
                if (flickable) {
                    flickDriver.flickable = flickable
                    flickDriver.start()
                }
            }
            var over = now - since > 120000
            if (!page.built && !over)
                return
            bench.watch = null
            if (tickless) {
                polling = false
                quiet = false
                log("page build with the tick stopped: its intervals are the poll's, its frames the frame log's")
            }
            flickDriver.stop()
            if (flickable)
                flickable.cancelFlick()
            if (logged)
                step("build", "end")
            marks.sort(function (a, b) { return b[0] - a[0] })
            var s = stats(list)
            log("page build", over ? "did not end" : "built", "ms=" + (now - since), "started=" + startedAt,
                "flick=" + (flicked ? 1 : 0), statsText(s), "longest=" + marks.slice(0, 8).map(function (m) {
                    return m[0] + "@" + m[1]
                }).join(","))
            if (logged)
                pageChecks.build = { "ended": !over, "ms": now - since, "longest": s.max, "flicked": flicked }
            done()
        }
    }

    function runPage() {
        moving = false
        var steps = option("steps", "empty,build,rest,flick,spare,saved,cached,viewer").split(",")
        var has = function (name) { return steps.indexOf(name) >= 0 }
        var rest = parseInt(option("rest", "10"), 10) * 1000
        var page = null
        var flickable = null
        // scrolled to a place: pixels from the top, or below 0 the bottom
        var at = function (place) {
            flickable.cancelFlick()
            flickable.contentY = place >= 0 ? place : flickable.contentHeight - flickable.height
        }
        var list = []
        if (has("empty"))
            list.push(function (next) { spare("empty", next) })
        if (has("build") || has("rest") || has("flick") || has("spare")) {
            list.push(function (next) {
                page = makePage(false)
                buildPage(page, has("build"), function () {
                    flickable = findFlickable(page)
                    log("page content height", flickable.contentHeight, "view", flickable.height)
                    log("page kit", kitWait(findKit(page)))
                    if (page.flatten)
                        flattenPage(page, has("build"), next)
                    else
                        next()
                })
            })
        }
        if (has("rest")) {
            list.push(function (next) {
                at(0)
                quietly("rest-top", rest, next)
            })
            list.push(function (next) {
                at(-1)
                quietly("rest-bottom", rest, next)
            })
        }
        if (has("flick")) {
            list.push(function (next) {
                at(0)
                flickDriver.flickable = flickable
                flickDriver.start()
                phase("flick", 14000, function (s) {
                    flickDriver.stop()
                    at(0)
                    pageChecks.flick = s
                    next()
                })
            })
        }
        if (has("spare")) {
            list.push(function (next) {
                at(0)
                spare("page", next)
            })
        }
        if (has("saved"))
            list.push(function (next) { keptPage("saved", next) })
        if (has("cached"))
            list.push(function (next) { keptPage("cached", next) })
        if (has("viewer"))
            list.push(viewerStep)
        each(list, function (step, next) { step(next) }, function () {
            pageTable(has)
            finish()
        })
    }

    // blits over the window until the frames slip: what is left of the budget, in blits. "empty" before any page
    // exists. Something must move for every frame to be drawn: the page at rest draws none
    function spare(where, done) {
        style = "blit"
        fraction = 1
        held = 0.5
        moving = true
        var found = []
        var ks = numbers("ks", "0,16,18,20,22,24,26,28,30,32,40")
        each(ks, function (k, next) {
            copies = k
            after(600, function () {
                phase("spare " + where + " blits=" + k, 6000, function (s) {
                    found.push({ "k": k, "mean": s.mean, "slips": s.over16 > 0.02 * s.frames })
                    next()
                })
            })
        }, function () {
            copies = 0
            style = ""
            moving = false
            pageChecks["spare " + where] = found
            done()
        })
    }

    // ---- the viewer step: each moment on the viewer's stage (AnimationStage.qml), as the viewer plays it

    // the moments in the sheet's order, or those only= names
    function viewerList() {
        var only = option("only", "")
        var list = []
        for (var i = 0; i < Stills.ORDER.length; i++) {
            var moments = ["open", "load", "close"]
            for (var j = 0; j < moments.length; j++) {
                if (only === "" || only.split(",").indexOf(Stills.ORDER[i] + "-" + moments[j]) >= 0)
                    list.push({ "style": Stills.ORDER[i], "moment": moments[j] })
            }
        }
        return list
    }

    // an opening or closing of a style draws at a rung, a fraction of the stage; a loading at full size on its cover,
    // and Stock with plain items
    function hasRung(point) {
        return point.style !== "stock" && point.moment !== "load"
    }

    // The frames of the moments, quiet but for the stage, and per moment the largest rung that passes: under 5 percent
    // of its frames over 16.7 ms and none over 33 ms, over all its rounds. The frames are the stage's own intervals,
    // from its animation's ticks, as its step-down rule reads them, less the first two. The GUI thread advances its
    // animations after the scene graph's sync, so the first is only the wait from play() to the first tick, and the
    // second holds the render of the run's first frame (the scaled layer's new texture, a field's bake, a GPU that
    // was idle). The frame log keeps that frame out of its intervals too: it is in its "first" column
    function viewerStep(done) {
        pageLoader.active = false
        var size = viewerStageSize()
        if (size === null) {
            done()
            return
        }
        viewerLoader.stageWidth = size.width
        viewerLoader.stageHeight = size.height
        quiet = true
        viewerLoader.active = true
        var view = viewerLoader.item
        var results = []
        var waitForKit = function () {
            if (!view.kit.ready) {
                after(100, waitForKit)
                return
            }
            log("viewer stage", view.stage.width + "x" + view.stage.height, "from", size.from,
                "speed=" + view.stage.speed, "es3", view.kit.es3, "rounds=" + option("rounds", "3"))
            log("viewer kit", kitWait(view.kit))
            each(viewerList(), function (point, next) {
                viewerMoment(view, point, function (result) {
                    results.push(result)
                    next()
                })
            }, function () {
                viewerSummary(results)
                viewerLoader.active = false
                quiet = false
                done()
            })
        }
        waitForKit()
    }

    // The stage's size: with stage=WIDTH that width in a phone's shape, as the page shapes it, else the viewer page's
    // own stage in portrait, read from a page made from its file and dropped in the same call; the stage's line says
    // how long the make took, GUI time spent once, before the first run. That page has no window, so it draws and
    // compiles nothing, and it makes nothing: its start comes from a 0 ms Timer, and what the start makes loads
    // asynchronously, after the page has gone. Outside an ApplicationWindow Silica's Page logs ReferenceErrors when
    // it is made, as the sheet's page does in this scene. null, with a line, if the page cannot be made
    function viewerStageSize() {
        var given = parseInt(option("stage", "0"), 10)
        if (given > 0) {
            return { "width": given, "from": "stage=" + given,
                     "height": Math.round(given * viewerLoader.phoneHeight / viewerLoader.phoneWidth) }
        }
        var since = Date.now()
        var component = Qt.createComponent(Qt.resolvedUrl("../qml/settings/AnimationViewerPage.qml"))
        var page = component.status === Component.Ready ? component.createObject(null) : null
        if (page === null) {
            log("viewer page not made:", component.errorString())
            return null
        }
        var size = { "width": page.stageWidth, "height": page.stageHeight,
                     "from": "the viewer page (made in " + (Date.now() - since) + " ms)" }
        page.destroy()
        return size
    }

    // a moment at its rung from stills.js, then up while it passes or down while it fails; or at the rungs given
    function viewerMoment(view, point, done) {
        var ladder = Stills.RUNGS
        var table = hasRung(point) ? Stills.rung(point.style, point.moment) : 1
        var given = option("rungs", "")
        var fixed = !hasRung(point) || given === "table" ? [table]
                    : given !== "" ? given.split(",").map(parseFloat) : null
        var at = 0
        while (at < ladder.length - 1 && ladder[at] > table + 0.001)
            at++
        var tried = []
        var tryRung = function (rung) {
            viewerRounds(view, point, rung, function (passed) {
                tried.push({ "rung": rung, "passed": passed })
                var nextRung = null
                if (fixed) {
                    if (tried.length < fixed.length)
                        nextRung = fixed[tried.length]
                } else {
                    // up from the table's rung while it passes, down while it fails
                    var up = tried[0].passed
                    if (tried.length === 1 || passed === up) {
                        var to = at + (up ? -tried.length : tried.length)
                        if (to >= 0 && to < ladder.length)
                            nextRung = ladder[to]
                    }
                }
                if (nextRung !== null) {
                    tryRung(nextRung)
                    return
                }
                // the largest that passed, and how it did at the table's rung (null: not run there)
                var largest = null
                var atTable = null
                for (var i = 0; i < tried.length; i++) {
                    if (tried[i].passed && (largest === null || tried[i].rung > largest))
                        largest = tried[i].rung
                    if (Math.abs(tried[i].rung - table) < 0.001)
                        atTable = tried[i].passed
                }
                done({ "style": point.style, "moment": point.moment, "rung": hasRung(point), "table": table,
                       "largest": largest, "atTable": atTable, "tried": tried })
            })
        }
        tryRung(fixed ? fixed[0] : table)
    }

    // the rounds of a moment at one rung, and whether they pass together
    function viewerRounds(view, point, rung, done) {
        var rounds = parseInt(option("rounds", "3"), 10)
        var all = []
        var ordinals = []
        for (var r = 1; r <= rounds; r++)
            ordinals.push(r)
        each(ordinals, function (round, next) {
            viewerRun(view, point, rung, round, function (frames) {
                all = all.concat(frames.slice(2))
                next()
            })
        }, function () {
            var s = stats(all)
            var passed = all.length > 0 && s.over16 < 0.05 * all.length && s.over33 === 0
            log("viewer", point.style + "-" + point.moment, hasRung(point) ? "rung=" + rung : "",
                "rounds=" + rounds, "frames=" + s.frames, "over16.7=" + s.over16,
                "(" + (s.frames ? 100 * s.over16 / s.frames : 0).toFixed(1) + "%)", "over33=" + s.over33,
                "longest=" + s.max, passed ? "passes" : "fails")
            done(passed)
        })
    }

    // One run as the viewer plays it: the app grabbed at the run's size and the program drawn once, at rest and only
    // when they are not yet (as the viewer's queue does), then half a second still, then play(). The step covers the
    // moment itself, up to ran(); its end and fade come after it, outside
    function viewerRun(view, point, rung, round, done) {
        var stage = view.stage
        var kit = view.kit
        var name = point.style + "-" + point.moment + (hasRung(point) ? " rung=" + rung : "") + " round=" + round
        stage.halt()
        stage.style = point.style
        stage.moment = point.moment
        stage.rung = rung
        var work = []
        if (hasRung(point)) {
            var mip = kit.es3 && Styles.has(point.style, "blur")
            if (kit.runScale !== rung || kit.runMip !== mip) {
                work.push(function () {
                    kit.runScale = rung
                    kit.runMip = mip
                    return "app"
                })
            }
        }
        if (point.style !== "stock") {
            var own = hasRung(point) && Styles.has(point.style, "shards") ? "shards"
                      : { "style": point.style, "moment": point.moment }
            var ownName = typeof own === "string" ? own : point.style + "-" + point.moment
            if (!view.warmed[ownName]) {
                work.push(function () {
                    view.warmed[ownName] = true
                    return own
                })
            }
        }
        each(work, function (make, next) {
            atWarmed = next
            stage.warmer.program = make()
            stage.warmer.develop()
        }, function () {
            atWarmed = null
            after(500, function () {
                var frames = []
                var ran = false
                atRan = function (ranStyle, ranMoment, list) {
                    atRan = null
                    ran = true
                    frames = list
                    step("viewer " + name, "end")
                }
                atRunEnded = function (whole) {
                    atRan = null
                    atRunEnded = null
                    later.stop()
                    bench.then = null
                    if (!ran)
                        step("viewer " + name, "end")
                    var s = stats(frames.slice(2))
                    var late = frames.filter(function (ms) { return ms > 20 }).length
                    log("viewer", name, "length=" + stage.length, whole ? "" : "halted",
                        "first=" + (frames[0] || 0) + "," + (frames[1] || 0),
                        "frames=" + s.frames, "over16.7=" + s.over16, "over33=" + s.over33, "longest=" + s.max,
                        "mean=" + s.mean.toFixed(1), "stepdown=" + (hasRung(point) && late > 0.1 * frames.length),
                        "all=" + frames.join(","))
                    done(frames)
                }
                step("viewer " + name, "begin")
                stage.play()
                // a run that never ends: a render thread that draws nothing ends no fade
                after(stage.length * (stage.slow ? 4 : 1) + 5000, function () {
                    log("viewer", name, "did not end")
                    stage.halt()
                })
            })
        })
    }

    // per moment the largest rung that passes, and the table stills.js would need for it
    function viewerSummary(results) {
        var stage = {}
        var failing = []
        for (var i = 0; i < results.length; i++) {
            var result = results[i]
            var name = result.style + "-" + result.moment
            log("viewer moment", name, result.rung ? "table=" + result.table : "",
                "largest=" + (result.largest === null ? "none" : result.largest),
                "tried=" + result.tried.map(function (t) { return t.rung + ":" + (t.passed ? "passes" : "fails") })
                                       .join(","))
            if (result.largest === null)
                failing.push(name)
            else if (result.rung && Math.abs(result.largest - 0.62) > 0.001) {
                stage[result.style] = stage[result.style] || {}
                stage[result.style][result.moment] = result.largest
            }
        }
        log("viewer STAGE", JSON.stringify(stage), failing.length ? "none passes: " + failing.join(",") : "")
        pageChecks.viewer = results
    }

    // What each step saw against its limit, one line a check, from the bench's own intervals. Frames rendered at rest,
    // the GUI thread's animations and the over-16.7 counts that decide are in the frame log (scripts/bench-frames.py)
    function pageTable(has) {
        var checks = pageChecks
        var line = function (what, saw, limit, verdict) {
            log("check", what + ":", saw, "| limit:", limit, "|", verdict)
        }
        var verdict = function (passed) {
            return passed ? "passes" : "fails"
        }
        log("checks", option("flatten", "1") === "0" ? "on the frames" : "on the picture")
        if (has("rest"))
            line("rest", "frames rendered at the top and at the bottom: in the frame log", "2 in 10 s, each", "-")
        if (checks.flick) {
            var flick = checks.flick
            line("flick", flick.over16 + " of " + flick.frames + " over 16.7 ms ("
                 + (100 * flick.over16 / Math.max(1, flick.frames)).toFixed(1) + "%), longest " + flick.max,
                 "2%, and the GUI's animations 0.3 ms a frame (frame log)",
                 verdict(flick.over16 <= 0.02 * flick.frames))
        }
        var empty = checks["spare empty"]
        var page = checks["spare page"]
        if (empty && page) {
            var at40 = function (list) {
                for (var i = 0; i < list.length; i++) {
                    if (list[i].k === 40)
                        return list[i].mean
                }
                return -1
            }
            var slip = function (list) {
                for (var i = 0; i < list.length; i++) {
                    if (list[i].slips)
                        return list[i].k
                }
                return -1
            }
            var difference = at40(page) >= 0 && at40(empty) >= 0 ? at40(page) - at40(empty) : null
            var slips = [slip(page), slip(empty)]
            // a page that never slips holds; one that does, against an empty window that never did, cannot be told
            var slipHolds = slips[0] < 0 ? true : slips[1] < 0 ? null : slips[0] >= slips[1] - 2
            line("spare", "40 blits " + (difference === null ? "not run" : (difference >= 0 ? "+" : "")
                                         + difference.toFixed(1) + " ms over the empty window") + ", first slip at "
                 + (slips[0] < 0 ? "none" : slips[0]) + " blits, empty " + (slips[1] < 0 ? "none" : slips[1]),
                 "1 ms; a first slip at most 2 blits below the empty window's",
                 difference !== null && difference > 1 || slipHolds === false ? verdict(false)
                 : difference === null || slipHolds === null ? "-" : verdict(true))
        }
        if (checks.build) {
            var build = checks.build
            var cold = option("salt", "0") === "1"
            // with tick=0 the longest is the poll's, not a frame: only the time can fail here
            var tickless = option("tick", "1") === "0"
            var slow = !build.ended || !cold && build.ms > 3500
            line("build", (build.ended ? "" : "did not end, ") + build.ms + " ms, longest "
                 + (tickless ? "frame in the frame log, the tick stopped" : build.longest)
                 + (cold ? ", cold" : "") + (build.flicked ? ", flicked" : ""),
                 cold ? "longest 120 ms" : "3500 ms, longest 30 ms",
                 build.flicked ? "-" : tickless ? (slow ? verdict(false) : "-")
                                     : verdict(build.ended && (cold ? build.longest <= 120
                                                                    : build.ms <= 3500 && build.longest <= 30)))
        }
        if (checks.saved) {
            var saved = checks.saved
            line("saved", "grab " + saved.grab + " ms, save " + saved.save + " ms, key file " + saved.holds,
                 "300 ms together", verdict(saved.ended && saved.grab >= 0 && saved.save >= 0 && saved.holds
                                            && saved.grab + saved.save <= 300))
        }
        if (checks.cached) {
            var cached = checks.cached
            var first = cached.afterStart.length ? cached.afterStart[0] : -1
            line("cached", "from the file " + cached.fromFile + ", a frame wanted " + cached.wanted
                 + ", frames after the start " + cached.afterStart.join(","),
                 "no frame made, the first frame after the start 33 ms or less",
                 verdict(cached.ended && cached.fromFile && !cached.wanted && first >= 0 && first <= 33))
        }
        if (checks.viewer) {
            var failed = []
            var notRun = []
            var lower = []
            var higher = []
            for (var i = 0; i < checks.viewer.length; i++) {
                var result = checks.viewer[i]
                var name = result.style + "-" + result.moment
                if (result.atTable === false)
                    failed.push(name)
                if (result.atTable === null)
                    notRun.push(name)
                if (!result.rung)
                    continue
                if (result.largest !== null && result.largest > result.table + 0.001)
                    higher.push(name + " " + result.largest)
                if (result.largest === null || result.largest < result.table - 0.001)
                    lower.push(name + " " + (result.largest === null ? "none passes" : result.largest))
            }
            line("viewer", checks.viewer.length + " moments, " + failed.length + " fail at their rung"
                 + (failed.length ? " (" + failed.join(",") + ")" : "")
                 + (notRun.length ? ", " + notRun.length + " not run at it" : ""),
                 "under 5% over 16.7 ms and none over 33 ms", notRun.length ? "-" : verdict(failed.length === 0))
            if (option("rungs", "") === "")
                line("viewer rungs", "a larger one passes: " + (higher.join(",") || "none") + "; a smaller one needed: "
                     + (lower.join(",") || "none"), "the rung in stills.js is the largest that passes",
                     verdict(higher.length === 0 && lower.length === 0))
        }
    }

    NumberAnimation on tick {
        running: !scene.quiet
        from: 0
        to: 1
        duration: 1000
        loops: Animation.Infinite
    }

    // stands in for the tick where a step must not ask for frames (tick=0): a Timer keeps a clock of its own while no
    // animation runs
    Timer {
        interval: 10
        repeat: true
        running: scene.polling
        onTriggered: scene.frame(true)
    }

    Timer {
        id: later

        onTriggered: {
            var then = scene.bench.then
            scene.bench.then = null
            if (then)
                then()
        }
    }

    // play with driver=gui: progress and time from the GUI thread
    NumberAnimation {
        id: run

        target: scene
        property: "played"
        from: 0
        to: 1
    }

    Timer {
        id: flickDriver

        property var flickable
        property int sign: 1

        interval: 1500
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            flickable.flick(0, -sign * 4000 * Theme.pixelRatio)
            sign = -sign
        }
    }

    // a window-sized picture that changes every frame, for the capture
    Item {
        id: captured

        width: scene.width
        height: scene.height
        visible: scene.kind === "capture"

        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            source: scene.harness ? "file://" + scene.harness.picture : ""
        }

        Rectangle {
            x: scene.flip ? 0 : 1
            width: 1
            height: 1
        }
    }

    // the wallpaper
    Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: scene.harness ? "file://" + scene.harness.picture : ""
    }

    // moves a little when moving: a frame that draws next to nothing
    Rectangle {
        x: scene.moved > 0 ? 2 : 0
        width: 2
        height: 2
        color: "black"
    }

    NotesPreview {
        id: app

        width: scene.width
        height: scene.height
        picture: scene.harness ? scene.harness.picture : ""
    }

    ShaderEffectSource {
        id: appTexture

        width: scene.drawWidth
        height: scene.drawHeight
        visible: false
        hideSource: true
        textureSize: Qt.size(scene.drawWidth, scene.drawHeight)
        mipmap: warm.es3 && scene.kind === "effect" && Styles.has(scene.style, "blur")
        sourceItem: app
    }

    NoiseTile {
        id: noise
    }

    Image {
        id: icon

        width: 256
        height: 256
        visible: false
        sourceSize: Qt.size(256, 256)
        source: "image://theme/icon-launcher-notes"
    }

    Loader {
        id: pageLoader

        anchors.fill: parent
        active: false
        source: Qt.resolvedUrl("../qml/settings/AnimationsPage.qml")
    }

    // the viewer's stage and its kit, at the size viewerStageSize() gives, set before the Loader is made active
    Loader {
        id: viewerLoader

        readonly property real phoneWidth: Math.min(Screen.width, Screen.height)
        readonly property real phoneHeight: Math.max(Screen.width, Screen.height)
        property int stageWidth: 1
        property int stageHeight: 1

        x: Math.round((scene.width - stageWidth) / 2)
        y: Math.max(0, Math.round((scene.height - stageHeight) / 2))
        width: stageWidth
        height: stageHeight
        active: false
        sourceComponent: Component {
            Item {
                readonly property Item kit: viewerKit
                readonly property Item stage: viewerStage
                // the programs drawn once, by name: they stay compiled
                property var warmed: ({})

                PreviewKit {
                    id: viewerKit

                    side: viewerLoader.stageWidth
                    picture: scene.harness ? scene.harness.picture : ""
                    tint: Qt.vector3d(Theme.highlightColor.r, Theme.highlightColor.g, Theme.highlightColor.b)
                    useTint: 1
                }

                AnimationStage {
                    id: viewerStage

                    width: viewerLoader.stageWidth
                    height: viewerLoader.stageHeight
                    kit: viewerKit
                    speed: parseInt(scene.option("speed", "2"), 10)
                }
            }
        }
    }

    Connections {
        target: viewerLoader.item ? viewerLoader.item.stage : null
        onRan: {
            if (scene.atRan)
                scene.atRan(ranStyle, ranMoment, frames)
        }
        onEnded: {
            if (scene.atRunEnded)
                scene.atRunEnded(whole)
        }
    }

    Connections {
        target: viewerLoader.item ? viewerLoader.item.stage.warmer : null
        onDone: {
            var then = scene.atWarmed
            scene.atWarmed = null
            if (then)
                then()
        }
    }

    Repeater {
        id: effectCopies

        model: scene.kind === "effect" ? scene.copies : 0

        Effect {
            width: scene.drawWidth
            height: scene.drawHeight
            visible: ready && scene.shown
            style: scene.style
            moment: scene.moment
            source: scene.moment === "load" ? icon : appTexture
            noiseTex: noise
            progress: scene.progressNow
            time: scene.timeNow
            // the opening comes from an icon of the app grid, a closing lets go at the upper third, a loading is on a
            // cover
            origin: scene.moment === "close" ? Qt.point(0.5, 0.3) : Qt.point(0.375, 0.34)
            originRect: scene.moment === "close" ? Qt.rect(0, 0, 1, 1)
                                                 : Qt.rect(0.375 - scene.iconSide / scene.width / 2,
                                                           0.34 - scene.iconSide / scene.height / 2,
                                                           scene.iconSide / scene.width, scene.iconSide / scene.height)
            radiusPx: scene.moment === "close" ? 0 : Theme.paddingMedium
            tint: Qt.vector3d(Theme.highlightColor.r, Theme.highlightColor.g, Theme.highlightColor.b)
            useTint: 1
            layer.enabled: scene.layered ? true : half
            layer.textureSize: scene.layered ? Qt.size(width, height)
                                             : Qt.size(Math.ceil(width / 2), Math.ceil(height / 2))
        }
    }

    Repeater {
        id: shardsCopies

        model: scene.kind === "shards" ? scene.copies : 0

        Shards {
            width: scene.drawWidth
            height: scene.drawHeight
            visible: ready && scene.shown
            // the home screen's break at full size, a cover's and the page's when smaller
            rays: scene.fraction < 1 ? 9 : 11
            rings: scene.fraction < 1 ? [0.08, 0.2, 0.38, 0.6, 1.0] : [0.05, 0.12, 0.22, 0.35, 0.52, 0.75, 1.05, 1.5]
            source: appTexture
            assemble: scene.moment === "open"
            impact: scene.moment === "close" ? Qt.point(0.5, 0.3) : Qt.point(0.375, 0.34)
            progress: scene.progressNow
            tint: Qt.vector3d(Theme.highlightColor.r, Theme.highlightColor.g, Theme.highlightColor.b)
            useTint: 1
            onReadyChanged: {
                if (ready)
                    build()
            }

            // as the home screen, which lays them out when the moment starts
            Connections {
                target: scene
                onShownChanged: {
                    if (scene.shown && ready)
                        build()
                }
            }
        }
    }

    Repeater {
        model: scene.kind === "blit" ? scene.copies : 0

        ShaderEffect {
            property variant source: appTexture

            width: scene.drawWidth
            height: scene.drawHeight
            blending: true
        }
    }

    Repeater {
        model: scene.kind === "capture" ? scene.copies : 0

        ShaderEffect {
            property variant source: copyOf

            x: -2
            y: -2
            width: 1
            height: 1

            ShaderEffectSource {
                id: copyOf

                width: scene.drawWidth
                height: scene.drawHeight
                visible: false
                mipmap: scene.style === "capture-mip"
                textureSize: Qt.size(scene.drawWidth, scene.drawHeight)
                sourceItem: captured
            }
        }
    }

    // a shader's first draw, as the home screen's warm-up does it: one pixel, nearly clear, off the screen. (size=100:
    // over the whole screen.) It also gives the GL version
    Effect {
        id: warm

        readonly property real size: scene.mode === "compile" ? parseFloat(scene.option("size", "0")) / 100 : 0

        x: size > 0 ? 0 : -2
        y: size > 0 ? 0 : -2
        width: size > 0 ? scene.width * size : 1
        height: size > 0 ? scene.height * size : 1
        opacity: 0.02
        visible: style !== "" && ready
        source: noise
        noiseTex: noise
        progress: 0.5
    }

    // what the animators mode plays: nothing binds its progress or time
    Effect {
        id: animated

        width: scene.width
        height: scene.height
        visible: running && ready
        source: appTexture
        noiseTex: noise
        origin: Qt.point(0.5, 0.3)
        originRect: Qt.rect(0, 0, 1, 1)
        tint: Qt.vector3d(Theme.highlightColor.r, Theme.highlightColor.g, Theme.highlightColor.b)
        useTint: 1
        onEnded: {
            scene.endedCount++
            var then = scene.atEnded
            scene.atEnded = null
            if (then)
                then()
        }
    }

    // the window's way back to whole, as AnimationController.qml plays it with a closing
    ParallelAnimation {
        id: comeBack

        UniformAnimator {
            target: animated
            uniform: "clipTop"
            from: animated.clipTop
            to: 0
            duration: 180
            easing.type: Easing.OutCubic
        }
        UniformAnimator {
            target: animated.grains
            uniform: "clipTop"
            from: animated.clipTop
            to: 0
            duration: 180
            easing.type: Easing.OutCubic
        }
        OpacityAnimator {
            target: animated
            from: animated.opacity
            to: 1
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    Component {
        id: ownEffect

        Effect {
            width: scene.width
            height: scene.height
            visible: running && ready
            source: appTexture
            noiseTex: noise
            origin: Qt.point(0.5, 0.3)
            originRect: Qt.rect(0, 0, 1, 1)
            onEnded: destroy()
            Component.onDestruction: scene.log("animators gone", style + "-" + moment)
        }
    }

    Component {
        id: plainEffect

        Effect {
            visible: false
            source: noise
            noiseTex: noise
        }
    }

    // a cover for the covers' closing, which only its frozen copy draws
    Component {
        id: standIn

        Rectangle {
            width: Theme.coverSizeLarge.width
            height: Theme.coverSizeLarge.height
            visible: false
            color: "#304050"
        }
    }

    Component {
        id: coverClosing

        CoverClosing {
            Component.onDestruction: scene.log("animators gone cover closing", style)
        }
    }

    // what the hook's Loader gives a cover's loading
    Component {
        id: coverLoading

        Item {
            readonly property var launcherItem: ({ "iconId": "icon-launcher-notes" })
            readonly property real radius: Theme.paddingMedium

            x: 100
            y: 200
            width: Theme.coverSizeLarge.width
            height: Theme.coverSizeLarge.height

            CoverLoading {
                Component.onDestruction: scene.log("animators gone cover loading", style)
            }
        }
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
        source: noise
        progress: 0.5
        onReadyChanged: {
            if (ready)
                build()
        }
    }
}
