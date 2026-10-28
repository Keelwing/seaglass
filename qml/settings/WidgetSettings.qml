// The data widgets' options (the widgets themselves are DataWidgets.qml's list)
import QtQuick 2.6
import Nemo.Configuration 1.0
import "../widgets/data/store.js" as Store

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

    // the starter widgets that are not on the grid, added as on a fresh install (store.js); the others keep their
    // neighbours
    function restoreStarter() {
        var entries = Store.parse(list || "[]")
        Store.addStarters(entries)
        list = JSON.stringify(entries)
    }
}
