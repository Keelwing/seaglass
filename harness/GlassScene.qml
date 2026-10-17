// The glass scene: the app grid pulled up over the home screen with LauncherWallpaper.qml on GlassSource.qml: the
// wallpaper stays put and the grid is glass over it; a glass folder (FolderPreview.qml) and a glass card
// (GroupWidget.qml) on the grid; the grid turns to its second page and back, then closes. Slowed down for frames
// (scripts/harness.sh --frames makes a GIF). Argument: "[look=glass|clear|stock] [frost=0|1|2]
// [tint=auto|dark|light|none] [parallax=0|1|2] [depth=0|1]
//            [edge=0|1] [photo=PATH] [still=EXPOSURE] [slow=6]"
// still=: no motion, the grid held at that exposure (0..1) for a screenshot (--shot)
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import "../qml/glass"
import "../qml/widgets/group"

Item {
    id: scene

    property Item harness
    property var preset: ({ "look": "glass", "picture": "home", "image": "", "frost": 1, "tint": "auto", "dim": 0.25,
                            "edge": true, "folders": true, "openFolder": true, "cards": true, "parallax": 1,
                            "depth": true, "tilt": false, "drift": false })
    property real slow: 6
    property real still: -1
    property var apps: []
    property real exposure: 0

    readonly property real cellWidth: harness ? harness.grid.cellWidth : 200
    readonly property real cellHeight: harness ? harness.grid.cellHeight : 250
    readonly property int columns: harness ? harness.grid.columns : 5
    readonly property int rows: harness ? harness.grid.rows : 9
    readonly property int perPage: columns * (rows - 1)

    onHarnessChanged: {
        var words = (harness.sceneArgument || "").split(" ")
        var p = preset
        for (var i = 0; i < words.length; i++) {
            var w = words[i].split("=")
            if (w.length !== 2)
                continue
            if (w[0] === "slow") slow = parseFloat(w[1])
            else if (w[0] === "still") still = parseFloat(w[1])
            else if (w[0] === "photo") { p.picture = "photo"; p.image = w[1] }
            else if (w[0] === "look" || w[0] === "tint") p[w[0]] = w[1]
            else if (w[0] === "depth" || w[0] === "edge") p[w[0]] = w[1] === "1"
            else p[w[0]] = parseFloat(w[1])
        }
        preset = p
        apps = harness.apps(harness.launcherModel, [])
        console.log("harness: glass", JSON.stringify(preset), "apps", apps.length)
        if (still >= 0) {
            exposure = still
        } else {
            script.start()
        }
    }

    // The home screen: its wallpaper (Silica's square picture, as the home screen's) and two app covers
    Image {
        id: homePicture

        visible: false
        sourceSize.height: Screen.height
        source: scene.harness ? "image://silica-square/" + encodeURIComponent("file://" + scene.harness.picture) : ""
    }

    Image {
        anchors.fill: parent
        source: scene.harness ? "file://" + scene.harness.picture : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.height: height
    }

    Repeater {
        model: 2

        Rectangle {
            x: Theme.horizontalPageMargin + index * (scene.width / 2 - Theme.horizontalPageMargin / 2)
            y: scene.height * 0.18
            width: scene.width / 2 - Theme.horizontalPageMargin * 1.5
            height: width * 1.6
            radius: Theme.paddingLarge
            color: Theme.rgba("black", 0.55)
            border.color: Theme.rgba("white", 0.2)

            Label {
                anchors.centerIn: parent
                text: index === 0 ? "Messages" : "Browser"
            }
        }
    }

    // The home screen's frame: a centred square, as Lipstick's wallpaper.transformItem
    Item {
        id: stockFrame

        anchors.centerIn: parent
        width: Math.max(scene.width, scene.height)
        height: width
    }

    GlassSource {
        id: glass

        home: homePicture.status === Image.Ready ? homePicture : null
        frameParent: stockFrame
        preset: scene.preset
    }

    // The launcher layer: slides up from the bottom with its exposure, clipped as the stock EdgeLayer
    Item {
        id: sliding

        readonly property real maximumExposure: scene.height
        readonly property real absoluteExposure: scene.exposure * scene.height

        y: (1 - scene.exposure) * scene.height
        width: scene.width
        height: scene.height
        clip: true

        Loader {
            // what the hook's Loader gives, plus what HomeController.qml would give through motion.js
            property Item edgeLayer: sliding
            property Item pager: pager
            property Item glass: glass

            anchors.fill: parent
            source: Qt.resolvedUrl("../qml/glass/LauncherWallpaper.qml")
        }

        // the app grid's pager: two pages; a card and a folder at the top of the first
        Flickable {
            id: pager

            anchors.fill: parent
            contentHeight: 2 * height
            interactive: false

            Item {
                id: page

                readonly property real inset: (scene.width - scene.columns * scene.cellWidth) / 2

                y: Theme.paddingLarge * 2
                width: scene.width
                height: 2 * scene.height

                // a card (2 × 2) over the first two columns of the first two rows
                GroupWidget {
                    x: page.inset
                    width: 2 * scene.cellWidth
                    height: 2 * scene.cellHeight
                    folder: scene.harness ? scene.harness.madeUpFolder(6, 3) : null
                    type: "card"
                    plainGlass: true
                    glassSource: glass
                }

                Repeater {
                    model: scene.apps.slice(0, 2 * scene.perPage - 4)

                    Item {
                        // three columns beside the card for two rows, then full rows; page two below
                        readonly property int slot: index < 6 ? Math.floor(index / 3) * scene.columns + 2 + index % 3
                                                              : index + 4
                        readonly property int onPage: slot % scene.perPage
                        readonly property bool isFolder: index === 3

                        x: page.inset + (onPage % scene.columns) * scene.cellWidth
                        y: Math.floor(slot / scene.perPage) * scene.height + Math.floor(onPage / scene.columns) * scene.cellHeight
                        width: scene.cellWidth
                        height: scene.cellHeight

                        LauncherIcon {
                            id: icon

                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Theme.paddingLarge
                            // the hook empties the folder's shape while the glass tile is there
                            icon: isFolder ? (preview.item && preview.item.glass ? "" : scene.harness.shape(8))
                                           : modelData.iconId

                            Loader {
                                id: preview

                                property QtObject folder: isFolder && scene.harness ? scene.harness.madeUpFolder(5, 20) : null
                                property bool pressed
                                property Item controller: controllerStub
                                property bool editMode
                                property string iconId: isFolder && scene.harness ? scene.harness.shape(8) : ""

                                anchors.fill: parent
                                active: isFolder
                                source: Qt.resolvedUrl("../qml/folders/FolderPreview.qml")
                            }
                        }

                        Label {
                            anchors.top: icon.bottom
                            anchors.topMargin: Theme.paddingSmall
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            truncationMode: TruncationMode.Fade
                            font.pixelSize: Theme.fontSizeTiny
                            text: isFolder ? "Games" : modelData.title
                        }
                    }
                }
            }
        }
    }

    // what FolderPreview.qml reads of HomeController.qml
    Item {
        id: controllerStub

        readonly property Item glass: glass

        function setType(folder, type) {}
    }

    // The run: pull the grid up, turn to page two, back, close; frames all along
    SequentialAnimation {
        id: script

        PauseAnimation { duration: 600 }
        ScriptAction { script: { scene.harness.frameSlow = scene.slow; scene.harness.startFrames() } }
        NumberAnimation { target: scene; property: "exposure"; from: 0; to: 1; duration: 450 * scene.slow; easing.type: Easing.OutCubic }
        PauseAnimation { duration: 250 * scene.slow }
        NumberAnimation { target: pager; property: "contentY"; from: 0; to: pager.height; duration: 500 * scene.slow; easing.type: Easing.InOutQuad }
        PauseAnimation { duration: 200 * scene.slow }
        NumberAnimation { target: pager; property: "contentY"; to: 0; duration: 500 * scene.slow; easing.type: Easing.InOutQuad }
        NumberAnimation { target: scene; property: "exposure"; to: 0; duration: 400 * scene.slow; easing.type: Easing.InCubic }
        PauseAnimation { duration: 150 * scene.slow }
        ScriptAction { script: scene.harness.stopFrames() }
    }
}
