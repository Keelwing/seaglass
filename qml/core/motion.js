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
