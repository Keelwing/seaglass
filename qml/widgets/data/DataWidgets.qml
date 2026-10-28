// The data widgets of the app grid (docs/WIDGETS.md): live information as glass blocks among the icons. A data widget
// has no folder; it holds a slot (at): its index in the grid's order, which is the model's order with the data widgets
// spliced in (grid.js compose).
//
// Stored in dconf (/apps/seaglass/widgets/list) as a JSON list: [{"id": "w3", "kind": "clock",
// "size": "card", "at": 7}]. With persistent: false (the harness) the list lives in memory only. What a change does
// to the list is in store.js.
import QtQuick 2.6
import Nemo.Configuration 1.0
import "store.js" as Store

QtObject {
    id: store

    property bool persistent: true
    property var memory: []
    readonly property var list: persistent ? Store.parse(setting.value) : memory
    readonly property var kindOrder: Store.KIND_ORDER

    property ConfigurationValue setting: ConfigurationValue {
        // in memory mode an unused key, only read, never written
        key: store.persistent ? "/apps/seaglass/widgets/list" : "/apps/seaglass/unused"
        // empty until the list is first written: a fresh install gets the starter widgets (an emptied list is "[]")
        defaultValue: ""
    }

    readonly property bool fresh: persistent && setting.value === ""

    // the kind's sizes, the first being the default
    function sizesOf(kind) {
        return Store.sizesOf(kind)
    }

    // an entry this version draws (a later version's kinds and sizes are kept, but not shown)
    function shown(entry) {
        return Store.shown(entry)
    }

    function write(entries) {
        if (persistent)
            setting.value = JSON.stringify(entries)
        else
            memory = entries
    }

    function copy() {
        return Store.parse(JSON.stringify(list))
    }

    // the starter widgets that are not on the grid, added (the settings' Restore starter widgets does the same)
    function addStarter() {
        var entries = copy()
        Store.addStarters(entries)
        write(entries)
    }

    // A new widget: slots ({id: at}, grid.js slotsOf) holds its slot under "new", and the others' slots, which its
    // place may shift; one write. Returns its id.
    function add(kind, size, slots) {
        var entries = copy()
        var id = Store.add(entries, kind, size, slots)
        write(entries)
        return id
    }

    // the others keep their neighbours
    function remove(id) {
        var entries = copy()
        if (Store.remove(entries, id))
            write(entries)
    }

    function resize(id, size) {
        var entries = copy()
        if (Store.resize(entries, id, size))
            write(entries)
    }

    // The slots after a move ({id: at}, grid.js slotsOf): written only when one changed
    function setSlots(slots) {
        var entries = copy()
        var changed = Store.setSlots(entries, slots)
        if (changed)
            write(entries)
        return changed
    }
}
