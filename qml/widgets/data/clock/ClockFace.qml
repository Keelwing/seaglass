// The clock widget's face (docs/WIDGETS.md), drawn inside DataWidget.qml's glass.
//   source     ClockSource.qml (time, twentyFour, nextAlarm), or null
//   size       card | shelf
//   style      digital | analogue (not "face": the id would win over a property of that name)
//   showAlarm  the next alarm as a chip
// A tap on the widget opens the Clock app (activate()).
import QtQuick 2.6
import Sailfish.Silica 1.0

Item {
    id: face

    property Item source
    property string size: "card"
    property string style: "digital"
    property bool showAlarm: true
    property bool editMode

    signal request(string what, string argument)

    readonly property bool shelf: size === "shelf"
    readonly property bool analogue: style === "analogue"
    readonly property date time: source ? source.time : new Date()
    readonly property bool twentyFour: source ? source.twentyFour : true
    readonly property var alarm: source && showAlarm ? source.nextAlarm : null
    readonly property real pad: Theme.paddingLarge

    function activate() {
        request("app", "/usr/share/applications/jolla-clock.desktop")
    }

    // no controls of its own: a tap anywhere opens the Clock (DataWidget.qml's handle)
    function pressAt(x, y) {
        return false
    }

    function release() {
    }

    function tapAt(x, y) {
        return false
    }

    function pad2(n) {
        return n < 10 ? "0" + n : "" + n
    }

    // the time without a day period: 24 hours as the locale writes it, 12 hours as the stock clock (h:mm)
    function clockText(t) {
        if (twentyFour)
            return Format.formatDate(t, Formatter.TimeValueTwentyFourHours)
        var hours = t.getHours() % 12
        return (hours === 0 ? 12 : hours) + ":" + pad2(t.getMinutes())
    }

    function periodText(t) {
        return twentyFour ? "" : (t.getHours() < 12 ? Qt.locale().amText : Qt.locale().pmText)
    }

    function capitalized(text) {
        return text.length > 0 ? text.charAt(0).toUpperCase() + text.slice(1) : text
    }

    readonly property string weekday: capitalized(Format.formatDate(time, Formatter.WeekdayNameStandalone))
    // the day and the month: the locale's long date without its year ("15 October", "október 15.")
    readonly property string dateText: Format.formatDate(time, Formatter.DateLong)
                                       .replace(/^\s*\d{4}\.?\s*/, "").replace(/[\s,]*\d{4}\.?\s*$/, "")
    // the alarm: its time, with the weekday when it is more than a day away
    readonly property string alarmText: {
        if (!alarm)
            return ""
        var at = clockText(alarm) + (twentyFour ? "" : " " + periodText(alarm))
        if (alarm.getTime() - time.getTime() > 24 * 3600 * 1000)
            at = Qt.formatDate(alarm, "ddd") + " " + at
        return at
    }

    TextMetrics {
        id: timeMetrics

        font.family: Theme.fontFamilyHeading
        font.pixelSize: 100
        text: face.clockText(face.time)
    }

    // ---- digital ----

    Item {
        id: digital

        visible: !face.analogue
        anchors.fill: parent

        // card: the weekday, the time large, the date; the alarm at the bottom
        Column {
            visible: !face.shelf
            width: parent.width - 2 * face.pad
            x: face.pad
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: alarmChip.visible ? -alarmChip.height / 2 : 0
            spacing: Theme.paddingSmall

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.highlightColor
                text: face.weekday
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter

                Label {
                    id: bigTime

                    // as large as fits the card's width
                    font.pixelSize: Math.max(Theme.fontSizeLarge,
                                             Math.min(Theme.fontSizeHuge * 1.45,
                                                      100 * (face.width - 2 * face.pad - period.width)
                                                      / Math.max(1, timeMetrics.width)))
                    font.family: Theme.fontFamilyHeading
                    renderType: Text.NativeRendering
                    color: Theme.primaryColor
                    text: face.clockText(face.time)
                }

                Label {
                    id: period

                    anchors.baseline: bigTime.baseline
                    leftPadding: text ? Theme.paddingSmall : 0
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.secondaryColor
                    text: face.periodText(face.time)
                }
            }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                text: face.dateText
            }
        }

        // shelf: the time on the left, the day and the alarm on the right
        Row {
            visible: face.shelf
            x: face.pad
            height: parent.height
            spacing: Theme.paddingLarge

            Row {
                anchors.verticalCenter: parent.verticalCenter

                Label {
                    id: shelfTime

                    font.pixelSize: Math.min(Theme.fontSizeHuge * 1.3, face.height * 0.6)
                    font.family: Theme.fontFamilyHeading
                    renderType: Text.NativeRendering
                    color: Theme.primaryColor
                    text: face.clockText(face.time)
                }

                Label {
                    anchors.baseline: shelfTime.baseline
                    leftPadding: text ? Theme.paddingSmall : 0
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.secondaryColor
                    text: face.periodText(face.time)
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: face.width - x - 2 * face.pad
                spacing: Theme.paddingSmall / 2

                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.highlightColor
                    text: face.weekday
                }

                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.secondaryColor
                    text: face.dateText
                }

                AlarmChip {
                    visible: face.alarmText !== ""
                    text: face.alarmText
                }
            }
        }
    }

    // ---- analogue ----

    Item {
        visible: face.analogue
        anchors.fill: parent

        ClockDial {
            id: dial

            readonly property real room: face.shelf ? face.height - 2 * Theme.paddingMedium
                                                    : Math.min(face.width - 2 * face.pad,
                                                               face.height - 2 * face.pad - cardText.height
                                                               - (alarmChip.visible ? alarmChip.height : 0))
            x: face.shelf ? face.pad : (face.width - width) / 2
            y: face.shelf ? (face.height - height) / 2 : face.pad
            width: Math.max(0, room)
            height: width
            time: face.time
        }

        // card: the day under the dial
        Label {
            id: cardText

            visible: !face.shelf
            anchors.top: dial.bottom
            anchors.topMargin: Theme.paddingSmall
            x: face.pad
            width: face.width - 2 * face.pad
            horizontalAlignment: Text.AlignHCenter
            truncationMode: TruncationMode.Fade
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.highlightColor
            text: Qt.formatDate(face.time, "ddd") + " " + face.dateText
        }

        // shelf: the time, the day and the alarm beside the dial
        Column {
            visible: face.shelf
            anchors.verticalCenter: parent.verticalCenter
            x: dial.x + dial.width + Theme.paddingLarge
            width: face.width - x - face.pad
            spacing: Theme.paddingSmall / 2

            Label {
                font.pixelSize: Theme.fontSizeExtraLarge
                font.family: Theme.fontFamilyHeading
                color: Theme.primaryColor
                text: face.clockText(face.time) + (face.twentyFour ? "" : " " + face.periodText(face.time))
            }

            Label {
                width: parent.width
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.highlightColor
                text: face.weekday + " " + face.dateText
            }

            AlarmChip {
                visible: face.alarmText !== ""
                text: face.alarmText
            }
        }
    }

    // the card's alarm, at its bottom
    AlarmChip {
        id: alarmChip

        visible: !face.shelf && face.alarmText !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: face.pad * 0.75
        text: face.alarmText
    }
}
