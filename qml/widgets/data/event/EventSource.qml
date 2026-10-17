// The Next event widget's source (docs/WIDGETS.md): the coming events from the calendar, through
// org.nemomobile.calendar.lightweight's CalendarEventsModel, as the Events view's calendar widget
// (Sailfish/Calendar/CalendarWidget.qml): past events left out, up to six. Events open in the Calendar through
// com.jolla.calendar.ui, as from the Events view. Loaded by DataSources.qml; when the module is missing, Next event is
// not offered.
//   live       the app grid is on screen: the relative times tick once a minute only then
//   demo       sample values (the harness): made-up events, never the phone's calendar
//   demoState  with "empty": no events
//   days       how far ahead: 0 today only, else through the end of the day that many days away (at most 6, so
//              that no weekday name comes twice)
//   allDay     all-day events too
import QtQuick 2.6
import org.nemomobile.calendar.lightweight 1.0
import Nemo.Time 1.0
import Nemo.DBus 2.0

// an Item, not a QtObject: Qt 5's Loader does not load non-visual root objects
Item {
    id: source

    property bool live: true
    property bool demo
    property string demoState
    property int days: 6
    property bool allDay: true

    readonly property date now: demo ? demoNow : wallClock.time
    // the events, soonest first: [{key, title, location, start, end, allDay, color, cancelled}]
    readonly property var events: demo ? demoEvents() : found
    // how many events there are in the range, shown or not
    readonly property int total: demo ? events.length : calendarModel ? calendarModel.totalCount : 0
    readonly property date demoNow: new Date(2026, 9, 15, 9, 41)

    // the last event or day asked for (the harness checks it)
    property string lastAction
    property var found: []
    // the phone's CalendarEventsModel (the Instantiator's object below), never made in the harness: no one's events in
    // a sample
    property QtObject calendarModel: null
    // a turn after loading: DataSources.qml sets demo once the source is made, so the model waits for it
    property bool started
    // the day the model counts from; moved on at midnight and when the model's answer expires (the stock rule)
    property date modelDate: new Date()

    visible: false

    function dayStart(date) {
        return new Date(date.getFullYear(), date.getMonth(), date.getDate())
    }

    function addDays(date, n) {
        var d = new Date(date.getTime())
        d.setDate(d.getDate() + n)
        return d
    }

    function demoEvents() {
        if (demoState.indexOf("empty") >= 0)
            return []
        var today = dayStart(demoNow)
        function at(dayOffset, hours, minutes) {
            var d = addDays(today, dayOffset)
            d.setHours(hours, minutes, 0, 0)
            return d
        }
        var list = [
            { "key": "demo-1", "title": "Design review", "location": "Room 4", "start": at(0, 10, 0),
              "end": at(0, 11, 0), "allDay": false, "color": "#3d9cf0", "cancelled": false },
            { "key": "demo-2", "title": "Team lunch", "location": "Harbour café", "start": at(0, 12, 30),
              "end": at(0, 13, 30), "allDay": false, "color": "#e8a33d", "cancelled": false },
            { "key": "demo-3", "title": "Swimming", "location": "", "start": at(0, 18, 0),
              "end": at(0, 19, 0), "allDay": false, "color": "#4fc27a", "cancelled": false },
            { "key": "demo-4", "title": "Name day", "location": "", "start": at(1, 0, 0),
              "end": at(2, 0, 0), "allDay": true, "color": "#c86ad8", "cancelled": false },
            { "key": "demo-5", "title": "Dentist", "location": "Main street 12", "start": at(2, 8, 15),
              "end": at(2, 9, 0), "allDay": false, "color": "#3d9cf0", "cancelled": false }
        ]
        var shown = []
        var end = rangeEnd(demoNow)
        for (var i = 0; i < list.length; i++) {
            if ((allDay || !list[i].allDay) && list[i].start < end)
                shown.push(list[i])
        }
        return shown
    }

    // the end of the range from a day
    function rangeEnd(date) {
        return addDays(dayStart(date), Math.max(0, Math.min(6, days)) + 1)
    }

    function collect() {
        var list = []
        for (var i = 0; i < rows.count; i++) {
            var row = rows.objectAt(i)
            if (row)
                list.push({ "key": row.instance, "title": row.title, "location": row.location, "start": row.start,
                            "end": row.end, "allDay": row.wholeDay, "color": row.tint, "cancelled": row.cancelled })
        }
        found = list
    }

    // An event in the Calendar (as the Events view: viewEventByIdentifier with its start)
    function open(key) {
        lastAction = "event " + key
        if (demo)
            return
        for (var i = 0; i < found.length; i++) {
            if (found[i].key === key) {
                calendar.call("viewEventByIdentifier", [key, Qt.formatDateTime(found[i].start, Qt.ISODate)])
                return
            }
        }
    }

    // The Calendar on today
    function openToday() {
        lastAction = "today"
        if (demo)
            return
        var noon = dayStart(new Date())
        noon.setHours(12)
        calendar.call("viewDate", [Qt.formatDateTime(noon, Qt.ISODate)])
    }

    WallClock {
        id: wallClock

        enabled: source.live && !source.demo
        updateFrequency: WallClock.Minute
        onTimeChanged: {
            if (!source.calendarModel)
                return
            var expiry = source.calendarModel.expiryDate
            if (!isNaN(expiry.getTime()) && (time < source.calendarModel.creationDate || expiry <= time
                                              || source.modelDate.getDate() !== time.getDate()
                                              || source.modelDate.getMonth() !== time.getMonth()
                                              || source.modelDate.getFullYear() !== time.getFullYear()))
                source.modelDate = time
        }
    }

    Timer {
        interval: 0
        running: true
        onTriggered: source.started = true
    }

    Instantiator {
        model: source.started && !source.demo ? 1 : 0

        CalendarEventsModel {
            startDate: source.modelDate
            endDate: source.rangeEnd(source.modelDate)
            filterMode: CalendarEventsModel.FilterPast
            contentType: source.allDay ? CalendarEventsModel.ContentAll : CalendarEventsModel.ContentEvents
            eventDisplayTime: 900
            eventLimit: 6
        }

        onObjectAdded: source.calendarModel = object
        onObjectRemoved: source.calendarModel = null
    }

    // the model's rows as plain values (the roles of the stock CalendarWidgetDelegate.qml, and the location)
    Instantiator {
        id: rows

        model: source.calendarModel

        QtObject {
            readonly property string instance: model.instanceId || ""
            readonly property string title: model.displayLabel || ""
            readonly property string location: model.location || ""
            readonly property var start: model.startTime
            readonly property var end: model.endTime
            readonly property bool wholeDay: model.allDay
            readonly property string tint: model.color ? "" + model.color : ""
            readonly property bool cancelled: model.cancelled
            onInstanceChanged: collectTimer.restart()
            onTitleChanged: collectTimer.restart()
            onStartChanged: collectTimer.restart()
            onEndChanged: collectTimer.restart()
            onCancelledChanged: collectTimer.restart()
        }

        onObjectAdded: collectTimer.restart()
        onObjectRemoved: collectTimer.restart()
    }

    // one collection after a burst of changes
    Timer {
        id: collectTimer

        interval: 0
        onTriggered: source.collect()
    }

    DBusInterface {
        id: calendar

        service: "com.jolla.calendar.ui"
        path: "/com/jolla/calendar/ui"
        iface: "com.jolla.calendar.ui"
    }
}
