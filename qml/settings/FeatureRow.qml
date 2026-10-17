// A row of the settings' first page: a feature's icon, its name and what it is set to now; it opens the feature's page.
import QtQuick 2.6
import Sailfish.Silica 1.0

BackgroundItem {
    id: row

    property string icon
    property string title
    property string summary

    height: Math.max(Theme.itemSizeMedium, texts.height + 2 * Theme.paddingMedium)

    Icon {
        id: iconItem

        x: Theme.horizontalPageMargin
        anchors.verticalCenter: parent.verticalCenter
        source: row.icon !== "" ? "image://theme/" + row.icon : ""
        highlighted: row.highlighted
    }

    Column {
        id: texts

        anchors {
            left: iconItem.right
            leftMargin: Theme.paddingLarge
            right: parent.right
            rightMargin: Theme.horizontalPageMargin
            verticalCenter: parent.verticalCenter
        }

        Label {
            width: parent.width
            truncationMode: TruncationMode.Fade
            color: row.highlighted ? Theme.highlightColor : Theme.primaryColor
            text: row.title
        }

        Label {
            width: parent.width
            visible: row.summary !== ""
            truncationMode: TruncationMode.Fade
            font.pixelSize: Theme.fontSizeExtraSmall
            color: row.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
            text: row.summary
        }
    }
}
