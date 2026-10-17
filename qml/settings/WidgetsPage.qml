// Settings: the data widgets' options.
import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: page

    allowedOrientations: Orientation.All

    WidgetSettings {
        id: widgetSettings
    }

    RemorsePopup {
        id: remorse
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        VerticalScrollDecorator {}

        Column {
            id: column

            width: parent.width

            PageHeader {
                title: qsTr("Widgets")
            }

            TextSwitch {
                text: qsTr("Show widgets")
                description: qsTr("Live information in the app grid. Add a widget in the edit mode (hold the grid) with "
                                  + "Add widget at the bottom; move it by dragging, size it or take it away with its pill.")
                checked: widgetSettings.show
                automaticCheck: false
                onClicked: widgetSettings.show = !widgetSettings.show
            }

            ComboBox {
                label: qsTr("Clock face")
                visible: widgetSettings.show
                currentIndex: widgetSettings.clockFace === "analogue" ? 1 : 0
                menu: ContextMenu {
                    MenuItem { text: qsTr("Digital"); onClicked: widgetSettings.clockFace = "digital" }
                    MenuItem { text: qsTr("Analogue"); onClicked: widgetSettings.clockFace = "analogue" }
                }
            }

            TextSwitch {
                visible: widgetSettings.show
                text: qsTr("Next alarm on the clock")
                checked: widgetSettings.clockAlarm
                automaticCheck: false
                onClicked: widgetSettings.clockAlarm = !widgetSettings.clockAlarm
            }

            TextSwitch {
                visible: widgetSettings.show
                text: qsTr("Switch from the status widget")
                description: qsTr("A tap on Wi-Fi, Bluetooth or flight mode switches it, as in the top menu. Off: it "
                                  + "opens the settings page.")
                checked: widgetSettings.statusSwitches
                automaticCheck: false
                onClicked: widgetSettings.statusSwitches = !widgetSettings.statusSwitches
            }

            ComboBox {
                label: qsTr("Now playing when idle")
                description: qsTr("With nothing playing, or after 30 minutes paused.")
                visible: widgetSettings.show
                currentIndex: widgetSettings.playerIdle === "hide" ? 1 : 0
                menu: ContextMenu {
                    MenuItem { text: qsTr("Play the last player"); onClicked: widgetSettings.playerIdle = "last" }
                    MenuItem { text: qsTr("Hide the controls"); onClicked: widgetSettings.playerIdle = "hide" }
                }
            }

            TextSwitch {
                visible: widgetSettings.show
                text: qsTr("Album art behind")
                description: qsTr("The album art, blurred and dimmed, fills the Now playing widget.")
                checked: widgetSettings.playerArt
                automaticCheck: false
                onClicked: widgetSettings.playerArt = !widgetSettings.playerArt
            }

            ComboBox {
                label: qsTr("Events: days ahead")
                visible: widgetSettings.show
                currentIndex: widgetSettings.eventDays <= 0 ? 0 : widgetSettings.eventDays <= 3 ? 1 : 2
                menu: ContextMenu {
                    MenuItem { text: qsTr("Today"); onClicked: widgetSettings.eventDays = 0 }
                    MenuItem { text: qsTr("3 days"); onClicked: widgetSettings.eventDays = 3 }
                    MenuItem { text: qsTr("6 days"); onClicked: widgetSettings.eventDays = 6 }
                }
            }

            TextSwitch {
                visible: widgetSettings.show
                text: qsTr("All-day events")
                checked: widgetSettings.eventAllDay
                automaticCheck: false
                onClicked: widgetSettings.eventAllDay = !widgetSettings.eventAllDay
            }

            TextSwitch {
                visible: widgetSettings.show
                text: qsTr("Hide event details")
                description: qsTr("Only the times and the calendars' colours, with Busy for each title.")
                checked: widgetSettings.eventPrivate
                automaticCheck: false
                onClicked: widgetSettings.eventPrivate = !widgetSettings.eventPrivate
            }

            ComboBox {
                label: qsTr("Weather forecast")
                visible: widgetSettings.show
                currentIndex: widgetSettings.weatherForecast === "hourly" ? 1
                              : widgetSettings.weatherForecast === "daily" ? 2 : 0
                menu: ContextMenu {
                    MenuItem { text: qsTr("By size"); onClicked: widgetSettings.weatherForecast = "auto" }
                    MenuItem { text: qsTr("Hourly"); onClicked: widgetSettings.weatherForecast = "hourly" }
                    MenuItem { text: qsTr("Daily"); onClicked: widgetSettings.weatherForecast = "daily" }
                }
                description: widgetSettings.weatherForecast === "auto"
                             ? qsTr("The next hours on a shelf, the next days on a panel.") : ""
            }

            TextSwitch {
                visible: widgetSettings.show
                text: qsTr("Weather: Feels like")
                checked: widgetSettings.weatherFeels
                automaticCheck: false
                onClicked: widgetSettings.weatherFeels = !widgetSettings.weatherFeels
            }

            // Silica's own layout: side by side when they fit, else one above the other, with its spacing
            ButtonLayout {
                Button {
                    text: qsTr("Restore starter widgets")
                    onClicked: widgetSettings.restoreStarter()
                }

                Button {
                    enabled: widgetSettings.list !== "[]" && widgetSettings.list !== ""
                    text: qsTr("Remove all widgets")
                    onClicked: remorse.execute(qsTr("Removing all widgets"), function () { widgetSettings.list = "[]" })
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                topPadding: Theme.paddingLarge
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                text: qsTr("A folder you open next uses the motion settings; the background, the glass, the search "
                           + "row, the badges and the widgets change at once. Folder previews and folder widgets are set "
                           + "in a folder: tap its icon in the open folder.")
            }
        }
    }
}
