// How each folder shows on the home screen ("icon", "card", "shelf", "panel"), by folder title.
//
// Stored in dconf (/apps/seaglass/folder_types) as a JSON object from title to type; folders have no other
// stable id in QML. Only widget types are stored: a folder that is not in it is an icon. With persistent: false
// (the harness) the types live in memory only.
import QtQuick 2.6
import Nemo.Configuration 1.0
import "../../core/grid.js" as Grid

QtObject {
    id: store

    property bool persistent: true
    property var memory: ({})
    readonly property var map: persistent ? parse(setting.value) : memory

    property ConfigurationValue setting: ConfigurationValue {
        // in memory mode an unused key, only read, never written
        key: store.persistent ? "/apps/seaglass/folder_types" : "/apps/seaglass/unused"
        defaultValue: "{}"
    }

    function parse(text) {
        try {
            var types = JSON.parse(text)
            return types && typeof types === "object" ? types : {}
        } catch (e) {
            return {}
        }
    }

    function typeOf(title) {
        var type = map[title]
        return Grid.isWidgetType(type) ? type : "icon"
    }

    function write(types) {
        if (persistent)
            setting.value = JSON.stringify(types)
        else
            memory = types
    }

    function copy() {
        return parse(JSON.stringify(map))
    }

    // (the locals are not called map: a "var map" would hide the property in the whole function)
    function setType(title, type) {
        var next = copy()
        if (Grid.isWidgetType(type))
            next[title] = type
        else
            delete next[title]
        write(next)
    }

    // a widget folder was renamed: its type moves along
    function rename(from, to) {
        if (from === to || !(from in map))
            return
        var next = copy()
        next[to] = next[from]
        delete next[from]
        write(next)
    }
}
