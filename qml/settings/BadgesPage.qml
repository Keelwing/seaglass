// Settings: notification badges, with a preview of each style, and the peek.
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../badges"

Page {
    id: page

    allowedOrientations: Orientation.All

    BadgeSettings {
        id: badges
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        VerticalScrollDecorator {}

        Column {
            id: column

            width: parent.width

            PageHeader {
                title: qsTr("Badges")
            }

            // A preview: an icon with the chosen badge
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingLarge * 2
                height: Theme.iconSizeLauncher + Theme.paddingLarge * 2
                visible: badges.show

                Repeater {
                    model: [1, 7, 128]

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.iconSizeLauncher * 0.75
                        height: width
                        radius: width * 0.3
                        color: Theme.rgba(Theme.primaryColor, 0.3)

                        Badge {
                            x: parent.width - width * 0.75
                            y: -height * 0.25
                            iconSize: parent.width
                            count: modelData
                            style: badges.style
                            tone: badges.tone
                        }
                    }
                }
            }

            TextSwitch {
                text: qsTr("Notification badges")
                description: qsTr("Apps with notifications show how many on their icons.")
                checked: badges.show
                automaticCheck: false
                onClicked: badges.show = !badges.show
            }

            ComboBox {
                label: qsTr("Style")
                visible: badges.show
                currentIndex: badges.style === "dot" ? 1 : 0
                menu: ContextMenu {
                    MenuItem { text: qsTr("Count"); onClicked: badges.style = "count" }
                    MenuItem { text: qsTr("Dot"); onClicked: badges.style = "dot" }
                }
            }

            ComboBox {
                label: qsTr("Colour")
                visible: badges.show
                currentIndex: badges.tone === "red" ? 1 : 0
                menu: ContextMenu {
                    MenuItem { text: qsTr("Ambience"); onClicked: badges.tone = "accent" }
                    MenuItem { text: qsTr("Red"); onClicked: badges.tone = "red" }
                }
            }

            TextSwitch {
                visible: badges.show
                text: qsTr("On folders and cards")
                description: qsTr("A folder shows its apps' notifications together; a card shows each app's.")
                checked: badges.folders
                automaticCheck: false
                onClicked: badges.folders = !badges.folders
            }

            TextSwitch {
                visible: badges.show
                text: qsTr("Long press shows notifications")
                description: qsTr("Hold an app or a folder with a badge to see its notifications, open or clear them. "
                                  + "Edit grid in the card starts the edit mode.")
                checked: badges.peek
                automaticCheck: false
                onClicked: badges.peek = !badges.peek
            }
        }
    }
}
