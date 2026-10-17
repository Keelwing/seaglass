// The clock widget's source (docs/WIDGETS.md): the time, once a minute, the 12 or 24 hour setting, and the next enabled
// alarm. Loaded by DataSources.qml; when a module is missing, the clock is not offered.
//   live   the app grid is on screen: the clock ticks only then
//   demo   sample values (the harness): 9:41 on a Thursday, an alarm at 6:30
import QtQuick 2.6
import Nemo.Time 1.0
import Nemo.Alarms 1.0
import Nemo.Configuration 1.0

// an Item, not a QtObject: Qt 5's Loader does not load non-visual root objects
Item {
    id: source

    property bool live: true
    property bool demo

    readonly property date time: demo ? new Date(2026, 9, 15, 9, 41) : wallClock.time
    readonly property bool twentyFour: demo ? true : timeFormat.value === "24"
    // the next enabled alarm as a Date, or null
    readonly property var nextAlarm: demo ? new Date(2026, 9, 16, 6, 30) : upcoming
    property var upcoming: null

    visible: false

    WallClock {
        id: wallClock

        enabled: source.live && !source.demo
        updateFrequency: WallClock.Minute
        onTimeChanged: source.updateAlarm()
    }

    ConfigurationValue {
        id: timeFormat

        key: "/sailfish/i18n/lc_timeformat24h"
    }

    AlarmsModel {
        id: alarms
    }

    EnabledAlarmsProxyModel {
        id: enabledAlarms

        model: alarms
    }

    // the model has no count: its alarms are read through an Instantiator
    Instantiator {
        id: alarmObjects

        model: source.demo ? null : enabledAlarms

        QtObject {
            readonly property QtObject alarm: model.alarm
            readonly property double trigger: alarm ? alarm.triggerTime : 0
            onTriggerChanged: source.updateAlarm()
        }

        onObjectAdded: source.updateAlarm()
        onObjectRemoved: source.updateAlarm()
    }

    // The earliest coming trigger of an enabled clock alarm (timed schedules it: triggerTime, seconds)
    function updateAlarm() {
        var now = new Date().getTime()
        var best = 0
        for (var i = 0; i < alarmObjects.count; i++) {
            var holder = alarmObjects.objectAt(i)
            var alarm = holder ? holder.alarm : null
            if (!alarm || !alarm.enabled || alarm.countdown)
                continue
            var at = alarm.triggerTime * 1000
            if (at > now && (best === 0 || at < best))
                best = at
        }
        upcoming = best > 0 ? new Date(best) : null
    }
}
