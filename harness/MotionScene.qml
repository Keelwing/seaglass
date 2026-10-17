// The motion scene: a folder of the phone opens over the app grid's first page with FolderMotion.qml, stays open,
// and closes, slowed down so that the harness can grab it frame by frame (scripts/harness.sh --frames makes a GIF).
// The folder is a stand-in for LauncherFolder.qml (its background, header and apps), with the same Loader
// contract as the hook.
// Argument: "STYLE [nocascade] [nodepth] [glass] [from=TITLE] [speed=1.0] [slow=8]"
//   glass  the open folder on glass: the app grid on glass too, and the folder on a frosted sheet
//   STYLE  zoom | spring | reveal | slide | fade
//   from   the folder to open: its icon on the page is the origin (a widget title opens from a card)
import QtQuick 2.6
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import Nemo.Configuration 1.0
import org.nemomobile.lipstick 0.1
import "../qml/glass"
import "../qml/widgets/group"
import "../qml/core/motion.js" as Motion

Item {
    id: scene

    property Item harness
    property string style: "zoom"
    property bool cascade: true
    property bool depth: true
    property real speed: 1.0
    property real slow: 8
    property string from: "Media"
    property bool card
    property bool glassOn
    property QtObject openFolder
    property var pageItems: []
    property Item opened

    readonly property real cellWidth: harness ? harness.grid.cellWidth : 200
    readonly property real cellHeight: harness ? harness.grid.cellHeight : 250
    readonly property int columns: harness ? harness.grid.columns : 5

    onHarnessChanged: {
        var words = (harness.sceneArgument || "zoom").split(" ")
        style = words[0]
        for (var i = 1; i < words.length; i++) {
            var w = words[i]
            if (w === "nocascade") cascade = false
            else if (w === "nodepth") depth = false
            else if (w.indexOf("from=") === 0) from = w.slice(5)
            else if (w.indexOf("speed=") === 0) speed = parseFloat(w.slice(6))
            else if (w.indexOf("slow=") === 0) slow = parseFloat(w.slice(5))
            else if (w === "card") card = true
            else if (w === "glass") glassOn = true
        }
        openFolder = harness.folderNamed(from) || harness.folders()[0]
        // the page: the folder (as an icon, or as a card) after the first row of apps, other apps around it
        var items = []
        var model = harness.launcherModel
        for (i = 0; i < model.itemCount && items.length < 25; i++) {
            var item = model.get(i)
            if (item !== openFolder && item.type !== LauncherModel.Folder)
                items.push(item)
        }
        items.splice(6, 0, openFolder)
        pageItems = items
        console.log("harness: motion", style, "cascade", cascade, "depth", depth, "from", openFolder.title,
                    card ? "(card)" : "(icon)", "slow", slow)
        Motion.setHome({ "grid": home, "glass": glassOn ? glassSource : null })
        script.start()
    }


    Image {
        id: wallpaper

        anchors.fill: parent
        source: scene.harness ? "file://" + scene.harness.picture : ""
        fillMode: Image.PreserveAspectCrop
        visible: false
    }

    FastBlur {
        anchors.fill: parent
        source: wallpaper
        radius: 64
        visible: !scene.glassOn
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.rgba(Theme.overlayBackgroundColor, 0.45)
        visible: !scene.glassOn
    }

    // With glass: the home screen's square wallpaper and frame, and the app grid on glass
    Image {
        id: homePicture

        visible: false
        sourceSize.height: Screen.height
        source: scene.glassOn ? "image://silica-square/" + encodeURIComponent("file://" + scene.harness.picture) : ""
    }

    Item {
        id: stockFrame

        anchors.centerIn: parent
        width: Math.max(scene.width, scene.height)
        height: width
    }

    GlassSource {
        id: glassSource

        home: homePicture.status === Image.Ready ? homePicture : null
        frameParent: stockFrame
        preset: ({ "look": "glass", "picture": "home", "image": "", "frost": 1, "tint": "auto", "dim": 0.25,
                   "edge": true, "folders": true, "openFolder": true, "cards": true, "parallax": 0,
                   "depth": false, "tilt": false, "drift": false })
    }

    GlassPane {
        anchors.fill: parent
        glass: scene.glassOn ? glassSource : null
        frost: 1
        color: glassSource.tintColor(0)
    }

    // The app grid's first page
    Item {
        id: home

        x: (parent.width - width) / 2
        y: Theme.paddingLarge * 2
        width: scene.columns * scene.cellWidth
        height: 5 * scene.cellHeight

        Flow {
            width: parent.width

            Repeater {
                model: scene.pageItems

                Item {
                    id: cellItem

                    readonly property bool isOrigin: modelData === scene.openFolder

                    width: isOrigin && scene.card ? 2 * scene.cellWidth : scene.cellWidth
                    height: isOrigin && scene.card ? 2 * scene.cellHeight : scene.cellHeight

                    GroupWidget {
                        id: tile

                        visible: parent.isOrigin && scene.card
                        anchors.fill: parent
                        folder: visible ? modelData : null
                        type: "card"
                        plainGlass: true
                    }

                    LauncherIcon {
                        id: launcherIcon

                        visible: !(parent.isOrigin && scene.card)
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Theme.paddingLarge
                        icon: modelData.iconId

                        Loader {
                            property QtObject folder: modelData.itemCount !== undefined ? modelData : null

                            anchors.fill: parent
                            active: folder !== null
                            source: Qt.resolvedUrl("../qml/folders/FolderPreview.qml")
                        }
                    }

                    Label {
                        visible: launcherIcon.visible
                        anchors {
                            top: launcherIcon.bottom
                            topMargin: Theme.paddingSmall
                            left: parent.left
                            right: parent.right
                        }
                        horizontalAlignment: Text.AlignHCenter
                        truncationMode: TruncationMode.Fade
                        font.pixelSize: Theme.fontSizeTiny
                        text: modelData.title
                    }

                    // a tap: note the origin as HomeController.qml does, and open the folder
                    function origin() {
                        if (scene.card) {
                            var g = Theme.paddingSmall
                            var p = tile.mapToItem(null, g, g)
                            return { "x": p.x, "y": p.y, "width": tile.width - 2 * g, "height": tile.height - 2 * g,
                                     "radius": Theme.paddingLarge }
                        }
                        var q = launcherIcon.mapToItem(null, 0, 0)
                        return { "x": q.x, "y": q.y, "width": launcherIcon.width, "height": launcherIcon.height,
                                 "radius": launcherIcon.width / 4 }
                    }
                    Component.onCompleted: if (isOrigin) scene.originItem = cellItem
                }
            }
        }
    }
    property Item originItem

    // The open folder: as LauncherFolder.qml draws it, with the hook's FolderMotion Loader
    Component {
        id: folderComponent

        Rectangle {
            id: launcherFolder

            property QtObject model: scene.openFolder

            function close() {
                if (motionLoader.item && motionLoader.item.close())
                    return
                opacity = 0.0
                enabled = false
                destroy(200)
                console.log("harness: folder closed")
            }

            width: scene.width
            height: scene.height
            z: 10
            opacity: 0.0
            Behavior on opacity {
                enabled: !(motionLoader.item && motionLoader.item.managed)
                SmoothedAnimation { duration: 400 * scene.slow; velocity: 1000 / duration }
            }
            // as the hook: transparent while the folder is on glass
            readonly property bool seaglassGlass: motionLoader.item ? motionLoader.item.glass === true : false
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.rgba(Theme.overlayBackgroundColor, launcherFolder.seaglassGlass ? 0.0 : 1.0) }
                GradientStop { position: 1.0; color: Theme.rgba(Theme.overlayBackgroundColor, launcherFolder.seaglassGlass ? 0.0 : Theme.opacityOverlay) }
            }
            Component.onCompleted: if (!(motionLoader.item && motionLoader.item.managed)) opacity = 1.0

            Loader {
                id: motionLoader

                property Item folder: launcherFolder
                property Item grid: folderGrid
                // instead of dconf, and slowed down
                property string style: scene.style
                property bool cascade: scene.cascade
                property bool depth: scene.depth
                property real speed: scene.speed
                property real timeScale: scene.slow

                source: Qt.resolvedUrl("../qml/folders/FolderMotion.qml")
            }

            Rectangle {
                id: header

                width: parent.width
                height: Theme.paddingLarge + scene.cellHeight - Theme.fontSizeExtraSmall / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.rgba(Theme.primaryColor, 0.0) }
                    GradientStop { position: 1.0; color: Theme.rgba(Theme.primaryColor, 0.15) }
                }

                LauncherIcon {
                    id: headerIcon

                    x: (scene.width - scene.columns * scene.cellWidth) / 2 + (scene.cellWidth - width) / 2
                    y: Theme.paddingLarge + (scene.cellHeight - height - Theme.fontSizeExtraSmall) / 2
                    icon: scene.openFolder ? scene.openFolder.iconId : ""

                    Loader {
                        property QtObject folder: scene.openFolder

                        anchors.fill: parent
                        source: Qt.resolvedUrl("../qml/folders/FolderPreview.qml")
                    }
                }

                Label {
                    anchors {
                        right: parent.right
                        rightMargin: Theme.horizontalPageMargin
                        verticalCenter: headerIcon.verticalCenter
                    }
                    font.pixelSize: Theme.fontSizeExtraLarge
                    font.family: Theme.fontFamilyHeading
                    text: scene.openFolder ? scene.openFolder.title : ""
                }
            }

            // a stand-in for the folder's LauncherGrid: its contentItem holds the delegates' content items
            Flickable {
                id: folderGrid

                anchors.top: header.bottom
                anchors.topMargin: Theme.fontSizeExtraSmall / 2
                x: (scene.width - width) / 2
                width: scene.columns * scene.cellWidth
                height: 4 * scene.cellHeight
                interactive: false

                Repeater {
                    model: scene.openFolder

                    Item {
                        objectName: "EditableGridDelegate_contentItem"
                        x: (index % scene.columns) * scene.cellWidth
                        y: Math.floor(index / scene.columns) * scene.cellHeight
                        width: scene.cellWidth
                        height: scene.cellHeight

                        LauncherIcon {
                            id: appIcon

                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Theme.paddingLarge
                            icon: model.object.iconId
                        }

                        Label {
                            anchors {
                                top: appIcon.bottom
                                topMargin: Theme.paddingSmall
                                left: parent.left
                                right: parent.right
                            }
                            horizontalAlignment: Text.AlignHCenter
                            truncationMode: TruncationMode.Fade
                            font.pixelSize: Theme.fontSizeTiny
                            text: model.object.title
                        }
                    }
                }
            }
        }
    }

    // The run: wait, tap the folder, keep it open a moment, close it; frames all along
    SequentialAnimation {
        id: script

        PauseAnimation { duration: 600 }
        ScriptAction {
            script: {
                if (scene.originItem)
                    Motion.setOrigin(scene.originItem.origin())
                scene.opened = folderComponent.createObject(scene)
                scene.harness.frameSlow = scene.slow
                scene.harness.startFrames()
            }
        }
        PauseAnimation { duration: 700 * scene.slow }
        ScriptAction { script: if (scene.opened) scene.opened.close() }
        PauseAnimation { duration: 450 * scene.slow }
        ScriptAction { script: scene.harness.stopFrames() }
    }
}
