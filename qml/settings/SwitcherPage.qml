// Settings: the task switcher's chips, recently closed apps, the card row and the pinch.
import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: page

    allowedOrientations: Orientation.All

    SwitcherSettings {
        id: switcherSettings
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        VerticalScrollDecorator {}

        Column {
            id: column

            width: parent.width

            PageHeader {
                title: qsTr("Task switcher")
            }

            ComboBox {
                label: qsTr("Background")
                description: currentIndex === 0 ? qsTr("Your wallpaper, as it is.")
                                                : qsTr("While apps run, your wallpaper frosts behind their covers, "
                                                       + "like the app grid.")
                currentIndex: switcherSettings.background === "frosted" ? 1 : 0
                menu: ContextMenu {
                    MenuItem { text: qsTr("Wallpaper"); onClicked: switcherSettings.background = "wallpaper" }
                    MenuItem { text: qsTr("Frosted"); onClicked: switcherSettings.background = "frosted" }
                }
            }

            TextSwitch {
                text: qsTr("Names under the covers")
                description: qsTr("A small chip with the app's icon and name under each cover.")
                checked: switcherSettings.chips
                automaticCheck: false
                onClicked: switcherSettings.chips = !switcherSettings.chips
            }

            ComboBox {
                label: qsTr("Layout")
                description: currentIndex === 0 ? qsTr("The covers in a grid, as stock.")
                                                : qsTr("A row of cards, swiped sideways, the last used in front.")
                currentIndex: switcherSettings.layout === "cards" ? 1 : 0
                menu: ContextMenu {
                    MenuItem { text: qsTr("Grid"); onClicked: switcherSettings.layout = "grid" }
                    MenuItem { text: qsTr("Cards"); onClicked: switcherSettings.layout = "cards" }
                }
            }

            TextSwitch {
                text: qsTr("Pinch between grid and cards")
                description: qsTr("Pinch in on the cards for the grid, pinch out on a cover for the cards.")
                checked: switcherSettings.pinch
                automaticCheck: false
                onClicked: switcherSettings.pinch = !switcherSettings.pinch
            }

            TextSwitch {
                visible: switcherSettings.layout === "cards"
                text: qsTr("Flick up to close")
                description: qsTr("Flick a card up to close its app. Long press for the stock way, as always.")
                checked: switcherSettings.flickClose
                automaticCheck: false
                onClicked: switcherSettings.flickClose = !switcherSettings.flickClose
            }

            TextSwitch {
                text: qsTr("Recently closed")
                description: qsTr("The apps you closed last, to start again with a tap; a long press takes one off.")
                checked: switcherSettings.recent
                automaticCheck: false
                onClicked: switcherSettings.recent = !switcherSettings.recent
            }

            Slider {
                width: parent.width
                visible: switcherSettings.recent
                label: qsTr("How many")
                minimumValue: 1
                maximumValue: 10
                stepSize: 1
                value: switcherSettings.recentCount
                valueText: Math.round(value)
                onReleased: switcherSettings.recentCount = Math.round(value)
            }

            Button {
                property bool done

                anchors.horizontalCenter: parent.horizontalCenter
                visible: switcherSettings.recent
                enabled: switcherSettings.recentApps !== "[]" && !done
                text: done ? qsTr("Forgotten") : qsTr("Forget closed apps")
                onClicked: {
                    switcherSettings.recentApps = "[]"
                    done = true
                }
            }
        }
    }
}
