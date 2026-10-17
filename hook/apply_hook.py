#!/usr/bin/env python3
"""The Patchmanager hook of seaglass: a few lines in the stock home screen QML that load our own QML
from /usr/share/seaglass, and keep the stock look when that fails to load.

This script is the source of the hook. It applies the edits to the stock files by anchors and writes the
unified diff that Patchmanager applies (patchmanager/unified_diff.patch). An anchor that is missing or
not unique stops it, so a changed home screen (a new Sailfish OS version) is never patched blindly.

  apply_hook.py BASE                  print the unified diff for the stock files under BASE
  apply_hook.py BASE --out DIR        also write the patched files under DIR
  apply_hook.py BASE --check PATCH    exit 1 when PATCH differs from the diff for BASE
  apply_hook.py --files               list the stock files the hook changes

BASE (and DIR) hold the files at their device paths: BASE/usr/share/lipstick-jolla-home-qt5/launcher/...
The stock files are Jolla's (proprietary): scripts/pull-base.sh copies them from the phone into out/base/,
which is not committed.
"""
import argparse
import difflib
import sys
from pathlib import Path

HOME = "usr/share/lipstick-jolla-home-qt5"
# our QML module (qml/ of this repository), one folder per feature
MODULE = "file:///usr/share/seaglass/qml/"
PREVIEW_URL = MODULE + "folders/FolderPreview.qml"
CONTROLLER_URL = MODULE + "core/HomeController.qml"
CHOOSER_URL = MODULE + "widgets/group/FolderTypeChooser.qml"
TILE_URL = MODULE + "widgets/group/WidgetTile.qml"
MOTION_URL = MODULE + "folders/FolderMotion.qml"
WALLPAPER_URL = MODULE + "glass/LauncherWallpaper.qml"
BADGE_URL = MODULE + "badges/IconBadge.qml"
SWITCHER_URL = MODULE + "switcher/SwitcherController.qml"
CHIP_URL = MODULE + "switcher/SwitcherChip.qml"
# every file of ours the hook loads
URLS = [PREVIEW_URL, CONTROLLER_URL, CHOOSER_URL, TILE_URL, MOTION_URL, WALLPAPER_URL, BADGE_URL, SWITCHER_URL,
        CHIP_URL]

# The stock files the hook changes, in diff order
FILES = [f"{HOME}/launcher/LauncherFolder.qml", f"{HOME}/launcher/LauncherGrid.qml",
         f"{HOME}/main/EditableGridDelegate.qml", f"{HOME}/layers/LauncherLayer.qml",
         f"{HOME}/switcher/Switcher.qml", f"{HOME}/switcher/SwitcherItem.qml"]


class AnchorError(Exception):
    pass


def find_once(text, anchor, start=0, end=None, what=""):
    """The position of anchor in text[start:end]; it must occur exactly once there."""
    end = len(text) if end is None else end
    pos = text.find(anchor, start, end)
    if pos < 0:
        raise AnchorError(f"{what}: anchor not found: {anchor.strip()!r}")
    if text.find(anchor, pos + 1, end) >= 0:
        raise AnchorError(f"{what}: anchor not unique: {anchor.strip()!r}")
    return pos


def block_end(text, open_pos):
    """The position after the closing brace of the QML block whose "{" is the first one at open_pos."""
    depth = 0
    for i in range(text.index("{", open_pos), len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return i + 1
    raise AnchorError("unbalanced braces")


def indent(lines, spaces):
    return "".join((" " * spaces + line if line else "") + "\n" for line in lines)


def insert_after(text, anchor, lines, spaces, what):
    """text with lines inserted after the unique line anchor, behind a blank line."""
    pos = find_once(text, anchor, what=what) + len(anchor)
    return text[:pos] + "\n" + indent(lines, spaces) + text[pos:]


def replace_line(text, old, new, what):
    """text with the unique line old replaced by new (both without the line break)."""
    pos = find_once(text, old + "\n", what=what)
    return text[:pos] + new + text[pos + len(old):]


def loader(spaces, ident, props, active=None):
    return indent([
        "// seaglass: small icons of the folder's apps (/usr/share/seaglass);",
        "// the item count below stays when they cannot be loaded",
        "Loader {",
        f"    id: {ident}",
        *[f"    property {p}" for p in props],
        "    anchors.fill: parent",
        *([f"    active: {active}"] if active else []),
        f'    source: "{PREVIEW_URL}"',
        "}",
        "",
    ], spaces)


def hook_grid(text):
    """LauncherGrid.qml: the app grid's delegate. The folder's LauncherIcon gets the Loader before its
    item-count Text, and the Text hides once the preview is loaded."""
    what = "LauncherGrid.qml"
    icon = find_once(text, "        LauncherIcon {\n            id: launcherIcon\n", what=what)
    icon_end = block_end(text, icon)
    count = find_once(text, "\n            Text {\n", icon, icon_end, what) + 1
    count_end = block_end(text, count)
    visible = "                visible: "
    vis = find_once(text, visible, count, count_end, what)
    line_end = text.index("\n", vis)
    expr = text[vis + len(visible):line_end]
    new_visible = f"{visible}folderPreview.status !== Loader.Ready && ({expr})"
    text = text[:vis] + new_visible + text[line_end:]
    props = [
        "QtObject folder: isFolder ? model.object : null",
        "bool pressed: down",
        "bool dropTarget: isFolder && manager.folderIndex == index",
        "Item controller: seaglass.item",
        "bool editMode: launcherEditMode",
    ]
    text = text[:count] + loader(12, "folderPreview", props, active="isFolder && !seaglassWidget") + text[count:]
    return hook_layout(text)


def hook_layout(text):
    """LauncherGrid.qml: group widgets as blocks of the grid. The root grid loads HomeController.qml, whose
    layout gives each delegate its drawn block (targetX, targetY, width, height); a widget folder draws its tile
    (WidgetTile.qml) instead of its icon and name; the drag finds items by their drawn blocks; a footer makes the
    pages for the rows the widgets add. Without the controller every changed value is the stock one."""
    what = "LauncherGrid.qml"
    text = insert_after(text, "    signal itemLaunched\n", [
        "// seaglass: group widgets as blocks of the grid (/usr/share/seaglass);",
        "// the stock grid stays when they cannot be loaded",
        "readonly property var seaglassLayout: seaglass.item ? seaglass.item.layout : null",
        "",
        "Loader {",
        "    id: seaglass",
        "    property Item grid: gridview",
        "    // the stock experimental clock, which the search row goes under when it is on",
        "    property Component clockHeader: launcherClockConfig.launcher_clock_visible ? clockHeader : null",
        "    active: rootFolder",
        f'    source: "{CONTROLLER_URL}"',
        "}",
    ], 4, what)
    text = insert_after(text, "    header: launcherClockConfig.launcher_clock_visible ? clockHeader : null\n", [
        "// seaglass: room for the rows the widgets add, so that the pager makes enough pages",
        "footer: seaglass.item ? seaglass.item.footer : null",
    ], 4, what)
    # the search row in the stock header slot, with the clock above it when that is on
    text = replace_line(
        text, "    header: launcherClockConfig.launcher_clock_visible ? clockHeader : null",
        "    header: seaglass.item && seaglass.item.header ? seaglass.item.header\n"
        "                                                : (launcherClockConfig.launcher_clock_visible ? clockHeader : null)",
        what)
    # the "new folder" shape shown while an app is held over another: at the drawn x (targetX), which is the
    # GridView's x without widgets
    text = replace_line(
        text, "        anchors.horizontalCenter: target ? target.horizontalCenter : gridview.contentItem.horizontalCenter",
        "        x: target ? target.targetX + (target.width - width) / 2 : (gridview.contentItem.width - width) / 2",
        what)
    text = insert_after(text, "    function showFolder(folder) {\n", [
        "// seaglass: where the folder opens from (its icon or widget), for its opening motion",
        "if (seaglass.item)",
        "    seaglass.item.noteOrigin(folder)",
    ], 8, what)
    text = insert_after(text, "    EditableGridManager {\n        id: gridManager\n", [
        "// seaglass: the item drawn at a point (with widgets the drawn grid is not the GridView's)",
        "function itemAt(x, y) {",
        "    return seaglass.item ? seaglass.item.itemAt(x, y) : view.itemAt(x, y)",
        "}",
    ], 8, what)
    text = insert_after(text, "        editMode: gridview.launcherEditMode\n", [
        "// seaglass: the drawn block of this item; a widget folder spans several cells",
        "readonly property var seaglassBlock: gridview.seaglassLayout ? gridview.seaglassLayout.cells[index] || null",
        "                                                             : null",
        "readonly property bool seaglassWidget: seaglassBlock !== null && (seaglassBlock.w > 1 || seaglassBlock.h > 1)",
        "// the delegate itself keeps the stock cell size: the GridView scrolls to show the whole current item",
        "// (set on every press), so a taller delegate would scroll the grid; only what is drawn is the block",
        "targetX: seaglassBlock ? seaglassBlock.col * cellWidth : x",
        "targetWidth: seaglassBlock ? seaglassBlock.w * cellWidth : width",
        "targetHeight: seaglassBlock ? seaglassBlock.h * gridview.realCellHeight : height",
    ], 8, what)
    # a widget lifts a little: at the icons' 1.3 a large tile would cover half the page
    text = replace_line(text, "                        ? 1.3 : 1)",
                        "                        ? (seaglassWidget ? 1.04 : 1.3) : 1)", what)
    text = insert_after(text, "        targetY: {\n", [
        "// seaglass: the block's row, on its page",
        "if (seaglassBlock)",
        "    return gridview.originY + Math.floor(seaglassBlock.row / gridview.rows) * launcherPager.height",
        "            + gridview.topMargin + (seaglassBlock.row % gridview.rows) * gridview.realCellHeight",
    ], 12, what)
    # the app's notification badge: the icon's last child, so that it is drawn over it and moves with it
    icon = find_once(text, "        LauncherIcon {\n            id: launcherIcon\n", what=what)
    close_line = text.rindex("\n", 0, block_end(text, icon) - 1) + 1
    text = text[:close_line] + indent([
        "",
        "// seaglass: the app's notification badge (/usr/share/seaglass)",
        "Loader {",
        "    id: seaglassBadge",
        "    property QtObject launcherItem: model.object",
        "    anchors.fill: parent",
        "    active: !isFolder",
        f'    source: "{BADGE_URL}"',
        "}",
    ], 12) + text[close_line:]
    # a long press on a badged app or folder may peek at its notifications instead (the peek has Edit grid)
    text = insert_after(text, "        onPressAndHold: {\n", [
        "// seaglass: a badged app's or folder's notifications instead of the edit mode, when the peek is on",
        "if ((seaglassBadge.item && seaglassBadge.item.peek())",
        "        || (folderPreview.item && folderPreview.item.peek !== undefined && folderPreview.item.peek()))",
        "    return",
    ], 12, what)
    label = find_once(text, "        Label {\n            id: launcherText\n", what=what)
    tile = indent([
        "// seaglass: a widget folder draws its group widget instead of its icon and name",
        "Loader {",
        "    id: seaglassTile",
        "    property QtObject folder: model.object",
        "    property Item controller: seaglass.item",
        "    property bool editMode: launcherEditMode",
        "    property bool dropTarget: manager.folderIndex == index",
        "    property bool lifted: reordering",
        "    anchors.fill: parent",
        "    active: seaglassWidget",
        f'    source: "{TILE_URL}"',
        "}",
        # Qt 5's Binding restores only bindings when "when" turns false, not values: the icon has no stock visible
        # binding, so it is bound for good (as stock while no tile is loaded); the name's stock binding comes back
        'Binding { target: launcherIcon; property: "visible"; value: seaglassTile.status !== Loader.Ready }',
        'Binding { target: launcherText; property: "visible"; value: false; when: seaglassTile.status === Loader.Ready }',
        "// seaglass: a glass folder draws its glass tile instead of the stock shape; the small icons are",
        "// the shape's children, so only its picture goes (the stock icon binding comes back)",
        'Binding { target: launcherIcon; property: "icon"; value: ""; when: folderPreview.item !== null && folderPreview.item.glass === true }',
        "",
    ], 8)
    return text[:label] + tile + text[label:]


def hook_delegate(text):
    """main/EditableGridDelegate.qml: the draggable delegate draws itself at targetX (by default its x, as in
    stock), and the reorder logic compares drawn positions: with widgets the drawn grid is not the GridView's."""
    what = "EditableGridDelegate.qml"
    text = insert_after(text, "    property real targetY: y\n", [
        "// seaglass: the drawn x and size, as targetY is the drawn y (LauncherGrid.qml sets them all)",
        "property real targetX: x",
        "property real targetWidth: width",
        "property real targetHeight: height",
    ], 4, what)
    text = replace_line(text, "        width: wrapper.width", "        width: wrapper.targetWidth", what)
    text = replace_line(text, "        height: wrapper.height", "        height: wrapper.targetHeight", what)
    text = replace_line(text, "                            ? item.width / 4 : item.width / 2",
                        "                            ? item.targetWidth / 4 : item.targetWidth / 2", what)
    text = replace_line(text, "                    } else if (offset >= item.width - folderThreshold) {",
                        "                    } else if (offset >= item.targetWidth - folderThreshold) {", what)
    uses = text.count("wrapper.x")
    if uses != 7:
        raise AnchorError(f"{what}: {uses} uses of wrapper.x, the hook expects 7")
    text = text.replace("wrapper.x", "wrapper.targetX")
    text = insert_after(text, "                onTargetYChanged: {\n                    moveTimer.running = true\n                }\n", [
        "onTargetXChanged: {",
        "    moveTimer.running = true",
        "}",
    ], 16, what)
    # The "differing heights" guard compares the GridView's y with the drawn targetY. In the stock launcher all
    # items are one cell high and the rows one cell apart, so it never returns there. With widgets the GridView's
    # rows and the drawn ones differ by whole rows, and the mixed comparison could stop the reorder at random:
    # compare drawn positions, and items of one height only (a widget is taller than the app dragged to it).
    text = replace_line(
        text, "            if (item && item !== wrapper && item.y !== wrapper.y) {",
        "            if (item && item !== wrapper && item.targetY !== wrapper.targetY && item.height === wrapper.height) {",
        what)
    text = replace_line(text, "                var yDist = item.y - targetY",
                        "                var yDist = item.targetY - targetY", what)
    text = replace_line(text, "                    var offset = gridViewPos.x - item.x",
                        "                    var offset = gridViewPos.x - item.targetX", what)
    # Scrolling to the next page starts when the dragged item's bottom reaches the page's: a widget is rows high,
    # so it started while the widget was still well inside the page. Count one cell at most (a stock item is one
    # cell high: as stock). The task switcher's grid (a plain Grid) has no cellHeight: there the item's height
    return replace_line(
        text,
        "            } else if (globalY + height >= manager.pager.height && manager.pager.contentY < maxContentY) {",
        "            } else if (globalY + Math.min(height, manager.view.cellHeight || height) >= manager.pager.height\n"
        "                       && manager.pager.contentY < maxContentY) {", what)


def hook_folder(text):
    """LauncherFolder.qml: the header of an open folder shows the folder icon with the item count."""
    what = "LauncherFolder.qml"
    icon_line = find_once(text, "                    icon: model.iconId\n", what=what)
    icon = text.rfind("                LauncherIcon {\n", 0, icon_line)
    if icon < 0:
        raise AnchorError(f"{what}: no LauncherIcon around 'icon: model.iconId'")
    icon_end = block_end(text, icon)
    count = find_once(text, "\n                    Text {\n", icon_line, icon_end, what) + 1
    count_end = block_end(text, count)
    if "visible:" in text[count:count_end]:
        raise AnchorError(f"{what}: the header's count Text has a visible binding now")
    item_count = find_once(text, "                        text: model.itemCount\n", count, count_end, what)
    after = text.index("\n", item_count) + 1
    text = (text[:after] + "                        visible: headerFolderPreview.status !== Loader.Ready\n"
            + text[after:])
    props = [
        "QtObject folder: model",
        "bool pressed: icon.pressed && icon.containsMouse",
    ]
    text = text[:count] + loader(20, "headerFolderPreview", props) + text[count:]
    return hook_motion(hook_chooser(text))


def hook_chooser(text):
    """LauncherFolder.qml: below the 16 folder shapes of the icon selector, how the folder shows on the home
    screen (FolderTypeChooser.qml); the selector's flickable grows by its height."""
    what = "LauncherFolder.qml"
    text = replace_line(
        text, "            contentHeight: folderIconGrid.height",
        "            contentHeight: folderIconGrid.height + (folderTypeChooser.item ? folderTypeChooser.item.height : 0)",
        what)
    grid = find_once(text, "                Grid {\n                    id: folderIconGrid\n", what=what)
    end = block_end(text, grid)
    return text[:end] + "\n\n" + indent([
        "// seaglass: how the folder shows on the home screen, below the shapes",
        "Loader {",
        "    id: folderTypeChooser",
        "    property QtObject folder: launcherFolder.model",
        "    y: folderIconGrid.height",
        "    width: folderIconGrid.width",
        f'    source: "{CHOOSER_URL}"',
        "    onLoaded: item.finished.connect(function () { selectIcon = false })",
        "}",
    ], 16).rstrip("\n") + text[end:]


def hook_motion(text):
    """LauncherFolder.qml: how the folder opens and closes (FolderMotion.qml). While it manages the motion (any
    style but "fade"), the stock fade is off, the folder's opacity is its, and close() plays the closing motion
    first; without it, or with "fade", the stock fade. While it puts the folder on glass, the stock dark
    gradient is transparent."""
    what = "LauncherFolder.qml"
    text = insert_after(text, "    property int visibleRowCount: launcherGrid.rows - 2\n", [
        "// seaglass: the folder's opening and closing motion (/usr/share/seaglass);",
        "// the stock fade stays when it cannot be loaded",
        "readonly property bool seaglassMotion: folderMotion.item ? folderMotion.item.managed : false",
        "readonly property bool seaglassGlass: folderMotion.item ? folderMotion.item.glass === true : false",
        "",
        "Loader {",
        "    id: folderMotion",
        "    property Item folder: launcherFolder",
        "    property Item grid: launcherGrid",
        f'    source: "{MOTION_URL}"',
        "}",
    ], 4, what)
    text = insert_after(text, "    function close() {\n", [
        "// seaglass: the closing motion first; it calls close() again when it is done",
        "if (folderMotion.item && folderMotion.item.close())",
        "    return",
    ], 8, what)
    text = replace_line(
        text, "    Behavior on opacity { SmoothedAnimation { duration: 400; velocity: 1000 / duration } }",
        "    Behavior on opacity { enabled: !seaglassMotion; SmoothedAnimation { duration: 400; velocity: 1000 / duration } }",
        what)
    text = replace_line(
        text, "        GradientStop { position: 0.0; color: Theme.rgba(Theme.overlayBackgroundColor, 1.0) }",
        "        GradientStop { position: 0.0; color: Theme.rgba(Theme.overlayBackgroundColor, seaglassGlass ? 0.0 : 1.0) }",
        what)
    text = replace_line(
        text, "        GradientStop { position: 1.0; color: Theme.rgba(Theme.overlayBackgroundColor, Theme.opacityOverlay) }",
        "        GradientStop { position: 1.0; color: Theme.rgba(Theme.overlayBackgroundColor, "
        "seaglassGlass ? 0.0 : Theme.opacityOverlay) }",
        what)
    return replace_line(text, "    Component.onCompleted: opacity = 1.0",
                        "    Component.onCompleted: if (!seaglassMotion) opacity = 1.0", what)


def hook_layer(text):
    """layers/LauncherLayer.qml: a wallpaper behind the app grid (LauncherWallpaper.qml), under the icons like the
    stock MenuBackground, which hides while the wallpaper covers it; without our QML, or with "frosted", the stock
    background."""
    what = "LauncherLayer.qml"
    background = find_once(text, "    MenuBackground {\n        z: -1\n", what=what)
    text = insert_after(text, "    MenuBackground {\n        z: -1\n", [
        "// seaglass: hidden while our wallpaper covers it",
        "visible: !(seaglassWallpaper.item && seaglassWallpaper.item.covers)",
    ], 8, what)
    end = block_end(text, background)
    return text[:end] + "\n\n" + indent([
        "// seaglass: a wallpaper behind the app grid (/usr/share/seaglass); the stock background",
        "// stays when it cannot be loaded",
        "Loader {",
        "    id: seaglassWallpaper",
        "    property Item edgeLayer: launcherLayer",
        "    z: -1",
        "    anchors.fill: parent",
        "    parent: launcherLayer.contentItem",
        f'    source: "{WALLPAPER_URL}"',
        "}",
    ], 4).rstrip("\n") + text[end:]


def hook_switcher(text):
    """switcher/Switcher.qml: the task switcher. A controller (SwitcherController.qml) gets the stock pieces:
    it puts glass under the covers, the recently closed apps after them, and the card row in their place; the grid's
    rows make room for the name chips; the wrapper for the recently closed apps; the card row holds off the stock
    vertical scrolling. A pinch area around the wrapper switches the two layouts. Without the controller every
    changed value is the stock one and the pinch area is off; closing stays stock."""
    what = "Switcher.qml"
    text = replace_line(
        text, "    contentHeight: Math.ceil(switcherWrapper.y + switcherWrapper.height)",
        "    contentHeight: seaglassSwitcher.item && seaglassSwitcher.item.cards\n"
        "                   ? height : Math.ceil(switcherWrapper.y + switcherWrapper.height)", what)
    stock_height = ("        height: switcherGrid.implicitHeight <= switcherRoot.height - y\n"
                    "                ? switcherRoot.height - y\n"
                    "                : switcherGrid.implicitHeight + switcherGrid.rowSpacing - 1\n")
    pos = find_once(text, stock_height, what=what)
    text = text[:pos] + indent([
        "// seaglass: room for the recently closed apps after the covers",
        "readonly property real seaglassExtra: seaglassSwitcher.item ? seaglassSwitcher.item.extraHeight : 0",
        "height: switcherGrid.implicitHeight + seaglassExtra <= switcherRoot.height - y",
        "        ? switcherRoot.height - y",
        "        : switcherGrid.implicitHeight + switcherGrid.rowSpacing - 1 + seaglassExtra",
    ], 8) + text[pos + len(stock_height):]
    # The wrapper of the covers goes into a pinch area: a pinch reaches an item only when it filters its
    # children's touches. The stock lines inside keep their indent; the area is off without the controller, and its
    # own enabled (not Item.enabled) leaves the covers enabled
    wrapper_start = "    MouseArea {\n        id: switcherWrapper\n"
    pos = find_once(text, wrapper_start, what=what)
    end = block_end(text, pos)
    text = text[:pos] + indent([
        "// seaglass: a pinch switches between the grid and the card row (/usr/share/seaglass);",
        "// off without the controller",
        "PinchArea {",
        "    id: seaglassPinch",
        "    width: switcherRoot.width",
        "    height: Math.max(switcherRoot.height, switcherWrapper.y + switcherWrapper.height)",
        "    enabled: seaglassSwitcher.item ? seaglassSwitcher.item.pinchEnabled : false",
        "",
    ], 4) + text[pos:end] + "\n    } // seaglass: seaglassPinch" + text[end:]
    text = insert_after(text, "            columns: largeColumns\n", [
        "// seaglass: room for the name chips under the covers (the stock spacing without them)",
        "rowSpacing: (_largeScreen && _pageHeight > parent.width",
        "             ? Math.ceil((_pageHeight - statusBarHeight - largeRows * Theme.coverSizeLarge.height)",
        "                         / (largeRows + 1))",
        "             : spacing) + (seaglassSwitcher.item ? seaglassSwitcher.item.chipSpace : 0)",
    ], 12, what)
    pos = find_once(text, "    CloseAllAppsHint {}\n", what=what)
    return text[:pos] + indent([
        "// seaglass: glass under the covers, the recently closed apps, the card row (/usr/share/seaglass);",
        "// the stock switcher stays when it cannot be loaded",
        "Loader {",
        "    id: seaglassSwitcher",
        "    property Item switcher: switcherRoot",
        "    property Item grid: switcherGrid",
        "    property Item wrapper: switcherWrapper",
        "    property Item covers: switcherItems",
        "    property Item coverRepeater: repeater",
        "    property QtObject coverModel: switcherModel",
        "    property QtObject mruModel: mruSwitcherModel",
        "    property Item pinchArea: seaglassPinch",
        f'    source: "{SWITCHER_URL}"',
        "}",
        "",
    ], 4) + text[pos:]


def hook_switcher_item(text):
    """switcher/SwitcherItem.qml: an app's cover in the task switcher. Under the cover, its name chip
    (SwitcherChip.qml), in the cover's content item, so that it moves, scales and fades with the cover; it fades
    out in the stock housekeeping mode (the stock close button sits on the cover's bottom edge)."""
    what = "SwitcherItem.qml"
    pos = find_once(text, "    Loader {\n        id: loader\n", what=what)
    return text[:pos] + indent([
        "// seaglass: the app's name chip under the cover (/usr/share/seaglass)",
        "Loader {",
        "    id: seaglassChip",
        "    property var launcherItem: wrapper.launcherItem",
        "    property Item glass: seaglassSwitcher.item ? seaglassSwitcher.item.glass : null",
        "    property bool hidden: switcherRoot.housekeeping",
        "    property real maxWidth: wrapper.width",
        "    anchors.horizontalCenter: parent.horizontalCenter",
        "    anchors.top: parent.bottom",
        "    anchors.topMargin: Theme.paddingMedium",
        "    active: seaglassSwitcher.item ? seaglassSwitcher.item.chips : false",
        f'    source: "{CHIP_URL}"',
        "}",
        "",
    ], 4) + text[pos:]


HOOKS = {FILES[0]: hook_folder, FILES[1]: hook_grid, FILES[2]: hook_delegate, FILES[3]: hook_layer,
         FILES[4]: hook_switcher, FILES[5]: hook_switcher_item}


def build(base):
    """{path: (stock text, patched text)} for the stock files under base."""
    result = {}
    for path in FILES:
        source = Path(base, path)
        if not source.is_file():
            raise AnchorError(f"missing stock file: {source}")
        stock = source.read_text(encoding="utf-8")
        if "seaglass" in stock:
            raise AnchorError(f"{path}: already hooked (it mentions seaglass)")
        result[path] = (stock, HOOKS[path](stock))
    return result


def unified_diff(files):
    out = []
    for path in FILES:
        stock, patched = files[path]
        out.extend(difflib.unified_diff(stock.splitlines(keepends=True), patched.splitlines(keepends=True),
                                        fromfile=f"a/{path}", tofile=f"b/{path}", n=3))
    return "".join(out)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("base", nargs="?", help="directory with the stock files at their device paths")
    parser.add_argument("--out", help="write the patched files under this directory")
    parser.add_argument("--check", metavar="PATCH", help="compare with this unified diff")
    parser.add_argument("--files", action="store_true", help="list the stock files the hook changes")
    args = parser.parse_args()
    if args.files:
        print("\n".join(FILES))
        return 0
    if not args.base:
        parser.error("BASE is required")
    try:
        files = build(args.base)
    except AnchorError as err:
        print(f"apply_hook: {err}", file=sys.stderr)
        return 2
    diff = unified_diff(files)
    if args.out:
        for path, (_, patched) in files.items():
            target = Path(args.out, path)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(patched, encoding="utf-8")
    if args.check:
        if Path(args.check).read_text(encoding="utf-8") != diff:
            print(f"apply_hook: {args.check} is not the hook for {args.base} (run: make hook)", file=sys.stderr)
            return 1
        return 0
    sys.stdout.write(diff)
    return 0


if __name__ == "__main__":
    sys.exit(main())
