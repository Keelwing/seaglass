// The opening and closing effects of apps (docs/ANIMATIONS.md). The Patchmanager hook (hook/apply_hook.py) loads
// this into a Loader right after the app layer in compositor.qml; the Loader is its parent and gives appLayer, the
// app layer (layers/AppLayer.qml, a StackLayer), which lies under this item in the same coordinates, and overlay, an
// item above all the layers, where the closing effects play (the app layer's own layer hides as soon as the stock
// close is over). The app
// layer's show animation (StackLayer.qml) reads:
//   opening(layer)  its window is about to fade in: an opening effect may play over a copy of the layer, which is
//                   hidden meanwhile (the stock fade runs on unseen: the copy leaves out the layer's own opacity);
//                   true when it does
//   playing         an opening effect plays: the layer stays transitioning, so the home screen under it is drawn
// A swipe down from the top that closes the app (the layer's peekFilter: gestureTriggered with topActive) freezes
// the window whole, without the stock fade and wipe (the layer's snapshot item), and plays the closing effect from
// it: the window comes back from where the swipe left it, and the effect takes it away. The stock close runs on
// unseen underneath, the whole layer hidden.
// The effects never hold Sailfish up: the window is shown, focused and closed at the stock moment, and the effect
// plays on a copy of it. Every shader is read when the home screen starts and compiled a few seconds later, one at a
// time, so that none is compiled while it should play.
import QtQuick 2.6
import Sailfish.Silica 1.0
import org.nemomobile.lipstick 0.1
import "../settings"
import "../core/motion.js" as Motion
import "styles.js" as Styles
import "shaders.js" as Shaders

Item {
    id: controller

    readonly property Item appLayer: parent ? parent.appLayer : null
    readonly property Item overlay: parent && parent.overlay !== undefined ? parent.overlay : null
    readonly property bool playing: openRun.running
    readonly property vector3d tint: Qt.vector3d(Theme.highlightColor.r, Theme.highlightColor.g,
                                                 Theme.highlightColor.b)
    readonly property bool es3: openEffect.es3
    // Shatter plays with its shards (Shards.qml) instead of one effect
    property bool openShardsOn
    property bool closeShardsOn
    // the shaders still to compile ({style, moment})
    property var warmQueue: []

    function debugLog() {
        if (general.debug)
            console.log.apply(console, ["seaglass: animations:"].concat(Array.prototype.slice.call(arguments)))
    }

    // the style of a moment ("open", "loading", "close"): "stock", or a style of styles.js
    function styleFor(moment) {
        return Styles.choose(settings, moment)
    }

    // whether a moment may be Shatter's (the shard items are made only then)
    function mayShatter(moment) {
        return settings.enabled && (settings[moment] === "shatter"
                                    || (settings[moment] === "" && (settings.surprise || settings.style === "shatter")))
    }

    // where an app opens from, in this item's coordinates (0 to 1): the icon tapped while the app grid is still
    // there (within the last 3 s), else its cover on the home screen, else the middle of the screen
    function openingRect(layer) {
        var tapped = Motion.takeAppOrigin(3000)
        var launcher = Lipstick.compositor.launcherLayer
        var from = tapped && launcher && launcher.exposed ? tapped : null
        var kind = from ? "icon" : "middle"
        if (!from && Motion.switcher && layer.window.window) {
            from = Motion.switcher.coverRectFor(layer.window.window.windowId)
            if (from)
                kind = "cover"
        }
        debugLog("open from the", kind, "(an icon tapped:", tapped !== null, "app grid:", launcher ? launcher.exposed : "-",
                 "switcher:", Motion.switcher !== null, ")")
        if (from && width > 0 && height > 0) {
            var corner = controller.mapFromItem(null, from.x, from.y)
            return Qt.rect(corner.x / width, corner.y / height, from.width / width, from.height / height)
        }
        return Qt.rect(0.35, 0.4, 0.3, 0.2)
    }

    function opening(layer) {
        var style = styleFor("open")
        if (style === "stock" || !layer || !layer.window || !layer.active || closeRun.running)
            return false
        var shards = Styles.has(style, "shards")
        if (!shards)
            openEffect.style = style
        if (shards ? !openShards.ready : !openEffect.ready) {
            debugLog("open: stock,", style, "is not loaded yet")
            return false
        }
        var rect = openingRect(layer)
        openEffect.originRect = rect
        openEffect.origin = Qt.point(rect.x + rect.width / 2, rect.y + rect.height / 2)
        openEffect.progress = 0
        openShardsOn = shards
        if (shards) {
            openShards.impact = openEffect.origin
            openShards.build()
        }
        liveLayer.mipmap = es3 && Styles.has(style, "blur")
        liveLayer.sourceItem = layer
        openRun.duration = Styles.duration(style, "open", settings.speed)
        openRun.restart()
        debugLog("open:", style, openRun.duration, "ms from", Math.round(rect.x * 100), Math.round(rect.y * 100),
                 Math.round(rect.width * 100), Math.round(rect.height * 100))
        return true
    }

    // the app's own close gesture was let go: called once, from the first of the two signs (the gesture's trigger
    // with the top edge active, or the layer closing a window it dismisses)
    function closing(sign) {
        if (closeRun.running || !appLayer.window)
            return
        Motion.noteWindowClosing(appLayer.window.window ? appLayer.window.window.windowId : 0)
        var style = styleFor("close")
        if (style === "stock" || height <= 0) {
            debugLog("close: stock (" + sign + ")")
            return
        }
        var shards = Styles.has(style, "shards")
        if (!shards)
            closeEffect.style = style
        if (shards ? !closeShards.ready : !closeEffect.ready) {
            debugLog("close: stock,", style, "is not loaded yet")
            return
        }
        if (openRun.running)
            openRun.complete()
        // the swipe has wiped the window down to here, and faded it this far
        var top = Math.max(0, Math.min(height - 1, appLayer.peekFilter.absoluteProgress))
        var faded = Math.max(0.2, Math.min(1, appLayer.contentOpacity))
        closeEffect.originRect = Qt.rect(0, 0, 1, 1)
        closeEffect.origin = Qt.point(0.5, (top + (height - top) * 0.3) / height)
        closeEffect.progress = 0
        closeShardsOn = shards
        if (shards) {
            closeShards.impact = closeEffect.origin
            closeShards.build()
        }
        frozenLayer.mipmap = es3 && Styles.has(style, "blur")
        frozenLayer.sourceItem = appLayer.snapshotSource
        frozenLayer.scheduleUpdate()
        layerHider.sourceItem = appLayer
        unhide.restart()
        comeBack.stop()
        cameFrom.top = top / height
        cameFrom.opacity = faded
        comeBack.start()
        closeRun.duration = Styles.duration(style, "close", settings.speed)
        closeRun.restart()
        debugLog("close:", style, closeRun.duration, "ms, window top at", Math.round(top), "faded to",
                 Math.round(faded * 100) / 100, "(" + sign + ")")
    }

    // the closing effects into the overlay, out of the layer that hides when the stock close is over
    Component.onCompleted: {
        if (overlay) {
            closeEffect.parent = overlay
            closeShards.parent = overlay
        }
    }

    function finish() {
        if (openRun.running)
            openRun.complete()
        if (closeRun.running)
            closeRun.complete()
    }

    // every shader is read at once, then compiled one at a time (the chosen styles only, or every style with Surprise
    // me), a pixel large and nearly clear: compiling one can stall a frame
    function prepare() {
        if (!settings.enabled || openEffect.glMajor === 0)
            return
        var base = Qt.resolvedUrl("shaders/")
        var all = Styles.shaders()
        var queue = []
        for (var i = 0; i < all.length; i++) {
            var item = all[i]
            Shaders.load(base, item.style + "-" + item.moment, Styles.libs(item.style), es3, function () {})
            var moment = item.moment === "load" ? "loading" : item.moment
            if (settings.surprise || styleFor(moment) === item.style)
                queue.push(item)
        }
        Shaders.loadFile(base + "shards.vert", function () {})
        Shaders.loadFile(base + "shards.frag", function () {})
        warmQueue = queue
        warmUp.restart()
    }

    anchors.fill: parent

    AnimationSettings {
        id: settings
    }

    GeneralSettings {
        id: general
    }

    NoiseTile {
        id: noise
    }

    Connections {
        target: controller.appLayer ? controller.appLayer.peekFilter : null
        onGestureStarted: {
            // a swipe on an app that is still opening: the app as it is
            if (openRun.running)
                openRun.complete()
            controller.debugLog("gesture started, top", controller.appLayer.peekFilter.topActive)
        }
        onGestureTriggered: {
            controller.debugLog("gesture let go, top", controller.appLayer.peekFilter.topActive, "at",
                                Math.round(controller.appLayer.peekFilter.absoluteProgress))
            if (controller.appLayer.peekFilter.topActive)
                controller.closing("gesture")
        }
    }

    Connections {
        target: controller.appLayer
        // the layer's own sign that it dismisses its window (StackLayer.closingWindowId)
        onClosingChanged: {
            if (controller.appLayer.closing && controller.appLayer.closingWindowId !== 0)
                controller.closing("layer")
        }
        onClosed: layerHider.sourceItem = null
        onWindowChanged: {
            if (openRun.running && liveLayer.sourceItem !== null)
                openRun.complete()
        }
        onCompleteTransitions: controller.finish()
    }

    Connections {
        target: Lipstick.compositor
        onDisplayAboutToBeOff: controller.finish()
    }

    Connections {
        target: settings
        onEnabledChanged: controller.prepare()
        onStyleChanged: controller.prepare()
        onOpenChanged: controller.prepare()
        onCloseChanged: controller.prepare()
        onLoadingChanged: controller.prepare()
        onSurpriseChanged: controller.prepare()
    }

    // the app layer while it opens, live; hidden itself, so that it is not drawn twice
    ShaderEffectSource {
        id: liveLayer

        width: controller.width
        height: controller.height
        visible: false
        live: true
        hideSource: sourceItem !== null
        sourceItem: null
    }

    // the window as the swipe let it go, whole: the layer's snapshot item, without the stock fade and wipe
    ShaderEffectSource {
        id: frozenLayer

        width: controller.width
        height: controller.height
        visible: false
        live: false
        sourceItem: null
    }

    // hides the whole app layer while the stock close runs on underneath; it draws nothing itself
    ShaderEffectSource {
        id: layerHider

        width: 0
        height: 0
        visible: false
        live: false
        hideSource: sourceItem !== null
        sourceItem: null
    }

    Timer {
        id: unhide

        // the stock close takes up to 300 ms; never keep the layer hidden much longer
        interval: 800
        onTriggered: layerHider.sourceItem = null
    }

    Effect {
        id: openEffect

        anchors.fill: parent
        visible: openRun.running && ready && !controller.openShardsOn
        moment: "open"
        source: liveLayer
        noiseTex: noise
        tint: controller.tint
        useTint: settings.ambience ? 1 : 0
        onGlMajorChanged: controller.prepare()
    }

    Shards {
        id: openShards

        anchors.fill: parent
        visible: openRun.running && controller.openShardsOn
        active: controller.mayShatter("open")
        source: liveLayer
        assemble: true
        progress: openEffect.progress
        tint: controller.tint
        useTint: settings.ambience ? 1 : 0
    }

    NumberAnimation {
        id: openRun

        target: openEffect
        property: "progress"
        from: 0
        to: 1
        onStopped: liveLayer.sourceItem = null
    }

    Effect {
        id: closeEffect

        anchors.fill: parent
        visible: closeRun.running && ready && !controller.closeShardsOn
        moment: "close"
        source: frozenLayer
        noiseTex: noise
        tint: controller.tint
        useTint: settings.ambience ? 1 : 0
        clipTop: cameFrom.top
        opacity: cameFrom.opacity
    }

    Shards {
        id: closeShards

        anchors.fill: parent
        visible: closeRun.running && controller.closeShardsOn
        active: controller.mayShatter("close")
        source: frozenLayer
        progress: closeEffect.progress
        tint: controller.tint
        useTint: settings.ambience ? 1 : 0
        clipTop: cameFrom.top
        opacity: cameFrom.opacity
    }

    // where the swipe left the window (its wiped top edge, its fade), on its way back to whole
    QtObject {
        id: cameFrom

        property real top
        property real opacity: 1
    }

    ParallelAnimation {
        id: comeBack

        NumberAnimation {
            target: cameFrom
            property: "top"
            to: 0
            duration: 180
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: cameFrom
            property: "opacity"
            to: 1
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    NumberAnimation {
        id: closeRun

        target: closeEffect
        property: "progress"
        from: 0
        to: 1
        onStopped: {
            layerHider.sourceItem = null
            frozenLayer.sourceItem = null
        }
    }

    // compiles one shader every 150 ms, starting 3 s after the home screen (or after a change of settings)
    Effect {
        id: warmEffect

        x: -2
        y: -2
        width: 1
        height: 1
        opacity: 0.02
        visible: style !== "" && ready
        source: noise
        noiseTex: noise
        progress: 0.5
    }

    Timer {
        id: warmUp

        property bool started

        interval: started ? 150 : 3000
        repeat: true
        onTriggered: {
            started = true
            if (controller.warmQueue.length === 0) {
                warmEffect.style = ""
                stop()
                return
            }
            var next = controller.warmQueue[0]
            controller.warmQueue = controller.warmQueue.slice(1)
            warmEffect.moment = next.moment
            warmEffect.style = next.style
        }
    }
}
