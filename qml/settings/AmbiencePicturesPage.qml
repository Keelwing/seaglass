// Settings: a picture for the app grid's background (Glass > Picture) from the ambiences Sailfish OS ships in
// /usr/share/ambience. Anyone can try the picture look with these: none of them is the user's own photo.
import QtQuick 2.6
import Sailfish.Silica 1.0
import Qt.labs.folderlistmodel 2.1

Page {
    id: page

    // the picture chosen now (its path), outlined
    property string selected

    signal picked(string path)

    allowedOrientations: Orientation.All

    FolderListModel {
        id: ambiences

        folder: "file:///usr/share/ambience"
        showFiles: false
        showDirs: true
        showDotAndDotDot: false
        sortField: FolderListModel.Name
    }

    SilicaGridView {
        id: grid

        anchors.fill: parent
        cellWidth: Math.floor(width / (page.isPortrait ? 3 : 5))
        cellHeight: Math.round(cellWidth * 1.4)
        model: ambiences

        header: PageHeader {
            title: qsTr("Ambience picture")
        }

        delegate: Item {
            id: cell

            // an ambience's pictures (one, as a rule): the first
            readonly property string path: pictures.count > 0 ? pictures.get(0, "filePath") : ""
            readonly property string name: {
                var words = String(model.fileName).replace(/[-_]/g, " ")
                return words.charAt(0).toUpperCase() + words.slice(1)
            }

            width: grid.cellWidth
            height: grid.cellHeight

            FolderListModel {
                id: pictures

                folder: "file://" + model.filePath + "/images"
                nameFilters: ["*.jpg", "*.jpeg", "*.png"]
                showDirs: false
            }

            BackgroundItem {
                id: tile

                anchors {
                    fill: parent
                    margins: Theme.paddingSmall
                }
                visible: cell.path !== ""
                onClicked: {
                    page.picked(cell.path)
                    pageStack.pop()
                }

                Image {
                    anchors.fill: parent
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: width
                    clip: true
                    source: cell.path !== "" ? "file://" + cell.path : ""
                    opacity: tile.highlighted ? 0.7 : 1
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: label.height + 2 * Theme.paddingSmall
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Theme.rgba("black", 0.6) }
                    }
                }

                Label {
                    id: label

                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        margins: Theme.paddingSmall
                    }
                    truncationMode: TruncationMode.Fade
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: "white"
                    text: cell.name
                }

                Rectangle {
                    anchors.fill: parent
                    visible: cell.path !== "" && cell.path === page.selected
                    color: "transparent"
                    border.width: Math.max(2, Math.round(3 * Theme.pixelRatio))
                    border.color: Theme.highlightColor
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
