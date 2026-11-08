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
// plays on a copy of it, on the render thread (Effect.qml), so that it keeps moving while the home screen is busy with
// the app. The shaders the settings can pick are read when the home screen starts or the settings change, and compiled
// a few seconds later, one at a time, so that none is compiled while it should play.
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
    readonly property bool playing: openEffect.running || openShards.running
    readonly property vector3d tint: Qt.vector3d(Theme.highlightColor.r, Theme.highlightColor.g,
                                                 Theme.highlightColor.b)
    readonly property bool es3: openEffect.es3
    // Shatter plays with its shards (Shards.qml) instead of one effect
    property bool openShardsOn
    property bool closeShardsOn
    // the shaders still to compile ({style, moment}, or {style: "shards"} for Shatter's)
    property var warmQueue: []

    function debugLog() {
        if (general.debug)
            console.log.apply(console, ["seaglass: animations:"].concat(Array.prototype.slice.call(arguments)))
    }

    // the style of a moment ("open", "loading", "close"): "stock", or a style of styles.js
    function styleFor(moment) {
        return Styles.choose(settings, moment)
    }

    // whether a moment may be Shatter's (its shards read their files only then)
    function mayShatter(moment) {
        return settings.enabled && (Styles.setting(settings, moment) === "shatter"
                                    || (settings.surprise && settings[moment] !== "stock"))
    }

    // where an app opens from: the icon tapped while the app grid is still there (within the last 3 s), else its
    // cover on the home screen, else the middle of the screen. {rect: in this item's coordinates (0 to 1), radius:
    // its corners in pixels} (launcher icons are round)
    function openingFrom(layer) {
        var tapped = Motion.takeAppOrigin(3000)
        var launcher = Lipstick.compositor.launcherLayer
        var from = tapped && launcher && launcher.exposed ? tapped : null
        var kind = from ? "icon" : "middle"
        if (!from && Motion.switcher && layer.window.window) {
            from = Motion.switcher.coverRectFor(layer.window.window.windowId)
            if (from)
                kind = "cover"
        }
        var radius = kind === "icon" ? from.width / 2 : kind === "cover" ? from.radius : 0
        debugLog("open from the", kind, "radius", Math.round(radius), "(an icon tapped:", tapped !== null, "app grid:",
                 launcher ? launcher.exposed : "-", "switcher:", Motion.switcher !== null, ")")
        if (from && width > 0 && height > 0) {
            var corner = controller.mapFromItem(null, from.x, from.y)
            return { "rect": Qt.rect(corner.x / width, corner.y / height, from.width / width, from.height / height),
                     "radius": radius }
        }
        return { "rect": Qt.rect(0.35, 0.4, 0.3, 0.2), "radius": 0 }
    }

    function opening(layer) {
        // an earlier opening's ended clears the source, so it ends before anything is set
        stopOpening()
        var style = styleFor("open")
        if (style === "stock" || !layer || !layer.window || !layer.active || closeEffect.running || closeShards.running)
            return false
        var shards = Styles.has(style, "shards")
        if (!shards)
            openEffect.style = style
        if (shards ? !openShards.ready : !openEffect.ready) {
            debugLog("open: stock,", style, "is not loaded yet")
            return false
        }
        var from = openingFrom(layer)
        var rect = from.rect
        openEffect.originRect = rect
        openEffect.radiusPx = from.radius
        openEffect.origin = Qt.point(rect.x + rect.width / 2, rect.y + rect.height / 2)
        openShardsOn = shards
        if (shards) {
            openShards.impact = openEffect.origin
            openShards.build()
        }
        liveLayer.mipmap = es3 && Styles.has(style, "blur")
        liveLayer.sourceItem = layer
        var ms = Styles.duration(style, "open", settings.speed)
        if (openShardsOn)
            openShards.play(ms)
        else
            openEffect.play(ms)
        debugLog("open:", style, ms, "ms from", Math.round(rect.x * 100), Math.round(rect.y * 100),
                 Math.round(rect.width * 100), Math.round(rect.height * 100))
        return true
    }

    // the app's own close gesture was let go: called once, from the first of the two signs (the gesture's trigger
    // with the top edge active, or the layer closing a window it dismisses)
    function closing(sign) {
        if (closeEffect.running || closeShards.running || !appLayer.window)
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
        stopOpening()
        // the swipe has wiped the window down to here, and faded it this far
        var top = Math.max(0, Math.min(height - 1, appLayer.peekFilter.absoluteProgress))
        var faded = Math.max(0.2, Math.min(1, appLayer.contentOpacity))
        closeEffect.originRect = Qt.rect(0, 0, 1, 1)
        closeEffect.origin = Qt.point(0.5, (top + (height - top) * 0.3) / height)
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
        // the window comes back from there, and the GUI side starts there too, before the run
        effectBack.stop()
        shardsBack.stop()
        var piece = shards ? closeShards : closeEffect
        piece.clipTop = top / height
        piece.opacity = faded
        var ms = Styles.duration(style, "close", settings.speed)
        if (closeShardsOn) {
            closeShards.play(ms)
            shardsBack.start()
        } else {
            closeEffect.play(ms)
            effectBack.start()
        }
        debugLog("close:", style, ms, "ms, window top at", Math.round(top), "faded to",
                 Math.round(faded * 100) / 100, "(" + sign + ")")
    }

    // the closing effects into the overlay, out of the layer that hides when the stock close is over
    Component.onCompleted: {
        if (overlay) {
            closeEffect.parent = overlay
            closeShards.parent = overlay
        }
    }

    function stopOpening() {
        openEffect.halt()
        openShards.halt()
    }

    function finish() {
        stopOpening()
        closeEffect.halt()
        closeShards.halt()
    }

    // what the settings can pick (the chosen styles only, or every style with Surprise me) is read at once, then
    // compiled one at a time, a pixel large and nearly clear: compiling one can stall a frame. The shards read their
    // own files while they are active. Turned off, what is still queued is not compiled either
    function prepare() {
        if (!settings.enabled)
            warmQueue = []
        if (!settings.enabled || openEffect.glMajor === 0)
            return
        var base = Qt.resolvedUrl("shaders/")
        var all = Styles.shaders()
        var queue = []
        for (var i = 0; i < all.length; i++) {
            var item = all[i]
            var chosen = styleFor(item.moment === "load" ? "loading" : item.moment) === item.style
            if (settings.surprise || chosen) {
                Shaders.load(base, item.style + "-" + item.moment, Styles.libs(item.style), es3, function () {})
                queue.push(item)
            }
        }
        if (mayShatter("open") || mayShatter("close"))
            queue.push({ "style": "shards" })
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

        wanted: settings.enabled
    }

    Connections {
        target: controller.appLayer ? controller.appLayer.peekFilter : null
        onGestureStarted: {
            // a swipe on an app that is still opening: the app as it is
            controller.stopOpening()
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
            if (liveLayer.sourceItem !== null)
                controller.stopOpening()
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
        visible: running && ready
        moment: "open"
        source: liveLayer
        noiseTex: noise
        tint: controller.tint
        useTint: settings.ambience ? 1 : 0
        onGlMajorChanged: controller.prepare()
        onEnded: liveLayer.sourceItem = null
    }

    Shards {
        id: openShards

        anchors.fill: parent
        visible: running
        active: controller.mayShatter("open")
        source: liveLayer
        assemble: true
        tint: controller.tint
        useTint: settings.ambience ? 1 : 0
        onEnded: liveLayer.sourceItem = null
    }

    Effect {
        id: closeEffect

        anchors.fill: parent
        visible: running && ready
        moment: "close"
        source: frozenLayer
        noiseTex: noise
        tint: controller.tint
        useTint: settings.ambience ? 1 : 0
        onEnded: {
            layerHider.sourceItem = null
            frozenLayer.sourceItem = null
        }
    }

    Shards {
        id: closeShards

        anchors.fill: parent
        visible: running
        active: controller.mayShatter("close")
        source: frozenLayer
        tint: controller.tint
        useTint: settings.ambience ? 1 : 0
        onEnded: {
            layerHider.sourceItem = null
            frozenLayer.sourceItem = null
        }
    }

    // the window from where the swipe left it (its wiped top edge, its fade) back to whole, on the render thread as the
    // closing is. Written from the GUI thread, they would stand still while it is busy, and a write in the closing's
    // last frame would put the GUI side's progress, 0, back into the effect: the window whole for a frame. (An
    // OpacityAnimator does not reach an item drawn through its layer: no closing is half without being split.) A
    // closing that is not split has no grains pass, and the animator for it has no target and does nothing
    ParallelAnimation {
        id: effectBack

        UniformAnimator {
            target: closeEffect
            uniform: "clipTop"
            from: closeEffect.clipTop
            to: 0
            duration: 180
            easing.type: Easing.OutCubic
        }
        UniformAnimator {
            target: closeEffect.grains
            uniform: "clipTop"
            from: closeEffect.clipTop
            to: 0
            duration: 180
            easing.type: Easing.OutCubic
        }
        OpacityAnimator {
            target: closeEffect
            from: closeEffect.opacity
            to: 1
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: shardsBack

        UniformAnimator {
            target: closeShards
            uniform: "clipTop"
            from: closeShards.clipTop
            to: 0
            duration: 180
            easing.type: Easing.OutCubic
        }
        OpacityAnimator {
            target: closeShards
            from: closeShards.opacity
            to: 1
            duration: 180
            easing.type: Easing.OutCubic
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

    // Shatter's programs, the same way: they are the same for every Shards
    Shards {
        id: warmShards

        x: -2
        y: -2
        width: 1
        height: 1
        opacity: 0.02
        visible: ready
        active: false
        source: noise
        progress: 0.5
    }

    Timer {
        id: warmUp

        property bool started

        interval: started ? 150 : 3000
        repeat: true
        onTriggered: {
            started = true
            warmShards.active = false
            // first of all, so that the next moment under the last style does not read a shader nobody queued
            warmEffect.style = ""
            if (controller.warmQueue.length === 0) {
                stop()
                return
            }
            var next = controller.warmQueue[0]
            controller.warmQueue = controller.warmQueue.slice(1)
            if (next.style === "shards") {
                warmShards.active = true
                return
            }
            warmEffect.moment = next.moment
            warmEffect.style = next.style
        }
    }
}
