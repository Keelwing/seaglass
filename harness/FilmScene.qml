// The film scene (docs/DEVELOPMENT.md): short clips of the data widgets for the README, made like the touch scene
// (HomeController.qml on a stand-in grid, driven by real mouse events) but dressed as the home screen: the stock
// ambience picture, the widgets on glass, the icons with their names and sliding to their places, and a dot where the
// finger is. Run with qmlscene's slow motion (scripts/harness.sh --slow-animations): every animation and Timer runs
// five times slower, so that the grabs keep up; the frames are timed back to real speed. Sample data, in-memory
// widgets; with --public only the stock apps. Argument: "[clip=move|add|resize]"
//   move    a long press on the weather widget lifts it; it is carried two rows up and let go; the icons make way
//   add     Add widget, the gallery, a long press on the status card's preview, carried onto the grid among the icons
//           and let go
//   resize  in the edit mode, the size pill turns the clock from a card into a shelf, then back
import QtQuick 2.6
import QtTest 1.0
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0
import org.nemomobile.lipstick 0.1
import Sailfish.Lipstick 1.0
import "../qml/core"
import "../qml/widgets/group"

Item {
    id: scene

    property Item harness
    property string clip: "move"
    property int step: 0
    // qmlscene --slow-animations: Qt's slow motion factor
    readonly property real slowMotion: 5
    // the icons slide to their places once the first layout is drawn
    property bool settled

    onHarnessChanged: {
        var words = (harness.sceneArgument || "").split(" ")
        for (var i = 0; i < words.length; i++) {
            var w = words[i].split("=")
            if (w[0] === "clip")
                clip = w[1]
        }
        controller.demoData = true
        controller.dataStore.memory = [
            { "id": "w1", "kind": "clock", "size": "card", "at": 0 },
            { "id": "w2", "kind": "weather", "size": "shelf", "at": 6 }
        ]
        controller.glass.preset = glassPreset
        controller.glass.home = Qt.binding(function () { return homePicture.status === Image.Ready ? homePicture : null })
        controller.glass.frameParent = stockFrame
        controller.pager = pager
        controller.grid = grid
        console.log("harness: film", clip)
        stepTimer.start()
    }

    readonly property var glassPreset: ({ "look": "glass", "picture": "home", "image": "", "frost": 1, "tint": "auto",
                                          "dim": 0.25, "edge": true, "folders": true, "openFolder": true, "cards": true,
                                          "parallax": 0, "depth": false, "tilt": false, "drift": false })

    TestEvent {
        id: events
    }

    FolderTypes {
        id: memoryTypes

        persistent: false
    }

    function widgetNamed(id) {
        var children = grid.contentItem.children
        for (var i = 0; i < children.length; i++) {
            if (children[i].dragBody !== undefined && children[i].entry && children[i].entry.id === id)
                return children[i]
        }
        return null
    }

    // the widgets on our glass, as in the home screen (the controller draws them plain when it is not persistent)
    function dressWidgets() {
        var children = grid.contentItem.children
        for (var i = 0; i < children.length; i++) {
            if (children[i].dragBody !== undefined)
                children[i].plainGlass = false
        }
    }

    function find(item, test) {
        if (!item)
            return null
        if (test(item))
            return item
        var children = item.children || []
        for (var i = 0; i < children.length; i++) {
            var found = find(children[i], test)
            if (found)
                return found
        }
        return null
    }

    // The finger: the press, a glide to a point, the release; the dot follows it
    property real fingerX
    property real fingerY
    property bool fingerDown
    property real glideFromX
    property real glideFromY
    property real glideToX
    property real glideToY
    property real glideT

    function press(item, x, y) {
        var p = item.mapToItem(scene, x, y)
        fingerX = p.x
        fingerY = p.y
        fingerDown = true
        events.mousePress(scene, fingerX, fingerY, Qt.LeftButton, Qt.NoModifier, -1)
    }

    function glideTo(x, y, ms) {
        glideFromX = fingerX
        glideFromY = fingerY
        glideToX = x
        glideToY = y
        glide.duration = ms
        glideT = 0
        glide.restart()
    }

    onGlideTChanged: {
        if (!fingerDown)
            return
        fingerX = glideFromX + (glideToX - glideFromX) * glideT
        fingerY = glideFromY + (glideToY - glideFromY) * glideT
        events.mouseMove(scene, fingerX, fingerY, -1, Qt.LeftButton)
    }

    NumberAnimation {
        id: glide

        target: scene
        property: "glideT"
        from: 0
        to: 1
        easing.type: Easing.InOutQuad
    }

    function release() {
        events.mouseRelease(scene, fingerX, fingerY, Qt.LeftButton, Qt.NoModifier, -1)
        fingerDown = false
    }

    function tap(item, x, y) {
        press(item, x, y)
        tapRelease.start()
    }

    Timer {
        id: tapRelease

        interval: 120
        onTriggered: scene.release()
    }

    function startFilm() {
        settled = true
        dressWidgets()
        harness.frameSlow = slowMotion
        harness.frameInterval = 40
        harness.frameSize = Qt.size(540, Math.round(540 * height / width))
        harness.startFrames()
    }

    // a long press on an app icon starts the edit mode (the stand-in grid's icons take no touches: the finger is shown,
    // and the edit mode is set)
    function holdIcon(modelIndex) {
        var children = grid.contentItem.children
        for (var i = 0; i < children.length; i++) {
            if (children[i].modelIndex === modelIndex) {
                press(children[i], children[i].width / 2, children[i].height * 0.4)
                editTimer.start()
                return
            }
        }
    }

    Timer {
        id: editTimer

        interval: 500
        onTriggered: {
            grid.setEditMode(true)
            scene.release()
        }
    }

    // the size pill's option `index` of a widget (its sizes in order, then x)
    function sizeOption(widget, index) {
        var bar = find(widget, function (item) { return item.types !== undefined && item.current !== undefined
                                                         && item.button !== undefined })
        if (!bar)
            return null
        var options = []
        var stack = [bar]
        while (stack.length) {
            var item = stack.shift()
            if (item.selected !== undefined && item.accent !== undefined)
                options.push(item)
            for (var i = 0; i < (item.children || []).length; i++)
                stack.push(item.children[i])
        }
        options.sort(function (a, b) { return a.mapToItem(bar, 0, 0).x - b.mapToItem(bar, 0, 0).x })
        return options[index] || null
    }

    function tapItem(item) {
        if (item)
            tap(item, item.width / 2, item.height / 2)
        else
            console.log("harness: film step", step, "failed: nothing to tap")
    }

    // [wait before the step in ms of scene time, the step]
    readonly property var clips: ({
        "move": [
            [1200, function () { scene.startFilm() }],
            [900, function () {
                var weather = widgetNamed("w2")
                press(weather, weather.width * 0.7, weather.height / 2)
            }],
            [700, function () {
                console.log("harness: film lifted", controller.dataLifted === widgetNamed("w2"))
                glideTo(fingerX, fingerY - 2 * grid.realCellHeight, 1100)
            }],
            [1500, function () { release() }],
            [1200, function () { grid.setEditMode(false) }],
            [1200, function () { harness.stopFrames() }]
        ],
        "add": [
            [1200, function () { scene.startFilm() }],
            [800, function () { holdIcon(8) }],
            [1300, function () {
                tapItem(find(pager, function (item) { return item.down !== undefined && item.margin !== undefined
                                                              && item.glass !== undefined }))
            }],
            [1600, function () {
                var choice = find(controller.gallery, function (item) {
                    return item.lifting !== undefined && item.width > 0 && item.parent && item.parent.parent
                            && item.parent.parent.kind === "status"
                })
                if (choice)
                    press(choice, choice.width / 2, choice.height / 3)
                else
                    console.log("harness: film step", step, "failed: no status preview")
            }],
            [800, function () {
                console.log("harness: film ghost", controller.ghost !== null)
                // onto the Calendar's row: the icons make way
                var to = grid.mapToItem(scene, 1.0 * grid.cellWidth, 2.5 * grid.realCellHeight)
                glideTo(to.x, to.y, 1300)
            }],
            [1700, function () { release() }],
            [1300, function () {
                console.log("harness: film added", JSON.stringify(controller.dataStore.list))
                grid.setEditMode(false)
            }],
            [1300, function () { harness.stopFrames() }]
        ],
        "resize": [
            [1200, function () { scene.startFilm() }],
            [800, function () { holdIcon(8) }],
            [1300, function () { tapItem(sizeOption(widgetNamed("w1"), 1)) }],
            [1600, function () {
                console.log("harness: film resized", JSON.stringify(controller.dataStore.list[0]))
                tapItem(sizeOption(widgetNamed("w1"), 0))
            }],
            [1600, function () { grid.setEditMode(false) }],
            [1300, function () { harness.stopFrames() }]
        ]
    })
    readonly property var script: clips[clip] || clips.move

    Timer {
        id: stepTimer

        onTriggered: {
            var entry = scene.script[scene.step]
            scene.step++
            try {
                entry[1]()
            } catch (e) {
                console.log("harness: film step", scene.step, "failed:", e)
            }
            if (scene.step < scene.script.length) {
                interval = scene.script[scene.step][0]
                start()
            }
        }
        Component.onCompleted: interval = scene.script[0][0]
    }

    // The home screen's look: the stock ambience picture, blurred under the app grid, and our glass's picture
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
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.rgba(Theme.overlayBackgroundColor, 0.2)
    }

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

    // the pager: the drag container and the parent of the gallery and the capsule
    Flickable {
        id: pager

        anchors.fill: parent
        contentHeight: height * 3
        interactive: true

        // what the hook's Loader gives the controller: the root LauncherGrid
        Flickable {
            id: grid

            readonly property QtObject model: scene.harness ? scene.harness.launcherModel : null
            readonly property int columns: scene.harness ? scene.harness.grid.columns : 5
            readonly property int rows: scene.harness ? scene.harness.grid.rows : 9
            readonly property real cellWidth: scene.harness ? scene.harness.grid.cellWidth : 200
            readonly property real cellHeight: Math.floor(pager.height / rows)
            readonly property real realCellHeight: cellHeight
            readonly property real topMargin: 0
            readonly property real bottomMargin: 0
            readonly property bool reserveFirstRow: false
            property bool launcherEditMode
            property Item reorderItem
            property QtObject gridManager: QtObject {
                readonly property Item dragContainer: pager
                readonly property Item pager: pager
                function scroll(up) {}
                function stopScrolling() {}
            }

            signal itemLaunched()

            function setEditMode(enabled) {
                launcherEditMode = enabled
            }

            function showFolder(folder) {}

            x: (scene.width - width) / 2
            y: Theme.paddingLarge
            width: columns * cellWidth
            height: pager.contentHeight
            contentHeight: height
            interactive: false

            Repeater {
                model: scene.harness ? scene.harness.launcherModel : null

                Item {
                    id: cell

                    readonly property int modelIndex: index
                    readonly property var block: controller.layout.cells[index] || null
                    readonly property bool isFolder: model.object.type === LauncherModel.Folder

                    x: block ? block.col * grid.cellWidth : 0
                    y: block ? block.row * grid.cellHeight : 0
                    width: grid.cellWidth
                    height: grid.cellHeight

                    Behavior on x { enabled: scene.settled; NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                    Behavior on y { enabled: scene.settled; NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

                    LauncherIcon {
                        id: launcherIcon

                        anchors.horizontalCenter: parent.horizontalCenter
                        y: (parent.height - height - label.height - Theme.paddingSmall) / 2
                        icon: model.object.iconId

                        Loader {
                            property QtObject folder: cell.isFolder ? model.object : null

                            anchors.fill: parent
                            active: cell.isFolder
                            source: Qt.resolvedUrl("../qml/folders/FolderPreview.qml")
                        }
                    }

                    Label {
                        id: label

                        anchors {
                            top: launcherIcon.bottom
                            topMargin: Theme.paddingSmall
                            left: parent.left
                            right: parent.right
                            leftMargin: Theme.paddingSmall / 2
                            rightMargin: Theme.paddingSmall / 2
                        }
                        horizontalAlignment: Text.AlignHCenter
                        truncationMode: TruncationMode.Fade
                        font.pixelSize: Theme.fontSizeTiny
                        text: model.object.title
                        // the stock edit mode hides the app names
                        visible: !grid.launcherEditMode || cell.isFolder
                    }
                }
            }
        }
    }

    HomeController {
        id: controller

        store: memoryTypes
        persistent: false
    }

    // the finger
    Rectangle {
        x: scene.fingerX - width / 2
        y: scene.fingerY - height / 2
        width: Theme.itemSizeMedium
        height: width
        radius: width / 2
        color: Theme.rgba("white", 0.28)
        border.color: Theme.rgba("white", 0.75)
        border.width: Math.round(Theme.pixelRatio * 2)
        opacity: scene.fingerDown ? 1 : 0
        scale: scene.fingerDown ? 1 : 1.4

        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 150 } }
    }
}
