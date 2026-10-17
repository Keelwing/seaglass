// The touch scene (docs/WIDGETS.md): HomeController.qml with data widgets on a stand-in grid and pager, driven by real
// mouse events (QtTest's TestEvent): taps on a widget and on a chip, a long press that starts the edit mode and drags
// the widget, a drag in edit mode, a widget dragged out of the gallery, and the gallery pulled down to close; then the
// player's buttons, the art, an event, the day, the weather, and a long press on a player's button. Sample data,
// in-memory widgets; every step logs "harness: touch ..." with what it found.
import QtQuick 2.6
import QtTest 1.0
import Sailfish.Silica 1.0
import org.nemomobile.lipstick 0.1
import Sailfish.Lipstick 1.0
import "../qml/core"
import "../qml/widgets/group"

Item {
    id: scene

    property Item harness
    property int step: 0
    property int failures: 0

    onHarnessChanged: {
        controller.demoData = true
        controller.dataStore.memory = [
            { "id": "w1", "kind": "clock", "size": "card", "at": 0 },
            { "id": "w2", "kind": "status", "size": "shelf", "at": 7 }
        ]
        controller.pager = pager
        controller.grid = grid
        stepTimer.start()
    }

    TestEvent {
        id: events
    }

    FolderTypes {
        id: memoryTypes

        persistent: false
    }

    function check(what, ok, detail) {
        if (!ok)
            failures++
        console.log("harness: touch", ok ? "OK  " : "FAIL", what, detail !== undefined ? detail : "")
    }

    function widgetNamed(id) {
        var children = grid.contentItem.children
        for (var i = 0; i < children.length; i++) {
            if (children[i].dragBody !== undefined && children[i].entry && children[i].entry.id === id)
                return children[i]
        }
        return null
    }

    function slotOf(id) {
        var list = controller.dataStore.list
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === id)
                return list[i].at
        }
        return -1
    }

    // the centre of a face's control (FaceButton key, "event:KEY"), in the widget's coordinates
    function controlPoint(widget, key) {
        var face = widget.faceItem
        for (var y = 0; y < face.height; y += 6) {
            for (var x = 0; x < face.width; x += 6) {
                if (face.controlAt(x, y) === key) {
                    var x2 = x
                    while (x2 < face.width && face.controlAt(x2, y) === key)
                        x2 += 3
                    var y2 = y
                    while (y2 < face.height && face.controlAt(x, y2) === key)
                        y2 += 3
                    return face.mapToItem(widget, (x + x2) / 2, (y + y2) / 2)
                }
            }
        }
        return null
    }

    function clickAt(widget, p) {
        events.mouseClick(widget, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1)
    }

    // the centre of the status face's chip `index`, in the widget's coordinates
    function chipPoint(widget, index) {
        var face = widget.faceItem
        for (var y = 0; y < face.height; y += 8) {
            for (var x = 0; x < face.width; x += 8) {
                if (face.controlAt(x, y) === index) {
                    var x2 = x
                    while (x2 < face.width && face.controlAt(x2, y) === index)
                        x2 += 4
                    return face.mapToItem(widget, (x + x2) / 2, y + Theme.paddingLarge)
                }
            }
        }
        return null
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

    property real liftedY

    // where the press is, in the scene (the items under the finger move while they are dragged)
    property real pressX
    property real pressY

    function press(item, x, y) {
        var p = item.mapToItem(scene, x, y)
        pressX = p.x
        pressY = p.y
        events.mousePress(scene, pressX, pressY, Qt.LeftButton, Qt.NoModifier, -1)
    }

    function moveBy(dx, dy) {
        var n = 8
        for (var i = 1; i <= n; i++)
            events.mouseMove(scene, pressX + dx * i / n, pressY + dy * i / n, -1, Qt.LeftButton)
    }

    function release(dx, dy) {
        events.mouseRelease(scene, pressX + dx, pressY + dy, Qt.LeftButton, Qt.NoModifier, -1)
    }

    // [wait before the step in ms, the step]
    property var script: [
        [1500, function () {
            var clock = widgetNamed("w1")
            var status = widgetNamed("w2")
            check("widgets are drawn", clock !== null && status !== null && clock.visible && status.visible,
                  clock ? JSON.stringify(controller.layout.extra) : "")
            // a tap on the Wi-Fi chip (sample data: it cannot switch, so it asks for the settings page)
            var p = chipPoint(status, 0)
            check("the Wi-Fi chip is found", p !== null)
            if (p)
                events.mouseClick(status, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1)
        }],
        [300, function () {
            check("a tap on the chip asks for its page", controller.lastRequest === "settings system_settings/connectivity/wlan",
                  controller.lastRequest)
            controller.lastRequest = ""
            var status = widgetNamed("w2")
            events.mouseClick(status, 40, 40, Qt.LeftButton, Qt.NoModifier, -1)
        }],
        [300, function () {
            check("a tap beside the chips opens the battery page",
                  controller.lastRequest === "settings system_settings/system/battery", controller.lastRequest)
            // a long press on the Bluetooth chip: the edit mode, and the widget lifted at once
            var status = widgetNamed("w2")
            var p = chipPoint(status, 2)
            press(status, p.x, p.y)
        }],
        [1200, function () {
            check("a long press on a chip starts the edit mode", grid.launcherEditMode === true)
            check("... and lifts the widget", controller.dataLifted === widgetNamed("w2"))
            liftedY = widgetNamed("w2").dragBody.y
            // carried three rows down
            moveBy(0, 3 * grid.realCellHeight)
        }],
        [300, function () {
            var status = widgetNamed("w2")
            var moved = status.dragBody.y - liftedY
            check("the body follows the finger", status.dragBody.parent === pager
                  && Math.abs(moved - 3 * grid.realCellHeight) < 2, "moved " + Math.round(moved))
            check("a slot is planned", controller.dataPreview !== null,
                  controller.dataPreview ? JSON.stringify(controller.layout.extra.w2) : "")
            release(0, 3 * grid.realCellHeight)
        }],
        [500, function () {
            var status = widgetNamed("w2")
            check("dropped: the slot is stored", slotOf("w2") !== 7, "slot " + slotOf("w2"))
            check("dropped: the body is back in the grid", status.dragBody.parent === status && !status.lifted)
            // in edit mode: a press, a moment, and a drag of the clock two cells right
            var clock = widgetNamed("w1")
            press(clock, clock.width / 2, clock.height / 3)
        }],
        [400, function () {
            check("in edit mode a press lifts the widget", controller.dataLifted === widgetNamed("w1"))
            moveBy(2 * grid.cellWidth + 10, 0)
        }],
        [300, function () {
            release(2 * grid.cellWidth + 10, 0)
        }],
        [500, function () {
            var block = controller.layout.extra.w1
            check("the clock moved right", block && block.col === 2, JSON.stringify(block))
            // the gallery: a long press on its first preview, and the widget carried onto the grid
            controller.openGallery()
        }],
        [700, function () {
            var gallery = controller.gallery
            check("the gallery is open", gallery !== null && gallery.opened)
            var choice = find(gallery, function (item) { return item.lifting !== undefined && item.width > 0 })
            check("a preview is found", choice !== null)
            press(choice, choice.width / 2, choice.height / 3)
        }],
        [1200, function () {
            check("a long press lifts a widget out of the gallery", controller.ghost !== null && controller.gallery.ghosting)
            var to = grid.mapToItem(scene, 3 * grid.cellWidth, 5 * grid.realCellHeight)
            moveBy(to.x - pressX, to.y - pressY)
        }],
        [300, function () {
            check("its landing place is planned", controller.layout.extra["new"] !== undefined,
                  JSON.stringify(controller.layout.extra["new"]))
            var to = grid.mapToItem(scene, 3 * grid.cellWidth, 5 * grid.realCellHeight)
            release(to.x - pressX, to.y - pressY)
        }],
        [500, function () {
            var list = controller.dataStore.list
            check("dropped: a third widget", list.length === 3, JSON.stringify(list))
            check("the gallery closed", !controller.galleryOpen)
            // the gallery pulled down by its handle closes
            controller.openGallery()
        }],
        [700, function () {
            var header = find(controller.gallery, function (item) { return item.letGo !== undefined })
            check("the gallery's handle is found", header !== null)
            press(header, header.width / 2, header.height / 2)
            moveBy(0, Screen.height * 0.3)
        }],
        [200, function () {
            check("the sheet follows the pull", controller.gallery.pullOffset > Screen.height * 0.2,
                  Math.round(controller.gallery.pullOffset))
            release(0, Screen.height * 0.3)
        }],
        [600, function () {
            check("pulled down, the gallery closes", !controller.galleryOpen)
            // 0.12: Now playing, Next event and Weather, out of the edit mode
            grid.setEditMode(false)
            controller.dataStore.memory = [
                { "id": "w11", "kind": "player", "size": "card", "at": 0 },
                { "id": "w12", "kind": "event", "size": "card", "at": 2 },
                { "id": "w13", "kind": "weather", "size": "shelf", "at": 10 }
            ]
        }],
        [1200, function () {
            var player = widgetNamed("w11")
            check("the 0.12 widgets are drawn", player !== null && widgetNamed("w12") !== null && widgetNamed("w13") !== null
                  && player.faceItem !== null, JSON.stringify(controller.layout.extra))
            check("the player plays (sample)", player.source !== null && player.source.playing)
            var p = controlPoint(player, "playPause")
            check("the play/pause button is found", p !== null)
            controller.lastRequest = ""
            clickAt(player, p)
        }],
        [300, function () {
            var player = widgetNamed("w11")
            check("a tap on play/pause pauses", player.source.lastAction === "playPause" && !player.source.playing,
                  player.source.lastAction)
            check("... and opens nothing", controller.lastRequest === "", controller.lastRequest)
            clickAt(player, controlPoint(player, "next"))
        }],
        [300, function () {
            var player = widgetNamed("w11")
            check("a tap on next skips", player.source.lastAction === "next", player.source.lastAction)
            // the art: not a button, so the player comes up
            clickAt(player, Qt.point(player.width / 2, player.height * 0.25))
        }],
        [300, function () {
            check("a tap on the art brings the player up",
                  controller.lastRequest === "player /usr/share/applications/jolla-mediaplayer.desktop",
                  controller.lastRequest)
            var event = widgetNamed("w12")
            var p = controlPoint(event, "event:demo-1")
            check("the next event is found", p !== null)
            clickAt(event, p)
        }],
        [300, function () {
            var event = widgetNamed("w12")
            check("a tap on an event opens it", controller.lastRequest === "event demo-1"
                  && event.source.lastAction === "event demo-1", controller.lastRequest)
            // the day, at the top: the Calendar on today
            clickAt(event, Qt.point(event.width * 0.3, event.height * 0.12))
        }],
        [300, function () {
            var event = widgetNamed("w12")
            check("a tap on the day opens the Calendar on today", controller.lastRequest === "calendar "
                  && event.source.lastAction === "today", controller.lastRequest)
            var weather = widgetNamed("w13")
            clickAt(weather, Qt.point(weather.width / 2, weather.height / 2))
        }],
        [300, function () {
            check("a tap on the weather opens the Weather app",
                  controller.lastRequest === "app /usr/share/applications/sailfish-weather.desktop", controller.lastRequest)
            // a long press on a player's button: the edit mode and the widget lifted, the button not pressed
            var player = widgetNamed("w11")
            var p = controlPoint(player, "previous")
            player.source.lastAction = ""
            press(player, p.x, p.y)
        }],
        [1200, function () {
            var player = widgetNamed("w11")
            check("a long press on a player's button starts the edit mode", grid.launcherEditMode === true)
            check("... and lifts the widget", controller.dataLifted === player)
            release(0, 0)
        }],
        [500, function () {
            var player = widgetNamed("w11")
            check("... without using the button", player.source.lastAction === "", player.source.lastAction)
            check("dropped in place", !player.lifted && player.dragBody.parent === player)
            console.log("harness: touch done,", scene.failures, "failures")
        }]
    ]

    Timer {
        id: stepTimer

        onTriggered: {
            var entry = scene.script[scene.step]
            scene.step++
            try {
                entry[1]()
            } catch (e) {
                scene.check("step " + scene.step, false, String(e))
            }
            if (scene.step < scene.script.length) {
                interval = scene.script[scene.step][0]
                start()
            }
        }
        Component.onCompleted: interval = scene.script[0][0]
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

            function showFolder(folder) {
                console.log("harness: showFolder", folder.title)
            }

            x: (scene.width - width) / 2
            width: columns * cellWidth
            height: pager.contentHeight
            contentHeight: height
            interactive: false

            Repeater {
                model: scene.harness ? scene.harness.launcherModel : null

                Item {
                    readonly property int modelIndex: index
                    readonly property var block: controller.layout.cells[index] || null
                    readonly property real targetX: block ? block.col * grid.cellWidth : 0
                    readonly property real targetY: block ? block.row * grid.cellHeight : 0

                    x: targetX
                    y: targetY
                    width: grid.cellWidth
                    height: grid.cellHeight

                    LauncherIcon {
                        anchors.centerIn: parent
                        icon: model.object.iconId
                    }
                }
            }
        }
    }

    HomeController {
        id: controller

        // the faces' requests, for the checks
        property string lastRequest

        store: memoryTypes
        persistent: false
        onDataRequestMade: lastRequest = what + " " + argument
    }
}
