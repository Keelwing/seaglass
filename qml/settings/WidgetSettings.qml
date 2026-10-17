// The data widgets' options (the widgets themselves are DataWidgets.qml's list)
import QtQuick 2.6
import Nemo.Configuration 1.0

ConfigurationGroup {
    path: "/apps/seaglass/widgets"

    readonly property var keys: ["show", "clockFace", "clockAlarm", "statusSwitches", "playerIdle", "playerArt",
                                 "eventDays", "eventPrivate", "eventAllDay", "weatherFeels", "weatherForecast"]

    property bool show: true
    property string clockFace: "digital"
    property bool clockAlarm: true
    property bool statusSwitches: true
    property string playerIdle: "last"
    property bool playerArt: true
    // the desktop entry of the last MPRIS player, for the idle face's play button (kept by the home screen)
    property string lastPlayer
    property int eventDays: 6
    property bool eventPrivate
    property bool eventAllDay: true
    property bool weatherFeels: true
    property string weatherForecast: "auto"
    // the widgets on the grid (DataWidgets.qml): empty until the first ones are placed, "[]" once emptied
    property string list: ""

    // the starter widgets that are not on the grid, added (as DataWidgets.addStarter on the home screen)
    function restoreStarter() {
        var entries = []
        try {
            entries = JSON.parse(list || "[]") || []
        } catch (e) {
        }
        var starter = [{ "kind": "clock", "size": "card", "at": 0 }, { "kind": "status", "size": "shelf", "at": 7 }]
        var n = 0
        for (var i = 0; i < entries.length; i++) {
            var m = /^w(\d+)$/.exec(entries[i].id)
            if (m)
                n = Math.max(n, parseInt(m[1], 10))
        }
        for (var s = 0; s < starter.length; s++) {
            var there = false
            for (var j = 0; j < entries.length; j++)
                there = there || entries[j].kind === starter[s].kind
            if (!there)
                entries.push({ "id": "w" + (++n), "kind": starter[s].kind, "size": starter[s].size, "at": starter[s].at })
        }
        list = JSON.stringify(entries)
    }
}
