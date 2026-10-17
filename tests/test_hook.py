"""Tests of hook/apply_hook.py on small stand-ins for the three stock QML files (the real files are Jolla's and are
not committed). With a base pulled from the phone (out/base/current, scripts/pull-base.sh), the committed hook is
also checked against it."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "hook"))
import apply_hook  # noqa: E402

GRID = """IconGridViewBase {
    id: gridview

    property bool reserveFirstRow: false

    signal itemLaunched

    function showFolder(folder) {
        openedChildFolder = folder
    }

    header: launcherClockConfig.launcher_clock_visible ? clockHeader : null

    Image {
        id: newFolderIcon

        y: target ? target.targetY + target.iconOffset : -20000
        anchors.horizontalCenter: target ? target.horizontalCenter : gridview.contentItem.horizontalCenter
    }

    EditableGridManager {
        id: gridManager

        supportsFolders: rootFolder
    }

    delegate: EditableGridDelegate {
        id: wrapper

        width: cellWidth
        height: gridview.realCellHeight
        isFolder: model.object.type == LauncherModel.Folder
        editMode: gridview.launcherEditMode
        scale: newFolderIcon.show && manager.folderIndex == index && !isFolder
               ? 0.5 : (reordering || manager.folderIndex == index || scaleUpTimer.running
                        ? 1.3 : 1)

        targetY: {
            var indexOffset = gridview.reserveFirstRow ? gridview.columns : 0
            return indexOffset
        }

        onPressAndHold: {
            if (!launcherEditMode) {
                setEditMode(true)
                wrapper.startReordering(true)
            }
        }

        LauncherIcon {
            id: launcherIcon

            icon: model.object.iconId
            pressed: down
            opacity: 1.0

            Text {
                text: folderItemCount > 0 ? folderItemCount : ""
                anchors.centerIn: parent
                visible: !isUpdating || model.object.updatingProgress < 0
                opacity: 1.0
            }
        }

        Label {
            id: launcherText

            visible: !launcherEditMode || isFolder
        }
    }
}
"""

FOLDER = """Rectangle {
    id: launcherFolder

    property int visibleRowCount: launcherGrid.rows - 2

    function close() {
        opacity = 0.0
        destroy(450)
    }

    opacity: 0.0
    Behavior on opacity { SmoothedAnimation { duration: 400; velocity: 1000 / duration } }

    gradient: Gradient {
        GradientStop { position: 0.0; color: Theme.rgba(Theme.overlayBackgroundColor, 1.0) }
        GradientStop { position: 1.0; color: Theme.rgba(Theme.overlayBackgroundColor, Theme.opacityOverlay) }
    }

    Component.onCompleted: opacity = 1.0

    MouseArea {
        Rectangle {
            MouseArea {
                id: icon

                LauncherIcon {
                    y: header.topPadding
                    icon: model.iconId
                    pressed: icon.pressed && icon.containsMouse

                    Text {
                        color: Theme.lightPrimaryColor
                        text: model.itemCount
                        anchors.centerIn: parent
                    }
                }
            }
        }
    }

    Component {
        id: iconSelectorComponent

        SilicaFlickable {
            contentHeight: folderIconGrid.height

            MouseArea {
                height: folderIconGrid.height

                Grid {
                    id: folderIconGrid

                    Repeater {
                        model: 16
                    }
                }
            }
        }
    }
}
"""

DELEGATE = """Item {
    id: wrapper

    property real targetY: y

    Timer {
        id: moveTimer

        onTriggered: {
            delegateContentItem.x = wrapper.x
        }
    }

    MouseArea {
        id: delegateContentItem

        function moved() {
            var item = manager.itemAt(gridViewPos.x, gridViewPos.y)
            if (item && item !== wrapper && item.y !== wrapper.y) {
                var yDist = item.y - targetY
                if (Math.abs(yDist) <= item.height - height/2) {
                    return
                }
            }
            if (item && item !== wrapper) {
                if (manager.supportsFolders) {
                    var offset = gridViewPos.x - item.x
                    var folderThreshold = manager.supportsFolders && !isFolder
                            ? item.width / 4 : item.width / 2
                    if (offset < folderThreshold) {
                        idx = item.modelIndex
                    } else if (offset >= item.width - folderThreshold) {
                        idx = item.modelIndex + 1
                    }
                }
            }

            var globalY = manager.pager.mapFromItem(delegateContentItem, 0, 0).y
            if (globalY <= 0 && manager.pager.contentY > 0) {
                manager.scroll(true)
            } else if (globalY + height >= manager.pager.height && manager.pager.contentY < maxContentY) {
                manager.scroll(false)
            }
        }

        x: wrapper.x
        y: wrapper.targetY
        width: wrapper.width
        height: wrapper.height

        states: State {
            PropertyChanges {
                target: delegateContentItem
                x: wrapper.x
            }
            PropertyChanges {
                target: wrapper
                onTargetYChanged: {
                    moveTimer.running = true
                }
            }
        }

        ParallelAnimation {
            id: slideMoveAnim

            NumberAnimation { to: wrapper.x }
            onStopped: {
                delegateContentItem.x = wrapper.x
            }
        }

        SequentialAnimation {
            ScriptAction { script: { delegateContentItem.x = wrapper.x } }
            onStopped: {
                delegateContentItem.x = wrapper.x
            }
        }
    }
}
"""


LAYER = """EdgeLayer {
    id: launcherLayer

    MenuBackground {
        z: -1
        anchors.fill: parent
        parent: launcherLayer.contentItem
    }

    Timer {
        interval: 400
    }
}
"""


SWITCHER = """SilicaFlickable {
    id: switcherRoot

    contentHeight: Math.ceil(switcherWrapper.y + switcherWrapper.height)

    MouseArea {
        id: switcherWrapper

        y: switcherGrid.baseY
        height: switcherGrid.implicitHeight <= switcherRoot.height - y
                ? switcherRoot.height - y
                : switcherGrid.implicitHeight + switcherGrid.rowSpacing - 1
        width: switcherRoot.width

        SwitcherGrid {
            id: switcherGrid

            columns: largeColumns
            statusBarHeight: 0

            Repeater {
                id: repeater
            }
        }

        Item {
            id: switcherItems
        }
    }

    CloseAllAppsHint {}
}
"""

SWITCHER_ITEM = """EditableGridDelegate {
    id: wrapper

    property var launcherItem
    property bool launching: pending

    function close() {
        closeAnimation.start()
    }

    WindowPixmapItem {
        id: windowPixmap
    }

    LauncherIcon {
        icon: launcherItem ? launcherItem.iconId : ""
        opacity: hideCover ? 1.0 : 0.0
    }

    Loader {
        id: loader

        width: parent.width
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: launching
    }

    StartupWatcher {
        running: wrapper.launching
    }
}
"""


COMPOSITOR = """Compositor {
    id: root

    Item {
        id: layersParent

        Layer {
            id: peekLayer

            Item {
                id: peekBlurSource

                Item {
                    id: applicationBlurSource

                    AppLayer {
                        id: appLayerItem

                        peekedAt: false
                        onRequestFocus: {
                            if (root.visible) {
                                root.unlock()
                            }
                        }
                    }

                    ApplicationCloseGestureHint {
                        id: closeGestureHint
                    }
                }
            }
        }

        OverlayLayer {
            id: overlayLayer
        }
    }
}
"""

STACK_LAYER = """Layer {
    id: layer

    property bool snapshotInUse
    property bool _effectiveDelaySwitch: delaySwitch || snapshotInUse

    readonly property int closingWindowId: 0

    enabled: active
    transitioning: showAnimation.running || showAnimation.retries > 0

    SequentialAnimation {
        id: showAnimation

        property int retries

        PauseAnimation { id: delayAnimation; duration: 150 }
        ScriptAction {
            script: {
                showAnimation.retries = 0
            }
        }
        FadeAnimator {
            target: layer
            duration: 300
            from: 0.0
            to: 1.0
            easing.type: Easing.InOutQuad
        }
    }
}
"""


def write_base(root, grid=GRID, folder=FOLDER, delegate=DELEGATE, layer=LAYER, switcher=SWITCHER,
               switcher_item=SWITCHER_ITEM, compositor=COMPOSITOR, stack_layer=STACK_LAYER):
    for path, text in ((apply_hook.FILES[0], folder), (apply_hook.FILES[1], grid), (apply_hook.FILES[2], delegate),
                       (apply_hook.FILES[3], layer), (apply_hook.FILES[4], switcher),
                       (apply_hook.FILES[5], switcher_item), (apply_hook.FILES[6], compositor),
                       (apply_hook.FILES[7], stack_layer)):
        target = Path(root, path)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")


class HookTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def patched(self, path):
        return apply_hook.build(self.base)[path][1]

    # The folder preview

    def test_grid_gets_the_preview_loader_before_the_count(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[1])
        self.assertLess(text.index("id: folderPreview"), text.index("            Text {"))
        self.assertIn(f'source: "{apply_hook.PREVIEW_URL}"', text)
        self.assertIn("active: isFolder && !seaglassWidget", text)
        self.assertIn("property bool dropTarget: isFolder && manager.folderIndex == index", text)
        self.assertIn("property Item controller: seaglass.item", text)

    def test_grid_count_hides_only_when_the_preview_is_ready(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[1])
        self.assertIn("visible: folderPreview.status !== Loader.Ready && "
                      "(!isUpdating || model.object.updatingProgress < 0)", text)
        # the label's visible binding stays as it was
        self.assertIn("visible: !launcherEditMode || isFolder\n", text)

    def test_folder_header_gets_the_loader_and_a_visible_binding(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[0])
        self.assertIn("id: headerFolderPreview", text)
        self.assertIn("property QtObject folder: model", text)
        self.assertIn("text: model.itemCount\n                        visible: headerFolderPreview.status "
                      "!== Loader.Ready\n", text)

    def test_folder_chooser_below_the_shapes(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[0])
        self.assertIn("contentHeight: folderIconGrid.height + (folderTypeChooser.item ? "
                      "folderTypeChooser.item.height : 0)", text)
        self.assertLess(text.index("id: folderIconGrid"), text.index("id: folderTypeChooser"))
        self.assertIn(f'source: "{apply_hook.CHOOSER_URL}"', text)
        self.assertIn("onLoaded: item.finished.connect(function () { selectIcon = false })", text)

    # The folder's opening and closing motion

    def test_folder_loads_its_motion(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[0])
        self.assertIn(f'source: "{apply_hook.MOTION_URL}"', text)
        self.assertIn("    readonly property bool seaglassMotion: folderMotion.item ? folderMotion.item.managed : false",
                      text)
        self.assertIn("        property Item grid: launcherGrid", text)

    def test_folder_motion_takes_over_only_when_loaded(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[0])
        self.assertIn("Behavior on opacity { enabled: !seaglassMotion; SmoothedAnimation", text)
        self.assertIn("Component.onCompleted: if (!seaglassMotion) opacity = 1.0", text)
        close = text[text.index("function close() {"):]
        self.assertLess(close.index("if (folderMotion.item && folderMotion.item.close())"),
                        close.index("opacity = 0.0"))

    def test_folder_on_glass_hides_the_stock_gradient(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[0])
        self.assertIn("    readonly property bool seaglassGlass: folderMotion.item ? folderMotion.item.glass === true : false",
                      text)
        self.assertIn("Theme.rgba(Theme.overlayBackgroundColor, seaglassGlass ? 0.0 : 1.0)", text)
        self.assertIn("Theme.rgba(Theme.overlayBackgroundColor, seaglassGlass ? 0.0 : Theme.opacityOverlay)", text)

    def test_show_folder_notes_the_origin(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[1])
        show = text[text.index("function showFolder(folder) {"):]
        self.assertLess(show.index("seaglass.item.noteOrigin(folder)"), show.index("openedChildFolder = folder"))

    # The app grid's wallpaper

    def test_layer_loads_the_wallpaper_under_the_icons(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[3])
        self.assertIn(f'source: "{apply_hook.WALLPAPER_URL}"', text)
        self.assertIn("        property Item edgeLayer: launcherLayer", text)
        loader = text[text.index("id: seaglassWallpaper"):]
        self.assertIn("z: -1", loader)
        self.assertIn("parent: launcherLayer.contentItem", loader)
        # after the stock background, so drawn above it at the same z
        self.assertLess(text.index("MenuBackground {"), text.index("id: seaglassWallpaper"))

    def test_stock_background_hides_only_while_covered(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[3])
        background = text[text.index("MenuBackground {"):text.index("Loader {")]
        self.assertIn("visible: !(seaglassWallpaper.item && seaglassWallpaper.item.covers)", background)

    # Widgets as blocks of the grid

    def test_grid_loads_the_controller_for_the_root_grid_only(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[1])
        self.assertIn(f'source: "{apply_hook.CONTROLLER_URL}"', text)
        self.assertIn("    readonly property var seaglassLayout: seaglass.item ? seaglass.item.layout : null", text)
        self.assertIn("        active: rootFolder", text)
        self.assertIn("    footer: seaglass.item ? seaglass.item.footer : null", text)
        # the stock header without the controller, and the stock offsets, stay
        self.assertIn(": (launcherClockConfig.launcher_clock_visible ? clockHeader : null)\n", text)
        self.assertIn("var indexOffset = gridview.reserveFirstRow ? gridview.columns : 0\n", text)

    def test_new_folder_shape_follows_the_drawn_position(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[1])
        self.assertIn("x: target ? target.targetX + (target.width - width) / 2 : "
                      "(gridview.contentItem.width - width) / 2", text)

    def test_grid_manager_finds_items_by_their_drawn_blocks(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[1])
        manager = text[text.index("EditableGridManager {"):text.index("delegate: EditableGridDelegate")]
        self.assertIn("function itemAt(x, y) {", manager)
        self.assertIn("return seaglass.item ? seaglass.item.itemAt(x, y) : view.itemAt(x, y)", manager)

    def test_delegate_geometry_falls_back_to_stock(self):
        write_base(self.base)
        delegate = self.patched(apply_hook.FILES[1])
        delegate = delegate[delegate.index("delegate: EditableGridDelegate"):]
        # the delegate keeps the stock cell: a taller one makes the GridView scroll to the current item
        self.assertIn("        width: cellWidth\n", delegate)
        self.assertIn("        height: gridview.realCellHeight\n", delegate)
        self.assertIn("targetX: seaglassBlock ? seaglassBlock.col * cellWidth : x", delegate)
        self.assertIn("targetWidth: seaglassBlock ? seaglassBlock.w * cellWidth : width", delegate)
        self.assertIn("targetHeight: seaglassBlock ? seaglassBlock.h * gridview.realCellHeight : height", delegate)
        self.assertIn("? (seaglassWidget ? 1.04 : 1.3) : 1)", delegate)
        target_y = delegate[delegate.index("targetY: {"):]
        self.assertLess(target_y.index("if (seaglassBlock)"), target_y.index("var indexOffset"))

    def test_widget_tile_replaces_icon_and_name_once_loaded(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[1])
        self.assertIn(f'source: "{apply_hook.TILE_URL}"', text)
        self.assertNotIn("property Item delegate: wrapper", text)
        self.assertIn("    property bool lifted: reordering", text)
        # always active: Qt 5's Binding would not give the icon its visible value back
        self.assertIn('Binding { target: launcherIcon; property: "visible"; '
                      'value: seaglassTile.status !== Loader.Ready }', text)
        self.assertIn('Binding { target: launcherText; property: "visible"; value: false; '
                      'when: seaglassTile.status === Loader.Ready }', text)
        self.assertLess(text.index("id: seaglassTile"), text.index("id: launcherText"))

    def test_search_row_takes_the_header_slot(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[1])
        self.assertIn("    header: seaglass.item && seaglass.item.header ? seaglass.item.header\n"
                      "                                                : (launcherClockConfig.launcher_clock_visible"
                      " ? clockHeader : null)", text)
        self.assertIn("        property Component clockHeader: launcherClockConfig.launcher_clock_visible"
                      " ? clockHeader : null", text)

    def test_glass_folder_empties_only_the_stock_shape(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[1])
        # the stock icon binding comes back when the glass goes: a Binding restores bindings
        self.assertIn('Binding { target: launcherIcon; property: "icon"; value: ""; '
                      'when: folderPreview.item !== null && folderPreview.item.glass === true }', text)

    def test_app_icons_and_folders_get_a_badge_and_a_peek(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[1])
        self.assertIn(f'source: "{apply_hook.BADGE_URL}"', text)
        self.assertIn("                property QtObject launcherItem: model.object\n", text)
        self.assertIn("                active: !isFolder\n", text)
        # the badge is the icon's last child: after the item count, before the icon's closing brace
        icon = text[text.index("id: launcherIcon"):text.index("id: launcherText")]
        self.assertLess(icon.index("folderItemCount > 0"), icon.index("id: seaglassBadge"))
        # the peek (an app's, or a folder's through its preview) comes before the stock edit mode, and only returns
        # when it shows
        hold = text[text.index("onPressAndHold: {"):]
        self.assertLess(hold.index("if ((seaglassBadge.item && seaglassBadge.item.peek())"),
                        hold.index("if (!launcherEditMode) {"))
        self.assertLess(hold.index("folderPreview.item.peek()"), hold.index("if (!launcherEditMode) {"))

    # The task switcher

    def test_switcher_loads_its_controller_with_the_stock_pieces(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[4])
        self.assertIn(f'source: "{apply_hook.SWITCHER_URL}"', text)
        for piece in ("switcher: switcherRoot", "grid: switcherGrid", "wrapper: switcherWrapper",
                      "covers: switcherItems", "coverRepeater: repeater", "coverModel: switcherModel",
                      "mruModel: mruSwitcherModel"):
            self.assertIn(piece, text)
        self.assertLess(text.index("id: seaglassSwitcher"), text.index("CloseAllAppsHint {}"))

    def test_switcher_makes_room_and_falls_back_to_stock(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[4])
        # the card row holds off the scrolling; else the stock content height
        self.assertIn("? height : Math.ceil(switcherWrapper.y + switcherWrapper.height)", text)
        # room for the recently closed apps (0 without the controller)
        self.assertIn("readonly property real seaglassExtra: seaglassSwitcher.item ? "
                      "seaglassSwitcher.item.extraHeight : 0", text)
        self.assertIn(": switcherGrid.implicitHeight + switcherGrid.rowSpacing - 1 + seaglassExtra", text)
        # room for the chips: the stock spacing plus the chip's (0 without the controller)
        self.assertIn(": spacing) + (seaglassSwitcher.item ? seaglassSwitcher.item.chipSpace : 0)", text)

    def test_switcher_pinch_area_holds_the_covers_and_is_off_without_the_controller(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[4])
        start = text.index("    PinchArea {\n")
        inside = text[start:apply_hook.block_end(text, start)]
        # the wrapper and with it the covers, nothing after it
        self.assertIn("    MouseArea {\n        id: switcherWrapper\n", inside)
        self.assertIn("id: switcherItems", inside)
        self.assertNotIn("CloseAllAppsHint", inside)
        self.assertIn("enabled: seaglassSwitcher.item ? seaglassSwitcher.item.pinchEnabled : false", inside)
        self.assertIn("property Item pinchArea: seaglassPinch", text)

    def test_switcher_item_gets_its_name_chip(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[5])
        self.assertIn(f'source: "{apply_hook.CHIP_URL}"', text)
        self.assertIn("property var launcherItem: wrapper.launcherItem", text)
        self.assertIn("property bool hidden: switcherRoot.housekeeping", text)
        self.assertIn("active: seaglassSwitcher.item ? seaglassSwitcher.item.chips : false", text)
        self.assertLess(text.index("id: seaglassChip"), text.index("id: loader"))

    # The animations

    def test_compositor_loads_the_animations_after_the_app_layer(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[6])
        self.assertIn(f'source: "{apply_hook.ANIMATIONS_URL}"', text)
        self.assertIn("property Item appLayer: appLayerItem", text)
        self.assertIn("seaglassTransitions: seaglassAnimations.item", text)
        # above the app layer (after it), as its sibling, in the same coordinates
        layer = text.index("AppLayer {")
        self.assertLess(apply_hook.block_end(text, layer), text.index("id: seaglassAnimations"))
        self.assertLess(text.index("id: seaglassAnimations"), text.index("ApplicationCloseGestureHint {"))
        self.assertIn("anchors.fill: parent", text[text.index("id: seaglassAnimations"):])
        # the closing effects' own item: before the layer that holds the app layer in the file, above it by z
        self.assertIn("property Item overlay: seaglassAboveLayers", text)
        self.assertLess(text.index("id: seaglassAboveLayers"), text.index("        Layer {\n            id: peekLayer\n"))
        self.assertIn("    id: seaglassAboveLayers\n            anchors.fill: parent\n            z: 1\n", text)

    def test_stack_layer_tells_of_the_fade_before_it_runs(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[7])
        self.assertIn("    property QtObject seaglassTransitions: null\n", text)
        ask = text.index("if (showAnimation.retries === 0 && layer.seaglassTransitions !== null)")
        self.assertLess(text.index("showAnimation.retries = 0"), ask)
        self.assertLess(ask, text.index("FadeAnimator {"))
        self.assertIn("layer.seaglassTransitions.opening(layer)\n", text)
        # the stock fade stays as it is
        self.assertIn("        FadeAnimator {\n            target: layer\n            duration: 300\n", text)

    def test_stack_layer_keeps_transitioning_while_an_effect_plays(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[7])
        self.assertIn("    transitioning: showAnimation.running || showAnimation.retries > 0\n"
                      "                   || (seaglassTransitions !== null && seaglassTransitions.playing)\n", text)

    def test_cover_loads_its_loading_effect_in_place_of_the_busy_indicator(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[5])
        self.assertIn(f'source: "{apply_hook.LOADING_URL}"', text)
        self.assertIn("active: wrapper.launching", text)
        self.assertIn("property var launcherItem: wrapper.launcherItem", text)
        playing = "(seaglassLoading.item && seaglassLoading.item.playing)"
        self.assertIn(f"        running: launching && !{playing}\n", text)
        self.assertIn(f"opacity: hideCover && !{playing} ? 1.0 : 0.0", text)
        # the startup watcher keeps its own line
        self.assertIn("        running: wrapper.launching\n    }", text)
        self.assertLess(text.index("BusyIndicator {"), text.index("id: seaglassLoading"))

    def test_cover_close_tells_the_switcher_first(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[5])
        self.assertIn("    function close() {\n        // seaglass: the closing effect over the cover", text)
        self.assertLess(text.index("seaglassSwitcher.item.coverClosing(wrapper)"), text.index("closeAnimation.start()"))

    def test_drag_delegate_draws_at_target_x(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[2])
        self.assertIn("    property real targetX: x\n", text)
        self.assertIn("    property real targetWidth: width\n", text)
        self.assertIn("    property real targetHeight: height\n", text)
        self.assertIn("        width: wrapper.targetWidth\n        height: wrapper.targetHeight\n", text)
        self.assertNotIn("wrapper.x", text)
        self.assertEqual(text.count("wrapper.targetX"), 7)
        self.assertIn("onTargetXChanged: {\n                    moveTimer.running = true", text)

    def test_drag_logic_compares_drawn_positions(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[2])
        self.assertIn("if (item && item !== wrapper && item.targetY !== wrapper.targetY "
                      "&& item.height === wrapper.height) {", text)
        self.assertIn("var yDist = item.targetY - targetY", text)
        self.assertIn("var offset = gridViewPos.x - item.targetX", text)
        self.assertIn("? item.targetWidth / 4 : item.targetWidth / 2", text)
        self.assertIn("} else if (offset >= item.targetWidth - folderThreshold) {", text)

    def test_paging_counts_one_cell_of_a_widget(self):
        write_base(self.base)
        text = self.patched(apply_hook.FILES[2])
        # the task switcher's grid has no cellHeight: there the item's own height
        self.assertIn("} else if (globalY + Math.min(height, manager.view.cellHeight || height) >= manager.pager.height\n"
                      "                       && manager.pager.contentY < maxContentY) {", text)

    def test_unexpected_uses_of_wrapper_x_stop(self):
        write_base(self.base, delegate=DELEGATE.replace("        x: wrapper.x\n", "        x: wrapper.x + wrapper.x\n"))
        with self.assertRaisesRegex(apply_hook.AnchorError, "wrapper.x"):
            apply_hook.build(self.base)

    def test_only_these_stock_lines_change(self):
        write_base(self.base)
        diff = apply_hook.unified_diff(apply_hook.build(self.base))
        removed = [line[1:].strip() for line in diff.splitlines()
                   if line.startswith("-") and not line.startswith("---")]
        self.assertEqual(sorted(removed), sorted([
            "anchors.horizontalCenter: target ? target.horizontalCenter : gridview.contentItem.horizontalCenter",
            "contentHeight: folderIconGrid.height",
            "contentHeight: Math.ceil(switcherWrapper.y + switcherWrapper.height)",
            "height: switcherGrid.implicitHeight <= switcherRoot.height - y",
            ": switcherGrid.implicitHeight + switcherGrid.rowSpacing - 1",
            "header: launcherClockConfig.launcher_clock_visible ? clockHeader : null",
            "Behavior on opacity { SmoothedAnimation { duration: 400; velocity: 1000 / duration } }",
            "Component.onCompleted: opacity = 1.0",
            "GradientStop { position: 0.0; color: Theme.rgba(Theme.overlayBackgroundColor, 1.0) }",
            "GradientStop { position: 1.0; color: Theme.rgba(Theme.overlayBackgroundColor, Theme.opacityOverlay) }",
            "visible: !isUpdating || model.object.updatingProgress < 0",
            "width: wrapper.width",
            "height: wrapper.height",
            "? item.width / 4 : item.width / 2",
            "} else if (offset >= item.width - folderThreshold) {",
            "? 1.3 : 1)",
            "delegateContentItem.x = wrapper.x",
            "if (item && item !== wrapper && item.y !== wrapper.y) {",
            "var yDist = item.y - targetY",
            "var offset = gridViewPos.x - item.x",
            "} else if (globalY + height >= manager.pager.height && manager.pager.contentY < maxContentY) {",
            "x: wrapper.x",
            "x: wrapper.x",
            "NumberAnimation { to: wrapper.x }",
            "delegateContentItem.x = wrapper.x",
            "ScriptAction { script: { delegateContentItem.x = wrapper.x } }",
            "delegateContentItem.x = wrapper.x",
            "opacity: hideCover ? 1.0 : 0.0",
            "running: launching",
        ]))

    def test_braces_stay_balanced(self):
        write_base(self.base)
        for path in apply_hook.FILES:
            text = self.patched(path)
            self.assertEqual(text.count("{"), text.count("}"), path)

    def test_missing_anchor_stops(self):
        write_base(self.base, grid=GRID.replace("id: launcherIcon", "id: appIcon"))
        with self.assertRaisesRegex(apply_hook.AnchorError, "not found"):
            apply_hook.build(self.base)

    def test_duplicate_anchor_stops(self):
        write_base(self.base, folder=FOLDER.replace("icon: model.iconId\n",
                                                    "icon: model.iconId\n                    icon: model.iconId\n"))
        with self.assertRaisesRegex(apply_hook.AnchorError, "not unique"):
            apply_hook.build(self.base)

    def test_header_count_with_a_visible_binding_stops(self):
        write_base(self.base, folder=FOLDER.replace("anchors.centerIn: parent\n",
                                                    "anchors.centerIn: parent\n                        visible: true\n"))
        with self.assertRaisesRegex(apply_hook.AnchorError, "visible binding"):
            apply_hook.build(self.base)

    def test_hooked_files_are_not_hooked_twice(self):
        write_base(self.base)
        files = apply_hook.build(self.base)
        write_base(self.base, grid=files[apply_hook.FILES[1]][1], folder=files[apply_hook.FILES[0]][1],
                   delegate=files[apply_hook.FILES[2]][1], layer=files[apply_hook.FILES[3]][1])
        with self.assertRaisesRegex(apply_hook.AnchorError, "already"):
            apply_hook.build(self.base)

    def test_check_mode(self):
        write_base(self.base)
        patch = Path(self.base, "unified_diff.patch")
        patch.write_text(apply_hook.unified_diff(apply_hook.build(self.base)), encoding="utf-8")
        script = str(REPO / "hook" / "apply_hook.py")
        self.assertEqual(subprocess.run([sys.executable, "-I", script, self.base, "--check", str(patch)]).returncode, 0)
        patch.write_text("stale\n", encoding="utf-8")
        result = subprocess.run([sys.executable, "-I", script, self.base, "--check", str(patch)], capture_output=True)
        self.assertEqual(result.returncode, 1)


def series_diff(base):
    """The committed hook of a base's Sailfish OS series (5.2.0.20 -> patchmanager/diffs/5.2.patch)."""
    version = (Path(base) / "OS_VERSION").read_text().strip()
    return REPO / "patchmanager" / "diffs" / (".".join(version.split(".")[:2]) + ".patch")


# the stock files pulled from the phone (make hook) and downloaded from Jolla (make check-hooks), when there are some
BASES = sorted([*(REPO / "out" / "compat").glob("*/base"), REPO / "out" / "base" / "current"])
BASES = [base for base in BASES if (base / "OS_VERSION").is_file()]


@unittest.skipUnless(BASES, "no stock files (make hook, or make check-hooks)")
class StockBaseTest(unittest.TestCase):
    def test_committed_hooks_match_the_stock_files(self):
        for base in BASES:
            with self.subTest(base=str(base.relative_to(REPO))):
                diff = apply_hook.unified_diff(apply_hook.build(base))
                self.assertEqual(series_diff(base).read_text(encoding="utf-8"), diff,
                                 f"the hook does not match {base.resolve().parent.name} (run: make hook)")


if __name__ == "__main__":
    unittest.main()
