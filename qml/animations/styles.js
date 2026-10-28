// The animation styles (docs/ANIMATIONS.md): their names and groups, the length of their opening and closing
// effects in ms at the normal speed, the shader libraries they use (shaders/NAME.glsl, after common.glsl), whether
// they blur their source (blur: it needs mipmaps), and the moments ("open", "close", "load") drawn at half the
// resolution and scaled up (half: the grains, the heaviest shaders, and these styles' loading). Of those, a split
// moment draws its picture at full resolution and only its flying grains at half (split, Effect.qml). A style plays
// a moment only with its shader there (shaders/STYLE-MOMENT.frag); without it, that moment stays stock. Shatter
// opens and closes with its shards (Shards.qml), not with one shader.
.pragma library

var STYLES = [
    { "id": "seaglass", "name": "Seaglass", "group": "Sailfish", "open": 480, "close": 560, "libs": [], "blur": true },
    { "id": "tide", "name": "Tide", "group": "Sailfish", "open": 650, "close": 720, "libs": [] },
    { "id": "aurora", "name": "Northern lights", "group": "Sailfish", "open": 780, "close": 850, "libs": ["aurora"] },
    { "id": "ember", "name": "Ember", "group": "Elements", "open": 620, "close": 880, "libs": ["ember"] },
    { "id": "volt", "name": "Volt", "group": "Elements", "open": 620, "close": 700, "libs": ["volt"] },
    { "id": "frost", "name": "Frost", "group": "Elements", "open": 700, "close": 950, "libs": ["grains", "frost"],
      "blur": true, "half": ["close", "load"] },
    { "id": "shatter", "name": "Shatter", "group": "Extreme", "open": 720, "close": 1000, "libs": [],
      "shards": true },
    { "id": "singularity", "name": "Singularity", "group": "Extreme", "open": 660, "close": 950, "libs": [] },
    { "id": "dust", "name": "Dust", "group": "Extreme", "open": 800, "close": 1050, "libs": ["grains"],
      "half": ["open", "close", "load"] }
]

// the speed setting (0 relaxed, 1 normal, 2 quick) as a factor of the durations
var SPEEDS = [1.35, 1, 0.72]

function find(id) {
    for (var i = 0; i < STYLES.length; i++) {
        if (STYLES[i].id === id)
            return STYLES[i]
    }
    return null
}

// the length of a style's effect for a moment ("open" or "close") at a speed setting, in ms
function duration(id, moment, speed) {
    var style = find(id)
    var factor = SPEEDS[speed] !== undefined ? SPEEDS[speed] : 1
    return style && style[moment] ? Math.round(style[moment] * factor) : 0
}

// the shader libraries of a style
function libs(id) {
    var style = find(id)
    return style ? style.libs : []
}

// a flag of a style ("blur", "shards")
function has(id, flag) {
    var style = find(id)
    return style !== null && style[flag] === true
}

// whether a style draws a moment ("open", "close" or "load") at half the resolution
function half(id, moment) {
    return listed(id, "half", moment)
}

// whether a style draws a moment's picture at full resolution and only its grains at half
function split(id, moment) {
    return listed(id, "split", moment)
}

function listed(id, key, moment) {
    var style = find(id)
    return style !== null && style[key] !== undefined && style[key].indexOf(moment) >= 0
}

// the shaders of every style: [{style, moment}], Shatter's opening and closing left out (its shards)
function shaders() {
    var list = []
    for (var i = 0; i < STYLES.length; i++) {
        var moments = STYLES[i].shards ? ["load"] : ["open", "close", "load"]
        for (var j = 0; j < moments.length; j++)
            list.push({ "style": STYLES[i].id, "moment": moments[j] })
    }
    return list
}

// the style set for a moment ("open", "loading", "close"), Surprise me aside: "stock" or a style
function setting(settings, moment) {
    var chosen = settings[moment] !== "" ? settings[moment] : settings.style
    return find(chosen) ? chosen : "stock"
}

// the style of a moment under the settings (AnimationSettings.qml): "stock" or a style. Surprise me picks another
// style for every moment not set to Stock.
function choose(settings, moment) {
    if (!settings.enabled)
        return "stock"
    var chosen = setting(settings, moment)
    return settings.surprise && settings[moment] !== "stock" ? random(chosen) : chosen
}

// a style other than the given one, for Surprise me
function random(except) {
    var pool = STYLES.filter(function (style) { return style.id !== except })
    return pool[Math.floor(Math.random() * pool.length)].id
}
