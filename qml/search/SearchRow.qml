// The search row of the app grid's first page (docs/SEARCH.md): one glass capsule, like a dock, with the search on its
// left (the magnifier and "Search") and the apps used most on its right (search.js), inside it. At the bottom of the
// page (pillBelow, the default: under the thumb) the capsule sits low in the row, clear of the names of the icons above
// it; at the top, high in the row, under the camera. Tapping the search part opens SearchSheet.qml, which grows out of
// the capsule.
//   glass      the GlassSource; without it a plain tint
//   suggested  the apps used most: entries {key, title, iconId, item}; none: the capsule is all search
//   cellWidth, inset  the grid's columns (inset: where the first one starts): the capsule runs from the first
//                     column's icon to the last one's
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import "../badges"
import "../glass"

Item {
    id: row

    property Item glass
    property var suggested: []
    property real cellWidth: Theme.iconSizeLauncher * 1.5
    property real inset: 0
    property bool pillBelow
    readonly property Item pill: capsule

    readonly property real iconSize: Math.round(Theme.iconSizeLauncher * 0.62)
    readonly property real iconPitch: iconSize + Theme.paddingMedium
    // as many of the apps used most as fit beside the search
    readonly property int shown: Math.max(0, Math.min(suggested.length,
                                                      Math.floor((capsule.width - search.minimumWidth)
                                                                 / iconPitch)))

    signal search(Item pill)
    signal launch(var entry)

    Item {
        id: capsule

        x: row.inset + Math.max(Theme.paddingMedium, (row.cellWidth - Theme.iconSizeLauncher) / 2)
        y: row.pillBelow ? row.height - height - Theme.paddingLarge : Theme.paddingMedium
        width: row.width - 2 * x
        height: Math.max(Theme.itemSizeSmall, row.iconSize + 2 * Theme.paddingSmall)

        GlassPane {
            id: pane

            anchors.fill: parent
            radius: height / 2
            glass: row.glass
            frost: 1
            color: row.glass ? row.glass.tintColor(4) : "transparent"
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            visible: !pane.visible
            color: Theme.rgba(Theme.highlightDimmerColor, 0.7)
            border.width: Math.max(1, Math.round(Theme.pixelRatio))
            border.color: Theme.rgba(Theme.primaryColor, 0.2)
        }

        // The search: the left part, or all of it without suggestions
        MouseArea {
            id: search

            // room for the magnifier and the short word, whatever the label shows (no binding loop)
            readonly property real minimumWidth: magnifier.width + shortWord.implicitWidth + 3 * Theme.paddingLarge

            width: parent.width - (row.shown > 0 ? apps.width + Theme.paddingMedium : 0)
            height: parent.height
            onClicked: row.search(capsule)

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                visible: search.pressed && search.containsMouse
                color: Theme.rgba(Theme.highlightBackgroundColor, Theme.highlightBackgroundOpacity)
            }

            Icon {
                id: magnifier

                x: Theme.paddingLarge
                anchors.verticalCenter: parent.verticalCenter
                source: "image://theme/icon-m-search"
                highlighted: search.pressed
            }

            Label {
                id: label

                anchors {
                    left: magnifier.right
                    leftMargin: Theme.paddingMedium
                    right: parent.right
                    rightMargin: Theme.paddingMedium
                    verticalCenter: parent.verticalCenter
                }
                truncationMode: TruncationMode.Fade
                color: search.pressed ? Theme.highlightColor : Theme.primaryColor
                //: The search at the app grid's first page: beside the apps used most, or alone
                text: row.shown > 0 ? qsTr("Search") : qsTr("Search apps")
            }
        }

        Label {
            id: shortWord

            visible: false
            text: qsTr("Search")
        }

        // a thin line between the search and the apps
        Rectangle {
            visible: row.shown > 0
            x: search.width
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(1, Math.round(Theme.pixelRatio))
            height: parent.height * 0.5
            color: Theme.rgba(Theme.primaryColor, 0.25)
        }

        // The apps used most, inside the capsule on its right
        Row {
            id: apps

            anchors {
                right: parent.right
                rightMargin: Theme.paddingMedium
                verticalCenter: parent.verticalCenter
            }

            Repeater {
                model: row.shown > 0 ? row.suggested.slice(0, row.shown) : []

                Item {
                    width: row.iconPitch
                    height: row.iconSize

                    LauncherIcon {
                        anchors.centerIn: parent
                        size: row.iconSize
                        icon: modelData.iconId
                        pressed: suggestionArea.pressed && suggestionArea.containsMouse

                        // the app's notifications: a dot, the icons are small
                        IconBadge {
                            item: modelData.item
                            dot: true
                        }
                    }

                    MouseArea {
                        id: suggestionArea

                        anchors.fill: parent
                        onClicked: row.launch(modelData)
                    }
                }
            }
        }
    }
}
