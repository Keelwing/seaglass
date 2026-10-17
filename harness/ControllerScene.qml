// The controller scene: HomeController.qml on the launcher's folders, with a stand-in for the LauncherGrid it gets
// from the hook and in-memory folder types. It draws the first page as the hook does (each item at its block,
// widgets through WidgetTile.qml) and logs what the controller does: the layout, the hit test at a widget, and a
// rename that the widget type has to follow, in the harness's copy of the menu.
// Argument: the types as "Folder title=type,...", e.g. "Media=card,Office=panel,Tools=shelf", and optionally data
// widgets as "kind=size@slot,...", e.g. "Media=card clock=card@0,status=shelf@7": in memory, with sample data; the
// scene logs their blocks and the hit test over one.
import QtQuick 2.6
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import Nemo.Configuration 1.0
import org.nemomobile.lipstick 0.1
import "../qml/core"
import "../qml/widgets/group"

Item {
    id: scene

    property Item harness

    onHarnessChanged: {
        var map = {}
        var words = (harness.sceneArgument || "Media=card,Office=panel,Tools=shelf").split(" ")
        var specs = words[0].split(",")
        for (var i = 0; i < specs.length; i++) {
            var pair = specs[i].split("=")
            map[pair[0]] = pair[1]
        }
        memoryTypes.memory = map
        var data = []
        var dataSpecs = (words[1] || "").split(",")
        for (var d = 0; d < dataSpecs.length; d++) {
            var m = dataSpecs[d].match(/^(clock|status)=(card|shelf|panel)@(\d+)$/)
            if (m)
                data.push({ "id": "w" + (data.length + 1), "kind": m[1], "size": m[2], "at": parseInt(m[3], 10) })
        }
        controller.demoData = true
        controller.dataStore.memory = data
        console.log("harness: order before", scene.order(8))
        controller.grid = grid
    }

    function order(count) {
        var titles = []
        for (var i = 0; i < Math.min(count, harness.launcherModel.itemCount); i++)
            titles.push(harness.launcherModel.get(i).title)
        return titles.join(" | ")
    }

    FolderTypes {
        id: memoryTypes

        persistent: false
    }

    // what the hook's Loader gives the controller: the root LauncherGrid (geometry from the harness's grid)
    Flickable {
        id: grid

        readonly property QtObject model: scene.harness ? scene.harness.launcherModel : null
        readonly property int columns: scene.harness ? scene.harness.grid.columns : 5
        readonly property int rows: scene.harness ? scene.harness.grid.rows : 9
        readonly property real cellWidth: scene.harness ? scene.harness.grid.cellWidth : 200
        readonly property real cellHeight: scene.harness ? scene.harness.grid.cellHeight : 250
        readonly property real realCellHeight: cellHeight
        readonly property real topMargin: Theme.paddingSmall
        readonly property bool reserveFirstRow: false
        property bool launcherEditMode
        property Item reorderItem

        signal itemLaunched()

        function setEditMode(enabled) {
            launcherEditMode = enabled
        }

        function showFolder(folder) {
            console.log("harness: showFolder", folder.title)
        }

        x: (scene.width - width) / 2
        y: Theme.paddingLarge * 2
        width: columns * cellWidth
        height: rows * cellHeight
        contentHeight: height
        interactive: false

        // the delegates as the hook makes them: an item per model index, at its block
        Repeater {
            id: delegates

            model: scene.harness ? scene.harness.launcherModel : null

            Item {
                id: wrapper

                readonly property int modelIndex: index
                readonly property var block: controller.layout.cells[index] || null
                readonly property bool isWidget: block !== null && (block.w > 1 || block.h > 1)
                readonly property real targetX: block ? block.col * grid.cellWidth : 0
                readonly property real targetY: block ? block.row * grid.cellHeight : 0
                readonly property real targetWidth: block ? block.w * grid.cellWidth : grid.cellWidth
                readonly property real targetHeight: block ? block.h * grid.realCellHeight : grid.realCellHeight
                property bool reordering

                x: targetX
                y: targetY
                width: targetWidth
                height: targetHeight
                visible: block !== null && block.row < grid.rows

                Loader {
                    id: tile

                    property QtObject folder: model.object
                    property Item controller: controller
                    property Item delegate: wrapper
                    property bool editMode: grid.launcherEditMode
                    property bool dropTarget: false
                    property bool lifted: false

                    anchors.fill: parent
                    active: wrapper.isWidget
                    source: Qt.resolvedUrl("../qml/widgets/group/WidgetTile.qml")
                }

                LauncherIcon {
                    id: launcherIcon

                    visible: tile.status !== Loader.Ready
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Theme.paddingLarge
                    icon: model.object.iconId

                    Loader {
                        property QtObject folder: model.object.type === LauncherModel.Folder ? model.object : null
                        property Item controller: controller
                        property bool editMode: grid.launcherEditMode

                        anchors.fill: parent
                        active: folder !== null && !wrapper.isWidget
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
                    text: model.object.title
                }
            }
        }
    }

    HomeController {
        id: controller

        store: memoryTypes
        persistent: false
        onLayoutChanged: console.log("harness: layout rows", layout.rows, "footer", footerHeight)
    }

    // after the controller settled: the order, a hit test at the first widget, a rename
    Timer {
        interval: 1500
        running: scene.harness !== null
        onTriggered: {
            console.log("harness: order after", scene.order(8))
            var cells = controller.layout.cells
            for (var i = 0; i < cells.length; i++) {
                if (cells[i].w > 1) {
                    var hit = controller.itemAt(cells[i].col * grid.cellWidth + grid.cellWidth,
                                                cells[i].row * grid.cellHeight + grid.cellHeight)
                    console.log("harness: itemAt the first widget:", hit ? scene.harness.launcherModel.get(hit.modelIndex).title
                                                                         : "nothing", "(index", i + ")")
                    break
                }
            }
            var extra = controller.layout.extra
            for (var key in extra) {
                var r = controller.blockRect(extra[key])
                var over = controller.itemAt(r.x + r.width / 4, r.y + r.height / 2)
                console.log("harness: data widget", key, JSON.stringify(extra[key]), "itemAt its left half:",
                            over === null ? "null" : over.modelIndex !== undefined ? "index " + over.modelIndex : "?")
            }
            var folder = scene.harness.folderNamed("Media")
            if (folder) {
                folder.title = "Media Library"
                console.log("harness: renamed Media, types", JSON.stringify(memoryTypes.map))
            }
            dragTest.start()
        }
    }

    // Drags as the stock reorder logic does them: the last card aimed at a cell (row, col), moved to the index the
    // controller answers with, then its block checked. Aims: the top left corner, then lower right.
    property var aims: [[0, 0], [4, 3]]
    property int aimIndex: 0

    function lastCard() {
        var cells = controller.layout.cells
        for (var i = cells.length - 1; i >= 0; i--) {
            if (cells[i].w === 2 && cells[i].h === 2)
                return i
        }
        return -1
    }

    Timer {
        id: dragTest

        interval: 600
        onTriggered: {
            var moving = scene.lastCard()
            if (moving < 0) {
                console.log("harness: drag test needs a card")
                return
            }
            var row = scene.aims[scene.aimIndex][0]
            var col = scene.aims[scene.aimIndex][1]
            // the card's centre when its top left corner is on (row, col)
            var x = (col + 1) * grid.cellWidth
            var y = grid.originY + grid.topMargin + (row + 1) * grid.realCellHeight
            var dragged = delegates.itemAt(moving)
            dragged.reordering = true
            controller.liftedDelegate = dragged
            var item = controller.itemAt(x, y)
            controller.liftedDelegate = null
            dragged.reordering = false
            var target = item.modelIndex > moving ? item.modelIndex - 1 : item.modelIndex
            console.log("harness: drag", scene.harness.launcherModel.get(moving).title, "from", moving,
                        JSON.stringify(controller.layout.cells[moving]), "aimed at row", row, "col", col, "-> index", target)
            if (target !== moving)
                scene.harness.launcherModel.move(moving, target)
            settleCheck.target = target
            settleCheck.start()
        }
    }

    Timer {
        id: settleCheck

        property int target

        interval: 400
        onTriggered: {
            console.log("harness: after the drag", JSON.stringify(controller.layout.cells[target]))
            scene.aimIndex++
            if (scene.aimIndex < scene.aims.length)
                dragTest.start()
        }
    }


    Image {
        id: wallpaper

        anchors.fill: parent
        source: scene.harness ? "file://" + scene.harness.picture : ""
        fillMode: Image.PreserveAspectCrop
        visible: false
        z: -2
    }

    FastBlur {
        anchors.fill: parent
        source: wallpaper
        radius: 64
        z: -2
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.rgba(Theme.overlayBackgroundColor, 0.45)
        z: -1
    }
}
