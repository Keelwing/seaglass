// The status widget's face (docs/WIDGETS.md), drawn inside DataWidget.qml's glass: the battery as a ring, and Wi-Fi,
// mobile data, Bluetooth and flight mode as chips.
//   source    StatusSource.qml, or null
//   size      card | shelf | panel
//   switches  a tap on a chip switches it (mobile data always opens its settings page)
// A tap elsewhere on the widget opens the battery settings (activate()). The chips take no touches themselves:
// DataWidget.qml's handle lies over the whole widget and calls pressAt, release and tapAt.
import QtQuick 2.6
import Sailfish.Silica 1.0

Item {
    id: face

    property Item source
    property string size: "card"
    property bool switches: true
    property bool editMode

    signal request(string what, string argument)

    // the chip (index in chips) under the finger, lit while pressed
    property int pressedIndex: -1

    readonly property real pad: Theme.paddingLarge
    readonly property int percent: source ? source.percent : -1
    readonly property bool low: source ? (source.low || (percent >= 0 && percent < 15)) : false
    readonly property color errorColor: Theme.errorColor !== undefined ? Theme.errorColor : "#ff4956"
    readonly property string stateText: !source ? ""
                                        : source.charging ? qsTr("Charging")
                                        : source.powerSave ? qsTr("Power saving")
                                        : low ? qsTr("Low battery") : qsTr("Battery")

    // the connections, in the top menu's order
    readonly property var chips: [
        { "key": "wifi", "icon": "icon-m-wlan", "name": qsTr("Wi-Fi"),
          "on": source ? source.wifiOn : false, "connected": source ? source.wifiConnected : false,
          "detail": source && source.wifiConnected && source.wifiName ? source.wifiName
                                                                      : source && source.wifiOn ? qsTr("On") : qsTr("Off"),
          "page": "system_settings/connectivity/wlan" },
        { "key": "mobile", "icon": "icon-m-mobile-network", "name": qsTr("Mobile data"),
          "on": source ? source.mobileOn : false, "connected": source ? source.mobileConnected : false,
          "detail": source && source.mobileConnected ? qsTr("Connected")
                                                     : source && source.mobileOn ? qsTr("On") : qsTr("Off"),
          "page": "system_settings/connectivity/mobile" },
        { "key": "bluetooth", "icon": "icon-m-bluetooth", "name": qsTr("Bluetooth"),
          "on": source ? source.bluetoothOn : false, "connected": source ? source.bluetoothConnected : false,
          "detail": source && source.bluetoothConnected
                    ? (source.bluetoothDevices.length === 1 ? source.bluetoothDevices[0] : qsTr("Connected"))
                    : source && source.bluetoothOn ? qsTr("On") : qsTr("Off"),
          "page": "system_settings/connectivity/bluetooth" },
        { "key": "flight", "icon": "icon-m-airplane-mode", "name": qsTr("Flight mode"),
          "on": source ? source.flight : false, "connected": false,
          "detail": source && source.flight ? qsTr("On") : qsTr("Off"),
          "page": "system_settings/connectivity/flight" }
    ]

    function activate() {
        request("settings", "system_settings/system/battery")
    }

    // The chip under a point of the face (the card's and the shelf's chips, the panel's rows), or -1
    function controlAt(x, y) {
        var repeater = size === "card" ? cardRepeater : size === "shelf" ? shelfRepeater : panelRepeater
        for (var i = 0; i < repeater.count; i++) {
            var item = repeater.itemAt(i)
            if (!item)
                continue
            var p = item.mapFromItem(face, x, y)
            if (p.x >= 0 && p.y >= 0 && p.x < item.width && p.y < item.height)
                return i
        }
        return -1
    }

    // DataWidget.qml: a press on a chip lights it (true), elsewhere nothing (false)
    function pressAt(x, y) {
        pressedIndex = controlAt(x, y)
        return pressedIndex >= 0
    }

    function release() {
        pressedIndex = -1
    }

    // a tap: on a chip, the chip's action (true); elsewhere false, and the widget opens the battery settings
    function tapAt(x, y) {
        var index = controlAt(x, y)
        if (index < 0)
            return false
        tap(chips[index])
        return true
    }

    // a chip: switched here when it can be, else its settings page
    function tap(chip) {
        var done = false
        if (switches && source) {
            if (chip.key === "wifi")
                done = source.switchWifi()
            else if (chip.key === "bluetooth")
                done = source.switchBluetooth()
            else if (chip.key === "flight")
                done = source.switchFlight()
        }
        if (!done)
            request("settings", chip.page)
    }

    // The battery: the ring, the charge in its middle, and a bolt while charging or the saver in power saving
    Item {
        id: battery

        readonly property real diameter: face.size === "shelf" ? face.height - 2 * Theme.paddingMedium
                                         : face.size === "panel" ? Math.min(face.height - 2 * face.pad - stateLabel.height,
                                                                            face.width * 0.36)
                                         : Math.min(face.width - 2 * face.pad,
                                                    face.height - 2 * face.pad - cardChips.height - Theme.paddingLarge)

        x: face.size === "card" ? (face.width - width) / 2 : face.size === "shelf" ? Theme.paddingMedium : face.pad
        y: face.size === "panel" ? (face.height - height - stateLabel.height) / 2
                                 : face.size === "shelf" ? Theme.paddingMedium : face.pad
        width: Math.max(0, diameter)
        height: width

        RingGauge {
            anchors.fill: parent
            value: Math.max(0, face.percent) / 100
            color: face.low && !(face.source && face.source.charging) ? face.errorColor : Theme.highlightColor
            thickness: face.size === "shelf" ? 0.13 : 0.1
        }

        Column {
            anchors.centerIn: parent

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: face.source && (face.source.charging || face.source.powerSave)
                width: Math.round(battery.width * 0.16)
                height: width
                source: face.source && face.source.charging ? "image://theme/icon-m-charging"
                                                            : "image://theme/icon-m-battery-saver"
                highlighted: true
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter

                Label {
                    id: number

                    font.pixelSize: Math.round(battery.width * 0.3)
                    font.family: Theme.fontFamilyHeading
                    color: Theme.primaryColor
                    text: face.percent >= 0 ? face.percent : "–"
                }

                Label {
                    anchors.baseline: number.baseline
                    font.pixelSize: Math.round(battery.width * 0.12)
                    color: Theme.secondaryColor
                    text: face.percent >= 0 ? "%" : ""
                }
            }
        }
    }

    // the panel: the battery's state under the ring
    Label {
        id: stateLabel

        visible: face.size === "panel"
        anchors.top: battery.bottom
        anchors.topMargin: Theme.paddingSmall
        anchors.horizontalCenter: battery.horizontalCenter
        font.pixelSize: Theme.fontSizeSmall
        color: face.low ? face.errorColor : Theme.highlightColor
        text: face.stateText
    }

    // ---- the card: the four chips under the ring ----

    Row {
        id: cardChips

        readonly property real diameter: Math.min(Theme.itemSizeMedium,
                                                  (face.width - 2 * Theme.paddingMedium - 3 * spacing) / 4)

        visible: face.size === "card"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: face.pad * 0.75
        spacing: Theme.paddingMedium
        height: diameter

        Repeater {
            id: cardRepeater

            model: face.size === "card" ? face.chips : []

            StatusChip {
                diameter: cardChips.diameter
                icon: modelData.icon
                on: modelData.on
                connected: modelData.connected
                down: face.pressedIndex === index
            }
        }
    }

    // ---- the shelf: the chips with their names, spread beside the ring ----

    Row {
        id: shelfChips

        readonly property real column: (width - 3 * spacing) / 4
        readonly property real diameter: Math.min(Theme.itemSizeMedium, face.height * 0.48, column)

        visible: face.size === "shelf"
        x: battery.x + battery.width + Theme.paddingLarge
        width: face.width - x - Theme.paddingMedium
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.paddingSmall

        Repeater {
            id: shelfRepeater

            model: face.size === "shelf" ? face.chips : []

            Column {
                width: shelfChips.column
                spacing: Theme.paddingSmall

                StatusChip {
                    anchors.horizontalCenter: parent.horizontalCenter
                    diameter: shelfChips.diameter
                    icon: modelData.icon
                    on: modelData.on
                    connected: modelData.connected
                    down: face.pressedIndex === index
                }

                Label {
                    width: parent.width
                    horizontalAlignment: implicitWidth > width ? Text.AlignLeft : Text.AlignHCenter
                    truncationMode: TruncationMode.Fade
                    font.pixelSize: Theme.fontSizeTiny
                    color: modelData.on ? Theme.highlightColor : Theme.secondaryColor
                    // Wi-Fi: the network's name once connected
                    text: modelData.key === "wifi" && modelData.connected && face.source && face.source.wifiName
                          ? face.source.wifiName : modelData.name
                }
            }
        }
    }

    // ---- the panel: one row per connection beside the battery ----

    Column {
        id: panelRows

        visible: face.size === "panel"
        x: battery.x + battery.width + face.pad
        width: face.width - x - Theme.paddingMedium
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            id: panelRepeater

            model: face.size === "panel" ? face.chips : []

            Item {
                id: row

                readonly property real rowHeight: Math.min(Theme.itemSizeLarge, (face.height - 2 * Theme.paddingMedium) / 4)
                readonly property bool down: face.pressedIndex === index

                width: panelRows.width
                height: rowHeight

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.paddingMedium
                    color: Theme.rgba(Theme.highlightBackgroundColor, Theme.highlightBackgroundOpacity)
                    visible: row.down
                }

                StatusChip {
                    id: rowChip

                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.paddingSmall
                    diameter: row.rowHeight - 2 * Theme.paddingSmall
                    icon: modelData.icon
                    on: modelData.on
                    connected: modelData.connected
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    x: rowChip.x + rowChip.width + Theme.paddingMedium
                    width: parent.width - x - Theme.paddingSmall

                    Label {
                        width: parent.width
                        truncationMode: TruncationMode.Fade
                        font.pixelSize: Theme.fontSizeSmall
                        color: row.down ? Theme.highlightColor : Theme.primaryColor
                        text: modelData.name
                    }

                    Label {
                        width: parent.width
                        truncationMode: TruncationMode.Fade
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: modelData.on ? Theme.highlightColor : Theme.secondaryColor
                        text: modelData.detail
                    }
                }
            }
        }
    }
}
