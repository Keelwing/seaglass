// State shared by the app grid and an opening folder (one per QML engine: .pragma library). HomeController.qml notes
// where a folder is opened from (its icon, or its widget tile, in scene coordinates) and itself (for the depth effect);
// FolderMotion.qml reads them when the folder appears.
.pragma library

// {x, y, width, height, radius} in scene coordinates, or null
var origin = null
// HomeController.qml, or null
var home = null

var STYLES = ["zoom", "spring", "reveal", "slide", "fade"]

function setOrigin(rect) {
    origin = rect
}

function takeOrigin() {
    var rect = origin
    origin = null
    return rect
}

// where an app opens from (the icon or cover tapped): {x, y, width, height} in scene coordinates and when
// (Date.now()), for the opening effects (animations/AnimationController.qml)
var appOrigin = null

function setAppOrigin(rect) {
    appOrigin = rect ? { "x": rect.x, "y": rect.y, "width": rect.width, "height": rect.height, "time": Date.now() }
                     : null
}

// the origin noted at most maxAge ms ago, once; else null
function takeAppOrigin(maxAge) {
    var rect = appOrigin
    appOrigin = null
    return rect && Date.now() - rect.time <= maxAge ? rect : null
}

// the window an app's own close gesture (a swipe down from the top) is closing: {id, time}, or null. Its cover then
// closes with it in the switcher without an effect of its own (SwitcherController.qml)
var closingWindow = null

function noteWindowClosing(id) {
    closingWindow = id ? { "id": id, "time": Date.now() } : null
}

function windowJustClosed(id) {
    return closingWindow !== null && closingWindow.id === id && Date.now() - closingWindow.time < 3000
}

// SwitcherController.qml, or null: the covers, for the opening effects
var switcher = null

function setSwitcher(controller) {
    switcher = controller
}

function setHome(controller) {
    home = controller
}

function homeGrid() {
    return home && home.grid ? home.grid : null
}

// Robert Penner's back easing with a configurable overshoot: a settle with a small spring
function outBack(t, overshoot) {
    var s = overshoot === undefined ? 1.70158 : overshoot
    t = t - 1
    return t * t * ((s + 1) * t + s) + 1
}

function outCubic(t) {
    t = t - 1
    return t * t * t + 1
}

function inCubic(t) {
    return t * t * t
}

function clamp(value, low, high) {
    return Math.max(low, Math.min(high, value))
}
