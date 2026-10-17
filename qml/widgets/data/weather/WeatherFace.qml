// The Weather widget's face (docs/WIDGETS.md), drawn inside DataWidget.qml's glass: the place, the weather now with its
// icon and temperature, "Feels like", today's high and low, and the next hours or days.
//   source     WeatherSource.qml, or null
//   size       card | shelf | panel
//   showFeels  "Feels like"
//   forecast   auto (the next hours on the shelf, the next days on the panel) | hourly | daily
// Without a location the widget says Set up Weather. A tap anywhere opens the Weather app (activate()).
import QtQuick 2.6
import Sailfish.Silica 1.0

Item {
    id: face

    property Item source
    property string size: "card"
    property bool editMode
    property bool showFeels: true
    property string forecast: "auto"

    signal request(string what, string argument)

    readonly property bool ready: source !== null && source.ready
    readonly property real pad: Theme.paddingLarge
    readonly property bool hourly: forecast === "hourly" || (forecast === "auto" && size === "shelf")
    // the next five hours (from the coming one) or days (from today)
    readonly property var columns: {
        if (!source)
            return []
        var list = []
        var all = hourly ? source.hours : source.daysAhead
        var from = source.now.getTime() - 30 * 60 * 1000
        for (var i = 0; i < all.length && list.length < 5; i++) {
            if (!hourly || all[i].time.getTime() > from)
                list.push(all[i])
        }
        return list
    }
    readonly property var today: source && source.daysAhead.length > 0 ? source.daysAhead[0] : null
    readonly property string temperature: ready ? source.format(source.temperature) : ""
    readonly property string feels: ready && showFeels && source.hasFeelsLike
                                    ? qsTr("Feels like %1").arg(source.format(source.feelsLike)) : ""
    readonly property string highLow: ready && today ? qsTr("H %1 · L %2").arg(source.format(today.high))
                                                                         .arg(source.format(today.low)) : ""
    // older than three hours: when it was updated
    readonly property string staleText: {
        if (!ready || isNaN(source.updated.getTime()))
            return ""
        var hours = Math.floor((source.now.getTime() - source.updated.getTime()) / 3600000)
        return hours >= 3 ? qsTr("Updated %1 h ago").arg(hours) : ""
    }

    function icon(type, large) {
        return type ? "image://theme/" + (large ? "graphic-weather-" : "icon-m-weather-") + type : ""
    }

    // an hour short ("14:00", "2 PM"), a day by its short name ("Today" first)
    function columnLabel(entry, index) {
        if (hourly) {
            if (!source || source.twentyFour)
                return Format.formatDate(entry.time, Formatter.TimeValueTwentyFourHours)
            var hours = entry.time.getHours()
            return (hours % 12 === 0 ? 12 : hours % 12) + " " + (hours < 12 ? Qt.locale().amText : Qt.locale().pmText)
        }
        return index === 0 ? qsTr("Today") : Qt.formatDate(entry.time, "ddd")
    }

    function activate() {
        request("app", "/usr/share/applications/sailfish-weather.desktop")
    }

    // no controls of its own: a tap anywhere opens the Weather app (DataWidget.qml's handle)
    function pressAt(x, y) {
        return false
    }

    function release() {
    }

    function tapAt(x, y) {
        return false
    }

    // ---- without a location: Set up Weather ----

    Column {
        visible: !face.ready
        anchors.centerIn: parent
        width: parent.width - 2 * face.pad
        spacing: Theme.paddingMedium

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(Theme.iconSizeExtraLarge, face.height * 0.4)
            height: width
            sourceSize.width: width
            sourceSize.height: width
            source: "image://theme/graphic-weather-d100"
            opacity: 0.6
        }

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.highlightColor
            text: qsTr("Set up Weather")
        }

        Label {
            visible: face.size !== "shelf"
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
            text: qsTr("Choose a place in the Weather app")
        }
    }

    // ---- the card: the place, the icon and the temperature, the description, feels like, high and low ----

    Item {
        id: card

        visible: face.ready && face.size === "card"
        anchors.fill: parent

        Label {
            id: cardCity

            x: face.pad * 0.75
            y: face.pad * 0.6
            width: card.width - 2 * x
            truncationMode: TruncationMode.Fade
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.highlightColor
            text: face.source ? face.source.city : ""
        }

        Image {
            id: cardIcon

            x: face.pad * 0.5
            anchors.top: cardCity.bottom
            width: Math.round(card.width * 0.46)
            height: width
            sourceSize.width: width
            sourceSize.height: width
            source: face.ready ? face.icon(face.source.weatherType, true) : ""
        }

        Label {
            anchors.verticalCenter: cardIcon.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: face.pad * 0.75
            font.pixelSize: Math.min(Theme.fontSizeHuge * 1.3, card.width * 0.3)
            font.family: Theme.fontFamilyHeading
            renderType: Text.NativeRendering
            color: Theme.primaryColor
            text: face.temperature
        }

        Column {
            x: face.pad * 0.75
            width: card.width - 2 * x
            anchors.bottom: parent.bottom
            anchors.bottomMargin: face.pad * 0.6
            spacing: Theme.paddingSmall / 2

            Label {
                width: parent.width
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primaryColor
                text: face.source ? face.source.description : ""
            }

            Label {
                visible: text !== ""
                width: parent.width
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: face.feels
            }

            Label {
                visible: text !== ""
                width: parent.width
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                text: face.highLow
            }

            Label {
                visible: text !== ""
                width: parent.width
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeTiny
                color: Theme.secondaryColor
                text: face.staleText
            }
        }
    }

    // ---- the shelf and the panel: the weather now, and five columns of hours or days ----

    Item {
        id: wide

        visible: face.ready && face.size !== "card"
        anchors.fill: parent

        readonly property bool tall: face.size === "panel"
        // the shelf: now on the left, the columns on the right; the panel: now on top, the columns below
        readonly property real nowWidth: tall ? width : width * 0.5
        readonly property real nowHeight: tall ? height * 0.46 : height

        Image {
            id: nowIcon

            x: wide.tall ? face.pad * 0.5 : Theme.paddingSmall
            y: (wide.nowHeight - height) / 2 + (wide.tall ? face.pad * 0.25 : 0)
            width: Math.round(wide.nowHeight * (wide.tall ? 0.78 : 0.58))
            height: width
            sourceSize.width: width
            sourceSize.height: width
            source: face.ready ? face.icon(face.source.weatherType, true) : ""
        }

        Label {
            id: nowTemperature

            x: nowIcon.x + nowIcon.width
            anchors.verticalCenter: nowIcon.verticalCenter
            font.pixelSize: wide.tall ? Theme.fontSizeHuge * 1.3 : Theme.fontSizeExtraLarge
            font.family: Theme.fontFamilyHeading
            renderType: Text.NativeRendering
            color: Theme.primaryColor
            text: face.temperature
        }

        Column {
            x: nowTemperature.x + nowTemperature.width + (wide.tall ? Theme.paddingLarge : Theme.paddingMedium)
            width: wide.nowWidth - x - Theme.paddingMedium - (wide.tall ? face.pad * 0.5 + provider.width : 0)
            anchors.verticalCenter: nowIcon.verticalCenter
            spacing: Theme.paddingSmall / 2

            Label {
                width: parent.width
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.highlightColor
                text: face.source ? face.source.city : ""
            }

            Label {
                width: parent.width
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.primaryColor
                text: face.source ? face.source.description : ""
            }

            Label {
                visible: wide.tall && text !== ""
                width: parent.width
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: face.feels
            }

            Label {
                visible: text !== ""
                width: parent.width
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                text: face.staleText !== "" ? face.staleText : wide.tall ? face.highLow : ""
            }
        }

        // the next hours or days
        Row {
            id: forecastRow

            x: wide.tall ? face.pad * 0.5 : wide.nowWidth
            y: wide.tall ? wide.nowHeight : 0
            width: wide.width - x - (wide.tall ? face.pad * 0.5 : Theme.paddingMedium)
            height: wide.height - y - (wide.tall ? face.pad * 0.6 : 0)

            Repeater {
                model: face.ready ? face.columns : []

                Column {
                    width: forecastRow.width / 5
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: wide.tall ? Theme.paddingSmall : 0

                    Label {
                        width: parent.width
                        horizontalAlignment: implicitWidth > width ? Text.AlignLeft : Text.AlignHCenter
                        truncationMode: TruncationMode.Fade
                        font.pixelSize: Theme.fontSizeTiny
                        color: Theme.secondaryColor
                        text: face.columnLabel(modelData, index)
                    }

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(Theme.iconSizeMedium, forecastRow.height * (wide.tall ? 0.36 : 0.42))
                        height: width
                        sourceSize.width: width
                        sourceSize.height: width
                        source: face.icon(modelData.weatherType, false)
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.primaryColor
                        text: face.source ? face.source.format(face.hourly ? modelData.temperature : modelData.high) : ""
                    }

                    Label {
                        visible: !face.hourly
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.pixelSize: Theme.fontSizeTiny
                        color: Theme.secondaryColor
                        text: face.source && !face.hourly ? face.source.format(modelData.low) : ""
                    }
                }
            }
        }

        // the provider's logo, as in the Events view's banner
        Image {
            id: provider

            visible: wide.tall && status === Image.Ready
            anchors.right: parent.right
            anchors.rightMargin: face.pad * 0.6
            anchors.top: parent.top
            anchors.topMargin: face.pad * 0.6
            opacity: 0.7
            source: face.source && face.source.providerImage !== "" ? face.source.providerImage + Theme.primaryColor : ""
        }
    }
}
