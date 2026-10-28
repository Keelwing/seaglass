// The app grid's controller: widgets as blocks of the app grid (docs/FOLDERS.md), the search, the badges and the data
// widgets (below). The Patchmanager hook (hook/apply_hook.py) loads this into a Loader at the root of the app grid
// (LauncherGrid.qml, rootFolder only); the Loader is its parent and provides grid, the LauncherGrid. The hook reads:
//   layout         {cells: [{col, row, w, h}] by model index, rows}: where each item of the grid is drawn
//   itemAt(x, y)   the delegate drawn at a point of the grid's content (for the stock drag and drop)
//   footer         a footer Component as high as the rows the widgets add, so that the pager makes the pages
//                  (and the controller makes the grid as tall as its content: it never scrolls inside the pager)
//   noteOrigin(f)  a folder is about to open (showFolder): where it opens from, for FolderMotion.qml
//   header         the grid's header: with the search row at the top, the row (SearchRow.qml) under the stock
//                  experimental clock when it is on (the hook's Loader gives clockHeader); else null (stock header).
//                  At the bottom (the default) the row is drawn in the grid's last row of the first page
// and offers, through motion.js, pager: the app grid's pager (Launcher.qml), for LauncherWallpaper.qml, glass:
// the glass (GlassSource.qml) for the app grid's background, the folder icons, the open folder and the cards,
// and noteLaunch(item): an app was launched (FolderMotion.qml, for the apps in a folder).
// The search (docs/SEARCH.md): the search row opens SearchSheet.qml over the app grid; the controller gives
// it the apps (entries), counts the launches (usage, dconf /apps/seaglass/search) for the apps used most,
// launches, and shows an app in the grid.
// The badges (docs/BADGES.md): BadgeSource.qml counts the notifications per app; IconBadge.qml (on the icons,
// folders, cards and in the search) reads badgeCount(item), and a long press on a badged app or folder may peek at
// its notifications (NotificationPeek.qml; settings in dconf /apps/seaglass/badges).
// The data widgets (docs/WIDGETS.md): DataWidget.qml blocks in the grid's content, each holding a slot in
// the grid's order (grid.js compose: the model's items with the data widgets spliced in), kept in dconf by
// DataWidgets.qml (/apps/seaglass/widgets/list). The layout's cells stay by model index, as the hook reads
// them; layout.extra has the data widgets' blocks. Over a data widget, itemAt() answers the stock drag with a
// stand-in, and a stock move keeps a dropped icon on the side of the data widgets it was dropped on (modelMoved).
// The tiles (WidgetTile.qml) and the folder badges (FolderPreview.qml) call typeOf, setType, launch, open,
// enterEditMode. The widget being dragged is the one whose content item is the grid's reorderItem (stock).
//
// A widget's position is its folder's position in the grid's model, which Lipstick stores; the widget types
// are in FolderTypes.qml. When this file fails to load, the hook keeps the stock grid, and the widget folders are
// ordinary folder icons at their places.
import QtQuick 2.6
import QtQml 2.2
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import org.nemomobile.lipstick 0.1
import "../settings"
import "../badges"
import "../glass"
import "../search"
import "../widgets/data"
import "../widgets/group"
import "grid.js" as Grid
import "motion.js" as Motion
import "../search/search.js" as Search

Item {
    id: controller

    // the root LauncherGrid; the harness sets a stand-in with the same properties
    property Item grid: parent && parent.grid !== undefined ? parent.grid : null
    property QtObject model: grid ? grid.model : null
    property QtObject store: FolderTypes {}
    // false in the harness, which shares the phone's dconf: it writes nothing there (the widgets live in memory)
    property bool persistent: true

    // The Debug log switch (Seaglass's settings, About): diagnostics go to the journal only while
    // it is on, and the work done only for them (the badge probe, the pinch's checks) runs only then
    GeneralSettings {
        id: generalSettings
    }
    readonly property bool debug: generalSettings.debug

    // the version this home screen runs, for the settings' status (read from the installed patch.json)
    function noteRunningVersion() {
        if (!persistent)
            return
        var request = new XMLHttpRequest()
        request.onreadystatechange = function () {
            if (request.readyState !== XMLHttpRequest.DONE)
                return
            try {
                var version = JSON.parse(request.responseText).version || ""
                if (version !== "" && generalSettings.running !== version)
                    generalSettings.running = version
            } catch (e) {
            }
        }
        request.open("GET", "file:///usr/share/patchmanager/patches/seaglass/patch.json")
        request.send()
    }

    // console.log with our prefix, while Debug is on
    function debugLog() {
        if (debug)
            console.log.apply(console, ["seaglass:"].concat(Array.prototype.slice.call(arguments)))
    }

    property var layout: ({ "cells": [], "extra": {}, "rows": 0 })
    // the spans in model order and the reserved rows the layout was made from (for planning a widget's drag)
    property var spans: []
    property int reserved: 0
    // rows kept free at the bottom of the first page (the search row there)
    property int reservedEnd: 0
    // the last drag plan: the cell aimed at and the model index that lays the widget out nearest to it
    property var plan: ({ "key": "", "index": -1 })
    // [{folder, title}] of the widget folders, for following renames
    property var widgets: []
    // the delegate of the widget being dragged (its place in the grid stays outlined), or null: from the stock
    // reorderItem (the dragged content item), so that it can never outlive the drag
    property Item liftedDelegate
    // the app grid's pager: the SilicaListView of Launcher.qml around the root grid (the first ancestor with
    // contentY and snapMode), for the wallpaper's page parallax
    property Item pager
    // the components below have properties called controller: they reach this one by this name
    readonly property Item homeController: controller

    // The grid's order (grid.js compose): the one the layout was made from (a data widget's drag planned in
    // it), and the stored one
    property var order: []
    property var committedOrder: []
    // the data widgets' blocks in cells, by id
    property var extraSpans: ({})
    // a page of the pager: the hook draws page n at n pager heights
    readonly property real pageSpan: pager && pager.height > 0 ? pager.height : (grid ? pageRows * grid.cellHeight : 0)

    // The glass (docs/GLASS.md): the home screen's wallpaper, in the home screen's frame
    readonly property Item glass: glassSource
    GlassSource {
        id: glassSource

        home: Lipstick.compositor && Lipstick.compositor.wallpaper
              ? Lipstick.compositor.wallpaper.homeWallpaperItem : null
        frameParent: Lipstick.compositor && Lipstick.compositor.wallpaper
                     ? Lipstick.compositor.wallpaper.transformItem : null
    }

    function findPager() {
        var item = grid ? grid.parent : null
        while (item && !(item.snapMode !== undefined && item.contentY !== undefined))
            item = item.parent
        pager = item
    }

    readonly property int columns: grid ? Math.max(1, grid.columns) : 1
    readonly property int pageRows: grid ? grid.rows : 1
    readonly property real footerHeight: {
        if (!grid || !model)
            return 0
        var compact = Math.ceil(model.itemCount / columns) + reserved
        return Math.max(0, (layout.rows - compact) * grid.cellHeight)
    }

    readonly property Component footer: Component {
        Item {
            width: controller.grid ? controller.grid.width : 0
            height: controller.footerHeight
        }
    }

    visible: false

    function typeOf(folder) {
        return folder && folder.type === LauncherModel.Folder ? store.typeOf(folder.title) : "icon"
    }

    function setType(folder, type) {
        if (folder)
            store.setType(folder.title, type)
    }

    function launch(item) {
        // the launch emits the grid's itemLaunched: not counted again there
        ownLaunch = true
        if (actions.item)
            actions.item.launch(item)
        else
            console.log("seaglass: launch", item.title)
        ownLaunch = false
        noteLaunch(item)
    }

    function open(folder) {
        if (actions.item)
            actions.item.open(folder)
        else
            console.log("seaglass: open", folder.title)
    }

    function enterEditMode() {
        if (grid)
            grid.setEditMode(true)
    }

    // An app of the grid is launched: its icon in scene coordinates, for the opening effect
    // (animations/AnimationController.qml)
    function noteAppOrigin(index) {
        var children = grid ? grid.contentItem.children : []
        for (var i = 0; index >= 0 && i < children.length; i++) {
            var delegate = children[i]
            if (delegate.modelIndex !== index || delegate.contentItem === undefined)
                continue
            var item = delegate.contentItem
            var size = Theme.iconSizeLauncher
            var icon = item.mapToItem(null, (item.width - size) / 2,
                                      delegate.iconOffset !== undefined ? delegate.iconOffset : 0)
            Motion.setAppOrigin({ "x": icon.x, "y": icon.y, "width": size, "height": size })
            return
        }
    }

    // A folder is about to open: its icon, or its widget tile, in scene coordinates, for FolderMotion.qml
    function noteOrigin(folder) {
        Motion.setOrigin(null)
        var index = model ? model.indexOf(folder) : -1
        var children = grid ? grid.contentItem.children : []
        for (var i = 0; index >= 0 && i < children.length; i++) {
            var delegate = children[i]
            if (delegate.modelIndex !== index || delegate.contentItem === undefined)
                continue
            var item = delegate.contentItem
            var block = layout.cells[index]
            if (block && (block.w > 1 || block.h > 1)) {
                var gutter = Theme.paddingSmall
                var corner = item.mapToItem(null, gutter, gutter)
                Motion.setOrigin({ "x": corner.x, "y": corner.y, "width": item.width - 2 * gutter,
                                   "height": item.height - 2 * gutter, "radius": Theme.paddingLarge })
            } else {
                var size = Theme.iconSizeLauncher
                var icon = item.mapToItem(null, (item.width - size) / 2,
                                          delegate.iconOffset !== undefined ? delegate.iconOffset : 0)
                Motion.setOrigin({ "x": icon.x, "y": icon.y, "width": size, "height": size, "radius": size / 4 })
            }
            return
        }
    }

    // The delegate being dragged (its content item is the stock reorderItem), or null
    function draggedDelegate() {
        var dragged = grid && grid.reorderItem !== undefined ? grid.reorderItem : null
        var children = dragged ? grid.contentItem.children : []
        for (var i = 0; i < children.length; i++) {
            if (children[i].contentItem === dragged)
                return children[i]
        }
        return null
    }

    // The drag started or ended: the dragged delegate, when it is a widget
    function updateLifted() {
        var delegate = draggedDelegate()
        liftedDelegate = delegate && delegate.seaglassWidget ? delegate : null
        if (!delegate) {
            aimed = null
            crossPlan = null
        }
    }

    // The delegate whose drawn block covers (x, y) of the grid's content: delegates have modelIndex and targetX.
    // While a widget is dragged, (x, y) is its centre, and the answer is a stand-in that makes the stock reorder
    // logic (EditableGridDelegate.qml, moved()) move it to the place planned by aim().
    // Over a data widget, the dragged icon goes right before it (its left half) or right after it: a stand-in
    // for the model index that puts it there, or the dragged delegate itself ("stay") when only the slots change.
    // Over a delegate, the delegate, noted as the item aimed at (modelMoved); over no item, the stock moves the icon
    // to the end.
    function itemAt(x, y) {
        if (liftedDelegate !== null && liftedDelegate.reordering && liftedDelegate.modelIndex !== undefined)
            return aim(liftedDelegate.modelIndex, x, y)
        var hit = dataHit(x, y)
        var dragged = hit ? draggedDelegate() : null
        if (dragged && dragged.modelIndex !== undefined) {
            var index = dragged.modelIndex
            var next = Grid.placeBeside(committedOrder, { "m": index }, { "x": hit.key }, !hit.left)
            var target = Grid.modelIndexAt(next, Grid.positionOf(next, { "m": index }))
            planCrossing(index, target, next)
            aimed = null
            return target === index ? dragged : standIn(index, target, x)
        }
        var children = grid.contentItem.children
        for (var i = 0; i < children.length; i++) {
            var item = children[i]
            if (item.modelIndex === undefined || item.targetX === undefined)
                continue
            // the drawn block: the delegate itself keeps the stock cell size
            var w = item.targetWidth !== undefined ? item.targetWidth : item.width
            var h = item.targetHeight !== undefined ? item.targetHeight : item.height
            if (x >= item.targetX && x < item.targetX + w && y >= item.targetY && y < item.targetY + h) {
                if (!liftedDelegate) {
                    aimed = { "object": model ? model.get(item.modelIndex) : null }
                    crossPlan = null
                    crossTimer.stop()
                }
                return item
            }
        }
        if (!liftedDelegate)
            aimed = { "end": true }
        return null
    }

    // Read by the stock reorder logic (EditableGridDelegate.qml, moved()) as "before item modelIndex" (offset 0 is in
    // the left half; y and height never match the dragged delegate's): the dragged item at index ends at target
    function standIn(index, target, x) {
        return { "modelIndex": target > index ? target + 1 : target, "targetX": x, "targetY": -1, "y": -1,
                 "width": 2, "targetWidth": 2, "height": -1, "folderItemCount": 99 }
    }

    // The cell a dragged block of w × h cells aims at, from its centre (x, y) in the grid's content: the cell under
    // its top left corner, on the page under its centre
    function cellFor(w, h, x, y) {
        var cellWidth = grid.cellWidth
        var cellHeight = grid.realCellHeight
        var col = Math.max(0, Math.min(columns - w, Math.round((x - w * cellWidth / 2) / cellWidth)))
        var page = Math.max(0, Math.floor((y - grid.originY) / pageSpan))
        var top = y - h * cellHeight / 2 - grid.originY - page * pageSpan - grid.topMargin
        var rowInPage = Math.max(0, Math.min(pageRows - h, Math.round(top / cellHeight)))
        return { "row": page * pageRows + rowInPage, "col": col }
    }

    // A dragged widget aims at the cell under its top left corner (from its centre at x, y), on the page under its
    // centre; grid.js finds the place in the grid's order (with the data widgets in it) that lays it out nearest to
    // that cell, and the stand-in hands its model index to the stock move.
    function aim(index, x, y) {
        var block = layout.cells[index]
        if (!block)
            return null
        var cell = cellFor(block.w, block.h, x, y)
        var key = index + ":" + cell.row + ":" + cell.col
        if (plan.key !== key) {
            var from = Grid.positionOf(committedOrder, { "m": index })
            var next = from < 0 ? committedOrder
                                : Grid.bestOrder(committedOrder, spans, extraSpans, from, cell.row, cell.col, columns,
                                                 pageRows, reserved, reservedEnd)
            var target = Grid.modelIndexAt(next, Grid.positionOf(next, { "m": index }))
            plan = { "key": key, "index": target }
            planCrossing(index, target, next)
        }
        return standIn(index, plan.index, x)
    }

    function rebuild() {
        if (!model || !grid) {
            layout = { "cells": [], "extra": {}, "rows": 0 }
            widgets = []
            return
        }
        // (no local is called like a property: a "var spans" would hide the property in the whole function)
        var blocks = []
        var list = []
        for (var i = 0; i < model.itemCount; i++) {
            var item = model.get(i)
            var type = typeOf(item)
            blocks.push(Grid.spanOf(type, columns))
            if (type !== "icon")
                list.push({ "folder": item, "title": item.title })
        }
        reserved = (grid.reserveFirstRow ? 1 : 0) + (searchShown && !searchAtBottom ? 1 : 0)
        reservedEnd = searchShown && searchAtBottom ? 1 : 0
        // the data widgets at their slots (one not shown has no cells); while one is dragged, the order planned for it
        var xspans = {}
        for (var d = 0; d < dataEntries.length; d++)
            xspans[dataEntries[d].id] = dataStore.shown(dataEntries[d]) ? Grid.spanOf(dataEntries[d].size, columns)
                                                                       : { "w": 0, "h": 0 }
        var extras = dataExtras()
        // a widget being dragged out of the gallery: "new", at the end until it is planned
        if (ghost) {
            extras.push({ "id": "new", "at": 1e6 })
            xspans["new"] = Grid.spanOf(ghost.size, columns)
        }
        var base = Grid.compose(model.itemCount, extras)
        var current = dataPreview && dataPreview.order.length === base.length ? dataPreview.order : base
        spans = blocks
        extraSpans = xspans
        committedOrder = base
        order = current
        layout = Grid.layoutOrder(current, blocks, xspans, columns, pageRows, reserved, reservedEnd)
        widgets = list
        rebuildEntries()
    }

    // the model fills in after it is created: lay out once it settles
    Timer {
        id: settle

        interval: 300
        onTriggered: {
            // a fresh install: the starter widgets, and once the grid shows them, a hint about the edit mode
            if (controller.dataStore.fresh && controller.model && controller.model.itemCount > 0) {
                controller.dataStore.addStarter()
                generalSettings.editHint = "pending"
            }
            controller.rebuild()
            if (!controller.pager)
                controller.findPager()
        }
    }

    Component.onCompleted: {
        Motion.setHome(controller)
        loadUsage()
        settle.restart()
        noteRunningVersion()
    }
    Component.onDestruction: {
        if (Motion.home === controller)
            Motion.setHome(null)
    }
    onModelChanged: settle.restart()
    onColumnsChanged: rebuild()
    onPageRowsChanged: rebuild()
    onSearchShownChanged: rebuild()
    onSearchAtBottomChanged: rebuild()

    Connections {
        target: controller.store
        onMapChanged: controller.rebuild()
    }

    Connections {
        target: controller.model
        ignoreUnknownSignals: true
        onItemCountChanged: controller.rebuild()
        // (typeof: should the signal's parameter names be missing, the grid is laid out again all the same)
        onRowsMoved: controller.modelMoved(typeof start === "number" ? start : -1, typeof row === "number" ? row : -1)
    }

    Connections {
        target: controller.grid
        ignoreUnknownSignals: true
        onReserveFirstRowChanged: controller.rebuild()
        onReorderItemChanged: controller.updateLifted()
        onLauncherEditModeChanged: {
            if (!controller.grid.launcherEditMode) {
                controller.closeGallery(false)
                if (controller.dataLifted)
                    controller.dataLifted.drop()
            }
        }
        // a tap on an app: the stock press made it the current item just before
        onItemLaunched: {
            if (!controller.ownLaunch && controller.grid.currentIndex !== undefined && controller.model) {
                controller.noteLaunch(controller.model.get(controller.grid.currentIndex))
                controller.noteAppOrigin(controller.grid.currentIndex)
            }
        }
        onContentYChanged: controller.pinGrid()
        onOriginYChanged: controller.pinGrid()
    }

    // The grid inside the pager: Launcher.qml makes the root grid as tall as its stock rows and its header, and
    // the pager as many pages as the grid's content needs. The rows the widgets add are in the footer, so the grid
    // is made as tall as its content with them: it never scrolls inside the pager, which would hide its top rows
    //. Without widgets, or in the harness (no count), the stock height.
    readonly property real stockHeight: grid && grid.count !== undefined
                                        ? grid.cellHeight * Math.ceil(grid.count / columns)
                                          + (grid.headerItem ? grid.headerItem.height : 0)
                                        : 0
    Binding {
        target: controller.grid
        property: "height"
        value: controller.stockHeight + controller.footerHeight
        when: controller.stockHeight > 0 && controller.footerHeight > 0
    }

    // and should anything scroll it all the same, back to its top at once (the stock grid is never scrolled)
    property bool pinning
    function pinGrid() {
        if (pinning || !grid || grid.originY === undefined || grid.contentY === grid.originY)
            return
        pinning = true
        debugLog("the app grid was scrolled by", grid.contentY - grid.originY, "- back to its top")
        grid.contentY = grid.originY
        pinning = false
    }

    // Renames: a widget folder keeps its type under its new title
    Instantiator {
        model: controller.widgets

        QtObject {
            property string known: modelData.title
            property Connections watch: Connections {
                target: modelData.folder
                onTitleChanged: {
                    var title = modelData.folder.title
                    controller.store.rename(known, title)
                    known = title
                }
            }
        }
    }

    // The place of the widget being dragged: an outlined glass slot under the icons, where its delegate (the
    // stock placeholder, which stays in the grid) is
    Rectangle {
        readonly property Item slot: controller.liftedDelegate

        parent: controller.grid ? controller.grid.contentItem : controller
        visible: slot !== null && slot.reordering === true
        z: -1
        x: slot ? slot.targetX + Theme.paddingSmall : 0
        y: slot ? slot.targetY + Theme.paddingSmall : 0
        width: slot ? slot.targetWidth - 2 * Theme.paddingSmall : 0
        height: slot ? slot.targetHeight - 2 * Theme.paddingSmall : 0
        radius: Theme.paddingLarge
        color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
        border.width: Math.max(1, Math.round(2 * Theme.pixelRatio))
        border.color: Theme.rgba(Theme.highlightColor, 0.45)
    }

    Loader {
        id: actions

        source: "LauncherActions.qml"
        onLoaded: item.grid = Qt.binding(function () { return controller.grid })
    }

    // ---- The search (docs/SEARCH.md) ----

    // the stock experimental clock's header component while the clock is on (from the hook's Loader)
    readonly property Component clockHeader: parent && parent.clockHeader !== undefined ? parent.clockHeader : null
    // suggestions (the pill and the apps used most) | pill | off
    readonly property string searchRow: searchSettings.row
    readonly property bool searchShown: searchRow === "suggestions" || searchRow === "pill"
    // bottom (the first page's last row, under the thumb) | top (under the camera's island)
    readonly property bool searchAtBottom: searchSettings.position !== "top"
    readonly property Component header: searchShown && !searchAtBottom ? searchHeader : null
    // the apps and folders: {key, title, file, folder, iconId, item, isFolder}
    property var entries: []
    // launches: {key: {n, t}} (search.js)
    property var usage: ({})
    property var suggested: []
    property bool ownLaunch

    SearchSettings {
        id: searchSettings

        // written elsewhere (the settings page forgets the launches): follow it
        onUsageChanged: if (!saveUsage.running) controller.loadUsage()
    }

    function loadUsage() {
        try {
            usage = JSON.parse(searchSettings.usage || "{}") || {}
        } catch (e) {
            usage = {}
        }
        updateSuggestions()
    }

    // An app was launched (from the grid, a folder, a widget or the search): counted for the apps used most
    function noteLaunch(item) {
        if (!item || !item.filePath || item.type === LauncherModel.Folder || !searchSettings.remember)
            return
        usage = Search.noteUse(usage, item.filePath, Date.now())
        updateSuggestions()
        if (persistent)
            saveUsage.restart()
    }

    // one write a few seconds after the last launch
    Timer {
        id: saveUsage

        interval: 4000
        onTriggered: searchSettings.usage = JSON.stringify(controller.usage)
    }

    function collect(folder, folderTitle, list) {
        for (var i = 0; i < folder.itemCount; i++) {
            var item = folder.get(i)
            if (!item)
                continue
            if (item.type === LauncherModel.Folder) {
                list.push({ "key": "folder:" + item.title, "title": item.title, "file": "", "folder": "",
                            "iconId": item.iconId, "item": item, "isFolder": true })
                collect(item, item.title, list)
            } else if (item.iconId || item.title) {
                var file = String(item.filePath || "").split("/").pop().replace(/\.desktop$/, "")
                list.push({ "key": item.filePath || item.title, "title": item.title, "file": file,
                            "folder": folderTitle, "iconId": item.iconId, "item": item, "isFolder": false })
            }
        }
        return list
    }

    function rebuildEntries() {
        entries = model ? collect(model, "", []) : []
        updateSuggestions()
    }

    function updateSuggestions() {
        suggested = Search.suggestions(entries, usage, columns, Date.now())
    }

    function launchEntry(entry) {
        if (!entry)
            return
        if (entry.isFolder)
            open(entry.item)
        else
            launch(entry.item)
    }

    function openSearch(pill) {
        if (actions.item)
            actions.item.showLauncher()
        rebuildEntries()
        sheetLoader.active = true
        if (sheetLoader.item)
            sheetLoader.item.open(pill)
    }

    function closeSearch(now) {
        if (sheetLoader.item)
            sheetLoader.item.close(now)
    }

    // Show an entry in the grid: an app or a folder of the grid: its page, and a ring of light around it; an app
    // in a folder: the folder opens
    function revealEntry(entry) {
        if (!entry || !model || !pager)
            return
        var index = model.indexOf(entry.item)
        if (index < 0 && entry.folder) {
            for (var i = 0; i < model.itemCount; i++) {
                var item = model.get(i)
                if (item && item.type === LauncherModel.Folder && item.title === entry.folder) {
                    var block = layout.cells[i]
                    if (block)
                        turnTo(Math.floor(block.row / pageRows))
                    open(item)
                    return
                }
            }
            return
        }
        var cell = layout.cells[index]
        if (!cell)
            return
        turnTo(Math.floor(cell.row / pageRows))
        ring.show(index)
    }

    function turnTo(page) {
        pageTurn.to = pager.originY + page * pager.height
        pageTurn.restart()
    }

    NumberAnimation {
        id: pageTurn

        target: controller.pager
        property: "contentY"
        duration: 350
        easing.type: Easing.InOutQuad
    }

    // The header: the stock clock when it is on, then the search row, one row of the grid each
    Component {
        id: searchHeader

        Item {
            id: headerItem

            readonly property Item grid: controller.grid
            readonly property int clockRows: grid && grid.reserveFirstRow ? 1 : 0
            readonly property real statusBar: grid && grid.statusBarHeight !== undefined ? grid.statusBarHeight : 0

            width: grid ? grid.width : 0
            height: grid ? (clockRows + 1) * grid.cellHeight - statusBar : 0

            Loader {
                width: parent.width
                sourceComponent: headerItem.clockRows > 0 ? controller.clockHeader : null
            }

            SearchRow {
                y: headerItem.grid ? headerItem.grid.topMargin + headerItem.clockRows * headerItem.grid.realCellHeight : 0
                width: parent.width
                height: headerItem.grid ? headerItem.grid.realCellHeight : 0
                glass: controller.glass
                cellWidth: headerItem.grid ? headerItem.grid.cellWidth : 0
                suggested: controller.searchRow === "suggestions" ? controller.suggested : []
                onSearch: controller.openSearch(pill)
                onLaunch: controller.launchEntry(entry)
            }
        }
    }

    // The search row at the bottom: in the grid's content, over the first page's last row (kept free)
    SearchRow {
        parent: controller.grid ? controller.grid.contentItem : controller
        visible: controller.searchShown && controller.searchAtBottom && controller.grid !== null && opacity > 0
        // in edit mode the "+ Widget" capsule takes its place
        opacity: controller.grid && controller.grid.launcherEditMode ? 0 : 1
        enabled: opacity === 1
        Behavior on opacity { FadeAnimation {} }
        z: 1
        y: controller.grid ? controller.grid.originY + controller.grid.topMargin
                             + (controller.pageRows - 1) * controller.grid.realCellHeight : 0
        width: controller.grid ? controller.grid.width : 0
        height: controller.grid ? controller.grid.realCellHeight : 0
        pillBelow: true
        glass: controller.glass
        cellWidth: controller.grid ? controller.grid.cellWidth : 0
        suggested: controller.searchRow === "suggestions" ? controller.suggested : []
        onSearch: controller.openSearch(pill)
        onLaunch: controller.launchEntry(entry)
    }

    // The sheet: made the first time it opens, over the app grid and an open folder (which the stock puts in the
    // pager too, at z 10)
    Loader {
        id: sheetLoader

        active: false
        sourceComponent: SearchSheet {
            parent: controller.pager
            z: 20
            width: controller.pager ? controller.pager.width : 0
            height: controller.pager ? controller.pager.height : 0
            glass: controller.glass
            entries: controller.entries
            usage: controller.usage
            suggested: controller.suggested
            columns: controller.columns
            fieldAtBottom: controller.searchAtBottom
            onLaunch: controller.launchEntry(entry)
            onReveal: controller.revealEntry(entry)
        }
    }

    // closed at once when the app grid hides or the display goes off
    Connections {
        target: controller.pager
        ignoreUnknownSignals: true
        onVisibleChanged: {
            if (!controller.pager.visible) {
                controller.closeSearch(true)
                controller.closePeek(true)
                controller.closeGallery(true)
            }
        }
        // the pager turns under a lifted data widget: it aims again
        onContentYChanged: {
            if (controller.dataLifted)
                controller.dataReplan(controller.dataLifted)
            else if (controller.ghostItem)
                controller.replanFor("new", controller.ghostItem)
        }
    }

    Connections {
        target: Lipstick.compositor
        ignoreUnknownSignals: true
        onDisplayOff: {
            controller.displayOn = false
            controller.closeSearch(true)
            controller.closePeek(true)
            controller.closeGallery(true)
            if (controller.dataLifted)
                controller.dataLifted.drop()
        }
        onDisplayOn: controller.displayOn = true
    }

    // ---- The badges (docs/BADGES.md) ----

    BadgeSettings {
        id: badgeSettings
    }

    readonly property bool badgesShown: badgeSettings.show && badgeSource.item !== null
    readonly property string badgeStyle: badgeSettings.style
    readonly property string badgeTone: badgeSettings.tone
    readonly property bool badgeFolders: badgeSettings.folders
    readonly property int badgeRevision: badgeSource.item ? badgeSource.item.revision : 0

    // an app's notifications, or a folder's apps' together
    function badgeCount(item) {
        var source = badgeSource.item
        if (!source || !item)
            return 0
        if (item.type === LauncherModel.Folder)
            return badgeSettings.folders ? (source.folderCounts[item.title] || 0) : 0
        return item.filePath ? (source.counts[item.filePath] || 0) : 0
    }

    // A long press on a badged icon (IconBadge.qml, FolderPreview.qml): its notifications by the icon, when the peek
    // is on. An app shows its own; a folder its apps' together, newest first. The card lists {app, note} pairs.
    function peekAt(item, icon) {
        if (!badgeSettings.peek || !badgeSource.item || !pager || !item)
            return false
        if (grid && grid.launcherEditMode)
            return false
        var notes = badgeSource.item.notes
        var list = []
        if (item.type === LauncherModel.Folder) {
            for (var i = 0; i < entries.length; i++) {
                var entry = entries[i]
                var own = !entry.isFolder && entry.folder === item.title ? notes[entry.key] || [] : []
                for (var j = 0; j < own.length; j++)
                    list.push({ "app": entry.item, "note": own[j] })
            }
            list.sort(function (a, b) {
                return (b.note.timestamp ? b.note.timestamp.getTime() : 0)
                        - (a.note.timestamp ? a.note.timestamp.getTime() : 0)
            })
        } else {
            var mine = notes[item.filePath] || []
            for (var k = 0; k < mine.length; k++)
                list.push({ "app": item, "note": mine[k] })
        }
        if (list.length === 0)
            return false
        peekLoader.active = true
        peekLoader.item.open(item, list, icon)
        return true
    }

    readonly property bool peekOpen: peekLoader.item ? peekLoader.item.visible : false

    function closePeek(now) {
        if (peekLoader.item)
            peekLoader.item.close(now)
    }

    // Open: the notification's own action when it has one (the Events view does the same), else the app
    function openNotification(item, notification) {
        if (notification && notification.actions && notification.actions.indexOf("default") >= 0) {
            notification.actionInvoked("default")
            if (actions.item)
                actions.item.hideLauncher()
        } else if (item) {
            launch(item)
        }
    }

    function clearNotifications(list) {
        for (var i = 0; i < list.length; i++) {
            if (list[i] && list[i].userRemovable)
                list[i].removeRequested()
        }
    }

    // the home screen's notifications (it loads only inside Lipstick: in the harness, no badges)
    Loader {
        id: badgeSource

        source: "../badges/BadgeSource.qml"
        onLoaded: {
            item.entries = Qt.binding(function () { return controller.entries })
            item.probe = Qt.binding(function () { return controller.debug })
        }
    }

    Loader {
        id: peekLoader

        active: false
        sourceComponent: NotificationPeek {
            parent: controller.pager
            z: 20
            width: controller.pager ? controller.pager.width : 0
            height: controller.pager ? controller.pager.height : 0
            glass: controller.glass
            onOpenRequested: {
                if (item && item.type === LauncherModel.Folder)
                    controller.open(item)
                else
                    controller.openNotification(item, notification)
            }
            onClearRequested: controller.clearNotifications(notes)
            onEditRequested: controller.enterEditMode()
        }
    }

    // A ring of light that pulses twice around an item shown from the search
    Rectangle {
        id: ring

        property Item target

        function show(index) {
            var children = controller.grid ? controller.grid.contentItem.children : []
            target = null
            for (var i = 0; i < children.length; i++) {
                if (children[i].modelIndex === index && children[i].targetX !== undefined) {
                    target = children[i]
                    break
                }
            }
            if (target)
                pulse.restart()
        }

        readonly property real size: target && target.seaglassWidget
                                     ? Math.min(target.targetWidth, target.targetHeight) : Theme.iconSizeLauncher * 1.3

        parent: controller.grid ? controller.grid.contentItem : controller
        z: 5
        visible: pulse.running && target !== null
        x: target ? target.targetX + ((target.targetWidth || target.width) - width) / 2 : 0
        y: target ? target.targetY + (target.iconOffset !== undefined && !target.seaglassWidget
                                      ? target.iconOffset + (Theme.iconSizeLauncher - height) / 2
                                      : ((target.targetHeight || target.height) - height) / 2) : 0
        width: size
        height: size
        radius: width * 0.3
        color: "transparent"
        border.width: Math.max(2, Math.round(3 * Theme.pixelRatio))
        border.color: Theme.highlightColor
        opacity: 0

        SequentialAnimation {
            id: pulse

            PauseAnimation { duration: 300 }
            ParallelAnimation {
                NumberAnimation { target: ring; property: "opacity"; from: 0; to: 1; duration: 200 }
                NumberAnimation { target: ring; property: "scale"; from: 1.4; to: 1; duration: 350; easing.type: Easing.OutBack }
            }
            NumberAnimation { target: ring; property: "opacity"; to: 0.3; duration: 300 }
            NumberAnimation { target: ring; property: "opacity"; to: 1; duration: 300 }
            PauseAnimation { duration: 500 }
            NumberAnimation { target: ring; property: "opacity"; to: 0; duration: 400 }
        }
    }

    // ---- The data widgets (docs/WIDGETS.md) ----

    property QtObject dataStore: DataWidgets {
        persistent: controller.persistent
    }
    // sample data in the sources (the harness)
    property bool demoData
    property bool displayOn: true
    // the app grid is on screen: the sources tick only then
    readonly property bool dataLive: grid !== null && grid.visible && displayOn
    // the widgets in the grid's order: the store's, unless they are switched off
    readonly property var dataEntries: widgetSettings.show ? dataStore.list : []
    // the widgets shown: those of a kind and size this version knows (the others keep their slots, undrawn)
    readonly property var dataList: {
        var shown = []
        for (var i = 0; i < dataEntries.length; i++) {
            if (dataStore.shown(dataEntries[i]))
                shown.push(dataEntries[i])
        }
        return shown
    }
    // while a data widget is dragged: {id, order}, the order planned for it
    property var dataPreview: null
    property Item dataLifted: null
    property string dataPlanKey
    // a drag's plan for the data widgets' slots: {object, target, order} (planCrossing)
    property var crossPlan: null
    // what the stock drag of an icon aimed at last: {object} or {end: true} (modelMoved)
    property var aimed: null
    readonly property bool galleryOpen: galleryLoader.item ? galleryLoader.item.opened : false
    readonly property Item gallery: galleryLoader.item
    property string pendingPulse
    // a widget dragged out of the gallery: {kind, size}, and its item (in the gallery, over the grid)
    property var ghost: null
    property Item ghostItem: null

    onDataListChanged: {
        syncDataModel()
        rebuild()
    }

    WidgetSettings {
        id: widgetSettings
    }

    DataSources {
        id: dataSources

        live: controller.dataLive
        demo: controller.demoData
        eventDays: widgetSettings.eventDays
        eventAllDay: widgetSettings.eventAllDay
        weatherHourly: widgetSettings.weatherForecast !== "daily"
        onPlayerChanged: controller.keepLastPlayer()
        wanted: {
            var kinds = {}
            for (var i = 0; i < controller.dataList.length; i++)
                kinds[controller.dataList[i].kind] = true
            for (var k = 0; controller.galleryOpen && k < controller.dataStore.kindOrder.length; k++)
                kinds[controller.dataStore.kindOrder[k]] = true
            return kinds
        }
    }

    // the last MPRIS player, for the Now playing widget's idle face (only with the real settings)
    function keepLastPlayer() {
        var entry = dataSources.player && !demoData ? dataSources.player.desktopEntry : ""
        if (persistent && entry !== "" && widgetSettings.lastPlayer !== entry)
            widgetSettings.lastPlayer = entry
    }

    Connections {
        target: dataSources.player
        onDesktopEntryChanged: controller.keepLastPlayer()
    }

    function dataExtras() {
        var extras = []
        for (var i = 0; i < dataEntries.length; i++)
            extras.push({ "id": dataEntries[i].id, "at": dataEntries[i].at })
        return extras
    }

    function dataSizesOf(kind) {
        return dataStore.sizesOf(kind)
    }

    // A block's drawn rectangle in the grid's content: the hook's targetX, targetY, targetWidth and targetHeight
    function blockRect(block) {
        return { "x": block.col * grid.cellWidth,
                 "y": grid.originY + Math.floor(block.row / pageRows) * pageSpan + grid.topMargin
                      + (block.row % pageRows) * grid.realCellHeight,
                 "width": block.w * grid.cellWidth, "height": block.h * grid.realCellHeight }
    }

    // The data widget drawn at a point of the grid's content: {key, left (its left half)}, or null
    function dataHit(x, y) {
        var extra = layout.extra || {}
        for (var key in extra) {
            var r = blockRect(extra[key])
            if (x >= r.x && x < r.x + r.width && y >= r.y && y < r.y + r.height)
                return { "key": key, "left": x < r.x + r.width / 2 }
        }
        return null
    }

    // A drag's plan for the data widgets' slots: applied when the stock moves the item to target (modelMoved), or
    // after the stock reorder delay when the model's order stays (the item only passes data widgets)
    function planCrossing(index, target, next) {
        crossPlan = { "object": model ? model.get(index) : null, "target": target, "order": next }
        crossTimer.stop()
        if (target === index && dataEntries.length > 0)
            crossTimer.restart()
    }

    Timer {
        id: crossTimer

        interval: 150
        onTriggered: {
            if (controller.crossPlan)
                controller.dataStore.setSlots(Grid.slotsOf(controller.crossPlan.order))
        }
    }

    // A stock move (a drag in edit mode): the data widgets' slots follow the drag's plan, or the crossing rule: an
    // icon dropped next to the item it aimed at stays on that side of the data widgets between them
    function modelMoved(start, row) {
        var to = row > start ? row - 1 : row
        crossTimer.stop()
        if (model && dataEntries.length > 0 && start >= 0 && row >= 0) {
            var movedItem = model.get(to)
            var itemCount = model.itemCount
            var slots = null
            if (crossPlan && crossPlan.object === movedItem && crossPlan.target === to) {
                slots = Grid.slotsOf(crossPlan.order)
            } else if (aimed) {
                var base = Grid.compose(itemCount, dataExtras())
                if (aimed.object) {
                    var at = model.indexOf(aimed.object)
                    if (at === to + 1 || at === to - 1)
                        slots = Grid.slotsOf(Grid.placeBeside(base, { "m": to }, { "m": at }, at === to - 1))
                } else if (aimed.end && to === itemCount - 1) {
                    slots = Grid.slotsOf(Grid.moveEntry(base, Grid.positionOf(base, { "m": to }), base.length - 1))
                }
            }
            if (slots)
                dataStore.setSlots(slots)
        }
        crossPlan = null
        rebuild()
    }

    // ---- dragging a data widget: DataWidget.qml lifts its body into the stock drag container ----

    function dataDragContainer() {
        return grid && grid.gridManager ? grid.gridManager.dragContainer : null
    }

    function dataLift(widget) {
        dataLifted = widget
        dataPlanKey = ""
        closeGallery(true)
    }

    function dataMoved(widget) {
        if (dataLifted !== widget)
            return
        dataReplan(widget)
        edgeScroll(widget.dragBody)
    }

    function dataReplan(widget) {
        if (widget)
            replanFor(widget.entry.id, widget.dragBody)
    }

    // The widget wid, drawn by item, aims at the cell under its top left corner; the order planned for it is laid
    // out at once, so the icons slide out of its way
    function replanFor(wid, item) {
        if (!grid || !item)
            return
        var block = layout.extra ? layout.extra[wid] : null
        if (!block)
            return
        var centre = item.mapToItem(grid.contentItem, item.width / 2, item.height / 2)
        var cell = cellFor(block.w, block.h, centre.x, centre.y)
        var key = wid + ":" + cell.row + ":" + cell.col
        if (dataPlanKey === key)
            return
        dataPlanKey = key
        var from = Grid.positionOf(committedOrder, { "x": wid })
        if (from < 0)
            return
        dataPreview = { "id": wid, "order": Grid.bestOrder(committedOrder, spans, extraSpans, from, cell.row, cell.col,
                                                          columns, pageRows, reserved, reservedEnd) }
        rebuild()
    }

    function dataDrop(widget) {
        if (grid && grid.gridManager)
            grid.gridManager.stopScrolling()
        var preview = dataPreview
        dataPreview = null
        dataLifted = null
        dataPlanKey = ""
        if (!preview || !dataStore.setSlots(Grid.slotsOf(preview.order)))
            rebuild()
    }

    // The page turns when the widget's top reaches the page's bottom, or its top the page's top (as the stock drag)
    function edgeScroll(item) {
        var manager = grid && grid.gridManager ? grid.gridManager : null
        var view = manager ? manager.pager : null
        if (!view || !item)
            return
        var maxContentY = view.contentHeight - view.height
        var globalY = view.mapFromItem(item, 0, 0).y
        if (globalY <= 0 && view.contentY > 0)
            manager.scroll(true)
        else if (globalY + Math.min(item.height, grid.cellHeight) >= view.height && view.contentY < maxContentY)
            manager.scroll(false)
        else
            manager.stopScrolling()
    }

    // ---- a widget dragged out of the gallery (WidgetGallery.qml): planned as "new", added where it is let go ----

    function ghostStart(kind, size, item) {
        ghost = { "kind": kind, "size": size }
        ghostItem = item
        dataPreview = null
        dataPlanKey = ""
        rebuild()
        ghostMove(item)
    }

    function ghostMove(item) {
        if (!ghost)
            return
        replanFor("new", item)
        edgeScroll(item)
    }

    function ghostDrop(kind, size) {
        if (grid && grid.gridManager)
            grid.gridManager.stopScrolling()
        var planned = dataPreview && dataPreview.id === "new" ? dataPreview.order : committedOrder
        ghost = null
        ghostItem = null
        dataPreview = null
        dataPlanKey = ""
        pendingPulse = dataStore.add(kind, size, Grid.slotsOf(planned))
        pulseTimer.restart()
        rebuild()
    }

    function ghostCancel() {
        if (grid && grid.gridManager)
            grid.gridManager.stopScrolling()
        ghost = null
        ghostItem = null
        dataPreview = null
        dataPlanKey = ""
        rebuild()
    }

    function dataResize(id, size) {
        dataStore.resize(id, size)
    }

    function dataRemove(id) {
        dataStore.remove(id)
    }

    // a face's request, as it is made (the harness checks them)
    signal dataRequestMade(string what, string argument)

    // A widget's face asks for its app, a settings page, its player (its app, else MPRIS raise), an event in
    // the Calendar or the Calendar on today
    function dataRequest(what, argument) {
        dataRequestMade(what, argument)
        if (what === "app") {
            launchFile(argument)
        } else if (what === "player") {
            if (!launchFile(argument) && dataSources.player) {
                dataSources.player.raise()
                hideLauncher()
            }
        } else if (what === "settings" && actions.item) {
            actions.item.openSettings(argument)
        } else if (what === "event" && dataSources.event) {
            dataSources.event.open(argument)
            hideLauncher()
        } else if (what === "calendar" && dataSources.event) {
            dataSources.event.openToday()
            hideLauncher()
        } else {
            debugLog("widget request", what, argument)
        }
    }

    // the app grid away, as after a launch: another app comes up (the harness has no actions)
    function hideLauncher() {
        if (actions.item)
            actions.item.hideLauncher()
    }

    // an app of the grid by its desktop file: launched (true), or not in the grid (false)
    function launchFile(path) {
        if (entries.length === 0)
            rebuildEntries()
        for (var i = 0; i < entries.length; i++) {
            if (!entries[i].isFolder && entries[i].item && entries[i].item.filePath === path) {
                launch(entries[i].item)
                return true
            }
        }
        debugLog("no app", path)
        return false
    }

    function currentPage() {
        if (!pager || pager.height <= 0)
            return 0
        return Math.max(0, Math.round((pager.contentY - pager.originY) / pager.height))
    }

    // A new widget at the top of the current page: the slot that lays it out nearest to the page's first row
    function addData(kind, size) {
        if (!model || !grid)
            return
        var extras = dataExtras()
        extras.push({ "id": "new", "at": 1e6 })
        var base = Grid.compose(model.itemCount, extras)
        var xspans = {}
        for (var key in extraSpans)
            xspans[key] = extraSpans[key]
        xspans["new"] = Grid.spanOf(size, columns)
        var page = currentPage()
        var next = Grid.bestOrder(base, spans, xspans, base.length - 1, page * pageRows + (page === 0 ? reserved : 0), 0,
                                  columns, pageRows, reserved, reservedEnd)
        pendingPulse = dataStore.add(kind, size, Grid.slotsOf(next))
        pulseTimer.restart()
    }

    Timer {
        id: pulseTimer

        interval: 150
        onTriggered: {
            for (var i = 0; i < dataWidgets.count; i++) {
                var widget = dataWidgets.objectAt(i)
                if (widget && widget.entry.id === controller.pendingPulse)
                    widget.pulse()
            }
        }
    }

    // The widgets as a list model, changed in place: a widget keeps its item (and its slide) when others change
    ListModel {
        id: dataModel
    }

    function syncDataModel() {
        var list = dataList
        for (var i = dataModel.count - 1; i >= 0; i--) {
            var keep = false
            for (var j = 0; j < list.length; j++)
                keep = keep || list[j].id === dataModel.get(i).wid
            if (!keep)
                dataModel.remove(i)
        }
        for (var n = 0; n < list.length; n++) {
            var found = -1
            for (var m = 0; m < dataModel.count; m++) {
                if (dataModel.get(m).wid === list[n].id)
                    found = m
            }
            if (found < 0)
                dataModel.append({ "wid": list[n].id, "kind": list[n].kind, "size": list[n].size })
            else if (dataModel.get(found).size !== list[n].size)
                dataModel.setProperty(found, "size", list[n].size)
        }
    }

    // (an Instantiator, not a Repeater: the widgets live in the grid's content, not beside the Repeater)
    Instantiator {
        id: dataWidgets

        model: dataModel

        DataWidget {
            readonly property var block: homeController.layout.extra ? homeController.layout.extra[model.wid] || null
                                                                     : null
            readonly property var rect: block && homeController.grid ? homeController.blockRect(block) : null

            parent: homeController.grid ? homeController.grid.contentItem : homeController
            visible: rect !== null
            entry: ({ "id": model.wid, "kind": model.kind, "size": model.size })
            controller: homeController
            sources: dataSources
            settings: widgetSettings
            editMode: homeController.grid ? !!homeController.grid.launcherEditMode : false
            glassSource: homeController.glass
            plainGlass: !homeController.persistent
            targetX: rect ? rect.x : 0
            targetY: rect ? rect.y : 0
            targetWidth: rect ? rect.width : 0
            targetHeight: rect ? rect.height : 0
        }
    }

    // where the widget dragged out of the gallery will land: an outlined glass slot
    Rectangle {
        readonly property var block: homeController.ghost && homeController.layout.extra
                                     ? homeController.layout.extra["new"] || null : null
        readonly property var rect: block && homeController.grid ? homeController.blockRect(block) : null

        parent: homeController.grid ? homeController.grid.contentItem : homeController
        visible: rect !== null
        x: rect ? rect.x + Theme.paddingSmall : 0
        y: rect ? rect.y + Theme.paddingSmall : 0
        width: rect ? rect.width - 2 * Theme.paddingSmall : 0
        height: rect ? rect.height - 2 * Theme.paddingSmall : 0
        radius: Theme.paddingLarge
        color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
        border.width: Math.max(1, Math.round(2 * Theme.pixelRatio))
        border.color: Theme.rgba(Theme.highlightColor, 0.45)
    }

    // While the gallery or the peek is open, the pager stays still under it (its interactive is a binding in
    // Launcher.qml, which comes back when they close); a widget dragged out of the gallery still turns the pages
    // (gridManager)
    Binding {
        target: homeController.pager
        property: "interactive"
        value: false
        when: homeController.pager !== null && (homeController.galleryOpen || homeController.peekOpen)
    }

    // The launcher layer closes when it is dragged down: the compositor's launcherInteractiveArea takes the drags of
    // everything on it. While the gallery or the peek is open, their own lists take a pull down instead (closing the
    // gallery, scrolling the notifications): that area is off. Its enabled is a binding in compositor.qml, back when
    // they close.
    readonly property QtObject launcherArea: Lipstick.compositor && Lipstick.compositor.launcherLayer
                                             ? Lipstick.compositor.launcherLayer.interactiveArea || null : null

    Binding {
        target: homeController.launcherArea
        property: "enabled"
        value: false
        when: homeController.launcherArea !== null && (homeController.galleryOpen || homeController.peekOpen)
    }

    // The peek opens under the finger of the long press, which the area already holds (a pressed MouseArea goes on
    // filtering after it is disabled): without a target, that finger cannot drag the layer down either
    Binding {
        target: homeController.launcherArea ? homeController.launcherArea.drag : null
        property: "target"
        value: null
        when: homeController.launcherArea !== null && (homeController.galleryOpen || homeController.peekOpen)
    }

    // After the starter widgets: once, how to edit the grid (GeneralSettings.editHint). A tap on it, or the edit mode,
    // puts it away for good.
    Loader {
        parent: homeController.pager ? homeController.pager : homeController
        z: 16
        anchors.fill: parent
        active: controller.persistent && generalSettings.editHint === "pending"
        sourceComponent: Item {
            readonly property bool shown: controller.dataLive && controller.grid !== null
                                          && !controller.grid.launcherEditMode && !controller.galleryOpen

            opacity: shown ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { FadeAnimation {} }

            InteractionHintLabel {
                id: hintLabel

                anchors.bottom: parent.bottom
                text: qsTr("Hold a widget or an icon to edit the grid. Add widget is at the bottom then.")
            }

            MouseArea {
                anchors.fill: hintLabel
                onClicked: generalSettings.editHint = "done"
            }
        }
    }

    Connections {
        target: controller.grid
        ignoreUnknownSignals: true
        onLauncherEditModeChanged: {
            if (controller.grid.launcherEditMode && generalSettings.editHint === "pending")
                generalSettings.editHint = "done"
        }
    }

    // The edit mode's "+ Widget" capsule, over the bottom of the screen
    AddWidget {
        parent: homeController.pager ? homeController.pager : homeController
        z: 15
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? parent.height - height - (homeController.grid && homeController.grid.bottomMargin !== undefined
                                              ? homeController.grid.bottomMargin : 0) - Theme.paddingSmall : 0
        glass: homeController.glass
        // with the widgets hidden there is nothing to add them to
        opacity: widgetSettings.show && homeController.grid && homeController.grid.launcherEditMode
                 && !homeController.galleryOpen && !homeController.grid.reorderItem
                 && homeController.dataLifted === null ? 1 : 0
        visible: opacity > 0
        enabled: opacity === 1
        Behavior on opacity { FadeAnimation {} }
        onClicked: homeController.openGallery()
    }

    function openGallery() {
        galleryLoader.active = true
        if (galleryLoader.item)
            galleryLoader.item.open()
    }

    function closeGallery(now) {
        if (ghost)
            ghostCancel()
        if (galleryLoader.item)
            galleryLoader.item.close(now)
    }

    Loader {
        id: galleryLoader

        active: false
        sourceComponent: WidgetGallery {
            parent: homeController.pager
            z: 20
            width: homeController.pager ? homeController.pager.width : 0
            height: homeController.pager ? homeController.pager.height : 0
            glass: homeController.glass
            sources: dataSources
            settings: widgetSettings
            controller: homeController
            cellWidth: homeController.grid ? homeController.grid.cellWidth : 0
            cellHeight: homeController.grid ? homeController.grid.realCellHeight : 0
            columns: homeController.columns
            onChosen: {
                close(false)
                homeController.addData(kind, size)
            }
            onGhostStarted: homeController.ghostStart(ghostKind, ghostSize, ghost)
            onGhostMoved: homeController.ghostMove(ghost)
            onGhostDropped: homeController.ghostDrop(kind, size)
            onGhostCanceled: homeController.ghostCancel()
        }
    }
}
