// Settings: one effect at a time, large, from the Animations page's sheet (AnimationsPage.qml): a style's opening,
// loading or closing on the made-up home screen with the ambience's picture. It plays once when the page opens, and
// again on a tap. A swipe sideways goes to the next or previous style, up or down back to the sheet; the tabs show
// another moment, and the strip under the stage holds the moment's stills from its start to its end, to drag through.
// Looking changes no setting: only the Use buttons write, and Speed, which can only be judged while watching.
//
// As on the sheet, nothing is made before the page is on top and the window knows its OpenGL version (started). Every
// still is made at rest, one at a time (FreezeQueue.qml), and only for what is on screen: the style shown and what its
// run needs first, its neighbours and the strip once a run has ended by itself. So a shader compiles only at rest, in
// a still, and a run draws programs that a still has drawn already. The live scene is AnimationStage.qml, the strip
// AnimationStrip.qml.
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../animations/styles.js" as Styles
import "stills.js" as Stills

FullscreenContentPage {
    id: page

    // what it shows first: "stock" or a style, and "open", "load" or "close"; and how it plays: "one" once, "round"
    // the style's loading, opening and closing, "tour" the moment in every style in turn
    property string style: "ember"
    property string moment: "open"
    property string mode: "one"
    // the ambience's picture, from the sheet (the harness gives a stock one); "" draws a neutral gradient
    property string ambienceFile

    // whether stills are made and runs play: only on top, with the Settings app in front (always in the harness's
    // settings scene, which has no page stack). A page in a stack has its pageContainer
    readonly property bool live: !page.pageContainer || (status === PageStatus.Active && Qt.application.active)
    // first true once the page is live and the window knows its GL version; the 0 ms wait lets a harness scene set
    // ambienceFile first
    property bool started
    // the window's GL version, read on an Item: read in a Timer, OpenGLInfo crashes Qt 5.6
    readonly property int glMajor: OpenGLInfo.majorVersion

    property bool round: mode === "round"
    // the tour goes on until a touch
    property bool touring: mode === "tour"
    property bool slow
    // the point of the moment the current still shows after a lift on the strip, 0 to 1 (-1: the sheet's)
    property real scrubAt: -1
    // rungs lowered by the step-down rule, by "STYLE MOMENT", for the life of the page
    property var lowered: ({})
    // changes when every still is to be made again: the kit was grabbed again, as after a turn
    property int generation
    // the delegates' stills by style, while they exist
    property var shotsBy: ({})
    // what the app at the run's size was last grabbed for, and the programs drawn a pixel large: they stay compiled
    property string appMadeFor
    property var warmed: ({})
    // whether the queue drew anything for the run it prepares, and a run waiting for its turn
    property bool drew
    property bool wantsPlay
    // a move of the stills since the last landing, and one made by the page (not by a finger)
    property bool moved
    property bool sliding
    // the strip's stills are made after the neighbours', once a run has ended by itself
    property bool stripWanted
    property bool stripDue
    property bool kitSeen
    // runs that ended by themselves, for the harness
    property int played

    readonly property Item kit: kitLoader.item
    readonly property Item stage: stageLoader.item
    readonly property Item strip: controls.item ? controls.item.strip : null
    readonly property Item stripKit: stripKitLoader.item
    // the ABOUT line, for the harness: the lines it took, and whether Qt cut it
    readonly property Item aboutLine: aboutLabel
    readonly property bool canPrepare: started && stage !== null && kit !== null && kit.ready
    // nothing developed or played meanwhile: a finger on the stills, the strip or the page, or the stage moving
    readonly property bool still: live && !shots.dragging && !shots.flicking && !shots.moving && !sliding && !navigating
                                  && !(strip !== null && strip.held) && !(stage !== null && stage.moving)
    // the page swiped up or down, back to the sheet
    readonly property bool navigating: page.pageContainer !== null && page.pageContainer.dragInProgress === true
    // at rest with nothing to make: for the harness. The strip's kit is still being made, and its stills not yet
    // queued, until it is ready
    readonly property bool settled: canPrepare && stage.phase === "rest" && !queue.busy && !wantsPlay
                                    && !landing.running && !tourGap.running && !turned.running && !stripDue
                                    && (!stripWanted || stripKit !== null && stripKit.ready)

    readonly property real phoneWidth: Math.min(Screen.width, Screen.height)
    readonly property real phoneHeight: Math.max(Screen.width, Screen.height)
    // clear of the cutout: at the top in portrait, at a side in landscape
    readonly property real inset: Math.max(Screen.topCutout.height, Theme.paddingLarge)
    readonly property int gap: Math.max(2, Math.floor(3 * Theme.pixelRatio))
    // the strip: seven stills across the phone's width, the same size in landscape
    readonly property int stripWidth: Math.floor((phoneWidth - 2 * Theme.horizontalPageMargin - 6 * gap) / 7)
    readonly property int stripHeight: Math.round(stripWidth * phoneHeight / phoneWidth)
    // under the stage: the strip, Slow and Speed, the tabs and the Use buttons
    readonly property real textRowHeight: Theme.fontSizeSmall + 2 * Theme.paddingSmall
    readonly property real controlsHeight: stripHeight + Theme.paddingSmall + textRowHeight + Theme.itemSizeExtraSmall
                                           + Theme.itemSizeExtraSmall + Theme.paddingLarge
    // the stage: a phone's shape, as tall as the rest leaves, at most 68 percent of the page's width. In landscape it
    // stands at the left, and the caption and the controls at the right
    readonly property real room: isPortrait
                                 ? height - caption.y - caption.height - controlsHeight - 2 * Theme.paddingMedium
                                 : height - 2 * Theme.paddingLarge
    readonly property int stageWidth: Math.max(1, Math.min(Math.floor(room * phoneWidth / phoneHeight),
                                                           Math.round(width * 0.68)))
    readonly property int stageHeight: Math.round(stageWidth * phoneHeight / phoneWidth)
    readonly property real shotsWidth: isPortrait ? width : stageWidth + 2 * Theme.itemSizeMedium
    readonly property real sideX: isPortrait ? 0 : inset + shotsWidth + Theme.paddingLarge
    readonly property real sideWidth: isPortrait ? width : width - sideX - inset

    // the moments: a tab, its key in the settings, and its Use button
    readonly property var moments: [{ "moment": "open", "key": "open", "text": qsTr("Opening"),
                                      "use": qsTr("Use for opening") },
                                    { "moment": "load", "key": "loading", "text": qsTr("Loading"),
                                      "use": qsTr("Use for loading") },
                                    { "moment": "close", "key": "close", "text": qsTr("Closing"),
                                      "use": qsTr("Use for closing") }]
    readonly property var shownMoment: moments[moment === "load" ? 1 : moment === "close" ? 2 : 0]
    readonly property string momentKey: shownMoment.key
    // the moment a round plays now, for the tabs
    readonly property string playingMoment: stage !== null && stage.round && stage.phase === "running"
                                            ? stage.playingMoment : moment
    // what the moment plays now: "surprise", "stock" or a style, as the sheet's heads say
    readonly property string inUse: Stills.inUse(settings, momentKey)
    // what a tap on Use would leave as it is: the moment, or all three, already playing this style
    readonly property bool usedForMoment: Styles.setting(settings, momentKey) === style
                                          && (style === "stock" ? !settings.surprise || settings[momentKey] === "stock"
                                                                : settings.enabled && !settings.surprise)
    readonly property bool usedForAll: Styles.setting(settings, "open") === style
                                       && Styles.setting(settings, "loading") === style
                                       && Styles.setting(settings, "close") === style
                                       && !settings.surprise && (style === "stock" || settings.enabled)
    // the size an opening or closing draws at; a round's opening and closing draw at the same one
    readonly property real runRung: round ? Math.min(rungFor(style, "open"), rungFor(style, "close"))
                                          : rungFor(style, moment)
    // what the effects take of the ambience, as the home screen gives it to them
    readonly property vector3d tint: Qt.vector3d(Theme.highlightColor.r, Theme.highlightColor.g,
                                                 Theme.highlightColor.b)
    readonly property real useTint: settings.ambience ? 1 : 0
    // where the playhead stands: the stage's point while it shows this moment, else the still's
    readonly property real head: stage !== null && stage.shown && stage.playingStyle === style
                                 && stage.playingMoment === moment ? stage.p : stillPoint
    readonly property real stillPoint: scrubAt >= 0 ? scrubAt
                                       : moment === "load" ? Stills.at(style, "load") / clipOf(style)
                                       : Stills.at(style, moment)

    function styleName(id) {
        var found = Styles.find(id)
        return found ? found.name : qsTr("Stock")
    }

    function clipOf(id) {
        return Stills.STILLS[id].clip
    }

    function rungFor(id, moment) {
        var lower = lowered[id + " " + moment]
        return lower !== undefined ? lower : Stills.rung(id, moment)
    }

    // the point a still of a style shows: the strip's last lift for the one shown, else the sheet's
    function stillAt(id, isCurrent) {
        if (isCurrent && scrubAt >= 0)
            return moment === "load" ? scrubAt * clipOf(id) : scrubAt
        return Stills.at(id, moment)
    }

    // what a still is made for: a change makes it again
    function stillKey(id, moment, at, kit) {
        return kit === null ? "-" : [id, moment, at, kit.side, kit.tint, kit.useTint, generation].join(" ")
    }

    // A style plays for every moment through "" (same as style). Stock is written to each moment as well: Surprise me
    // leaves a moment alone only when the moment itself is set to Stock
    function useAll(id) {
        var each = id === "stock" ? "stock" : ""
        settings.style = id; settings.open = each; settings.loading = each; settings.close = each
        settings.surprise = false
        if (id !== "stock")
            settings.enabled = true
    }

    function useFor(key, id) {
        settings[key] = id
        if (id !== "stock") {
            settings.enabled = true
            settings.surprise = false
        }
    }

    // A still's turn in the queue: its FrozenFrame, if it is not made for what it shows now. frameOf finds it then: a
    // delegate may have gone since
    function stillTurn(frameOf) {
        return function () {
            var frame = frameOf()
            if (!frame || frame.kit === null || !frame.kit.ready || frame.madeFor === frame.wanted)
                return null
            frame.making = frame.wanted
            page.drew = true
            return frame
        }
    }

    function shotOf(id) {
        return function () {
            return page.shotsBy[id] || null
        }
    }

    function stripStill(index) {
        return function () {
            return page.strip ? page.strip.still(index) : null
        }
    }

    // the app at the size the run draws, grabbed now; mipmaps only for a style that blurs
    function appTurn() {
        return function () {
            if (!page.kit || !page.stage || page.style === "stock" || page.moment === "load" && !page.round)
                return null
            var mip = page.kit.es3 && Styles.has(page.style, "blur")
            var made = [page.runRung, mip, page.kit.side, page.generation].join(" ")
            if (page.appMadeFor === made)
                return null
            page.kit.runScale = page.runRung
            page.kit.runMip = mip
            page.appMadeFor = made
            page.stage.warmer.program = "app"
            page.drew = true
            return page.stage.warmer
        }
    }

    function warmTurn(program) {
        return function () {
            var name = typeof program === "string" ? program : program.style + "-" + program.moment
            if (!page.stage || page.warmed[name])
                return null
            page.warmed[name] = true
            page.stage.warmer.program = program
            page.drew = true
            return page.stage.warmer
        }
    }

    // the programs a round switches to that the still shown has not drawn: the other moments' shaders, Shatter's
    // shards and Frost's field
    function roundPrograms(id, shown) {
        var list = []
        if (id === "stock")
            return list
        var seen = {}
        var own = function (moment) {
            return moment !== "load" && Styles.has(id, "shards") ? "shards" : id + "-" + moment
        }
        var add = function (name, program) {
            if (!seen[name]) {
                seen[name] = true
                list.push(program)
            }
        }
        seen[own(shown)] = true
        if (Styles.listed(id, "field", shown))
            seen[id + "-field"] = true
        var all = ["load", "open", "close"]
        for (var i = 0; i < all.length; i++) {
            if (Styles.listed(id, "field", all[i]))
                add(id + "-field", { "style": id, "moment": "field" })
            add(own(all[i]), own(all[i]) === "shards" ? "shards" : { "style": id, "moment": all[i] })
        }
        return list
    }

    // Makes what a run of the style shown needs, at rest and one at a time: its still, the app at the run's size, and
    // for a round the programs it switches to. Then it plays, 150 ms after anything was drawn, at once if nothing was
    function prepare(thenPlay) {
        queue.clear()
        wantsPlay = false
        stripDue = false
        drew = false
        queue.add(stillTurn(shotOf(style)))
        queue.add(appTurn())
        if (round) {
            var programs = roundPrograms(style, moment)
            for (var i = 0; i < programs.length; i++)
                queue.add(warmTurn(programs[i]))
        }
        if (thenPlay) {
            queue.add(function () {
                playSoon.interval = page.drew ? 150 : 0
                page.wantsPlay = true
                return null
            })
        }
    }

    // a run ended by itself: what comes after it; in a tour, the next style after 0.4 s
    function afterRun() {
        played++
        var at = Stills.ORDER.indexOf(style)
        if (touring) {
            if (at + 1 < Stills.ORDER.length) {
                queue.add(stillTurn(shotOf(Stills.ORDER[at + 1])))
                tourGap.restart()
                return
            }
            touring = false
        }
        queueRest()
    }

    // after a whole run, or a tour stopped between two: the app at the run's size again if the run stepped down, the
    // neighbours' stills, then the strip's
    function queueRest() {
        var count = Stills.ORDER.length
        var at = Stills.ORDER.indexOf(style)
        queue.add(appTurn())
        queue.add(stillTurn(shotOf(Stills.ORDER[(at + count - 1) % count])))
        queue.add(stillTurn(shotOf(Stills.ORDER[(at + 1) % count])))
        queue.add(function () {
            page.stripWanted = true
            page.stripDue = true
            page.queueStrip()
            return null
        })
    }

    function queueStrip() {
        if (!stripDue || !strip || !stripKit || !stripKit.ready)
            return
        stripDue = false
        for (var i = 0; i < strip.points.length; i++)
            queue.add(stillTurn(stripStill(i)))
    }

    // Stop rules: a run stops at once and the still shows; nothing resumes by itself
    function halt() {
        if (stage)
            stage.halt()
        wantsPlay = false
        touring = false
        tourGap.stop()
    }

    // a finger moved the stills: nothing made for the last style is wanted any more
    function interrupt() {
        halt()
        queue.clear()
        stripDue = false
        moved = true
        sliding = false
        landing.interval = 300
    }

    // the stills to another style, by the page: a tour's next, or what "In use" names
    function goTo(id) {
        var index = Stills.ORDER.indexOf(id)
        if (index < 0 || index === shots.currentIndex)
            return
        var tour = touring
        halt()
        touring = tour
        queue.clear()
        stripDue = false
        moved = true
        sliding = true
        landing.interval = 50
        shots.currentIndex = index
    }

    // the stills came to rest on a style: no new drag for 300 ms (a move by the page: 50 ms), then it plays
    function landed() {
        if (shots.dragging || shots.flicking)
            return
        sliding = false
        landing.interval = 300
        if (!moved)
            return
        moved = false
        if (canPrepare)
            prepare(true)
    }

    // plays the style and moment shown again, from the start
    function replay() {
        halt()
        if (canPrepare)
            prepare(true)
    }

    function showMoment(id) {
        if (id === moment && !round)
            return
        halt()
        round = false
        scrubAt = -1
        moment = id
        if (canPrepare)
            prepare(true)
    }

    function toggleSlow() {
        slow = !slow
        replay()
    }

    function cycleSpeed() {
        settings.speed = (settings.speed + 1) % 3
        replay()
    }

    // the strip pressed or dragged, and lifted: the still is made again at that point before the stage goes
    function scrub(at) {
        if (!stage)
            return
        touring = false
        wantsPlay = false
        tourGap.stop()
        stage.scrub(at)
    }

    function lift(at) {
        if (!stage)
            return
        stage.lift()
        scrubAt = Math.max(0, Math.min(1, at))
        queue.clear()
        queue.add(stillTurn(shotOf(style)))
        queue.add(function () {
            if (page.stage)
                page.stage.settle()
            return null
        })
    }

    // Step-down rule: more than 10 percent of a run's frames over 20 ms, and the next run of that style and moment
    // draws at the next lower rung, for as long as the page is open. 20 ms is past a 60 Hz frame and its jitter, and
    // past a slipped 90 Hz frame; 25 ms and 20 percent let no run step down at 90 Hz, however it stuttered. A loading
    // draws at full size on its cover, and Stock is plain items: neither has a rung
    function judge(id, moment, frames) {
        if (id === "stock" || moment === "load" || frames.length === 0)
            return
        var late = 0
        for (var i = 0; i < frames.length; i++) {
            if (frames[i] > 20)
                late++
        }
        if (late <= 0.1 * frames.length)
            return
        var now = rungFor(id, moment)
        for (i = 0; i < Stills.RUNGS.length; i++) {
            if (Stills.RUNGS[i] < now - 0.001) {
                var next = {}
                for (var name in lowered)
                    next[name] = lowered[name]
                next[id + " " + moment] = Stills.RUNGS[i]
                lowered = next
                return
            }
        }
    }

    // the kit grabbed again (after a turn, or a change of the ambience's colour): what is on screen is made again
    function regrabbed() {
        if (!kitSeen) {
            kitSeen = true
            return
        }
        halt()
        generation++
        if (!canPrepare)
            return
        prepare(false)
        var count = Stills.ORDER.length
        var at = Stills.ORDER.indexOf(style)
        queue.add(stillTurn(shotOf(Stills.ORDER[(at + count - 1) % count])))
        queue.add(stillTurn(shotOf(Stills.ORDER[(at + 1) % count])))
        stripDue = stripWanted
        queueStrip()
    }

    allowedOrientations: Orientation.All
    onLiveChanged: {
        if (!live)
            halt()
    }
    onNavigatingChanged: {
        if (navigating)
            halt()
    }
    onCanPrepareChanged: {
        if (canPrepare)
            prepare(true)
    }
    // a turn: the stills are made again at the new size once it has settled
    onStageWidthChanged: {
        if (started) {
            halt()
            queue.clear()
            turned.restart()
        }
    }
    Component.onCompleted: shots.positionViewAtIndex(Math.max(0, Stills.ORDER.indexOf(style)), PathView.SnapPosition)

    AnimationSettings {
        id: settings
    }

    Timer {
        interval: 0
        running: page.live && !page.started && page.glMajor > 0
        onTriggered: page.started = true
    }

    Timer {
        id: playSoon

        running: page.wantsPlay && page.still && page.stage !== null
        onTriggered: {
            page.wantsPlay = false
            page.stage.play()
        }
    }

    Timer {
        id: landing

        interval: 300
        onTriggered: page.landed()
    }

    Timer {
        id: tourGap

        interval: 400
        onTriggered: {
            if (page.touring)
                page.goTo(Stills.ORDER[Stills.ORDER.indexOf(page.style) + 1])
        }
    }

    Timer {
        id: turned

        interval: 300
        onTriggered: {
            if (page.kit)
                page.kit.regrab()
        }
    }

    FreezeQueue {
        id: queue

        paused: !page.still
    }

    // the made-up home screen at the stage's size, and at the strip's (made once the strip is wanted)
    Loader {
        id: kitLoader

        active: page.started
        asynchronous: true
        sourceComponent: Component {
            PreviewKit {
                side: page.stageWidth
                picture: page.ambienceFile
                tint: page.tint
                useTint: page.useTint
                onGrabbed: page.regrabbed()
            }
        }
    }

    // a kit whose pictures are cached is ready while it is made, before the Loader hands it out: asked again then
    Loader {
        id: stripKitLoader

        active: page.stripWanted
        asynchronous: true
        onLoaded: page.queueStrip()
        sourceComponent: Component {
            PreviewKit {
                side: page.stripWidth
                picture: page.ambienceFile
                tint: page.tint
                useTint: page.useTint
                onReadyChanged: page.queueStrip()
            }
        }
    }

    // every style's still at the stage's size, the neighbours peeking in at the sides at half opacity
    SlideshowView {
        id: shots

        x: page.isPortrait ? 0 : page.inset
        y: page.isPortrait ? caption.y + caption.height + Theme.paddingMedium + (page.room - page.stageHeight) / 2
                           : (page.height - page.stageHeight) / 2
        width: page.shotsWidth
        height: page.stageHeight
        itemWidth: page.stageWidth + Theme.paddingLarge
        itemHeight: page.stageHeight
        clip: !page.isPortrait
        model: Stills.ORDER
        onCurrentIndexChanged: {
            page.style = Stills.ORDER[currentIndex]
            page.scrubAt = -1
        }
        onDraggingChanged: {
            if (dragging)
                page.interrupt()
        }
        onOffsetChanged: landing.restart()

        delegate: Item {
            id: shot

            readonly property bool isCurrent: PathView.isCurrentItem
            // under the stage while it covers the still
            readonly property bool covered: isCurrent && page.stage !== null && page.stage.coversStill

            width: shots.itemWidth
            height: shots.itemHeight

            // dark until the still is made for what the page shows
            Rectangle {
                x: frame.x
                width: frame.width
                height: frame.height
                visible: !frame.visible && !shot.covered
                opacity: frame.opacity
                color: Theme.rgba("white", 0.06)
            }

            FrozenFrame {
                id: frame

                // what it was last made for, and is being made for
                property string madeFor
                property string making
                readonly property string wanted: page.stillKey(style, moment, at, kit)

                x: (parent.width - page.stageWidth) / 2
                width: page.stageWidth
                height: page.stageHeight
                // a grab needs it shown: while it is made, the old one shows
                visible: (madeFor === wanted || developing) && !shot.covered
                opacity: shot.isCurrent ? 1 : 0.5
                style: modelData
                moment: page.moment
                at: page.stillAt(modelData, shot.isCurrent)
                kit: page.kit
                onDone: madeFor = making
            }

            // the still shown plays again; a neighbour comes to the middle
            MouseArea {
                anchors.fill: frame
                onClicked: {
                    if (shot.isCurrent)
                        page.replay()
                    else
                        page.goTo(modelData)
                }
            }

            Component.onCompleted: page.shotsBy[modelData] = frame
            // a delegate that goes with the page finds the page's ids gone, and nothing left to tidy
            Component.onDestruction: {
                if (!page)
                    return
                if (page.shotsBy[modelData] === frame)
                    delete page.shotsBy[modelData]
                if (queue.current === frame)
                    queue.clear()
            }
        }
    }

    // the live scene, over the still shown and under the rest of the page
    Loader {
        id: stageLoader

        x: shots.x + (shots.width - page.stageWidth) / 2
        y: shots.y
        width: page.stageWidth
        height: page.stageHeight
        active: page.started
        asynchronous: true
        sourceComponent: Component {
            AnimationStage {
                kit: page.kit
                style: page.style
                moment: page.moment
                round: page.round
                speed: settings.speed
                slow: page.slow
                rung: page.runRung
                onRan: page.judge(ranStyle, ranMoment, frames)
                onEnded: {
                    if (whole)
                        page.afterRun()
                }
            }
        }
    }

    // the style's name and what it is, what the moment plays now (a tap shows it), and the moment's length
    Column {
        id: caption

        x: page.isPortrait ? Theme.horizontalPageMargin : page.sideX
        y: page.isPortrait ? page.inset : Theme.paddingLarge
        width: page.isPortrait ? page.width - 2 * Theme.horizontalPageMargin : page.sideWidth
        spacing: Theme.paddingSmall

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignRight
            truncationMode: TruncationMode.Fade
            font.pixelSize: Theme.fontSizeLarge
            color: palette.highlightColor
            text: page.styleName(page.style)
        }

        // two lines whatever it says, so that a swipe never changes the stage's size. The lines stand the font's
        // lineSpacing apart: Text's own line is ascent plus descent high, without the leading, which is negative in
        // Sail Sans Pro, and two of those do not fit in this height, so that Qt would cut the text to one line
        Label {
            id: aboutLabel

            width: parent.width
            height: Math.ceil(2 * aboutMetrics.lineSpacing)
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            lineHeightMode: Text.FixedHeight
            lineHeight: aboutMetrics.lineSpacing
            font.pixelSize: Theme.fontSizeExtraSmall
            color: palette.secondaryColor
            text: Stills.ABOUT[page.style] + (Styles.heavy(page.style, page.moment)
                                              ? " " + qsTr("May stutter on slower phones.") : "")

            FontMetrics {
                id: aboutMetrics

                font: aboutLabel.font
            }
        }

        Item {
            width: parent.width
            height: inUseLabel.height

            Label {
                id: inUseLabel

                width: Math.min(implicitWidth, parent.width - lengthLabel.implicitWidth - Theme.paddingLarge)
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeSmall
                color: inUseTouch.pressed && inUseTouch.enabled ? palette.highlightColor : palette.primaryColor
                text: !settings.enabled ? qsTr("Off")
                      : page.inUse === "surprise" ? qsTr("In use: Surprise me")
                      : qsTr("In use: %1").arg(page.styleName(page.inUse))
            }

            Label {
                id: lengthLabel

                anchors.right: parent.right
                font.pixelSize: Theme.fontSizeSmall
                color: palette.secondaryColor
                text: page.moment === "load" ? page.shownMoment.text
                      : qsTr("%1, %2 ms").arg(page.shownMoment.text)
                                          .arg(page.style === "stock" ? (page.moment === "open" ? 450 : 300)
                                                                      : Styles.duration(page.style, page.moment,
                                                                                        settings.speed))
            }

            // what plays shows, if it is a style or Stock: Off and Surprise me name none
            MouseArea {
                id: inUseTouch

                anchors.fill: inUseLabel
                anchors.margins: -Theme.paddingMedium
                enabled: settings.enabled && page.inUse !== "surprise"
                onClicked: page.goTo(page.inUse)
            }
        }
    }

    // the strip, Slow and Speed, the tabs and the Use buttons, made once the page has started
    Item {
        x: page.isPortrait ? 0 : page.sideX
        y: page.height - page.controlsHeight
        width: page.isPortrait ? page.width : page.sideWidth
        height: page.controlsHeight

        Loader {
            id: controls

            anchors.fill: parent
            active: page.started
            asynchronous: true
            sourceComponent: Component {
                Item {
                    readonly property Item strip: stripView

                    AnimationStrip {
                        id: stripView

                        x: Math.round((parent.width - width) / 2)
                        kit: page.stripKit
                        style: page.style
                        moment: page.moment
                        loadSeconds: page.clipOf(page.style)
                        frameWidth: page.stripWidth
                        frameHeight: page.stripHeight
                        gap: page.gap
                        generation: page.generation
                        head: page.head
                        onScrubbed: page.scrub(at)
                        onLifted: page.lift(at)
                        onCanceled: page.halt()
                    }

                    // Slow, for looking only; and Speed, which writes the setting
                    Item {
                        x: stripView.x
                        y: page.stripHeight + Theme.paddingSmall
                        width: stripView.width
                        height: page.textRowHeight

                        BackgroundItem {
                            width: slowLabel.width + 2 * Theme.paddingMedium
                            height: parent.height
                            onClicked: page.toggleSlow()

                            Label {
                                id: slowLabel

                                anchors.centerIn: parent
                                font.pixelSize: Theme.fontSizeSmall
                                color: page.slow || parent.highlighted ? palette.highlightColor : palette.primaryColor
                                text: qsTr("Slow")
                            }
                        }

                        BackgroundItem {
                            anchors.right: parent.right
                            width: speedLabel.width + 2 * Theme.paddingMedium
                            height: parent.height
                            onClicked: page.cycleSpeed()

                            Label {
                                id: speedLabel

                                anchors.centerIn: parent
                                font.pixelSize: Theme.fontSizeSmall
                                color: parent.highlighted ? palette.highlightColor : palette.primaryColor
                                text: [qsTr("Speed: Relaxed"), qsTr("Speed: Normal"),
                                       qsTr("Speed: Quick")][settings.speed] || qsTr("Speed: Normal")
                            }
                        }
                    }

                    // the same style at another moment
                    Row {
                        x: stripView.x
                        y: page.stripHeight + Theme.paddingSmall + page.textRowHeight
                        width: stripView.width

                        Repeater {
                            model: page.moments

                            BackgroundItem {
                                width: Math.floor(stripView.width / 3)
                                height: Theme.itemSizeExtraSmall
                                onClicked: page.showMoment(modelData.moment)

                                Label {
                                    anchors.centerIn: parent
                                    color: page.playingMoment === modelData.moment || parent.highlighted
                                           ? palette.highlightColor : palette.primaryColor
                                    text: modelData.text
                                }
                            }
                        }
                    }

                    // the only writes besides Speed: this style for the moment shown, or for all three
                    Row {
                        x: stripView.x
                        y: page.stripHeight + Theme.paddingSmall + page.textRowHeight + Theme.itemSizeExtraSmall
                        spacing: Theme.paddingMedium

                        Button {
                            width: Math.floor((stripView.width - parent.spacing) / 2)
                            enabled: !page.usedForMoment
                            text: page.usedForMoment ? qsTr("In use") : page.shownMoment.use
                            onClicked: page.useFor(page.momentKey, page.style)
                        }

                        SecondaryButton {
                            width: Math.floor((stripView.width - parent.spacing) / 2)
                            enabled: !page.usedForAll
                            text: page.usedForAll ? qsTr("In use") : qsTr("Use for all three")
                            onClicked: page.useAll(page.style)
                        }
                    }
                }
            }
        }
    }

    // a touch anywhere ends the tour, on the style it is at; between two runs, what a whole run leaves to make is
    // made then
    MouseArea {
        anchors.fill: parent
        enabled: page.touring
        onPressed: {
            var between = tourGap.running
            page.touring = false
            tourGap.stop()
            if (between)
                page.queueRest()
            mouse.accepted = false
        }
    }
}
