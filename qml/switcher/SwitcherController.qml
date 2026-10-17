// The task switcher (docs/SWITCHER.md). The Patchmanager hook loads this into a Loader in the stock switcher
// (switcher/Switcher.qml); the Loader is its parent and provides the stock pieces:
//   switcher       the switcher (switcherRoot: a SilicaFlickable; housekeeping, count, activateWindowFor)
//   grid           the stock grid of covers (switcherGrid: coverSize, columns)
//   wrapper        the grid's wrapper in the switcher's content (switcherWrapper)
//   covers         the covers' drawn layer (switcherItems)
//   coverRepeater  the covers' Repeater (repeater; its items are the stock SwitcherItems)
//   coverModel     the running apps (switcherModel); mruModel: the same, most recently used first
//   pinchArea      a PinchArea around the wrapper (seaglassPinch): the card row lives in it too
// The hook reads chips and chipSpace (the name chips under the covers, SwitcherChip.qml), extraHeight (room for the
// recently closed apps after the covers), cards (the card row holds off the stock scrolling) and pinchEnabled (the
// pinch area's own enabled).
//
// Settings (dconf /apps/seaglass/switcher, Settings > Patchmanager > Seaglass):
//   background  wallpaper: the chosen wallpaper as it is (stock) | frosted: it frosts while apps run
//   chips       a name chip under each cover
//   layout      grid (stock) | cards: a row of large covers, swiped sideways
//   flickClose  in the card row, a card flicked up closes its app (the stock close)
//   recent      the recently closed apps (RecentApps.qml), recentCount of them, remembered in recentApps
//   pinch       a pinch switches the layout (docs/SWITCHER.md): in for the grid, out for the cards
// Closing stays stock: the housekeeping mode, the ×, Close all; flicking a card up calls the stock close too. The
// hook tells coverClosing(cover) first: in the grid, the closing effect of the animations plays over the cover
// (animations/CoverClosing.qml, docs/ANIMATIONS.md) when they play on covers.
import QtQuick 2.6
import QtQml 2.2
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import Nemo.Configuration 1.0
import org.nemomobile.lipstick 0.1
import com.jolla.coveractions 0.1
import "../settings"
import "../glass"
import "../animations"
import "../core/motion.js" as Motion
import "../animations/styles.js" as Styles
import "../animations/shaders.js" as Shaders

Item {
    id: controller

    readonly property Item switcher: parent && parent.switcher !== undefined ? parent.switcher : null
    readonly property Item grid: parent && parent.grid !== undefined ? parent.grid : null
    readonly property Item wrapper: parent && parent.wrapper !== undefined ? parent.wrapper : null
    readonly property Item covers: parent && parent.covers !== undefined ? parent.covers : null
    readonly property Item coverRepeater: parent && parent.coverRepeater !== undefined ? parent.coverRepeater : null
    readonly property QtObject coverModel: parent && parent.coverModel !== undefined ? parent.coverModel : null
    readonly property QtObject mruModel: parent && parent.mruModel !== undefined ? parent.mruModel : null
    readonly property Item pinchArea: parent && parent.pinchArea !== undefined ? parent.pinchArea : null

    readonly property bool chips: settings.chips
    readonly property bool cards: settings.layout === "cards"
    readonly property real chipSpace: chips ? Theme.iconSizeSmall + 2 * Theme.paddingSmall + Theme.paddingMedium : 0
    // room for the recently closed apps after the covers, in the grid
    readonly property real gridExtra: recentRow.apps.length > 0 ? chipSpace + recentRow.height + Theme.paddingLarge * 3
                                                                : 0
    readonly property real extraHeight: cards ? 0 : gridExtra
    readonly property int count: switcher ? switcher.count : 0
    readonly property bool housekeeping: switcher ? switcher.housekeeping : false

    // the glass: the app grid's when motion.js has it, else one of our own (the home screen's wallpaper)
    property Item homeGlass: Motion.home && Motion.home.glass ? Motion.home.glass : null
    readonly property Item glass: homeGlass ? homeGlass : ownGlass.item

    visible: false

    // The Debug log switch (Seaglass's settings, About): diagnostics go to the journal only while
    // it is on, and the work done only for them (the badge probe, the pinch's checks) runs only then
    GeneralSettings {
        id: debugSettings
    }
    readonly property bool debug: debugSettings.debug

    // console.log with our prefix, while Debug is on
    function debugLog() {
        if (debug)
            console.log.apply(console, ["seaglass:"].concat(Array.prototype.slice.call(arguments)))
    }

    SwitcherSettings {
        id: settings

        // written elsewhere (the settings page forgets them, or keeps fewer): follow it
        onRecentAppsChanged: if (!controller.saving) controller.loadRecent()
        onRecentCountChanged: controller.loadRecent()
    }

    property bool saving

    // a second blurred wallpaper costs memory: ours only until the app grid's glass is found
    Loader {
        id: ownGlass

        active: controller.homeGlass === null
        sourceComponent: GlassSource {
            home: Lipstick.compositor && Lipstick.compositor.wallpaper
                  ? Lipstick.compositor.wallpaper.homeWallpaperItem : null
            frameParent: Lipstick.compositor && Lipstick.compositor.wallpaper
                         ? Lipstick.compositor.wallpaper.transformItem : null
        }
    }

    // Motion.home does not notify: the switcher may be made before the app grid
    Timer {
        property int tries

        interval: 1000
        repeat: true
        running: controller.homeGlass === null && tries < 60
        onTriggered: {
            tries++
            if (Motion.home && Motion.home.glass)
                controller.homeGlass = Motion.home.glass
        }
    }

    // ---- Frosted behind the covers (when chosen): fixed in the switcher's view, under its content ----

    property real frost: count > 0 ? 1 : 0
    Behavior on frost { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }

    GlassPane {
        parent: controller.switcher
        z: -1
        anchors.fill: parent
        visible: settings.background === "frosted" && controller.glass !== null && controller.glass.ready
                 && controller.frost > 0
        glass: controller.glass
        frost: controller.frost
        color: controller.glass ? controller.faded(controller.glass.tintColor(0), controller.frost) : "transparent"
        edgeLight: false
    }

    function faded(color, amount) {
        return Qt.rgba(color.r, color.g, color.b, color.a * amount)
    }

    // ---- Recently closed ----

    // [{filePath, item}]: item is a LauncherItem made for the desktop file
    property var recent: []
    property var itemCache: ({})

    Component {
        id: launcherItemComponent

        LauncherItem {}
    }

    function launcherItemFor(filePath) {
        if (!itemCache[filePath])
            itemCache[filePath] = launcherItemComponent.createObject(controller, { "filePath": filePath })
        return itemCache[filePath]
    }

    function loadRecent() {
        var paths = []
        try {
            paths = JSON.parse(settings.recentApps || "[]") || []
        } catch (e) {
            paths = []
        }
        var list = []
        for (var i = 0; i < paths.length && list.length < settings.recentCount; i++) {
            var item = launcherItemFor(paths[i])
            if (item && item.isValid !== false)
                list.push({ "filePath": paths[i], "item": item, "title": item.title, "iconId": item.iconId })
        }
        recent = list
    }

    function saveRecent() {
        var paths = []
        for (var i = 0; i < recent.length; i++)
            paths.push(recent[i].filePath)
        saving = true
        settings.recentApps = JSON.stringify(paths)
        saving = false
    }

    function withoutApp(list, filePath) {
        var out = []
        for (var i = 0; i < list.length; i++) {
            if (list[i].filePath !== filePath)
                out.push(list[i])
        }
        return out
    }

    // a cover went away: an app the user closed, or that quit (not a start that failed: a pending cover)
    function noteClosed(item) {
        if (!settings.recent || !item || item.pending || !item.launcherItem || !item.launcherItem.filePath)
            return
        var path = item.launcherItem.filePath
        var app = launcherItemFor(path)
        var list = withoutApp(recent, path)
        list.unshift({ "filePath": path, "item": app, "title": app.title, "iconId": app.iconId })
        recent = list.slice(0, settings.recentCount)
        saveRecent()
    }

    function noteRunning(item) {
        if (item && item.launcherItem && item.launcherItem.filePath) {
            var list = withoutApp(recent, item.launcherItem.filePath)
            if (list.length !== recent.length) {
                recent = list
                saveRecent()
            }
        }
    }

    function launchRecent(app) {
        if (app && app.item && switcher)
            switcher.activateWindowFor(app.item)
    }

    function forgetRecent(app) {
        recent = withoutApp(recent, app.filePath)
        saveRecent()
    }

    Connections {
        target: controller.coverRepeater
        ignoreUnknownSignals: true
        onItemRemoved: {
            controller.noteClosed(item)
            controller.revision++
        }
        onItemAdded: {
            controller.noteRunning(item)
            controller.revision++
        }
    }

    Component.onCompleted: {
        Motion.setSwitcher(controller)
        loadRecent()
        // the other way of a pinch gives a little, around the fingers
        if (pinchArea)
            pinchArea.transform = [stretchScale]
    }
    Component.onDestruction: {
        if (Motion.switcher === controller)
            Motion.setSwitcher(null)
    }

    RecentApps {
        id: recentRow

        readonly property real cardsY: controller.switcher ? controller.switcher.height - height
                                                             - Theme.paddingLarge * 3 : 0
        // in the grid's content (the wrapper's), its covers laid out as in the grid: at the bottom of the view, as
        // in the card row, or after the covers (and their chips) when they reach further down
        readonly property real gridY: Math.max(controller.gridHeight() + controller.chipSpace + Theme.paddingLarge * 2,
                                               cardsY - controller.wrapperY)

        // in the grid: in the switcher's content; in the card row: at the bottom of the view; in a switch: gliding
        // from one to the other, in the view
        parent: controller.cards || controller.morphing ? controller.switcher : controller.wrapper
        y: controller.morphing
           ? cardsY + (controller.wrapperY + gridY - controller.morphContentY - cardsY) * morph.gridness
           : controller.cards ? cardsY : gridY
        width: parent ? parent.width : 0
        visible: settings.recent && apps.length > 0 && !controller.housekeeping
        glass: controller.glass
        apps: settings.recent ? controller.recent : []
        onLaunch: controller.launchRecent(app)
        onForget: controller.forgetRecent(app)
    }

    // ---- The card row ----

    // as wide as fits, and never taller than the screen leaves room for (landscape)
    readonly property real cardWidth: switcher ? Math.round(Math.min(switcher.width * 0.56,
        switcher.height * 0.62 * Theme.coverSizeLarge.width / Theme.coverSizeLarge.height)) : 0
    // the cards overlap: the next one sits this far from the front one's centre (a card's width times), behind it
    readonly property real pitch: Math.round(cardWidth * 0.62)
    readonly property real cardHeight: Math.round(cardWidth * Theme.coverSizeLarge.height / Theme.coverSizeLarge.width)
    // goes up when the running apps change, for the cards' stock items
    property int revision

    // the stock covers' drawn layer: hidden in the card row (their wrappers stay visible: they keep the apps'
    // cover surfaces alive); a binding for good, as the layer's visible has none to come back to
    Binding {
        target: controller.covers
        property: "visible"
        value: !controller.cards && !controller.morphing
    }

    // Apps draw their covers at the size the switcher asks for: the card's in the card row. The stock sets the
    // grid's coverSize when its columns change: set again after it
    function applyCoverSize() {
        if (!grid)
            return
        var size = cards ? Qt.size(cardWidth, cardHeight)
                         : (grid.columns === grid.largeColumns ? Theme.coverSizeLarge : Theme.coverSizeSmall)
        if (grid.coverSize.width !== size.width || grid.coverSize.height !== size.height)
            grid.coverSize = size
    }

    onCardsChanged: applyCoverSize()
    onCardWidthChanged: if (cards) applyCoverSize()

    Connections {
        target: controller.grid
        ignoreUnknownSignals: true
        onCoverSizeChanged: if (controller.cards) controller.applyCoverSize()
    }

    Connections {
        target: controller.mruModel
        ignoreUnknownSignals: true
        onCountChanged: controller.revision++
        onRowsMoved: controller.revision++
        onRowsInserted: controller.revision++
        onRowsRemoved: controller.revision++
    }

    // the card row does not scroll the switcher (the stock ensureVisible would, under the status bar)
    Connections {
        target: controller.switcher
        ignoreUnknownSignals: true
        onContentYChanged: {
            if (controller.cards && !controller.housekeeping && controller.switcher.contentY !== 0)
                controller.switcher.contentY = 0
        }
        // gone mid-pinch (an app came up): the pinch ends there
        onVisibleChanged: if (!controller.switcher.visible) gesture.end()
    }

    // the stock close sound and vibration (no hard dependency on the module, as the stock switcher)
    property QtObject closeFeedback

    function stockItem(row) {
        if (!mruModel || !coverRepeater || row < 0)
            return null
        return coverRepeater.itemAt(mruModel.mapRowToSource(row))
    }

    function closeCard(stock) {
        if (!stock)
            return
        if (!closeFeedback) {
            try {
                closeFeedback = Qt.createQmlObject("import Nemo.Ngf 1.0; NonGraphicalFeedback { event: 'close_app' }",
                                                   controller, "NonGraphicalFeedback")
            } catch (e) {
                closeFeedback = null
            }
        }
        if (closeFeedback)
            closeFeedback.play()
        stock.close()
    }

    // The row: in the middle of the room between the top and the recently closed apps (and the hint). Its place is
    // the same in the grid, so that a switch to the cards lands where the row is
    readonly property real rowTop: Math.max(Screen.topCutout.height, Theme.paddingLarge) + Theme.paddingLarge * 2
    readonly property real rowBottom: switcher ? switcher.height - (recentRow.visible
                                                                    ? recentRow.height + Theme.paddingLarge * 4
                                                                    : Theme.paddingLarge * 4) : 0
    readonly property real rowHeight: cardHeight + chipSpace + Theme.paddingLarge * 2
    readonly property real dotsHeight: Theme.paddingLarge * 2 + (hint.wanted ? hint.height + Theme.paddingLarge : 0)
    // the card being pushed up: how far, for the scrim
    readonly property real pushed: row.currentItem ? Math.min(1, row.currentItem.progress) : 0

    // a dark veil over the wallpaper while a card is pushed up: the card, its ring and its label stand out
    Rectangle {
        parent: controller.switcher
        visible: controller.cards && opacity > 0
        anchors.fill: parent
        color: "black"
        opacity: 0.45 * controller.pushed
    }

    ListView {
        id: row

        // in the pinch area (in the switcher's content, which the card row holds at the top), so that a pinch on
        // the cards reaches it
        parent: controller.pinchArea ? controller.pinchArea : controller.switcher
        visible: controller.cards && controller.switcher !== null && !controller.morphing
        y: Math.max(controller.rowTop,
                    controller.rowTop + (controller.rowBottom - controller.rowTop - controller.rowHeight
                                         - controller.dotsHeight) / 2)
        width: parent ? parent.width : 0
        height: controller.rowHeight
        orientation: ListView.Horizontal
        // A deck: the cards overlap, the one in front on top, the others behind it, smaller and darker. A card's
        // turn is only the pitch (about a third of the screen), and a fling runs on over several cards
        spacing: controller.pitch - controller.cardWidth
        snapMode: ListView.SnapToItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width - controller.cardWidth) / 2
        preferredHighlightEnd: (width + controller.cardWidth) / 2
        highlightMoveDuration: 240
        maximumFlickVelocity: 5000 * Theme.pixelRatio
        flickDeceleration: 1800 * Theme.pixelRatio
        // filled before a switch to the cards shows it
        model: controller.cards || controller.rowWanted ? controller.mruModel : null
        // a card pushed up keeps the row still
        interactive: !(currentItem && currentItem.dragging)
        // the cards after a closed one close up
        displaced: Transition {
            NumberAnimation { properties: "x"; duration: 260; easing.type: Easing.OutCubic }
        }

        delegate: SwitcherCard {
            id: slot

            readonly property Item stock: (controller.revision, controller.stockItem(index))
            // how far from the front, in cards
            readonly property real away: Math.abs((x - row.contentX + width / 2) - row.width / 2) / controller.pitch

            z: 10 - away
            // behind the front one: smaller, darker, and gone after the second
            scale: 1 - 0.17 * Math.min(1, away) - 0.08 * Math.max(0, Math.min(1, away - 1))
            dim: Math.min(0.72, 0.5 * away)
            front: away < 0.5
            opacity: away < 2 ? 1 : Math.max(0, 1 - (away - 2) * 2)
            cardWidth: controller.cardWidth
            cardHeight: controller.cardHeight
            glass: controller.glass
            launcherItem: stock ? stock.launcherItem : null
            housekeeping: controller.housekeeping
            // only the card in front closes by a flick
            flickClose: settings.flickClose && ListView.isCurrentItem
            chips: controller.chips

            cover: Component {
                Item {
                    // the stock cover's background (the ambience, as under a transparent cover): opaque, as stock
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.paddingMedium
                        color: Theme.highlightDimmerColor
                    }

                    Loader {
                        anchors.fill: parent
                        source: "file:///usr/share/lipstick-jolla-home-qt5/backgrounds/CoverBackground.qml"
                        onLoaded: item.radius = Theme.paddingMedium
                    }

                    WindowPixmapItem {
                        id: live

                        anchors.fill: parent
                        windowId: slot.stock ? (slot.stock.coverId ? slot.stock.coverId : slot.stock.windowId) : 0
                        radius: Theme.paddingMedium
                        smooth: true
                        opacity: slot.stock && !slot.stock.running ? Theme.opacityHigh : 1
                        xScale: windowSize.width > 0
                                ? Math.min(1.0, (windowSize.height / windowSize.width) / (height / width)) : 1
                        yScale: windowSize.height > 0
                                ? Math.min(1.0, (windowSize.width / windowSize.height) / (width / height)) : 1
                    }

                    LauncherIcon {
                        anchors.centerIn: parent
                        size: Theme.iconSizeLarge
                        icon: slot.launcherItem ? slot.launcherItem.iconId : ""
                        visible: !live.hasPixmap
                    }

                    // the cover's actions, at its bottom
                    CoverActionModel {
                        id: actions

                        window: model.window
                    }

                    Row {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: !controller.housekeeping && !slot.dragging

                        Repeater {
                            model: actions

                            IconButton {
                                width: controller.cardWidth / Math.max(1, actions.count)
                                height: Theme.itemSizeSmall
                                icon.source: model.iconSource
                                onClicked: actions.trigger(model.id)
                            }
                        }
                    }
                }
            }

            // the card in front opens its app; a card behind comes to the front
            onTapped: {
                if (!ListView.isCurrentItem)
                    row.currentIndex = index
                else if (stock)
                    stock.clicked()
            }
            onHeld: if (controller.switcher) controller.switcher.housekeeping = true
            onCloseRequested: {
                hint.learned()
                controller.closeCard(stock)
            }
        }
    }

    // a dot per card
    Row {
        id: dots

        parent: controller.switcher
        visible: (controller.cards || controller.morphing) && row.count > 1 && controller.pushed === 0
        opacity: controller.morphing ? 1 - morph.gridness : 1
        x: parent ? (parent.width - width) / 2 : 0
        y: row.y - controller.rowScroll + row.height + Theme.paddingMedium
        spacing: Theme.paddingMedium

        Repeater {
            model: controller.cards ? row.count : 0

            Rectangle {
                width: Theme.paddingSmall * 1.5
                height: width
                radius: width / 2
                color: index === row.currentIndex ? Theme.highlightColor : Theme.rgba(Theme.primaryColor, 0.4)
            }
        }
    }

    // The first few times: how to close, with an arrow that nudges up
    ConfigurationValue {
        id: hintCount

        key: "/apps/seaglass/switcher/flickHints"
        defaultValue: 0
    }

    SwitcherHint {
        id: hint

        // the hint's room under the row, in either layout (the row's place must not move in a switch); it stays
        // for the visit that counted it, until a card is closed by a flick
        readonly property bool wanted: settings.flickClose && controller.count > 0 && !controller.housekeeping
                                       && (hintCount.value < 3 || counted) && !learnt
        readonly property bool shown: controller.cards && wanted
        property bool counted
        property bool learnt

        // closed by a flick once: learned
        function learned() {
            hintCount.value = 3
            learnt = true
        }

        parent: controller.switcher
        // it fades in after a switch to the cards, and out with a switch to the grid
        visible: opacity > 0
        opacity: (shown && controller.pushed === 0 ? 1 : 0) * (controller.morphing ? 1 - morph.gridness : 1)
        Behavior on opacity { enabled: !controller.morphing; FadeAnimation {} }
        x: parent ? (parent.width - width) / 2 : 0
        y: dots.y + Theme.paddingLarge * 2
        glass: controller.glass

        // counted once per visit to the switcher
        onVisibleChanged: {
            if (visible && !counted) {
                counted = true
                hintCount.value = hintCount.value + 1
            }
        }

        Connections {
            target: controller.switcher
            ignoreUnknownSignals: true
            onVisibleChanged: {
                if (!controller.switcher.visible) {
                    hint.counted = false
                    hint.learnt = false
                }
            }
        }
    }

    // ---- The pinch between the grid and the card row (docs/SWITCHER.md) ----

    // the pinch area takes pinches: when there are covers to switch, and through a pinch that runs
    readonly property bool pinchEnabled: settings.pinch && pinchArea !== null && grid !== null && mruModel !== null
                                         && ((count > 0 && !housekeeping) || gesture.active)
    // the switch layer shows from the first move until the new layout is in place
    readonly property bool morphing: (gesture.active && gesture.progress > 0) || holding
    property bool holding
    // the card row filled before a switch to it shows it
    property bool rowWanted
    // the grid's scroll during a switch: where it was (to the cards) or where it will be (to the grid)
    property real morphContentY
    property int focalRow: -1
    property point pinchCentre
    readonly property real wrapperY: wrapper ? wrapper.y : 0
    // how far the content is scrolled under the card row (the housekeeping pull-down), for what is in the view
    readonly property real rowScroll: pinchArea && switcher && !morphing ? switcher.contentY : 0

    SwitcherPinch {
        id: gesture

        // letting go: the covers drawn for where the switch ends
        onReleased: controller.askCovers(switching ? controller.targetCoverSize : controller.startCoverSize)
        onFinished: controller.pinchFinished(switched)
    }

    // The apps draw their covers at the size asked (sharp covers): in a switch, at the other layout's, asked at the
    // first move, while the covers fly (a still hides each redraw: CoverFade.qml), and asked back if the switch
    // springs back. The stock grid's own size (coverSize) changes only once the switch is done
    property size startCoverSize
    property size targetCoverSize
    property size askedCoverSize

    onMorphingChanged: if (morphing && gesture.pinching) askCovers(targetCoverSize)

    function askCovers(size) {
        if (size.width === askedCoverSize.width && size.height === askedCoverSize.height)
            return
        askedCoverSize = size
        // a frame for the switch layer's pictures, then the stills, then (a frame later) the apps
        stillTimer.restart()
    }

    Timer {
        id: stillTimer

        interval: 40
        onTriggered: {
            morph.refresh()
            askTimer.restart()
        }
    }

    Timer {
        id: askTimer

        interval: 40
        onTriggered: {
            for (var i = 0; i < controller.coverRepeater.count; i++) {
                var stock = controller.coverRepeater.itemAt(i)
                if (stock && stock.cover && stock.cover.surface)
                    stock.cover.surface.requestSize(controller.askedCoverSize)
            }
        }
    }

    // The stock cover's picture (its WindowPixmapItem), which fades in (500 ms) when it comes back
    function stockPicture(stock) {
        var children = stock.contentItem.children
        for (var i = 0; i < children.length; i++) {
            if (children[i].windowId !== undefined && children[i].hasPixmap !== undefined)
                return children[i]
        }
        return null
    }

    // What keeps a stock cover from being at rest at place (in the view), or "" when it is: still moving or fading,
    // elsewhere, or its picture fading
    function stockUnrest(stock, place) {
        var drawn = stock.contentItem
        if (Math.abs(drawn.x - stock.targetX) > 0.5 || Math.abs(drawn.y - stock.targetY) > 0.5)
            return "moving"
        if (drawn.opacity < 1)
            return "fading"
        if (place) {
            var at = stockPlace(stock)
            if (Math.abs(at.x - place.x) > 1 || Math.abs(at.y - place.y) > 1 || Math.abs(at.w - place.w) > 1)
                return "elsewhere"
        }
        var picture = stockPicture(stock)
        if (picture && Math.abs(picture.opacity - stock.coverOpacity) > 0.02)
            return "picture " + picture.opacity.toFixed(2)
        return ""
    }

    // The layout under the switch layer is ready to show: the stock covers at rest at their places (the grid), or
    // the card row still, its card in front in the middle
    function layoutAtRest() {
        if (cards) {
            return row.currentItem !== null && !row.moving && row.currentIndex === focalRow
                    && Math.abs(row.currentItem.x - row.contentX - (row.width - cardWidth) / 2) < 1
        }
        for (var r = 0; r < morph.covers.length; r++) {
            var spec = morph.covers[r]
            if (spec.stock && stockUnrest(spec.stock, spec.grid) !== "")
                return false
        }
        return true
    }

    // The stock draws its ambience background under a transparent cover (and a starting one): the switch keeps it
    function stockBackground(stock) {
        if (!stock || !stock.running)
            return true
        if (stock.cover)
            return !!(stock.cover.surface && stock.cover.surface.windowProperties.TRANSPARENT)
        var window = stock.window
        return !!(window && window.surface && window.surface.windowProperties.BACKGROUND_VISIBLE)
    }

    Connections {
        target: controller.pinchArea
        ignoreUnknownSignals: true
        onPinchStarted: {
            if (!controller.startPinch(pinch.startCenter))
                pinch.accepted = false
        }
        onPinchUpdated: gesture.update(pinch.scale)
        onPinchFinished: gesture.end()
    }

    Scale {
        id: stretchScale

        origin.x: controller.pinchCentre.x
        origin.y: controller.pinchCentre.y
        xScale: 1 + (gesture.toGrid ? 0.04 : -0.04) * gesture.stretch
        yScale: xScale
    }

    SwitcherMorph {
        id: morph

        parent: controller.switcher
        z: 100
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        // drawn (unseen) from the pinch's start, so that the covers' pictures are there at the first move
        visible: gesture.active || controller.holding
        opacity: controller.morphing ? 1 : 0
        progress: gesture.progress
        toGrid: gesture.toGrid
        glass: controller.glass
        chips: controller.chips
        cover: Component {
            Item {
                id: flyingCover

                property var spec
                // 0 as a card (opaque) .. 1 as a cover in the grid (as stock: the ambience background only under a
                // transparent cover)
                property real gridness
                readonly property Item stock: spec ? spec.stock : null
                // a still of it shows the app's picture (or the stock shows none either)
                readonly property bool ready: flyingLive.hasPixmap || !stock || stock.hideCover

                // the app drew the cover again (at another size)
                signal redrawn()

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.paddingMedium
                    color: Theme.highlightDimmerColor
                    opacity: 1 - flyingCover.gridness
                    visible: opacity > 0
                }

                Loader {
                    anchors.fill: parent
                    source: "file:///usr/share/lipstick-jolla-home-qt5/backgrounds/CoverBackground.qml"
                    opacity: flyingCover.spec && flyingCover.spec.gridBackground ? 1 : 1 - flyingCover.gridness
                    visible: opacity > 0
                    onLoaded: item.radius = Theme.paddingMedium
                }

                WindowPixmapItem {
                    id: flyingLive

                    anchors.fill: parent
                    windowId: flyingCover.stock
                              ? (flyingCover.stock.coverId ? flyingCover.stock.coverId : flyingCover.stock.windowId)
                              : 0
                    radius: Theme.paddingMedium
                    smooth: true
                    opacity: flyingCover.stock && !flyingCover.stock.running ? Theme.opacityHigh : 1
                    xScale: windowSize.width > 0
                            ? Math.min(1.0, (windowSize.height / windowSize.width) / (height / width)) : 1
                    yScale: windowSize.height > 0
                            ? Math.min(1.0, (windowSize.width / windowSize.height) / (width / height)) : 1
                    onWindowSizeChanged: flyingCover.redrawn()
                }

                LauncherIcon {
                    anchors.centerIn: parent
                    size: Theme.iconSizeLarge
                    scale: Math.min(1, parent.width / controller.cardWidth)
                    icon: flyingCover.spec && flyingCover.spec.app ? flyingCover.spec.app.iconId : ""
                    // as the stock: only while the cover has no picture (not for a frame before ours comes)
                    visible: !flyingLive.hasPixmap && (!flyingCover.stock || flyingCover.stock.hideCover)
                }
            }
        }
    }

    // The covers' height in the grid, laid out at the grid's cover size (in the card row the stock grid holds the
    // card's size)
    function gridCoverSize() {
        return grid.columns === grid.largeColumns ? Theme.coverSizeLarge : Theme.coverSizeSmall
    }

    function gridHeight() {
        if (!grid || !coverModel)
            return 0
        var rows = Math.ceil(count / Math.max(1, grid.columns))
        return Math.max(0, rows * (gridCoverSize().height + grid.rowSpacing) - grid.rowSpacing)
    }

    // A cover's place in the grid (SwitcherGrid's layout: centred columns, rows from the wrapper's top), in the view
    // with the content scrolled to contentY
    function gridPlace(index, contentY) {
        var size = gridCoverSize()
        var columns = Math.max(1, grid.columns)
        var left = Math.floor((wrapper.width - (size.width + grid.spacing) * columns + grid.spacing) / 2)
        return { "x": left + (index % columns) * (size.width + grid.spacing),
                 "y": wrapper.y + Math.floor(index / columns) * (size.height + grid.rowSpacing) - contentY,
                 "w": size.width, "h": size.height }
    }

    // A stock cover's drawn place, in the view
    function stockPlace(stock) {
        var drawn = stock.contentItem
        var p = drawn.mapToItem(switcher, 0, 0)
        return { "x": p.x, "y": p.y, "w": drawn.width * drawn.scale, "h": drawn.height * drawn.scale }
    }

    // A card's place in the row, as the delegate draws it (scaled about its centre); left0: where row 0's
    // delegate is, in the view
    function cardPlace(r, left0) {
        var delegateHeight = cardHeight + Theme.iconSizeSmall + 2 * Theme.paddingSmall + 2 * Theme.paddingMedium
        var cx = left0 + r * pitch + cardWidth / 2
        var away = Math.abs(cx - row.width / 2) / pitch
        var s = 1 - 0.17 * Math.min(1, away) - 0.08 * Math.max(0, Math.min(1, away - 1))
        var cy = row.y + delegateHeight / 2
        return { "x": cx - cardWidth * s / 2, "y": cy + (row.y - cy) * s, "w": cardWidth * s, "h": cardHeight * s,
                 "dim": Math.min(0.72, 0.5 * away), "opacity": away < 2 ? 1 : Math.max(0, 1 - (away - 2) * 2),
                 "z": 10 - away, "front": away < 0.5 }
    }

    // The grid's scroll that shows the cover at index (as the stock ensureVisible: just enough)
    function gridScrollFor(index) {
        var place = gridPlace(index, 0)
        var bottom = place.y + place.h + grid.rowSpacing
        var contentHeight = wrapper.y + Math.max(switcher.height - wrapper.y,
                                                 gridHeight() + grid.rowSpacing - 1 + gridExtra)
        if (bottom <= switcher.height)
            return 0
        return Math.max(0, Math.min(contentHeight - switcher.height, bottom - switcher.height))
    }

    function mruRowOf(index) {
        for (var r = 0; r < mruModel.count; r++) {
            if (mruModel.mapRowToSource(r) === index)
                return r
        }
        return 0
    }

    // A cover is being closed (the stock close, hooked): the closing effect over it, frozen where it is
    function coverClosing(stock) {
        if (cards || morphing || !stock || !stock.contentItem)
            return
        // the app closed itself with its own close gesture: the effect played on its window
        if (Motion.windowJustClosed(stock.windowId)) {
            debugLog("cover closing: with its window")
            return
        }
        var style = Styles.choose(animationSettings, "close")
        if (!animationSettings.covers || style === "stock")
            return
        // only with its shaders loaded (AnimationController.qml reads them all): the cover hides at once
        var base = Qt.resolvedUrl("../animations/shaders/")
        var loaded = Styles.has(style, "shards")
                ? Shaders.fileReady(base + "shards.vert") && Shaders.fileReady(base + "shards.frag")
                : Shaders.ready(style + "-close")
        if (!loaded) {
            debugLog("cover closing: stock,", style, "is not loaded yet")
            return
        }
        // over the drawn covers (this item itself is hidden)
        var layer = covers ? covers : wrapper
        var drawn = stock.contentItem
        var place = drawn.mapToItem(layer, 0, 0)
        coverClosingComponent.createObject(layer, {
            "cover": drawn, "style": style, "x": place.x, "y": place.y, "width": drawn.width,
            "height": drawn.height, "radius": Theme.paddingMedium,
            "duration": Math.round(Styles.duration(style, "close", animationSettings.speed) * 0.85),
            "tint": Qt.vector3d(Theme.highlightColor.r, Theme.highlightColor.g, Theme.highlightColor.b),
            "useTint": animationSettings.ambience ? 1 : 0
        })
        debugLog("cover closing:", style)
    }

    AnimationSettings {
        id: animationSettings
    }

    Component {
        id: coverClosingComponent

        CoverClosing {}
    }

    // The cover of a window in scene coordinates ({x, y, width, height}), for the opening effect
    // (animations/AnimationController.qml); null when it has none
    function coverRectFor(windowId) {
        for (var i = 0; coverRepeater && windowId && i < coverRepeater.count; i++) {
            var stock = coverRepeater.itemAt(i)
            // a cover still launching has no window yet: the stock matches it by its app (Switcher.checkMinimized)
            if (!stock || (stock.windowId !== windowId
                           && (stock.running || !stock.launcherItem || !switcher
                               || !switcher.isWindowIdFor(windowId, stock.launcherItem))))
                continue
            var drawn = stock.contentItem
            var corner = drawn.mapToItem(null, 0, 0)
            return { "x": corner.x, "y": corner.y, "width": drawn.width, "height": drawn.height }
        }
        return null
    }

    // The cover under the fingers (in the pinch area), or the nearest one: its index in the stock model
    function coverAt(point) {
        var best = -1
        var bestDistance = 1e12
        for (var i = 0; i < coverRepeater.count; i++) {
            var stock = coverRepeater.itemAt(i)
            if (!stock)
                continue
            var drawn = stock.contentItem
            var p = drawn.mapToItem(pinchArea, 0, 0)
            var dx = point.x - Math.max(p.x, Math.min(p.x + drawn.width, point.x))
            var dy = point.y - Math.max(p.y, Math.min(p.y + drawn.height, point.y))
            if (dx * dx + dy * dy < bestDistance) {
                bestDistance = dx * dx + dy * dy
                best = i
            }
        }
        return best
    }

    function startPinch(centre) {
        if (gesture.active || holding || !pinchEnabled || count === 0 || housekeeping
                || (row.currentItem && row.currentItem.dragging))
            return false
        var toGrid = cards
        var left0
        switcher.cancelFlick()
        if (toGrid) {
            row.cancelFlick()
            focalRow = Math.max(0, row.currentIndex)
            morphContentY = gridScrollFor(mruModel.mapRowToSource(focalRow))
            // the delegates' positions: row r at left0 + r * pitch
            left0 = (row.currentItem ? row.currentItem.x - row.currentIndex * pitch : 0) - row.contentX
        } else {
            var index = coverAt(centre)
            if (index < 0)
                return false
            focalRow = mruRowOf(index)
            morphContentY = switcher.contentY
            // the card row, filled and at that card, ready under the switch
            rowWanted = true
            row.currentIndex = focalRow
            row.positionViewAtIndex(focalRow, ListView.Center)
            left0 = (row.width - cardWidth) / 2 - focalRow * pitch
        }
        var list = []
        for (var r = 0; r < mruModel.count; r++) {
            var stock = stockItem(r)
            var index2 = mruModel.mapRowToSource(r)
            list.push({ "app": stock ? stock.launcherItem : null, "stock": stock, "cards": cardPlace(r, left0),
                        "grid": toGrid || !stock ? gridPlace(index2, morphContentY) : stockPlace(stock),
                        "gridBackground": stockBackground(stock),
                        "lag": Math.min(1, Math.abs(r - focalRow) / 3) })
        }
        morph.covers = list
        pinchCentre = centre
        startCoverSize = grid.coverSize
        askedCoverSize = grid.coverSize
        targetCoverSize = toGrid ? gridCoverSize() : Qt.size(cardWidth, cardHeight)
        gesture.begin(toGrid)
        return true
    }

    // where the last switch went ("grid", "cards"), or "" when it sprang back
    property string switchedTo

    function pinchFinished(switched) {
        switchedTo = switched ? (gesture.toGrid ? "grid" : "cards") : ""
        if (switched) {
            settings.layout = switchedTo
            if (gesture.toGrid) {
                switcher.contentY = morphContentY
            } else {
                switcher.contentY = 0
                row.currentIndex = focalRow
                row.positionViewAtIndex(focalRow, ListView.Center)
            }
        }
        // the switch layer stays over the new (or the old) layout until it is ready
        holding = true
        hold.ticks = 0
        hold.restart()
    }

    // Under the last frame until the layout under it is ready: the apps have drawn the covers (the stills faded), and
    // the stock covers (or the card row) are at rest at their places; at least 80 ms, at most 1.2 s. The stock grid
    // lays its covers out again for the new cover size, and slides a cover that changes columns and fades one that
    // changes rows (150 ms): shown before they end, they flashed
    Timer {
        id: hold

        property int ticks

        interval: 40
        repeat: true
        onTriggered: {
            ticks++
            var busy = morph.busy() || stillTimer.running || askTimer.running
            var rest = controller.layoutAtRest()
            if ((ticks < 2 || busy || !rest) && ticks < 30)
                return
            stop()
            // the checks of the switch, only with Debug on
            if (controller.debug) {
                if (controller.switchedTo !== "")
                    controller.checkFit()
                controller.debugLog("pinch", controller.switchedTo !== "" ? "to " + controller.switchedTo : "back",
                                    "shown after", ticks * interval, "ms", busy ? "(covers still drawing)" : "",
                                    rest ? "" : "(not at rest)")
            }
            controller.rowWanted = false
            controller.holding = false
            morph.covers = []
            if (controller.debug) {
                watch.ticks = 0
                watch.restart()
            }
        }
    }

    // After the switch layer gave way: anything that still moves or fades in the grid, in the journal (what a flash
    // would be); only with Debug on
    Timer {
        id: watch

        property int ticks

        interval: 40
        repeat: true
        onTriggered: {
            ticks++
            if (controller.cards || controller.morphing || ticks > 10) {
                stop()
                return
            }
            for (var i = 0; i < controller.coverRepeater.count; i++) {
                var stock = controller.coverRepeater.itemAt(i)
                var unrest = stock ? controller.stockUnrest(stock, null) : ""
                if (unrest !== "")
                    controller.debugLog("pinch: cover", i, unrest, "at", ticks * interval, "ms")
            }
        }
    }

    // After a switch: how far the switch's last frame was from the layout shown now (0: no jump), in the journal (Debug)
    function checkFit() {
        var worst = 0
        var left0 = row.currentItem ? row.currentItem.x - row.currentIndex * pitch - row.contentX : 0
        for (var r = 0; r < morph.covers.length; r++) {
            var spec = morph.covers[r]
            if (!spec.stock)
                continue
            var want = gesture.toGrid ? spec.grid : spec.cards
            var got = gesture.toGrid ? stockPlace(spec.stock) : cardPlace(r, left0)
            worst = Math.max(worst, Math.abs(want.x - got.x), Math.abs(want.y - got.y),
                             Math.abs(want.w - got.w), Math.abs(want.h - got.h))
        }
        debugLog("pinch to", gesture.toGrid ? "grid" : "cards", "fit", Math.round(worst), "px")
    }
}
