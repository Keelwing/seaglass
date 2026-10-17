// How a folder shows on the home screen, chosen below the folder shapes of an open folder.
//
// "icon" is the stock folder icon on the grid (with the preview); "card", "shelf" and "panel" show the folder
// open as a group widget in the app grid (grid.js). Each option is a small sketch of the first page.
// The selector only reports the choice (chosen); the caller stores it.
import QtQuick 2.6
import Sailfish.Silica 1.0

Column {
    id: selector

    property string current: "icon"

    signal chosen(string type)

    readonly property var options: [
        { "type": "icon", "label": qsTr("Icon"), "widgetRows": 0, "dotRows": 5 },
        { "type": "card", "label": qsTr("Card"), "widgetRows": 2, "dotRows": 3 },
        { "type": "shelf", "label": qsTr("Shelf"), "widgetRows": 1, "dotRows": 4 },
        { "type": "panel", "label": qsTr("Panel"), "widgetRows": 2, "dotRows": 3 }
    ]

    bottomPadding: Theme.paddingLarge

    // like Silica's SectionHeader
    Label {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: Theme.itemSizeExtraSmall
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.highlightColor
        text: qsTr("On the home screen")
    }

    Row {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x

        Repeater {
            model: selector.options

            MouseArea {
                id: option

                readonly property var spec: modelData
                readonly property bool selected: spec.type === selector.current
                readonly property color accent: selected || (pressed && containsMouse) ? Theme.highlightColor
                                                                                        : Theme.primaryColor

                width: parent.width / selector.options.length
                height: page.y + page.height + Theme.paddingMedium + name.height + Theme.paddingMedium
                onClicked: selector.chosen(spec.type)

                // A sketch of the first page: the widget on top, the app icons as dots below it
                Rectangle {
                    id: page

                    readonly property real unit: width / 8.5

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Theme.paddingMedium
                    width: Math.min(parent.width - 2 * Theme.paddingMedium, Theme.itemSizeExtraLarge)
                    height: Math.round(unit * 10.5)
                    radius: unit
                    color: Theme.rgba(option.accent, option.selected ? 0.12 : 0.04)
                    border.width: Math.max(1, Math.round((option.selected ? 2 : 1) * Theme.pixelRatio))
                    border.color: Theme.rgba(option.accent, option.selected ? 0.9 : 0.3)

                    // the widget: half the width for a card, the full width otherwise
                    Rectangle {
                        visible: option.spec.widgetRows > 0
                        x: page.unit
                        y: page.unit
                        width: option.spec.type === "card" ? 3 * page.unit : 6.5 * page.unit
                        height: option.spec.widgetRows * 1.5 * page.unit + (option.spec.widgetRows - 1) * 0.5 * page.unit
                        radius: page.unit * 0.5
                        color: Theme.rgba(option.accent, 0.6)
                    }

                    Grid {
                        x: page.unit
                        y: page.unit + (option.spec.widgetRows > 0
                                        ? option.spec.widgetRows * 2 * page.unit : 0)
                        columns: 4
                        spacing: page.unit * 0.5

                        Repeater {
                            model: 4 * option.spec.dotRows

                            Rectangle {
                                // for "icon": the folder is the second icon of the second row
                                readonly property bool folderDot: option.spec.type === "icon" && index === 5

                                width: page.unit * 1.25
                                height: width
                                radius: folderDot ? width * 0.3 : width / 2
                                color: Theme.rgba(option.accent, folderDot ? 0.9 : 0.3)
                            }
                        }
                    }
                }

                Label {
                    id: name

                    anchors {
                        top: page.bottom
                        topMargin: Theme.paddingMedium
                        horizontalCenter: parent.horizontalCenter
                    }
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: option.accent
                    text: option.spec.label
                }
            }
        }
    }
}
