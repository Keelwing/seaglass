// The edit mode's "Add widget" capsule (docs/WIDGETS.md), at the bottom of the screen in the band where the last row's
// names are (the stock hides them in edit mode). A tap opens the widget gallery. The touch area reaches a little beyond
// the capsule, so that it is easy to hit.
//   glass  the GlassSource; without it a plain tint
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../../glass"

MouseArea {
    id: area

    property Item glass

    readonly property bool down: pressed && containsMouse
    readonly property real margin: Theme.paddingMedium

    width: capsule.width + 2 * margin
    height: capsule.height + 2 * margin

    Item {
        id: capsule

        anchors.centerIn: parent
        width: Math.max(row.width + 2 * Theme.paddingLarge * 1.5, Theme.itemSizeExtraLarge * 2.5)
        height: Math.round(Theme.itemSizeSmall * 0.85)

        GlassPane {
            id: pane

            anchors.fill: parent
            radius: height / 2
            glass: area.glass
            frost: 1
            color: area.glass ? area.glass.tintColor(4) : "transparent"
            lit: area.down
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            visible: !pane.visible
            color: area.down ? Theme.rgba(Theme.highlightBackgroundColor, Theme.highlightBackgroundOpacity)
                             : Theme.rgba(Theme.highlightDimmerColor, 0.85)
        }

        // a rim in the highlight colour: it reads as a button over any wallpaper
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Theme.rgba(Theme.overlayBackgroundColor, pane.visible ? 0.35 : 0.0)
            border.width: Math.max(2, Math.round(2 * Theme.pixelRatio))
            border.color: Theme.rgba(Theme.highlightColor, area.down ? 1.0 : 0.7)
        }

        Row {
            id: row

            anchors.centerIn: parent
            spacing: Theme.paddingMedium

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(capsule.height * 0.6)
                height: width
                source: "image://theme/icon-m-add"
                highlighted: true
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: Theme.fontSizeMedium
                color: area.down ? Theme.highlightColor : Theme.primaryColor
                //: The edit mode's button that opens the widget gallery
                text: qsTr("Add widget")
            }
        }
    }
}
