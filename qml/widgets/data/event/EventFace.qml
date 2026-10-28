// The Next event widget's face (docs/WIDGETS.md), drawn inside DataWidget.qml's glass: the day, the next event with its
// calendar's colour, its time ("in 25 min" within the hour, "Now" while it runs), and the events after it.
//   source       EventSource.qml, or null
//   size         card | shelf | panel
//   hideDetails  only the times and the colours, with Busy for each title
//   days         how far ahead the source looks (0: today only), for the empty text
// A tap on an event opens it in the Calendar; anywhere else the Calendar opens on today (activate()). The rows take
// no touches themselves: DataWidget.qml's handle lies over the whole widget and calls pressAt, release and tapAt.
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../faces.js" as Faces

Item {
    id: face

    property Item source
    property string size: "card"
    property bool editMode
    property bool hideDetails
    property int days: 6

    signal request(string what, string argument)

    // the row under the finger, lit while pressed
    property string pressedKey

    readonly property date now: source ? source.now : new Date()
    readonly property var events: source ? source.events : []
    readonly property date todayStart: new Date(now.getFullYear(), now.getMonth(), now.getDate())
    readonly property date tomorrowStart: new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1)
    // by the calendar, as tomorrowStart, not 24 hours on: a day can have 23 or 25 hours
    readonly property date dayAfterStart: new Date(now.getFullYear(), now.getMonth(), now.getDate() + 2)
    // the events still to come today, and the first one at all
    readonly property var todays: {
        var list = []
        for (var i = 0; i < events.length; i++) {
            if (events[i].start < tomorrowStart)
                list.push(events[i])
        }
        return list
    }
    readonly property var first: todays.length > 0 ? todays[0] : (events.length > 0 ? events[0] : null)
    readonly property var second: todays.length > 1 ? todays[1] : null
    readonly property int moreToday: Math.max(0, todays.length - 2)
    readonly property bool restOfDayFree: todays.length === 0
    readonly property string emptyText: days <= 0 ? qsTr("Nothing more today")
                                                  : qsTr("Nothing in the next %1 days").arg(days)
    readonly property real pad: Theme.paddingLarge
    readonly property real barWidth: Math.max(4, Math.round(Theme.paddingSmall * 0.6))

    function capitalized(text) {
        return text.length > 0 ? text.charAt(0).toUpperCase() + text.slice(1) : text
    }

    function weekdayOf(date) {
        return capitalized(Format.formatDate(date, Formatter.WeekdayNameStandalone))
    }

    function dayLabel(date) {
        return date < tomorrowStart ? qsTr("Today")
             : date < dayAfterStart ? qsTr("Tomorrow")
             : weekdayOf(date)
    }

    function titleOf(event) {
        return !event ? "" : hideDetails ? qsTr("Busy") : event.title !== "" ? event.title : qsTr("(Untitled event)")
    }

    function locationOf(event) {
        return event && !hideDetails ? event.location : ""
    }

    function clock(date) {
        return Format.formatDate(date, Formatter.TimeValue)
    }

    // "Now" while it runs, "in 25 min" within the hour, "All day", or its start and end
    function timeOf(event, withDay) {
        if (!event)
            return ""
        var prefix = withDay && event.start >= tomorrowStart ? dayLabel(event.start) + ", " : ""
        if (event.allDay)
            return prefix + qsTr("All day")
        if (event.start <= now && now < event.end)
            return qsTr("Now") + " – " + clock(event.end)
        var minutes = Math.ceil((event.start.getTime() - now.getTime()) / 60000)
        if (minutes > 0 && minutes <= 60)
            return qsTr("in %1 min").arg(minutes)
        // an event that began on an earlier day: from midnight
        var start = event.start < todayStart ? todayStart : event.start
        return prefix + clock(start) + "–" + clock(event.end)
    }

    function soon(event) {
        if (!event || event.allDay)
            return false
        var minutes = (event.start.getTime() - now.getTime()) / 60000
        return (event.start <= now && now < event.end) || (minutes > 0 && minutes <= 60)
    }

    // a short time for a row: its start, or All day
    function startOf(event) {
        return event.allDay ? qsTr("All day") : event.start < todayStart ? clock(todayStart) : clock(event.start)
    }

    function activate() {
        request("calendar", "")
    }

    function controlAt(x, y) {
        return Faces.controlAt(face, x, y)
    }

    // DataWidget.qml: a press on an event lights it (true), elsewhere nothing (false)
    function pressAt(x, y) {
        pressedKey = controlAt(x, y)
        return pressedKey !== ""
    }

    function release() {
        pressedKey = ""
    }

    // a tap: on an event, the event in the Calendar (true); elsewhere false, and the Calendar opens on today
    function tapAt(x, y) {
        var key = controlAt(x, y)
        if (key.indexOf("event:") !== 0)
            return false
        request("event", key.slice(6))
        return true
    }

    // The day: the weekday and a large day number, in the highlight colour; on the card in a row (the number, then
    // the weekday over the month), on the shelf and the panel in a column
    Grid {
        id: day

        readonly property bool inRow: face.size === "card"

        x: face.size === "panel" ? face.pad : face.pad * 0.75
        y: face.size === "shelf" ? (face.height - height) / 2 : face.pad * 0.5
        columns: inRow ? 2 : 1
        columnSpacing: Theme.paddingMedium
        layoutDirection: inRow ? Qt.RightToLeft : Qt.LeftToRight
        verticalItemAlignment: Grid.AlignVCenter

        Column {
            Label {
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.highlightColor
                text: face.weekdayOf(face.now)
            }

            // the month: under the weekday on the card, under the number on the panel
            Label {
                visible: day.inRow
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                text: face.capitalized(Format.formatDate(face.now, Formatter.MonthNameStandalone))
            }
        }

        Column {
            Label {
                font.pixelSize: face.size === "panel" ? Theme.fontSizeHuge * 1.25 : Theme.fontSizeHuge
                font.family: Theme.fontFamilyHeading
                renderType: Text.NativeRendering
                lineHeight: 0.85
                color: Theme.highlightColor
                text: face.now.getDate()
            }

            Label {
                visible: face.size === "panel"
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                text: face.capitalized(Format.formatDate(face.now, Formatter.MonthNameStandalone))
            }
        }
    }

    // ---- the card: the next event under the day, the one after it, and how many more today ----

    Item {
        id: card

        visible: face.size === "card"
        anchors.fill: parent

        Label {
            id: cardFree

            readonly property real roomTop: day.y + day.height + Theme.paddingSmall

            visible: face.restOfDayFree
            x: face.pad * 0.75
            // alone (no event at all), in the middle of the room under the day
            y: face.first ? roomTop : roomTop + Math.max(0, (card.height - roomTop - height) / 2 - face.pad * 0.5)
            width: card.width - 2 * x
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
            text: face.first ? qsTr("No more events today") : face.emptyText
        }

        EventBlock {
            id: cardNext

            visible: face.first !== null
            x: face.pad * 0.5
            y: face.restOfDayFree ? cardFree.y + cardFree.height + Theme.paddingSmall
                                  : day.y + day.height + Theme.paddingMedium
            width: card.width - 2 * x
            host: face
            event: face.first
            lines: 2
        }

        // the event after it, in one line, and "+2 today"
        Column {
            visible: face.second !== null || face.moreToday > 0
            x: face.pad * 0.75
            width: card.width - 2 * x
            anchors.bottom: parent.bottom
            anchors.bottomMargin: face.pad * 0.5

            EventLine {
                visible: face.second !== null
                width: parent.width
                host: face
                event: face.second
            }

            Label {
                visible: face.moreToday > 0
                width: parent.width
                font.pixelSize: Theme.fontSizeTiny
                color: Theme.highlightColor
                text: qsTr("+%1 today").arg(face.moreToday)
            }
        }
    }

    // ---- the shelf: the day, the next event, and the one after it ----

    Item {
        id: shelf

        visible: face.size === "shelf"
        anchors.fill: parent

        readonly property real textX: day.x + day.width + face.pad
        readonly property real half: (width - textX - Theme.paddingMedium) / 2

        Label {
            visible: face.first === null
            x: shelf.textX
            width: shelf.width - x - face.pad
            anchors.verticalCenter: parent.verticalCenter
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.secondaryColor
            text: face.emptyText
        }

        EventBlock {
            visible: face.first !== null
            x: shelf.textX - Theme.paddingSmall
            width: shelf.half
            anchors.verticalCenter: parent.verticalCenter
            host: face
            event: face.first
            lines: 1
            header: face.restOfDayFree ? qsTr("No more events today") : ""
        }

        EventBlock {
            visible: face.second !== null
            x: shelf.textX + shelf.half
            width: shelf.half
            anchors.verticalCenter: parent.verticalCenter
            host: face
            event: face.second
            lines: 1
            dim: true
            footer: face.moreToday > 0 ? qsTr("+%1 today").arg(face.moreToday) : ""
        }
    }

    // ---- the panel: the day, and up to five events under Today, Tomorrow and weekday headings ----

    Item {
        id: panel

        visible: face.size === "panel"
        anchors.fill: parent

        readonly property real textX: Math.max(day.x + day.width, face.width * 0.24) + face.pad
        readonly property real rowHeight: Math.round(Theme.fontSizeSmall * 1.6)
        readonly property real headingHeight: Math.round(Theme.fontSizeExtraSmall * 1.5)
        // headings and events, as many as fit (at most five events)
        readonly property var rows: {
            var list = []
            var room = height - 2 * face.pad * 0.6
            var shown = 0
            var lastDay = ""
            if (face.restOfDayFree && face.first !== null) {
                list.push({ "heading": qsTr("Today") })
                list.push({ "note": qsTr("No more events today") })
                room -= headingHeight + rowHeight
            }
            for (var i = 0; i < face.events.length && shown < 5; i++) {
                var event = face.events[i]
                var label = face.dayLabel(event.start < face.todayStart ? face.todayStart : event.start)
                var need = rowHeight + (label !== lastDay ? headingHeight : 0)
                if (need > room)
                    break
                if (label !== lastDay)
                    list.push({ "heading": label })
                list.push({ "event": event })
                lastDay = label
                room -= need
                shown++
            }
            return list
        }

        Label {
            visible: face.first === null
            x: panel.textX
            width: panel.width - x - face.pad
            anchors.verticalCenter: parent.verticalCenter
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.secondaryColor
            text: face.emptyText
        }

        Column {
            x: panel.textX - Theme.paddingSmall
            y: face.pad * 0.6
            width: panel.width - x - face.pad * 0.5

            Repeater {
                model: face.size === "panel" ? panel.rows : []

                Item {
                    readonly property string key: modelData.event ? "event:" + modelData.event.key : ""

                    width: parent.width
                    height: modelData.heading !== undefined ? panel.headingHeight : panel.rowHeight

                    Label {
                        visible: modelData.heading !== undefined
                        x: Theme.paddingSmall
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Theme.paddingSmall / 2
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.highlightColor
                        text: modelData.heading !== undefined ? modelData.heading : ""
                    }

                    Label {
                        visible: modelData.note !== undefined
                        x: Theme.paddingSmall
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.secondaryColor
                        text: modelData.note !== undefined ? modelData.note : ""
                    }

                    EventLine {
                        visible: modelData.event !== undefined
                        anchors.fill: parent
                        host: face
                        event: modelData.event !== undefined ? modelData.event : null
                        large: true
                    }
                }
            }
        }
    }
}
