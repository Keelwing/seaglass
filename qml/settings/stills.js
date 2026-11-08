// The still frames of the Animations page (AnimationsPage.qml, FrozenFrame.qml): which moment of each style the sheet
// shows, where its band of the screen lies, the size its viewer plays it at, and the line that says what it is. Not
// in styles.js, which the home screen reads when it starts.
.pragma library
.import "../animations/styles.js" as Styles

// what the stills are made from: a hash of the files that shape a still (the shaders, the files that draw them, the
// made-up home screen and this file without this line; tests/test_animation_page.py names them all and says the value
// when one has changed). A sheet kept from an earlier visit is used only with the same KEY
var KEY = "71a1ad4d7b92"
// the sheet's rows: Stock first, then the styles in their groups' order
var ORDER = ["stock", "contour", "fold", "halftone", "seaglass", "tide", "aurora", "ember", "volt", "frost",
             "shatter", "singularity", "dust"]
// per style: open [progress, centre of the band shown on the sheet as an offset from the icon's centre, in heights of
// the screen], close [progress, centre of the band, 0 to 1 of the height], load in seconds, clip the seconds a loading
// run plays. Stock's loading is the busy indicator standing still (0)
var STILLS = {
    "stock": { "open": [0.45, 0.03], "close": [0.60, 0.15], "load": 0, "clip": 1.5 },
    "contour": { "open": [0.22, 0], "close": [0.62, 0.40], "load": 0.8, "clip": 3 },
    "fold": { "open": [0.42, 0.08], "close": [0.40, 0.45], "load": 3.3, "clip": 3 },
    "halftone": { "open": [0.22, 0], "close": [0.36, 0.30], "load": 1.6, "clip": 3.6 },
    "seaglass": { "open": [0.06, 0.05], "close": [0.52, 0.62], "load": 0.8, "clip": 3.8 },
    "tide": { "open": [0.13, 0], "close": [0.50, 0.58], "load": 2.4, "clip": 5 },
    "aurora": { "open": [0.16, -0.07], "close": [0.50, 0.55], "load": 1.6, "clip": 4 },
    "ember": { "open": [0.16, 0], "close": [0.45, 0.60], "load": 4.5, "clip": 4 },
    "volt": { "open": [0.16, -0.08], "close": [0.46, 0.50], "load": 1.6, "clip": 3.3 },
    "frost": { "open": [0.30, 0], "close": [0.48, 0.45], "load": 1.6, "clip": 6 },
    "shatter": { "open": [0.26, 0], "close": [0.35, 0.40], "load": 1.6, "clip": 5.2 },
    "singularity": { "open": [0.16, 0], "close": [0.55, 0.30], "load": 2.4, "clip": 4 },
    "dust": { "open": [0.60, 0], "close": [0.27, 0.36], "load": 3.2, "clip": 4 }
}
// the fixed break of Shatter's stills
var SEED = [0.37, 0.61, 0.13, 0.83]
// the size a run draws at, per style and moment: a rung of RUNGS, default 0.62. STAGE is the largest rung that keeps
// the frame rate on the Jolla Phone's viewer stage, 597 x 1314 (bench page steps=viewer stage=597)
var RUNGS = [1, 0.8, 0.62, 0.46, 0.33]
var STAGE = {
    "contour": { "open": 1, "close": 1 },
    "fold": { "open": 1, "close": 1 },
    "halftone": { "open": 1, "close": 1 },
    "seaglass": { "open": 1, "close": 1 },
    "tide": { "open": 1, "close": 1 },
    "aurora": { "open": 1, "close": 1 },
    "ember": { "open": 1, "close": 1 },
    "volt": { "open": 1, "close": 0.8 },
    "frost": { "open": 1, "close": 1 },
    "shatter": { "open": 1, "close": 1 },
    "singularity": { "open": 1, "close": 1 },
    "dust": { "open": 1, "close": 1 }
}
// one line each for the viewer
var ABOUT = {
    "stock": "The Sailfish way: a fade, a busy indicator and a slide.",
    "contour": "Lines spread like the depth lines of a chart, and the app comes up in steps.",
    "fold": "The window opens and closes like a pleated paper screen.",
    "halftone": "The window comes and goes as a screen of printed dots.",
    "seaglass": "Frosted glass in the ambience's colour.",
    "tide": "A drop, a ripple, and a wave that washes the app away.",
    "aurora": "Curtains of light sweep the app in, and it melts upward into rays.",
    "ember": "A ring of fire opens the app, and it burns away from the bottom.",
    "volt": "Lightning strikes the icon, and the app switches off like an old TV.",
    "frost": "Frost melts from the icon, and the app freezes, cracks and falls as snow.",
    "shatter": "Shards fit together into the app, and it breaks where the finger let go.",
    "singularity": "The app bursts from a white hole and falls into a black one.",
    "dust": "Sand settles into the app, and the wind takes it away."
}

// what a moment shows as in use: "surprise", "stock" or a style. The sheet's heads and the viewer's "In use" read this
function inUse(settings, key) {
    return settings.surprise && settings[key] !== "stock" ? "surprise" : Styles.setting(settings, key)
}

// where a still of a moment ("open", "close", "load") is caught: its progress, or for a loading its seconds
function at(id, moment) {
    var still = STILLS[id]
    return moment === "load" ? still.load : still[moment][0]
}

// the middle of the band of the screen the sheet shows of an opening or closing, 0 to 1 of the height: for an
// opening from the icon's centre (iconCentre)
function band(id, moment, iconCentre) {
    var still = STILLS[id]
    return moment === "open" ? iconCentre + still.open[1] : still.close[1]
}

// the size a style's run draws at, as a fraction of the stage
function rung(id, moment) {
    return STAGE[id] !== undefined && STAGE[id][moment] !== undefined ? STAGE[id][moment] : 0.62
}
