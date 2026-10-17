// The size control of a widget (a group widget or a data widget) in the launcher's edit mode: a glass pill with the
// widget's sizes, each drawn as a small sketch of its block; the current one is lit. "icon" turns a group widget back
// into a folder icon; "remove" (a data widget) is an ×. Reports the choice with chosen(type).
import QtQuick 2.6
import Sailfish.Silica 1.0

Rectangle {
    id: bar

    property string current: "card"
    // the widest the bar may be (the tile's width): the buttons shrink to fit a card
    property real maxWidth: 4 * Theme.itemSizeSmall + 2 * Theme.paddingSmall

    signal chosen(string type)

    property var types: ["card", "shelf", "panel", "icon"]
    readonly property real button: Math.floor(Math.min(Theme.itemSizeSmall,
                                                        (maxWidth - 2 * Theme.paddingSmall) / types.length))

    width: row.width + Theme.paddingSmall * 2
    height: button + Theme.paddingSmall * 2
    radius: height / 2
    color: Theme.rgba(Theme.highlightDimmerColor, 0.85)
    border.width: Math.max(1, Math.round(Theme.pixelRatio))
    border.color: Theme.rgba(Theme.highlightColor, 0.5)

    Row {
        id: row

        anchors.centerIn: parent

        Repeater {
            model: bar.types

            MouseArea {
                id: option

                readonly property bool selected: modelData === bar.current
                readonly property color accent: selected || (pressed && containsMouse) ? Theme.highlightColor
                                                                                        : Theme.primaryColor

                width: bar.button
                height: bar.button
                onClicked: bar.chosen(modelData)

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Theme.paddingSmall / 2
                    radius: height / 2
                    color: Theme.rgba(Theme.highlightBackgroundColor, option.selected ? 0.35 : 0.0)
                }

                // the sketch: a frame of the grid's proportions with the type's block in it
                Icon {
                    visible: modelData === "remove"
                    anchors.centerIn: parent
                    width: Math.round(bar.button * 0.55)
                    height: width
                    source: visible ? "image://theme/icon-m-dismiss" : ""
                    highlighted: option.pressed && option.containsMouse
                }

                Item {
                    id: frame

                    readonly property real unit: width / 5

                    visible: modelData !== "remove"
                    anchors.centerIn: parent
                    width: Math.round(bar.button * 0.5)
                    height: Math.round(width * 1.15)

                    Rectangle {
                        anchors.fill: parent
                        radius: frame.unit * 0.6
                        color: "transparent"
                        border.width: Math.max(1, Math.round(Theme.pixelRatio))
                        border.color: Theme.rgba(option.accent, 0.6)
                    }

                    Rectangle {
                        x: frame.unit * 0.75
                        y: frame.unit * 0.75
                        width: modelData === "icon" ? frame.unit * 1.5
                               : modelData === "card" ? frame.unit * 2 : frame.unit * 3.5
                        height: modelData === "shelf" ? frame.unit : modelData === "icon" ? frame.unit * 1.5
                                                                                           : frame.unit * 2.25
                        radius: modelData === "icon" ? width / 2 : frame.unit * 0.35
                        color: option.accent
                    }
                }
            }
        }
    }
}
