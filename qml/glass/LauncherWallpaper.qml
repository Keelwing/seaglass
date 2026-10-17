// The app grid's background (docs/GLASS.md): the home screen's wallpaper seen through glass (GlassSource.qml,
// GlassPane.qml) instead of the stock dark frost of what is behind. The wallpaper does not move with the grid: only the
// icons rise over it. The hook loads this into a Loader in the launcher layer (LauncherLayer.qml) that provides:
//   edgeLayer  the launcher's EdgeLayer (its exposure while it is pulled up, its visibility)
// (not "layer": every Item has one; not "launcherLayer": the stock file's id, which the binding would hide)
// and reads covers (true: the stock MenuBackground can hide). The glass and the app grid's pager come from
// HomeController.qml, through motion.js; the harness's Loader provides them (glass, pager).
//
// The look (the glass's settings, Settings > Patchmanager > Seaglass):
//   glass  the wallpaper frosts under the grid as it rises, tinted, with a light along its top edge
//   clear  the wallpaper stays sharp, under a dimming veil; open apps' covers fade under the grid's rising edge
//   stock  nothing of ours: the stock background
// The motion moves the wallpaper seen through the glass (GlassSource's zoom, anchor and shift, which its material
// applies), so every glass surface moves with it:
//   depth     the wallpaper eases back (10 % larger) as the grid rises
//   parallax  it follows the pages more slowly than the icons: 6 % (subtle) or 12 % (deep) of the screen's
//             height a page, at most 18 % or 30 % over all of them
//   tilt      it shifts with the phone's tilt (the accelerometer, only while the grid shows)
//   drift     a slow zoom in and out while the grid shows
// With the grid closed there is no motion: the glass is aligned with the home screen.
import QtQuick 2.6
import QtSensors 5.0
import Sailfish.Silica 1.0
import "../core/motion.js" as Motion

Item {
    id: wallpaper

    readonly property Item edgeLayer: parent && parent.edgeLayer !== undefined ? parent.edgeLayer : null
    property Item pager: parent && parent.pager !== undefined ? parent.pager : null
    property Item glass: parent && parent.glass !== undefined ? parent.glass : null

    readonly property string look: glass ? glass.look : "stock"
    // the stock background can hide behind ours
    readonly property bool covers: look !== "stock" && glass !== null && glass.ready
    readonly property bool shown: covers && (edgeLayer ? edgeLayer.visible : true)

    // while the grid is pulled up: 0 hidden .. 1 fully open
    readonly property real exposure: edgeLayer && edgeLayer.maximumExposure > 0
                                     ? Motion.clamp(edgeLayer.absoluteExposure / edgeLayer.maximumExposure, 0, 1)
                                     : 1
    readonly property real eased: Motion.outCubic(exposure)
    // down the pages: 0 the first .. 1 the last
    readonly property real pageProgress: {
        if (!pager)
            return 0
        var range = pager.contentHeight - pager.height
        return range > 0 ? Motion.clamp((pager.contentY - pager.originY) / range, 0, 1) : 0
    }
    // the pages of the grid (the pager's content, a screen each)
    readonly property real pages: pager && pager.height > 0 ? Math.max(1, pager.contentHeight / pager.height) : 1
    // How much larger the wallpaper is seen with the grid open: room for the parallax's travel (so much of the
    // screen's height a page, up to a limit), the depth, and the tilt's shift on both sides
    readonly property real travel: !glass || glass.parallax === 0 ? 0
                                   : glass.parallax === 2 ? Math.min(0.30, 0.12 * (pages - 1))
                                   : Math.min(0.18, 0.06 * (pages - 1))
    readonly property real depthZoom: glass && glass.depth ? 0.10 : 0
    // the tilt's reach: three paddings on the phone's screen, less on a smaller one (the settings' preview)
    readonly property real tiltLimit: Theme.paddingLarge * 3
                                      * (viewport ? Math.min(1, Math.max(viewport.width, viewport.height)
                                                                / Math.max(Screen.width, Screen.height)) : 1)
    readonly property real tiltRoom: glass && glass.tilt && viewport && viewport.height > 0
                                     ? 2 * tiltLimit / viewport.height : 0
    property real driftZoom: 1
    // the display, as the app grid's controller knows it (on without it: the harness, the settings' preview). The glass
    // is read first: motion.js's home does not notify, and the glass comes from it, so the binding wakes up then.
    readonly property bool displayOn: glass !== null && Motion.home && Motion.home.displayOn !== undefined
                                      ? Motion.home.displayOn : true
    // the point the wallpaper grows around, as a part of the screen's height. With parallax it runs down the screen
    // with the pages, so that the picture moves by the travel (the depth's extra room stays split above and below);
    // without, its middle. The tilt's room is kept above and below it.
    readonly property real anchorFraction: {
        var grow = Math.max(depthZoom, travel)
        if (grow + tiltRoom <= 0)
            return 0.5
        return (tiltRoom / 2 + (grow - travel) / 2 + travel * (travel > 0 ? pageProgress : 0.5)) / (grow + tiltRoom)
    }
    readonly property Item viewport: edgeLayer && edgeLayer.parent ? edgeLayer.parent : parent

    function faded(color, amount) {
        return Qt.rgba(color.r, color.g, color.b, color.a * amount)
    }

    anchors.fill: parent
    visible: covers

    GlassPane {
        anchors.fill: parent
        glass: wallpaper.glass
        frost: wallpaper.look === "glass" ? wallpaper.eased : 0
        color: !wallpaper.glass ? "transparent"
               : wallpaper.look === "glass" ? wallpaper.faded(wallpaper.glass.tintColor(0), wallpaper.eased)
               : Theme.rgba("black", wallpaper.glass.dim * wallpaper.eased)
        edgeHeight: wallpaper.look === "clear" ? Theme.itemSizeLarge : 0
        edgeLight: wallpaper.look === "glass" && wallpaper.glass !== null && wallpaper.glass.edgeLight
    }

    // The frame's motion: larger by the depth or the parallax's room as the grid opens, around a point that runs
    // down the screen with the pages (the parallax), or its centre without parallax
    Binding {
        target: wallpaper.glass
        when: wallpaper.glass !== null && wallpaper.covers
        property: "exposure"
        value: wallpaper.exposure
    }

    Binding {
        target: wallpaper.glass
        when: wallpaper.glass !== null && wallpaper.covers
        property: "viewport"
        value: wallpaper.viewport
    }

    Binding {
        target: wallpaper.glass
        when: wallpaper.glass !== null && wallpaper.covers
        property: "zoom"
        value: (1 + (Math.max(wallpaper.depthZoom, wallpaper.travel) + wallpaper.tiltRoom) * wallpaper.eased)
               * (1 + (wallpaper.driftZoom - 1) * wallpaper.eased)
    }

    Binding {
        target: wallpaper.glass
        when: wallpaper.glass !== null && wallpaper.covers && wallpaper.viewport !== null
        property: "anchor"
        value: Qt.point(wallpaper.viewport.width / 2, wallpaper.viewport.height * wallpaper.anchorFraction)
    }

    Binding {
        target: wallpaper.glass
        when: wallpaper.glass !== null && wallpaper.covers
        property: "shift"
        // no room is kept for the tilt once it is off: no shift either
        value: wallpaper.tiltRoom > 0 ? Qt.point(tiltShift.x * wallpaper.eased, tiltShift.y * wallpaper.eased)
                                      : Qt.point(0, 0)
    }

    // Tilt: the phone's tilt from the accelerometer, smoothed, a few pixels of shift
    QtObject {
        id: tiltShift

        property real x: 0
        property real y: 0
    }

    Accelerometer {
        // the launcher layer stays visible under apps: the sensor runs only while the grid is out and the display on
        active: wallpaper.glass !== null && wallpaper.glass.tilt && wallpaper.shown && wallpaper.exposure > 0
                && Qt.application.active && wallpaper.displayOn
        dataRate: 25
        onReadingChanged: {
            // gravity in m/s²: about ±10 on the axis the phone leans on; a low-pass filter takes the shake out
            var limit = wallpaper.tiltLimit
            var x = Motion.clamp(reading.x / 6, -1, 1) * limit
            var y = Motion.clamp((reading.y - 6) / 6, -1, 1) * limit
            var nx = tiltShift.x + (x - tiltShift.x) * 0.15
            var ny = tiltShift.y + (y - tiltShift.y) * 0.15
            // every change draws all the glass again: a phone held still (the sensor's noise) changes nothing
            if (Math.abs(nx - tiltShift.x) >= 0.5 || Math.abs(ny - tiltShift.y) >= 0.5) {
                tiltShift.x = nx
                tiltShift.y = ny
            }
        }
    }

    // Drift: a slow zoom in and out while the grid shows
    SequentialAnimation {
        running: wallpaper.glass !== null && wallpaper.glass.drift && wallpaper.shown && wallpaper.exposure > 0
                 && Qt.application.active && wallpaper.displayOn
        loops: Animation.Infinite
        onRunningChanged: if (!running) wallpaper.driftZoom = 1

        NumberAnimation { target: wallpaper; property: "driftZoom"; from: 1.0; to: 1.08; duration: 14000; easing.type: Easing.InOutSine }
        NumberAnimation { target: wallpaper; property: "driftZoom"; from: 1.08; to: 1.0; duration: 14000; easing.type: Easing.InOutSine }
    }

    // With Debug log on: what the motion is made of, once a second while the grid shows, when it changed
    Timer {
        property string last

        interval: 1000
        repeat: true
        // the grid's exposure first: motion.js's home does not notify, so the binding must hang on something that does
        running: wallpaper.exposure > 0 && wallpaper.edgeLayer !== null && Motion.home !== null
                 && Motion.home !== undefined && Motion.home.debug === true
        onTriggered: {
            var g = wallpaper.glass
            var line = JSON.stringify({
                "look": wallpaper.look, "covers": wallpaper.covers, "shown": wallpaper.shown,
                "exposure": Math.round(wallpaper.exposure * 100) / 100,
                "absolute": wallpaper.edgeLayer ? Math.round(wallpaper.edgeLayer.absoluteExposure) : -1,
                "maximum": wallpaper.edgeLayer ? Math.round(wallpaper.edgeLayer.maximumExposure) : -1,
                "pager": wallpaper.pager !== null,
                "contentY": wallpaper.pager ? Math.round(wallpaper.pager.contentY - wallpaper.pager.originY) : -1,
                "contentHeight": wallpaper.pager ? Math.round(wallpaper.pager.contentHeight) : -1,
                "pagerHeight": wallpaper.pager ? Math.round(wallpaper.pager.height) : -1,
                "pages": Math.round(wallpaper.pages * 100) / 100,
                "progress": Math.round(wallpaper.pageProgress * 100) / 100,
                "travel": wallpaper.travel, "depth": wallpaper.depthZoom,
                "tiltRoom": Math.round(wallpaper.tiltRoom * 1000) / 1000,
                "zoom": g ? Math.round(g.zoom * 1000) / 1000 : -1,
                "anchor": g ? [Math.round(g.anchor.x), Math.round(g.anchor.y)] : [],
                "shift": g ? [Math.round(g.shift.x), Math.round(g.shift.y)] : [],
                "viewport": wallpaper.viewport ? [Math.round(wallpaper.viewport.width),
                                                  Math.round(wallpaper.viewport.height)] : [],
                "ready": g ? g.ready : false, "picture": g ? g.pictureKind : "",
                "pictureLoaded": g ? g.picture !== null : false, "home": g ? g.home !== null : false,
                "frameParent": g ? g.frameParent !== null : false,
                // the motion as the material gets it (the frame's coordinates, 0 .. 1)
                "motion": g ? [Math.round(g.motionZoom * 1000) / 1000, Math.round(g.anchorU * 1000) / 1000,
                               Math.round(g.anchorV * 1000) / 1000, Math.round(g.shiftU * 1000) / 1000,
                               Math.round(g.shiftV * 1000) / 1000] : [] })
            var debug = Motion.home && Motion.home.debug === true
            if (debug && line !== last) {
                last = line
                console.log("seaglass: wallpaper", line)
            }
        }
    }

    // The glass and the pager come with HomeController.qml, which may be made after this: look for them for a
    // minute (without the controller there is nothing to find)
    Timer {
        property int tries

        interval: 500
        repeat: true
        running: (wallpaper.pager === null || wallpaper.glass === null) && tries < 120
        onTriggered: {
            tries++
            if (Motion.home && Motion.home.pager && !wallpaper.pager)
                wallpaper.pager = Motion.home.pager
            if (Motion.home && Motion.home.glass && !wallpaper.glass)
                wallpaper.glass = Motion.home.glass
        }
    }
}
