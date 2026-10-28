// Settings: the effects with which apps open, load and close (docs/ANIMATIONS.md), with a live preview over the
// ambience's picture. The preview and the style tiles draw with the home screen's own files (../animations:
// Effect.qml, Shards.qml, NoiseTile.qml, styles.js, shaders.js), none of which needs Lipstick: the settings are not
// the compositor.
//
// The preview plays a story over and over: the app grid rises and Notes opens from its icon, then closes; the grid
// rises again, Notes starts on a new cover in the switcher and opens from there, then closes. Each moment takes its
// style from the settings as it starts (styles.js choose), so the preview does what the home screen does. A tile
// tapped plays one round in its own style; the buttons and the moment boxes jump to their moment.
import QtQuick 2.6
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import "../animations"
import "../animations/styles.js" as Styles
import "../animations/shaders.js" as Shaders

Page {
    id: page

    allowedOrientations: Orientation.All

    // whether the preview and the tiles move: only on top, with the Settings app in front (always in the harness,
    // which has no page stack and whose window is never the active one)
    readonly property bool live: !page.pageStack || (status === PageStatus.Active && Qt.application.active)
    readonly property vector3d tint: Qt.vector3d(Theme.highlightColor.r, Theme.highlightColor.g,
                                                 Theme.highlightColor.b)

    ConfigurationValue {
        id: ambiencePicture

        key: "/desktop/jolla/background/portrait/home_picture_filename"
    }
    // the ambience's picture for the preview (the harness sets a stock one)
    property string ambienceFile: ambiencePicture.value

    // the style tiles by group, Stock last, and the stock icon each one loads
    readonly property var groups: {
        var list = []
        for (var i = 0; i < Styles.STYLES.length; i++) {
            var style = Styles.STYLES[i]
            if (list.length === 0 || list[list.length - 1].name !== style.group)
                list.push({ "name": style.group, "styles": [] })
            list[list.length - 1].styles.push(style.id)
        }
        list.push({ "name": qsTr("Stock"), "styles": ["stock"] })
        return list
    }
    readonly property var tileIcons: ({ "stock": "notes", "seaglass": "weather", "tide": "messaging",
                                        "aurora": "clock", "ember": "camera", "volt": "browser", "frost": "map",
                                        "shatter": "gallery", "singularity": "mediaplayer", "dust": "file-manager" })
    readonly property real tileCell: Math.floor((width - 2 * Theme.horizontalPageMargin) / 3)
    // the tiles' loading effects run 12 s and start again, each a little after the one before
    property real tileTime

    // The preview is built at the phone's size and drawn smaller: an app grid of stock icons (Notes is tapped), the
    // switcher's first cover, and the made-up Notes app
    readonly property real full: Math.min(width, height)
    readonly property real fullHeight: Math.round(full * 2.2)
    readonly property real cell: full / 4
    readonly property real rowHeight: Math.round(cell * 1.15)
    readonly property real gridTop: Theme.itemSizeLarge
    readonly property int notesAt: 9
    readonly property var gridApps: [["phone", "Phone"], ["messaging", "Messages"], ["people", "People"],
                                     ["browser", "Browser"], ["email", "Email"], ["camera", "Camera"],
                                     ["gallery", "Gallery"], ["clock", "Clock"], ["calendar", "Calendar"],
                                     ["notes", "Notes"], ["weather", "Weather"], ["settings", "Settings"],
                                     ["store", "Store"], ["calculator", "Calculator"], ["map", "Maps"],
                                     ["mediaplayer", "Media"], ["file-manager", "Files"], ["todo", "Tasks"],
                                     ["office", "Documents"], ["shell", "Terminal"]]
    readonly property real coverX: Math.round((full - 2 * Theme.coverSizeLarge.width - Theme.paddingLarge) / 2)
    readonly property real coverY: Theme.itemSizeExtraLarge
    // where the app opens from, 0 to 1 over the preview: the icon, or the cover it loaded on
    readonly property rect iconRect: Qt.rect(((notesAt % 4) * cell + (cell - Theme.iconSizeLauncher) / 2) / full,
                                             (gridTop + Math.floor(notesAt / 4) * rowHeight + Theme.paddingMedium)
                                             / fullHeight,
                                             Theme.iconSizeLauncher / full, Theme.iconSizeLauncher / fullHeight)
    readonly property rect coverRect: Qt.rect(coverX / full, coverY / fullHeight, Theme.coverSizeLarge.width / full,
                                              Theme.coverSizeLarge.height / fullHeight)

    // The story, step by step, and how long a step without an effect takes (ms)
    readonly property var story: ["grid", "tap", "open", "hold", "close", "grid", "tap", "load", "open", "hold",
                                  "close"]
    readonly property var lengths: ({ "grid": 1300, "tap": 320, "hold": 1100, "load": 2200 })
    property int step: -1
    property string phase
    // 0 to 1 over the step, and in ms
    property real t
    readonly property real stepMs: t * run.duration
    // the second opening comes from the cover the app loaded on
    readonly property bool fromCover: step >= 7
    // a tile tapped: every moment of this round in its style
    property string forced
    // the style of the moment playing, and of the loading on the cover: "stock" when it plays the stock way
    property string momentStyle: "stock"
    property string loadStyle: "stock"
    property real loadTime
    property bool halting

    readonly property bool inMoment: phase === "open" || phase === "close"
    readonly property bool effectOn: inMoment && momentStyle !== "stock" && !Styles.has(momentStyle, "shards")
    readonly property bool shardsOn: inMoment && Styles.has(momentStyle, "shards")
    // the app grid up (1) or down (0), the tap on Notes, the new cover and its loading effect
    readonly property real exposure: phase === "grid" ? easeOut(clamp((stepMs - 500) / 450))
                                     : phase === "tap" ? 1
                                     : phase === "open" && !fromCover ? 1
                                     : phase === "load" ? 1 - easeIn(clamp(stepMs / 300))
                                     : 0
    readonly property real press: phase === "tap" ? Math.sin(Math.PI * t) : 0
    readonly property real coverShown: step === 7 ? clamp(stepMs / 200) : step === 8 || step === 9 ? 1 : 0
    readonly property real coverEffectShown: step === 7 ? clamp(stepMs / 200) : step === 8 ? 1 - clamp(stepMs / 150) : 0
    // the app itself, at rest and in the stock opening (a pause, then a fade) and closing (slides on, fades out)
    readonly property real appShown: phase === "hold" ? 1
                                     : phase === "open" && momentStyle === "stock" ? clamp((stepMs - 150) / 300)
                                     : phase === "close" && momentStyle === "stock" ? 1 - easeInOut(t)
                                     : 0
    readonly property real appSlide: phase === "close" && momentStyle === "stock" ? 0.25 * easeIn(t) : 0

    function clamp(x) {
        return Math.max(0, Math.min(1, x))
    }

    function easeOut(x) {
        return 1 - Math.pow(1 - x, 3)
    }

    function easeIn(x) {
        return x * x * x
    }

    function easeInOut(x) {
        return x * x * (3 - 2 * x)
    }

    function styleName(id) {
        var style = Styles.find(id)
        return style ? style.name : qsTr("Stock")
    }

    // a moment's setting ("", "stock" or a style) as its box lists it
    function momentIndex(value) {
        if (value === "stock")
            return 1
        for (var i = 0; i < Styles.STYLES.length; i++) {
            if (Styles.STYLES[i].id === value)
                return i + 2
        }
        return 0
    }

    // the style of a moment ("open", "loading", "close") as the home screen would choose it
    function styleOf(which) {
        return forced !== "" ? forced : Styles.choose(settings, which)
    }

    // plays the story from a step; length shortens a step without an effect
    function begin(index, length) {
        halting = true
        run.stop()
        nextStep.stop()
        halting = false
        if (index === 0)
            forced = ""
        step = index
        phase = story[index]
        var ms = length || lengths[phase] || 300
        if (inMoment) {
            var chosen = styleOf(phase)
            var shards = Styles.has(chosen, "shards")
            var rect = phase === "close" ? Qt.rect(0, 0, 1, 1) : fromCover ? coverRect : iconRect
            var point = phase === "close" ? Qt.point(0.5, 0.3)
                                          : Qt.point(rect.x + rect.width / 2, rect.y + rect.height / 2)
            effect.moment = phase
            effect.style = chosen !== "stock" && !shards ? chosen : ""
            effect.originRect = rect
            effect.origin = point
            pieces.assemble = phase === "open"
            pieces.impact = point
            var drawn = chosen !== "stock" && (shards ? pieces.ready : effect.ready)
            if (drawn && shards)
                pieces.build()
            momentStyle = drawn ? chosen : "stock"
            ms = drawn ? Styles.duration(chosen, phase, settings.speed) : phase === "open" ? 450 : 300
        } else if (phase === "load") {
            var loading = styleOf("loading")
            coverEffect.style = loading !== "stock" ? loading : ""
            loadStyle = loading !== "stock" && coverEffect.ready ? loading : "stock"
            loadClock.restart()
        }
        run.duration = ms
        run.restart()
    }

    // a button or a box: that moment now, in the settings' style
    function play(index) {
        forced = ""
        begin(index, index === 3 ? 450 : 0)
    }

    // whether every moment is set to the style (its tile is marked)
    function everyMoment(id) {
        return ["open", "loading", "close"].every(function (moment) { return Styles.setting(settings, moment) === id })
    }

    // a tile: the style for every moment, and a round of it in the preview
    function pick(id) {
        settings.style = id
        settings.open = ""
        settings.loading = ""
        settings.close = ""
        if (id !== "stock")
            settings.enabled = true
        forced = id
        begin(1)
    }

    function setMoment(key, value) {
        settings[key] = value
        play(key === "open" ? 1 : key === "loading" ? 6 : 3)
    }

    function resumeStory() {
        if (!live) {
            if (run.running && !run.paused)
                run.pause()
        } else if (step < 0) {
            begin(0)
        } else if (run.paused) {
            run.resume()
        }
    }

    // every shader is read at once, so that a moment never waits for one (compiled the first time it draws)
    function preload() {
        if (effect.glMajor === 0)
            return
        var base = Qt.resolvedUrl("../animations/shaders/")
        var all = Styles.shaders()
        for (var i = 0; i < all.length; i++)
            Shaders.load(base, all[i].style + "-" + all[i].moment, Styles.libs(all[i].style), effect.es3, function () {})
    }

    // a tap on a box's menu sets its currentIndex by hand, which ends the binding: bind again when back
    function rebind() {
        for (var i = 0; i < momentBoxes.count; i++) {
            (function (box) {
                box.currentIndex = Qt.binding(function () { return page.momentIndex(settings[box.settingKey]) })
            })(momentBoxes.itemAt(i))
        }
        speedBox.currentIndex = Qt.binding(function () { return settings.speed })
    }

    onLiveChanged: resumeStory()
    onStatusChanged: {
        if (status === PageStatus.Active)
            rebind()
    }
    Component.onCompleted: {
        preload()
        resumeStory()
    }

    AnimationSettings {
        id: settings
    }

    NoiseTile {
        id: noise
    }

    NumberAnimation {
        id: run

        target: page
        property: "t"
        from: 0
        to: 1
        onStopped: {
            if (!page.halting)
                nextStep.start()
        }
    }

    Timer {
        id: nextStep

        interval: 0
        onTriggered: page.begin((page.step + 1) % page.story.length)
    }

    NumberAnimation {
        id: loadClock

        target: page
        property: "loadTime"
        from: 0
        to: 600
        duration: 600000
    }

    NumberAnimation on tileTime {
        running: page.live
        from: 0
        to: 12
        duration: 12000
        loops: Animation.Infinite
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        VerticalScrollDecorator {}

        Column {
            id: column

            width: parent.width

            PageHeader {
                title: qsTr("Animations")
            }

            // The preview: a small phone over the ambience's picture
            Item {
                width: parent.width
                height: screen.height + 2 * Theme.paddingLarge

                Item {
                    id: screen

                    // from the phone's size to the preview's
                    readonly property real k: width / Math.max(1, page.full)

                    anchors.centerIn: parent
                    width: Math.round(page.full * 0.42)
                    height: Math.round(width * 2.2)
                    clip: true

                    Image {
                        anchors.fill: parent
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.height: Math.round(screen.height)
                        source: page.ambienceFile ? "file://" + page.ambienceFile : ""
                    }

                    // the home screen, at the phone's size: the switcher's new cover and the app grid
                    Item {
                        width: page.full
                        height: page.fullHeight
                        scale: screen.k
                        transformOrigin: Item.TopLeft

                        // the cover the app loads on: the stock look, an icon and a busy indicator
                        Rectangle {
                            x: page.coverX
                            y: page.coverY
                            width: Theme.coverSizeLarge.width
                            height: Theme.coverSizeLarge.height
                            radius: Theme.paddingMedium
                            visible: opacity > 0
                            opacity: page.coverShown
                            color: Theme.rgba("black", 0.35)
                            border.color: Theme.rgba("white", 0.12)

                            Image {
                                anchors.centerIn: parent
                                width: Theme.iconSizeLauncher
                                height: width
                                visible: page.loadStyle === "stock"
                                sourceSize: Qt.size(width, height)
                                source: "image://theme/icon-launcher-notes"
                            }

                            BusyIndicator {
                                anchors.centerIn: parent
                                size: BusyIndicatorSize.Large
                                visible: page.loadStyle === "stock" && page.step === 7
                                running: visible
                            }
                        }

                        // the app grid: rises from the bottom over a dimming veil
                        Item {
                            width: parent.width
                            height: parent.height
                            y: (1 - page.exposure) * height
                            visible: page.exposure > 0

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.rgba("black", 0.4)
                            }

                            Repeater {
                                model: page.gridApps

                                Item {
                                    readonly property real pressed: index === page.notesAt ? page.press : 0

                                    x: (index % 4) * page.cell
                                    y: page.gridTop + Math.floor(index / 4) * page.rowHeight
                                    width: page.cell
                                    height: page.rowHeight

                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: Theme.paddingMedium + (Theme.iconSizeLauncher - height) / 2
                                        width: Math.round(Theme.iconSizeLauncher * 1.3)
                                        height: width
                                        radius: width / 2
                                        visible: parent.pressed > 0
                                        opacity: parent.pressed * 0.5
                                        color: Theme.highlightBackgroundColor
                                    }

                                    Image {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: Theme.paddingMedium
                                        width: Theme.iconSizeLauncher
                                        height: width
                                        scale: 1 - 0.08 * parent.pressed
                                        sourceSize: Qt.size(width, height)
                                        source: "image://theme/icon-launcher-" + modelData[0]
                                    }

                                    Label {
                                        x: Theme.paddingSmall
                                        y: 2 * Theme.paddingMedium + Theme.iconSizeLauncher
                                        width: parent.width - 2 * x
                                        horizontalAlignment: Text.AlignHCenter
                                        truncationMode: TruncationMode.Fade
                                        font.pixelSize: Theme.fontSizeTiny
                                        color: parent.pressed > 0.3 ? Theme.highlightColor : Theme.primaryColor
                                        text: modelData[1]
                                    }
                                }
                            }
                        }
                    }

                    // the made-up app, drawn only through its texture
                    Item {
                        id: appStage

                        width: screen.width
                        height: screen.height

                        Item {
                            width: page.full
                            height: page.fullHeight
                            scale: screen.k
                            transformOrigin: Item.TopLeft

                            NotesPreview {
                                anchors.fill: parent
                                picture: page.ambienceFile
                            }
                        }
                    }

                    ShaderEffectSource {
                        id: appTexture

                        width: screen.width
                        height: screen.height
                        visible: false
                        hideSource: true
                        mipmap: effect.es3 && Styles.has(page.momentStyle, "blur")
                        sourceItem: appStage
                    }

                    Image {
                        id: coverIcon

                        width: Theme.iconSizeLauncher
                        height: width
                        visible: false
                        sourceSize: Qt.size(width, height)
                        source: "image://theme/icon-launcher-notes"
                    }

                    // the loading on the cover, in the preview's own pixels
                    Effect {
                        id: coverEffect

                        x: page.coverX * screen.k
                        y: page.coverY * screen.k
                        width: Theme.coverSizeLarge.width * screen.k
                        height: Theme.coverSizeLarge.height * screen.k
                        visible: page.loadStyle !== "stock" && ready && opacity > 0
                        opacity: page.coverEffectShown
                        moment: "load"
                        source: coverIcon
                        noiseTex: noise
                        time: page.loadTime
                        radiusPx: Theme.paddingMedium * screen.k
                        tint: page.tint
                        useTint: settings.ambience ? 1 : 0
                    }

                    // the app at rest, and in the stock opening and closing
                    ShaderEffect {
                        property variant source: appTexture

                        y: page.appSlide * screen.height
                        width: screen.width
                        height: screen.height
                        visible: opacity > 0
                        opacity: page.appShown
                    }

                    Effect {
                        id: effect

                        width: screen.width
                        height: screen.height
                        visible: page.effectOn && ready
                        source: appTexture
                        noiseTex: noise
                        progress: page.t
                        // the effect's own seconds, as on the home screen
                        time: page.stepMs / 1000
                        tint: page.tint
                        useTint: settings.ambience ? 1 : 0
                        onGlMajorChanged: page.preload()
                    }

                    // Shatter's shards, fewer than on the home screen
                    Shards {
                        id: pieces

                        anchors.fill: parent
                        visible: page.shardsOn && ready
                        capacity: 70
                        rays: 9
                        rings: [0.08, 0.2, 0.38, 0.6, 1.0]
                        source: appTexture
                        progress: page.t
                        tint: page.tint
                        useTint: settings.ambience ? 1 : 0
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: Theme.paddingLarge
                        border.width: Math.max(1, Math.round(Theme.pixelRatio))
                        border.color: Theme.rgba(Theme.primaryColor, 0.3)
                    }
                }
            }

            // one moment at a time
            Row {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                spacing: Theme.paddingMedium

                Repeater {
                    model: [{ "text": qsTr("Open"), "step": 1 }, { "text": qsTr("Loading"), "step": 6 },
                            { "text": qsTr("Close"), "step": 3 }]

                    Button {
                        width: Math.floor((parent.width - 2 * parent.spacing) / 3)
                        text: modelData.text
                        onClicked: page.play(modelData.step)
                    }
                }
            }

            Item {
                width: 1
                height: Theme.paddingLarge
            }

            TextSwitch {
                text: qsTr("App animations")
                description: qsTr("Effects when apps open, load and close. Off: the Sailfish fade.")
                checked: settings.enabled
                automaticCheck: false
                onClicked: settings.enabled = !settings.enabled
            }

            SectionHeader {
                text: qsTr("Style")
            }

            Repeater {
                model: page.groups

                Column {
                    width: column.width

                    Label {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * x
                        height: Theme.itemSizeExtraSmall
                        verticalAlignment: Text.AlignBottom
                        font.pixelSize: Theme.fontSizeExtraSmall
                        font.capitalization: Font.AllUppercase
                        color: Theme.secondaryHighlightColor
                        text: modelData.name
                    }

                    Grid {
                        x: Theme.horizontalPageMargin
                        columns: 3

                        Repeater {
                            model: modelData.styles

                            BackgroundItem {
                                id: tile

                                readonly property string styleId: modelData
                                readonly property bool chosen: page.everyMoment(styleId)
                                // each tile's loop a little after the one before
                                readonly property real offset: page.momentIndex(styleId) * 1.3

                                width: page.tileCell
                                height: tileCover.height + tileName.height + 3 * Theme.paddingMedium
                                onClicked: page.pick(styleId)

                                Item {
                                    id: tileCover

                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: Theme.paddingMedium
                                    width: Math.round(page.tileCell * 0.68)
                                    height: Math.round(width * Theme.coverSizeLarge.height / Theme.coverSizeLarge.width)

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.paddingMedium
                                        color: Theme.rgba("black", 0.3)
                                    }

                                    Image {
                                        id: tileIcon

                                        anchors.centerIn: parent
                                        width: Math.round(parent.width * 0.46)
                                        height: width
                                        visible: tile.styleId === "stock"
                                        sourceSize: Qt.size(Theme.iconSizeLauncher, Theme.iconSizeLauncher)
                                        source: "image://theme/icon-launcher-" + page.tileIcons[tile.styleId]
                                    }

                                    BusyIndicator {
                                        anchors.centerIn: parent
                                        size: BusyIndicatorSize.Medium
                                        visible: tile.styleId === "stock"
                                        running: visible && page.live
                                    }

                                    Effect {
                                        anchors.fill: parent
                                        visible: tile.styleId !== "stock" && ready
                                        opacity: Math.min(1, time / 0.4, (12 - time) / 0.4)
                                        style: tile.styleId !== "stock" ? tile.styleId : ""
                                        moment: "load"
                                        source: tileIcon
                                        noiseTex: noise
                                        time: (page.tileTime + tile.offset) % 12
                                        radiusPx: Theme.paddingMedium
                                        tint: page.tint
                                        useTint: settings.ambience ? 1 : 0
                                    }

                                    Rectangle {
                                        readonly property real line: tile.chosen ? Math.round(2 * Theme.pixelRatio) : 1

                                        anchors {
                                            fill: parent
                                            margins: -line
                                        }
                                        radius: Theme.paddingMedium + line
                                        color: "transparent"
                                        border.width: line
                                        border.color: tile.chosen ? Theme.highlightColor : Theme.rgba(Theme.primaryColor, 0.15)
                                    }
                                }

                                Label {
                                    id: tileName

                                    x: Theme.paddingSmall
                                    y: tileCover.y + tileCover.height + Theme.paddingMedium
                                    width: parent.width - 2 * x
                                    horizontalAlignment: Text.AlignHCenter
                                    truncationMode: TruncationMode.Fade
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    color: tile.chosen || tile.highlighted ? Theme.highlightColor : Theme.primaryColor
                                    text: page.styleName(tile.styleId)
                                }
                            }
                        }
                    }
                }
            }

            TextSwitch {
                text: qsTr("Surprise me")
                description: qsTr("A different style each time an app opens, loads or closes.")
                checked: settings.surprise
                automaticCheck: false
                onClicked: settings.surprise = !settings.surprise
            }

            SectionHeader {
                text: qsTr("Moments")
            }

            Repeater {
                id: momentBoxes

                model: [{ "key": "open", "label": qsTr("Opening") }, { "key": "loading", "label": qsTr("Loading") },
                        { "key": "close", "label": qsTr("Closing") }]

                ComboBox {
                    id: momentBox

                    readonly property string settingKey: modelData.key

                    label: modelData.label
                    currentIndex: page.momentIndex(settings[settingKey])
                    menu: ContextMenu {
                        MenuItem {
                            text: qsTr("Same as style")
                            onClicked: page.setMoment(momentBox.settingKey, "")
                        }

                        MenuItem {
                            text: qsTr("Stock")
                            onClicked: page.setMoment(momentBox.settingKey, "stock")
                        }

                        Repeater {
                            model: Styles.STYLES

                            MenuItem {
                                text: modelData.name
                                onClicked: page.setMoment(momentBox.settingKey, modelData.id)
                            }
                        }
                    }
                }
            }

            SectionHeader {
                text: qsTr("Feel")
            }

            ComboBox {
                id: speedBox

                label: qsTr("Speed")
                currentIndex: settings.speed
                menu: ContextMenu {
                    MenuItem { text: qsTr("Relaxed"); onClicked: { settings.speed = 0; page.play(1) } }
                    MenuItem { text: qsTr("Normal"); onClicked: { settings.speed = 1; page.play(1) } }
                    MenuItem { text: qsTr("Quick"); onClicked: { settings.speed = 2; page.play(1) } }
                }
            }

            TextSwitch {
                text: qsTr("Ambience colours")
                description: qsTr("Fire, water and light take the ambience's highlight colour.")
                checked: settings.ambience
                automaticCheck: false
                onClicked: settings.ambience = !settings.ambience
            }

            TextSwitch {
                text: qsTr("Covers too")
                description: qsTr("Closing a cover in the switcher, or all of them, plays the closing effect on the "
                                  + "covers.")
                checked: settings.covers
                automaticCheck: false
                onClicked: settings.covers = !settings.covers
            }
        }
    }
}
