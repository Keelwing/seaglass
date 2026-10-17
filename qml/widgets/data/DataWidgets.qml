// The data widgets of the app grid (docs/WIDGETS.md): live information as glass blocks among the icons. A data widget
// has no folder; it holds a slot (at): its index in the grid's order, which is the model's order with the data widgets
// spliced in (grid.js compose).
//
// Stored in dconf (/apps/seaglass/widgets/list) as a JSON list: [{"id": "w3", "kind": "clock",
// "size": "card", "at": 7}]. With persistent: false (the harness) the list lives in memory only.
import QtQuick 2.6
import Nemo.Configuration 1.0

QtObject {
    id: store

    property bool persistent: true
    property var memory: []
    readonly property var list: persistent ? parse(setting.value) : memory

    // the kinds and the sizes each one has, the first being the default
    readonly property var kinds: ({
        "clock": ["card", "shelf"],
        "status": ["card", "shelf", "panel"],
        "player": ["card", "shelf", "panel"],
        "event": ["card", "shelf", "panel"],
        "weather": ["card", "shelf", "panel"]
    })
    readonly property var kindOrder: ["clock", "status", "player", "event", "weather"]

    property ConfigurationValue setting: ConfigurationValue {
        // in memory mode an unused key, only read, never written
        key: store.persistent ? "/apps/seaglass/widgets/list" : "/apps/seaglass/unused"
        // empty until the list is first written: a fresh install gets the starter widgets (an emptied list is "[]")
        defaultValue: ""
    }

    readonly property bool fresh: persistent && setting.value === ""

    // The starter widgets: a clock card at the start of the grid, the status as a shelf below it
    readonly property var starter: [{ "kind": "clock", "size": "card", "at": 0 },
                                    { "kind": "status", "size": "shelf", "at": 7 }]

    // the starter widgets that are not on the grid, added (the settings' Restore starter widgets uses the same rule)
    function addStarter() {
        var entries = copy()
        for (var s = 0; s < starter.length; s++) {
            var there = false
            for (var i = 0; i < entries.length; i++)
                there = there || entries[i].kind === starter[s].kind
            if (!there)
                entries.push({ "id": nextId(entries), "kind": starter[s].kind, "size": starter[s].size,
                               "at": starter[s].at })
        }
        write(entries)
    }

    function sizesOf(kind) {
        return kinds[kind] || []
    }

    function known(kind) {
        return kinds[kind] !== undefined
    }

    // the entries that make sense (a later version may add kinds: they are kept, but not shown)
    function parse(text) {
        var entries = []
        try {
            var value = JSON.parse(text)
            if (value && value.length !== undefined) {
                for (var i = 0; i < value.length; i++) {
                    var entry = value[i]
                    if (entry && typeof entry.id === "string" && typeof entry.kind === "string"
                            && (entry.size === "card" || entry.size === "shelf" || entry.size === "panel")
                            && typeof entry.at === "number" && entry.at >= 0)
                        entries.push(entry)
                }
            }
        } catch (e) {
        }
        return entries
    }

    function write(entries) {
        if (persistent)
            setting.value = JSON.stringify(entries)
        else
            memory = entries
    }

    function copy() {
        return parse(JSON.stringify(list))
    }

    function entryOf(id) {
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === id)
                return list[i]
        }
        return null
    }

    function nextId(entries) {
        var n = 0
        for (var i = 0; i < entries.length; i++) {
            var m = /^w(\d+)$/.exec(entries[i].id)
            if (m)
                n = Math.max(n, parseInt(m[1], 10))
        }
        return "w" + (n + 1)
    }

    // A new widget: slots ({id: at}, grid.js slotsOf) holds its slot under "new", and the others' slots, which its
    // place may shift; one write. Returns its id.
    function add(kind, size, slots) {
        var entries = copy()
        var id = nextId(entries)
        var sizes = sizesOf(kind)
        for (var i = 0; i < entries.length; i++) {
            if (slots[entries[i].id] !== undefined)
                entries[i].at = slots[entries[i].id]
        }
        entries.push({ "id": id, "kind": kind, "size": sizes.indexOf(size) >= 0 ? size : sizes[0],
                       "at": slots["new"] !== undefined ? slots["new"] : 1e6 })
        write(entries)
        return id
    }

    function remove(id) {
        var entries = copy()
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].id === id) {
                entries.splice(i, 1)
                write(entries)
                return
            }
        }
    }

    function resize(id, size) {
        var entries = copy()
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].id === id && sizesOf(entries[i].kind).indexOf(size) >= 0 && entries[i].size !== size) {
                entries[i].size = size
                write(entries)
                return
            }
        }
    }

    // The slots after a move ({id: at}, grid.js slotsOf): written only when one changed
    function setSlots(slots) {
        var entries = copy()
        var changed = false
        for (var i = 0; i < entries.length; i++) {
            var at = slots[entries[i].id]
            if (at !== undefined && entries[i].at !== at) {
                entries[i].at = at
                changed = true
            }
        }
        if (changed)
            write(entries)
        return changed
    }
}
