// The data widgets' list (docs/WIDGETS.md) as plain functions on its entries: DataWidgets.qml keeps the list in dconf
// with them, and the settings' Restore starter widgets uses them too. An entry is {"id": "w3", "kind": "clock",
// "size": "card", "at": 7}, where at is the widget's slot: its index in the grid's order (grid.js compose). The
// functions change the list they are given. tests/test_store.py runs them with Node.
.pragma library

// the kinds and the sizes each one has, the first being the default
var KINDS = {
    "clock": ["card", "shelf"],
    "status": ["card", "shelf", "panel"],
    "player": ["card", "shelf", "panel"],
    "event": ["card", "shelf", "panel"],
    "weather": ["card", "shelf", "panel"]
}
var KIND_ORDER = ["clock", "status", "player", "event", "weather"]

// the starter widgets: a clock card at the start of the grid, the status as a shelf below it
var STARTERS = [{ "kind": "clock", "size": "card", "at": 0 }, { "kind": "status", "size": "shelf", "at": 7 }]

function sizesOf(kind) {
    return KINDS.hasOwnProperty(kind) ? KINDS[kind] : []
}

// shown by this version: a kind and a size it knows (a later version's entries are kept, but not shown)
function shown(entry) {
    return sizesOf(entry.kind).indexOf(entry.size) >= 0
}

// the entries that make sense, whatever their kind and size
function parse(text) {
    var entries = []
    try {
        var value = JSON.parse(text)
        if (value && value.length !== undefined) {
            for (var i = 0; i < value.length; i++) {
                var entry = value[i]
                if (entry && typeof entry.id === "string" && typeof entry.kind === "string"
                        && typeof entry.size === "string" && typeof entry.at === "number" && entry.at >= 0)
                    entries.push(entry)
            }
        }
    } catch (e) {
    }
    return entries
}

// "w" and a number, one above the highest in the list
function nextId(entries) {
    var n = 0
    for (var i = 0; i < entries.length; i++) {
        var m = /^w(\d+)$/.exec(entries[i].id)
        if (m)
            n = Math.max(n, parseInt(m[1], 10))
    }
    return "w" + (n + 1)
}

// The slots after a move or an add ({id: at}, grid.js slotsOf); an entry without one stays. True when one changed.
function setSlots(entries, slots) {
    var changed = false
    for (var i = 0; i < entries.length; i++) {
        var at = slots[entries[i].id]
        if (at !== undefined && entries[i].at !== at) {
            entries[i].at = at
            changed = true
        }
    }
    return changed
}

// A new widget, in the size asked for if its kind has it. slots holds its slot under "new", and the others' slots,
// which its place may shift. Returns its id.
function add(entries, kind, size, slots) {
    var id = nextId(entries)
    var sizes = sizesOf(kind)
    setSlots(entries, slots)
    entries.push({ "id": id, "kind": kind, "size": sizes.indexOf(size) >= 0 ? size : sizes[0],
                   "at": slots["new"] !== undefined ? slots["new"] : 1e6 })
    return id
}

// True when the widget changed to a size of its kind
function resize(entries, id, size) {
    for (var i = 0; i < entries.length; i++) {
        if (entries[i].id === id && sizesOf(entries[i].kind).indexOf(size) >= 0 && entries[i].size !== size) {
            entries[i].size = size
            return true
        }
    }
    return false
}

// Where the entries are in the grid's order when it has apps enough for every slot, by index: in the order of their
// slots (two on one slot in the list's order, as compose puts them), each at its slot or right after the one before
// it. With fewer apps, the widgets past the end come last in the same order, so slots written from these places keep
// every widget's neighbours.
function places(entries) {
    var sorted = []
    for (var i = 0; i < entries.length; i++)
        sorted.push(i)
    sorted.sort(function (a, b) { return entries[a].at !== entries[b].at ? entries[a].at - entries[b].at : a - b })
    var at = []
    var next = 0
    for (var k = 0; k < sorted.length; k++) {
        var place = Math.max(Math.ceil(entries[sorted[k]].at), next)
        at[sorted[k]] = place
        next = place + 1
    }
    return at
}

// The widget taken out; the others keep their neighbours, as after an add. True when it was there.
function remove(entries, id) {
    var at = places(entries)
    for (var i = 0; i < entries.length; i++) {
        if (entries[i].id === id) {
            var gone = at[i]
            entries.splice(i, 1)
            at.splice(i, 1)
            for (var j = 0; j < entries.length; j++)
                entries[j].at = at[j] > gone ? at[j] - 1 : at[j]
            return true
        }
    }
    return false
}

// An entry put in at its slot: the widgets at that place in the order or after it move one on
function insert(entries, entry) {
    var at = places(entries)
    for (var i = 0; i < entries.length; i++)
        entries[i].at = at[i] >= entry.at ? at[i] + 1 : at[i]
    entries.push(entry)
}

// The starter widgets whose kind is not on the grid, put in at their starter slots; the others keep their
// neighbours. Returns how many were added.
function addStarters(entries) {
    var added = 0
    for (var s = 0; s < STARTERS.length; s++) {
        var there = false
        for (var i = 0; i < entries.length; i++)
            there = there || entries[i].kind === STARTERS[s].kind
        if (!there) {
            insert(entries, { "id": nextId(entries), "kind": STARTERS[s].kind, "size": STARTERS[s].size,
                              "at": STARTERS[s].at })
            added++
        }
    }
    return added
}
