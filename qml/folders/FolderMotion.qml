// How an app grid folder opens and closes (LauncherFolder.qml). The Patchmanager hook loads this into a Loader in the
// open folder; the Loader is its parent and provides:
//   folder  the LauncherFolder (a full-screen Rectangle over the app grid)
//   grid    the folder's LauncherGrid (its apps)
// While managed (any style but "fade"), the hook leaves the folder's opacity to this item, and close() plays the
// closing motion first: it returns true, and calls the folder's close() again when done (then it returns false and
// the stock close runs). With "fade", or when this file is missing, the folder fades as in stock.
//
// Styles (Settings > Patchmanager > Seaglass, dconf /apps/seaglass/motion):
//   zoom    the folder grows out of its icon or widget tile with a soft settle, and shrinks back into it (iOS)
//   spring  it pops up from the icon with a springy overshoot
//   reveal  a circle grows from the icon and reveals it (Material)
//   slide   it rises from the bottom like a Sailfish sheet
//   fade    the stock fade
// and: cascade (the apps ripple in from the icon), depth (the app grid steps back), speed (0.7 fast .. 1.4 relaxed).
// The origin comes from motion.js (HomeController.qml notes the tapped icon or tile); without one, the centre.
// The glass (docs/GLASS.md): with the open folder on glass, a frosted sheet of the home screen's wallpaper under
// the folder's content (glass: the hook then makes the stock dark gradient transparent); with the zoom, the sheet
// grows out of the folder's glass tile, rounded like it.
import QtQuick 2.6
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import "../settings"
import "../glass"
import "../core/motion.js" as Motion

Item {
    id: motion

    readonly property Item folder: parent && parent.folder !== undefined ? parent.folder : null
    readonly property Item grid: parent && parent.grid !== undefined ? parent.grid : null

    // the settings, from dconf; the harness's Loader provides its own (they must be there when the folder appears)
    property string style: parent && parent.style !== undefined ? parent.style : settings.style
    property bool cascade: parent && parent.cascade !== undefined ? parent.cascade : settings.cascade
    property bool depth: parent && parent.depth !== undefined ? parent.depth : settings.depth
    property real speed: parent && parent.speed !== undefined ? parent.speed : settings.speed
    // the harness slows everything down to record it frame by frame
    property real timeScale: parent && parent.timeScale !== undefined ? parent.timeScale : 1.0

    readonly property bool managed: Motion.STYLES.indexOf(style) >= 0 && style !== "fade"
    property bool closing
    // 0: closed (at the icon), 1: open
    property real progress: 0
    // the origin in the folder's coordinates
    property real originX: folder ? folder.width / 2 : 0
    property real originY: folder ? folder.height / 2 : 0
    property real originSize: Theme.iconSizeLauncher
    property real originRadius: Theme.iconSizeLauncher / 4
    property var cascadeItems: []
    property Item homeGrid

    // the glass: HomeController.qml's, there before any folder opens
    readonly property Item glassSource: Motion.home && Motion.home.glass ? Motion.home.glass : null
    readonly property bool glass: glassSource !== null && glassSource.ready && glassSource.openFolder

    readonly property real openDuration: ({ "zoom": 380, "spring": 440, "reveal": 400, "slide": 360 })[style] || 380
    readonly property real closeDuration: ({ "zoom": 260, "spring": 260, "reveal": 280, "slide": 260 })[style] || 260

    visible: false

    MotionSettings {
        id: settings
    }

    // An app launched from the folder: counted for the search's apps used most (the stock press made it the
    // folder grid's current item just before)
    Connections {
        target: motion.grid
        ignoreUnknownSignals: true
        onItemLaunched: {
            var home = Motion.home
            if (home && home.noteLaunch && motion.grid.currentIndex !== undefined && motion.grid.model)
                home.noteLaunch(motion.grid.model.get(motion.grid.currentIndex))
        }
    }

    // The sheet: in the folder, under its content
    GlassPane {
        parent: motion.folder
        z: -1
        anchors.fill: parent
        glass: motion.glass ? motion.glassSource : null
        radius: motion.folder ? motion.folder.radius : 0
        frost: 1
        color: motion.glassSource ? motion.glassSource.tintColor(2) : "transparent"
        // a rim while it grows out of the tile; no line at the top when open
        edgeLight: radius > 0 && motion.glassSource !== null && motion.glassSource.edgeLight
    }

    Scale { id: folderScale }
    Translate { id: folderShift }
    Scale { id: homeScale }

    Component {
        id: itemScale

        Scale {}
    }

    // the circle of "reveal": the folder's layer through a round mask
    Component {
        id: revealEffect

        ShaderEffect {
            property variant source
            property point center: Qt.point(motion.originX, motion.originY)
            property real radius: motion.revealRadius
            property size size: Qt.size(motion.folder ? motion.folder.width : 1, motion.folder ? motion.folder.height : 1)
            property real softness: Theme.paddingLarge

            fragmentShader: "
                uniform sampler2D source;
                uniform lowp float qt_Opacity;
                uniform highp vec2 center;
                uniform highp float radius;
                uniform highp vec2 size;
                uniform highp float softness;
                varying highp vec2 qt_TexCoord0;
                void main() {
                    highp float d = distance(qt_TexCoord0 * size, center);
                    lowp float a = 1.0 - smoothstep(radius - softness, radius, d);
                    gl_FragColor = texture2D(source, qt_TexCoord0) * a * qt_Opacity;
                }"
        }
    }
    property real revealRadius: 0

    NumberAnimation {
        id: openAnimation

        target: motion
        property: "progress"
        from: 0
        to: 1
        duration: motion.openDuration * motion.speed * motion.timeScale
        onStopped: motion.finishOpen()
    }

    NumberAnimation {
        id: closeAnimation

        target: motion
        property: "progress"
        to: 0
        duration: motion.closeDuration * motion.speed * motion.timeScale
        onStopped: motion.finishClose()
    }

    function start() {
        if (!managed || !folder)
            return
        var rect = Motion.takeOrigin()
        if (rect) {
            var local = folder.mapFromItem(null, rect.x + rect.width / 2, rect.y + rect.height / 2)
            originX = local.x
            originY = local.y
            originSize = Math.max(rect.width, rect.height)
            originRadius = rect.radius !== undefined ? rect.radius : originSize / 4
        }
        homeGrid = depth ? Motion.homeGrid() : null
        folderScale.origin.x = originX
        folderScale.origin.y = originY
        folder.transform = [folderScale, folderShift]
        if (style === "reveal") {
            folder.layer.effect = revealEffect
            folder.layer.enabled = true
        }
        if (homeGrid) {
            var center = homeGrid.mapFromItem(folder, originX, originY)
            homeScale.origin.x = center.x
            homeScale.origin.y = center.y
            homeGrid.transform = homeScale
        }
        apply(0)
        openAnimation.start()
    }

    function finishOpen() {
        if (closing)
            return
        apply(1)
        if (style === "reveal") {
            folder.layer.enabled = false
            folder.layer.effect = null
        }
        folder.transform = []
        folder.radius = 0
        restoreItems()
    }

    // true: the closing motion runs, and calls folder.close() again when it is done
    function close() {
        if (!managed || closing || !folder)
            return false
        closing = true
        openAnimation.stop()
        folder.enabled = false
        restoreItems()
        folderScale.origin.x = originX
        folderScale.origin.y = originY
        folder.transform = [folderScale, folderShift]
        if (style === "reveal") {
            folder.layer.effect = revealEffect
            folder.layer.enabled = true
        }
        closeAnimation.from = progress
        closeAnimation.start()
        return true
    }

    function finishClose() {
        restoreHome()
        if (folder)
            folder.close()
    }

    function restoreHome() {
        if (homeGrid) {
            homeGrid.transform = []
            homeGrid.opacity = 1
            homeGrid = null
        }
    }

    function restoreItems() {
        for (var i = 0; i < cascadeItems.length; i++) {
            var entry = cascadeItems[i]
            if (entry.item) {
                entry.item.transform = []
                entry.item.opacity = 1
            }
            entry.scale.destroy()
        }
        cascadeItems = []
    }

    // The folder at progress p of its motion
    function apply(p) {
        var opening = !closing
        var s = 1
        var shift = 0
        var opacity = 1
        if (style === "zoom") {
            var from = Motion.clamp(originSize / Math.max(1, folder.width), 0.05, 1)
            var e = opening ? Motion.outBack(p, 0.9) : Motion.outCubic(p)
            s = from + (1 - from) * e
            opacity = Motion.clamp(p / 0.3, 0, 1)
            // rounded like the icon while small, square when open: the radius is drawn scaled by s
            folder.radius = originRadius * Math.max(0, 1 - e) / Math.max(0.05, s)
        } else if (style === "spring") {
            s = 0.82 + 0.18 * (opening ? Motion.outBack(p, 2.2) : Motion.outCubic(p))
            opacity = Motion.clamp(p / 0.3, 0, 1)
        } else if (style === "slide") {
            shift = (1 - Motion.outCubic(p)) * folder.height * 0.35
            opacity = Motion.clamp(p / 0.45, 0, 1)
        } else if (style === "reveal") {
            var far = Math.max(Math.sqrt(originX * originX + originY * originY),
                               Math.sqrt(Math.pow(folder.width - originX, 2) + originY * originY),
                               Math.sqrt(originX * originX + Math.pow(folder.height - originY, 2)),
                               Math.sqrt(Math.pow(folder.width - originX, 2) + Math.pow(folder.height - originY, 2)))
            revealRadius = originSize / 2 + (far + Theme.paddingLarge - originSize / 2) * Motion.outCubic(p)
        }
        folderScale.xScale = s
        folderScale.yScale = s
        folderShift.y = shift
        folder.opacity = opacity
        if (homeGrid) {
            var back = Motion.outCubic(p)
            homeScale.xScale = 1 - 0.06 * back
            homeScale.yScale = 1 - 0.06 * back
            homeGrid.opacity = 1 - 0.45 * back
        }
        if (opening && cascade && grid)
            applyCascade(p)
    }

    // The apps ripple in from the origin: each one scales up from 0.6 with a small spring, later the further
    // it is from the icon
    function applyCascade(p) {
        var duration = openDuration * speed * timeScale
        var children = grid.contentItem.children
        if (cascadeItems.length === 0 || cascadeItems.length < children.length) {
            var known = cascadeItems
            var farthest = 1
            for (var i = 0; i < children.length; i++) {
                var item = children[i]
                if (item.objectName !== "EditableGridDelegate_contentItem")
                    continue
                var seen = false
                for (var k = 0; k < known.length; k++)
                    seen = seen || known[k].item === item
                if (seen)
                    continue
                var centre = item.mapToItem(folder, item.width / 2, item.height / 2)
                var distance = Math.sqrt(Math.pow(centre.x - originX, 2) + Math.pow(centre.y - originY, 2))
                var scale = itemScale.createObject(motion)
                scale.origin.x = item.width / 2
                scale.origin.y = item.height / 2
                item.transform = scale
                known.push({ "item": item, "scale": scale, "distance": distance })
            }
            for (k = 0; k < known.length; k++)
                farthest = Math.max(farthest, known[k].distance)
            for (k = 0; k < known.length; k++)
                known[k].delay = known[k].distance / farthest * 0.45
            cascadeItems = known
        }
        for (var j = 0; j < cascadeItems.length; j++) {
            var entry = cascadeItems[j]
            var t = Motion.clamp((p - entry.delay) / 0.55, 0, 1)
            var e = Motion.outBack(t, 1.4)
            entry.scale.xScale = 0.6 + 0.4 * e
            entry.scale.yScale = 0.6 + 0.4 * e
            entry.item.opacity = t
        }
    }

    onProgressChanged: if (folder && (openAnimation.running || closeAnimation.running)) apply(progress)

    Component.onCompleted: start()
    Component.onDestruction: {
        restoreHome()
        restoreItems()
    }
}
