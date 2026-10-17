// A made-up Notes app in the Silica look, at the phone's size, for the previews of the animations: the settings page
// (AnimationsPage.qml) and the harness's reels. It draws only stock things and sample notes.
import QtQuick 2.6
import Sailfish.Silica 1.0

Item {
    id: notes

    // the ambience's picture, which a Silica app shows soft and dim as its background
    property string picture

    Rectangle {
        anchors.fill: parent
        color: "#0b1426"
    }

    Image {
        anchors.fill: parent
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize.height: 48
        smooth: true
        opacity: 0.7
        source: notes.picture ? "file://" + notes.picture : ""
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.rgba("black", 0.4)
    }

    Label {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: Theme.itemSizeLarge
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: Theme.fontSizeLarge
        color: Theme.highlightColor
        text: "Notes"
    }

    Grid {
        y: Theme.itemSizeLarge
        columns: 3
        spacing: Math.max(1, Math.round(Theme.pixelRatio))

        Repeater {
            model: ["Shopping list\nRye bread, coffee, oat milk",
                    "Cabin weekend\nFirewood, sauna towels, the map",
                    "Book tips\nThe Summer Book, Moomin comics",
                    "Bike repair\nRear brake pads, chain oil", "Gift ideas\nWool socks, tea",
                    "Recipe\nSalmon soup with dill", "Ferry\nLeaves 17:40, not 17:20",
                    "Choir\nRehearsal moved to Thursday", "Garden\nPlant the tulip bulbs",
                    "Sauna\nTonight at eight", "Plants\nWater the fern on Fridays",
                    "Ideas\nA lamp of sea glass", "Running\n5 km by the lake",
                    "Call\nThe dentist on Monday", "Bread\nRye starter, day 3"]

            Rectangle {
                width: Math.floor((notes.width - 2 * Math.max(1, Math.round(Theme.pixelRatio))) / 3)
                height: width
                color: Theme.rgba(Theme.primaryColor, 0.07)

                Rectangle {
                    width: Math.round(Theme.paddingSmall * 1.5)
                    height: parent.height * 0.4
                    color: ["#cc0000", "#cc7700", "#ccbb00", "#88cc00", "#00b315", "#00bf9f",
                            "#005fcc", "#0016de", "#bb00cc"][index % 9]
                }

                Label {
                    x: Theme.paddingLarge
                    y: Theme.paddingMedium
                    width: parent.width - x - Theme.paddingMedium
                    height: parent.height - 2 * y
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    font.pixelSize: Theme.fontSizeSmall
                    text: modelData
                }

                Label {
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                        margins: Theme.paddingSmall
                    }
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.highlightColor
                    text: index + 1
                }
            }
        }
    }
}
