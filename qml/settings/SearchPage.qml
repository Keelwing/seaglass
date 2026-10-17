// Settings: the search row on the app grid's first page, and the launches it counts.
import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: page

    allowedOrientations: Orientation.All

    readonly property var searchRows: ["suggestions", "pill", "off"]

    SearchSettings {
        id: search
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        VerticalScrollDecorator {}

        Column {
            id: column

            width: parent.width

            PageHeader {
                title: qsTr("Search")
            }

            ComboBox {
                label: qsTr("Search row")
                description: [qsTr("A search capsule on the app grid's first page, with the apps you use most in it."),
                              qsTr("A search capsule on the app grid's first page."),
                              qsTr("No search row: the app grid as before.")][currentIndex]
                currentIndex: Math.max(0, page.searchRows.indexOf(search.row))
                menu: ContextMenu {
                    MenuItem { text: qsTr("Search and apps used most"); onClicked: search.row = "suggestions" }
                    MenuItem { text: qsTr("Search only"); onClicked: search.row = "pill" }
                    MenuItem { text: qsTr("Off"); onClicked: search.row = "off" }
                }
            }

            ComboBox {
                label: qsTr("Position")
                visible: search.row !== "off"
                description: currentIndex === 0
                             ? qsTr("The last row of the first page: under your thumb, the field rides on the keyboard.")
                             : qsTr("The first row of the first page, under the camera.")
                currentIndex: search.position === "top" ? 1 : 0
                menu: ContextMenu {
                    MenuItem { text: qsTr("Bottom"); onClicked: search.position = "bottom" }
                    MenuItem { text: qsTr("Top"); onClicked: search.position = "top" }
                }
            }

            TextSwitch {
                text: qsTr("Remember launches")
                description: qsTr("The apps you launch are counted on this phone, for the apps used most. "
                                  + "Nothing leaves the phone.")
                checked: search.remember
                automaticCheck: false
                onClicked: search.remember = !search.remember
            }

            Button {
                id: forget

                property bool done

                anchors.horizontalCenter: parent.horizontalCenter
                enabled: search.usage !== "{}" && !done
                text: done ? qsTr("Forgotten") : qsTr("Forget used apps")
                onClicked: {
                    search.usage = "{}"
                    done = true
                }
            }
        }
    }
}
