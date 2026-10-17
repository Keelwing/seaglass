// The badges scene: app icons on the glass app grid with notification badges (Badge.qml) in each style: counts and
// dots, in the ambience's highlight colour and in red; a glass folder with its apps' sum; and the notification peek
// open on that folder (NotificationPeek.qml), with made-up notifications. A still picture:
// scripts/harness.sh --scene badges --shot NAME
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import org.nemomobile.lipstick 0.1
import "../qml/badges"
import "../qml/glass"

Item {
    id: scene

    property Item harness
    property var apps: []

    readonly property real cellWidth: harness ? harness.grid.cellWidth : 200
    readonly property real cellHeight: harness ? harness.grid.cellHeight : 250
    readonly property int columns: harness ? harness.grid.columns : 5
    readonly property real inset: (width - columns * cellWidth) / 2
    readonly property real topMargin: Math.max(Screen.topCutout.height, Theme.paddingSmall)

    // per row: the badge style and tone, and made-up counts
    readonly property var rows: [
        { "style": "count", "tone": "accent", "counts": [1, 3, 0, 12, 128] },
        { "style": "count", "tone": "red", "counts": [2, 0, 7, 1, 45] },
        { "style": "dot", "tone": "accent", "counts": [1, 0, 4, 0, 2] },
        { "style": "dot", "tone": "red", "counts": [0, 1, 0, 3, 1] }
    ]

    onHarnessChanged: apps = harness.apps(harness.launcherModel, [])

    // The home screen's wallpaper and frame, and the app grid on glass
    Image {
        id: homePicture

        visible: false
        sourceSize.height: Screen.height
        source: scene.harness ? "image://silica-square/" + encodeURIComponent("file://" + scene.harness.picture) : ""
    }

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
        preset: ({ "look": "glass", "picture": "home", "image": "", "frost": 1, "tint": "auto", "dim": 0.25,
                   "edge": true, "folders": true, "openFolder": true, "cards": true, "parallax": 0,
                   "depth": false, "tilt": false, "drift": false })
    }

    GlassPane {
        anchors.fill: parent
        glass: glass
        frost: 1
        color: glass.tintColor(0)
        edgeLight: false
    }

    Repeater {
        model: scene.rows.length * scene.columns

        Item {
            readonly property var rowSpec: scene.rows[Math.floor(index / scene.columns)]
            readonly property int count: rowSpec.counts[index % scene.columns]
            readonly property var app: scene.apps.length > index ? scene.apps[index] : null

            x: scene.inset + (index % scene.columns) * scene.cellWidth
            y: scene.topMargin + Math.floor(index / scene.columns) * scene.cellHeight
            width: scene.cellWidth
            height: scene.cellHeight

            LauncherIcon {
                id: icon

                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.paddingLarge
                icon: parent.app ? parent.app.iconId : ""

                Badge {
                    x: parent.width - width * 0.75
                    y: -height * 0.25
                    count: parent.parent.count
                    style: parent.parent.rowSpec.style
                    tone: parent.parent.rowSpec.tone
                }
            }

            Label {
                anchors.top: icon.bottom
                anchors.topMargin: Theme.paddingSmall
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeTiny
                text: parent.app ? parent.app.title : ""
            }
        }
    }

    // A glass folder with its apps' sum
    Item {
        x: scene.inset
        y: scene.topMargin + 4 * scene.cellHeight
        width: scene.cellWidth
        height: scene.cellHeight

        LauncherIcon {
            id: folderIcon

            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.paddingLarge
            icon: preview.item && preview.item.glass ? "" : scene.harness.shape(8)

            Loader {
                id: preview

                property QtObject folder: scene.harness ? scene.harness.madeUpFolder(4, 0) : null
                property bool pressed
                property Item glass: glass
                property string iconId: scene.harness ? scene.harness.shape(8) : ""

                anchors.fill: parent
                source: Qt.resolvedUrl("../qml/folders/FolderPreview.qml")
            }

            Badge {
                x: parent.width - width * 0.75
                y: -height * 0.25
                count: 6
            }
        }

        Label {
            anchors.top: folderIcon.bottom
            anchors.topMargin: Theme.paddingSmall
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSizeTiny
            text: madeUpFolder.title
        }
    }

    // The peek: a long press on the badged folder, its apps' notifications together, newest first (the real
    // NotificationPeek.qml, with made-up notifications from the folder's apps: Phone, Messages, People, Mail)
    QtObject {
        id: madeUpFolder

        property int type: LauncherModel.Folder
        property string title: "Contact"
        property string iconId: scene.harness ? scene.harness.shape(8) : ""
    }

    NotificationPeek {
        id: peek

        // a made-up notification, with the fields the home screen's have
        function note(summary, body, minutes) {
            return { "summary": summary, "body": body, "timestamp": new Date(Date.now() - minutes * 60000),
                     "actions": [], "userRemovable": true }
        }

        anchors.fill: parent
        glass: glass

        Timer {
            interval: 600
            running: scene.harness !== null && scene.apps.length > 3
            onTriggered: {
                var a = scene.apps
                peek.open(madeUpFolder, [
                    { "app": a[1], "note": peek.note("Anna", "See you at six at the station?", 2) },
                    { "app": a[3], "note": peek.note("Release team", "Build 41 is green, the release can go out", 18) },
                    { "app": a[1], "note": peek.note("Ben", "Photo", 60) },
                    { "app": a[0], "note": peek.note("Missed call", "+1 555 0100", 95) },
                    { "app": a[3], "note": peek.note("Design review", "Moved to Thursday", 180) },
                    { "app": a[1], "note": peek.note("Clara", "Thanks!", 240) }
                ], folderIcon)
            }
        }
    }
}
