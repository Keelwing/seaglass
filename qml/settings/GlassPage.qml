// Settings: the app grid's background and the glass, with a live preview over the home screen's wallpaper
// (GlassSource.qml, GlassPane.qml and LauncherWallpaper.qml, the same files as on the home screen).
import QtQuick 2.6
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import Sailfish.Pickers 1.0
import "../glass"

Page {
    id: page

    allowedOrientations: Orientation.All

    readonly property var looks: [
        { "id": "glass", "name": qsTr("Glass"),
          "about": qsTr("The wallpaper stays; the app grid is a pane of glass over it, frosting as it rises.") },
        { "id": "clear", "name": qsTr("Clear"),
          "about": qsTr("Only the icons rise; the wallpaper stays sharp under a dimming veil.") },
        { "id": "stock", "name": qsTr("Stock"), "about": qsTr("The Sailfish background: what is behind, frosted dark.") }
    ]

    readonly property var tints: ["auto", "dark", "light", "none"]

    function indexOf(list, id) {
        for (var i = 0; i < list.length; i++) {
            if ((list[i].id || list[i]) === id)
                return i
        }
        return 0
    }

    // the glass's settings, read through the preview's GlassSource and written to them
    readonly property QtObject glass: previewGlass.settings
    // false in the harness: its preview shows the stock picture, never a photo set on the phone
    property bool persistentGlass: true

    ConfigurationValue {
        id: ambiencePicture

        key: "/desktop/jolla/background/portrait/home_picture_filename"
    }
    // the ambience's picture for the preview (the harness sets a stock one)
    property string ambienceFile: ambiencePicture.value

    // the picture is a photo from the Gallery, or a stock ambience's picture (both kept as picture "photo")
    readonly property bool ambienceImage: previewGlass.image.indexOf("/usr/share/ambience/") === 0
    readonly property int pictureIndex: previewGlass.pictureKind !== "photo" ? 0 : ambienceImage ? 1 : 2

    // an ambience's name, from its picture's path (/usr/share/ambience/NAME/images/…), as the list shows it
    function ambienceName(path) {
        var words = String(path.split("/")[4] || "").replace(/[-_]/g, " ")
        return words.charAt(0).toUpperCase() + words.slice(1)
    }

    // the ambience pictures, loaded when asked for: without their module only that page is missing
    function pickAmbience() {
        var picker = pageStack.push(Qt.resolvedUrl("AmbiencePicturesPage.qml"), { "selected": previewGlass.image })
        if (picker) {
            picker.picked.connect(function (path) {
                page.glass.image = path
                page.glass.picture = "photo"
            })
        }
    }

    // back from a picker, picked or not: the picture's combo box shows the setting again (a tap on its menu sets its
    // currentIndex by hand, which ends the binding)
    onStatusChanged: {
        if (status === PageStatus.Active)
            pictureBox.currentIndex = Qt.binding(function () { return page.pictureIndex })
    }

    Component {
        id: imagePicker

        ImagePickerPage {
            onSelectedContentPropertiesChanged: {
                page.glass.image = selectedContentProperties.filePath
                page.glass.picture = "photo"
            }
        }
    }


    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        VerticalScrollDecorator {}

        Column {
            id: column

            width: parent.width

            PageHeader {
                title: qsTr("Glass")
            }

            SectionHeader {
                text: qsTr("App grid background")
            }

            // A live preview over the user's wallpaper: the app grid pulled up over the home screen (two app covers
            // on it), its second page and back, closed again; a glass folder and a glass card on it. The glass is
            // the home screen's own (GlassSource, GlassPane, LauncherWallpaper), in a small frame.
            Item {
                width: parent.width
                height: screen.height + 2 * Theme.paddingLarge

                Item {
                    id: screen

                    property real exposure: 0
                    readonly property real cell: width / 4

                    anchors.centerIn: parent
                    width: Math.round(Math.min(page.width, page.height) * 0.42)
                    height: Math.round(width * 2.2)
                    clip: true

                    // the home screen: the wallpaper, square as the home screen's, and two covers
                    Image {
                        id: previewHome

                        visible: false
                        asynchronous: true
                        sourceSize.height: Math.round(screen.height)
                        source: page.ambienceFile
                                ? "image://silica-square/" + encodeURIComponent("file://" + page.ambienceFile) : ""
                    }

                    Image {
                        anchors.fill: parent
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.height: Math.round(screen.height)
                        source: page.ambienceFile ? "file://" + page.ambienceFile : ""
                    }

                    Repeater {
                        model: 2

                        Rectangle {
                            x: screen.cell * 0.25 + index * screen.cell * 1.9
                            y: screen.height * 0.2
                            width: screen.cell * 1.6
                            height: width * 1.6
                            radius: Theme.paddingSmall
                            color: Theme.rgba("black", 0.55)
                            border.color: Theme.rgba("white", 0.2)
                        }
                    }

                    // the home screen's frame: a centred square
                    Item {
                        id: previewFrame

                        anchors.centerIn: parent
                        width: Math.max(screen.width, screen.height)
                        height: width
                    }

                    GlassSource {
                        id: previewGlass

                        home: previewHome.status === Image.Ready ? previewHome : null
                        frameParent: previewFrame
                        pictureSize: Math.round(screen.height)
                        // the harness never shows the phone's own photo
                        preset: page.persistentGlass ? null : { "picture": "home" }
                    }

                    // the app grid: slides up, clipped
                    Item {
                        id: previewLayer

                        readonly property real maximumExposure: screen.height
                        readonly property real absoluteExposure: screen.exposure * screen.height

                        y: (1 - screen.exposure) * screen.height
                        width: screen.width
                        height: screen.height
                        clip: true

                        Loader {
                            property Item edgeLayer: previewLayer
                            property Item pager: previewPager
                            property Item glass: previewGlass

                            anchors.fill: parent
                            source: Qt.resolvedUrl("../glass/LauncherWallpaper.qml")
                        }

                        Flickable {
                            id: previewPager

                            anchors.fill: parent
                            contentHeight: 2 * height
                            interactive: false

                            // a card, a folder and the apps, on two pages
                            GlassPane {
                                x: screen.cell * 0.1
                                y: Theme.paddingMedium + screen.cell * 0.1
                                width: screen.cell * 1.8
                                height: screen.cell * 1.8
                                radius: Theme.paddingMedium
                                glass: previewGlass.cards ? previewGlass : null
                                color: previewGlass.tintColor(1)
                            }

                            Rectangle {
                                x: screen.cell * 0.1
                                y: Theme.paddingMedium + screen.cell * 0.1
                                width: screen.cell * 1.8
                                height: screen.cell * 1.8
                                radius: Theme.paddingMedium
                                visible: !previewGlass.cards
                                color: Theme.rgba(Theme.highlightDimmerColor, 0.55)
                            }

                            Repeater {
                                model: 36

                                Item {
                                    // beside the card for two rows, then full rows; page two below
                                    readonly property int slot: index < 4 ? Math.floor(index / 2) * 4 + 2 + index % 2
                                                                          : index + 4
                                    readonly property int onPage: slot % 20
                                    readonly property bool isFolder: index === 1

                                    x: (onPage % 4) * screen.cell
                                    y: Math.floor(slot / 20) * screen.height + Theme.paddingMedium
                                       + Math.floor(onPage / 4) * screen.cell * 1.1
                                    width: screen.cell
                                    height: screen.cell

                                    GlassPane {
                                        anchors.centerIn: parent
                                        width: screen.cell * 0.62
                                        height: width
                                        radius: width * 0.3
                                        visible: parent.isFolder && previewGlass.folders && previewGlass.ready
                                        glass: visible ? previewGlass : null
                                        color: previewGlass.tintColor(1)
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: screen.cell * (parent.isFolder && previewGlass.folders ? 0.36 : 0.62)
                                        height: width
                                        radius: width * 0.3
                                        color: parent.isFolder ? Theme.highlightColor : Theme.rgba(Theme.primaryColor, 0.75)
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: Theme.paddingLarge
                        border.width: Math.max(1, Math.round(Theme.pixelRatio))
                        border.color: Theme.rgba(Theme.primaryColor, 0.3)
                    }

                    // pull up, page two and back, close: again and again (outside a page stack, in the harness, always:
                    // a page in a stack has its pageContainer). Paused, not stopped, under a picker or in the
                    // background, so that it goes on from where it was: a restart would jump from the held frame
                    SequentialAnimation {
                        running: true
                        paused: !((page.status === PageStatus.Active || !page.pageContainer) && Qt.application.active)
                        loops: Animation.Infinite

                        PauseAnimation { duration: 700 }
                        NumberAnimation { target: screen; property: "exposure"; from: 0; to: 1; duration: 650; easing.type: Easing.OutCubic }
                        PauseAnimation { duration: 700 }
                        NumberAnimation { target: previewPager; property: "contentY"; from: 0; to: previewPager.height; duration: 700; easing.type: Easing.InOutQuad }
                        PauseAnimation { duration: 700 }
                        NumberAnimation { target: previewPager; property: "contentY"; to: 0; duration: 700; easing.type: Easing.InOutQuad }
                        PauseAnimation { duration: 500 }
                        NumberAnimation { target: screen; property: "exposure"; to: 0; duration: 450; easing.type: Easing.InCubic }
                    }
                }
            }

            ComboBox {
                label: qsTr("Look")
                description: page.looks[currentIndex].about
                currentIndex: page.indexOf(page.looks, previewGlass.look)
                menu: ContextMenu {
                    Repeater {
                        model: page.looks

                        MenuItem {
                            text: modelData.name
                            onClicked: page.glass.look = modelData.id
                        }
                    }
                }
            }

            ComboBox {
                id: pictureBox

                label: qsTr("Picture")
                description: currentIndex === 0 ? qsTr("The home screen's wallpaper: it stays where it is.")
                             : currentIndex === 1 ? qsTr("A picture of another ambience: it fades in over the wallpaper "
                                                         + "as the grid rises.")
                             : qsTr("A picture from the Gallery: it fades in over the wallpaper as the grid rises.")
                visible: previewGlass.look !== "stock"
                currentIndex: page.pictureIndex
                menu: ContextMenu {
                    MenuItem { text: qsTr("Home wallpaper"); onClicked: page.glass.picture = "home" }
                    MenuItem {
                        text: qsTr("Ambience picture")
                        onClicked: {
                            if (page.ambienceImage)
                                page.glass.picture = "photo"
                            else
                                page.pickAmbience()
                        }
                    }
                    MenuItem {
                        text: qsTr("Photo")
                        onClicked: {
                            if (page.glass.image === "" || page.ambienceImage)
                                pageStack.push(imagePicker)
                            else
                                page.glass.picture = "photo"
                        }
                    }
                }
            }

            ValueButton {
                visible: previewGlass.look !== "stock" && previewGlass.pictureKind === "photo"
                label: page.ambienceImage ? qsTr("Ambience picture") : qsTr("Photo")
                value: previewGlass.image === "" ? qsTr("None")
                       : page.ambienceImage ? page.ambienceName(previewGlass.image)
                       : previewGlass.image.split("/").pop()
                onClicked: {
                    if (page.ambienceImage)
                        page.pickAmbience()
                    else
                        pageStack.push(imagePicker)
                }
            }

            Slider {
                width: parent.width
                visible: previewGlass.look === "clear"
                label: qsTr("Dimming")
                minimumValue: 0
                maximumValue: 0.7
                stepSize: 0.05
                value: previewGlass.dim
                valueText: Math.round(value * 100) + " %"
                onReleased: page.glass.dim = value
            }

            ComboBox {
                label: qsTr("Parallax")
                description: qsTr("The wallpaper follows the pages more slowly than the icons.")
                visible: previewGlass.look !== "stock"
                currentIndex: previewGlass.parallax
                menu: ContextMenu {
                    MenuItem { text: qsTr("Off"); onClicked: page.glass.parallax = 0 }
                    MenuItem { text: qsTr("Subtle"); onClicked: page.glass.parallax = 1 }
                    MenuItem { text: qsTr("Deep"); onClicked: page.glass.parallax = 2 }
                }
            }

            TextSwitch {
                visible: previewGlass.look !== "stock"
                text: qsTr("Depth")
                description: qsTr("The wallpaper eases back a little as the app grid rises.")
                checked: previewGlass.depth
                automaticCheck: false
                onClicked: page.glass.depth = !page.glass.depth
            }

            TextSwitch {
                visible: previewGlass.look !== "stock"
                text: qsTr("Tilt")
                description: qsTr("The wallpaper shifts a little as you tilt the phone (only while the app grid shows).")
                checked: previewGlass.tilt
                automaticCheck: false
                onClicked: page.glass.tilt = !page.glass.tilt
            }

            TextSwitch {
                visible: previewGlass.look !== "stock"
                text: qsTr("Drift")
                description: qsTr("A slow zoom in and out while the app grid shows.")
                checked: previewGlass.drift
                automaticCheck: false
                onClicked: page.glass.drift = !page.glass.drift
            }

            SectionHeader {
                text: qsTr("Glass")
            }

            TextSwitch {
                text: qsTr("Folder icons")
                description: qsTr("A folder is a glass tile with its apps on it, glowing in its colour.")
                checked: previewGlass.folders
                automaticCheck: false
                onClicked: page.glass.folders = !page.glass.folders
            }

            TextSwitch {
                text: qsTr("Open folder")
                description: qsTr("An open folder sits on frosted glass, growing out of its tile.")
                checked: previewGlass.openFolder
                automaticCheck: false
                onClicked: page.glass.openFolder = !page.glass.openFolder
            }

            TextSwitch {
                text: qsTr("Widget cards")
                description: qsTr("Cards are glass, a touch lighter than the app grid.")
                checked: previewGlass.cards
                automaticCheck: false
                onClicked: page.glass.cards = !page.glass.cards
            }

            ComboBox {
                label: qsTr("Frost")
                currentIndex: previewGlass.frost
                menu: ContextMenu {
                    MenuItem { text: qsTr("Light"); onClicked: page.glass.frost = 0 }
                    MenuItem { text: qsTr("Medium"); onClicked: page.glass.frost = 1 }
                    MenuItem { text: qsTr("Strong"); onClicked: page.glass.frost = 2 }
                }
            }

            ComboBox {
                label: qsTr("Tint")
                description: currentIndex === 0 ? qsTr("Dark on a dark ambience, light on a light one.") : ""
                currentIndex: page.indexOf(page.tints, previewGlass.tintSetting)
                menu: ContextMenu {
                    MenuItem { text: qsTr("Auto"); onClicked: page.glass.tint = "auto" }
                    MenuItem { text: qsTr("Dark"); onClicked: page.glass.tint = "dark" }
                    MenuItem { text: qsTr("Light"); onClicked: page.glass.tint = "light" }
                    MenuItem { text: qsTr("None"); onClicked: page.glass.tint = "none" }
                }
            }

            TextSwitch {
                text: qsTr("Edge light")
                description: qsTr("A thin light along the glass's edges.")
                checked: previewGlass.edgeLight
                automaticCheck: false
                onClicked: page.glass.edge = !page.glass.edge
            }
        }
    }
}
