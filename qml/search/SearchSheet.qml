// Searching the apps (docs/SEARCH.md): a glass sheet over the app grid that grows out of the search row's pill. Before
// anything is typed: the apps used most, and all the apps A–Z with a letter rail on the right edge (drag along it: a
// bubble shows the letter, the list goes there). While typing: the matches, best first (search.js), the first one
// ringed: Enter launches it. A long press shows an app in the grid instead.
//   glass     the GlassSource; without it a dark tint
//   entries   the apps (and folders): {key, title, file, folder, iconId, item, isFolder}
//   usage     how much each was used (search.js)
//   keyboard  false in the harness: no focus, so no keyboard
//   fieldAtBottom  the search row is at the bottom: the field rides on the keyboard, the matches just over it
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import "../glass"
import "search.js" as Search
import "../core/motion.js" as Motion

Item {
    id: sheet

    property Item glass
    property var entries: []
    property var usage: ({})
    property var suggested: []
    property int columns: 5
    property bool keyboard: true
    property bool fieldAtBottom
    property real timeScale: 1
    // the keyboard's height (the harness, which has none, can give one), and the room the camera's island takes
    // at the top
    property real fakeKeyboard: -1
    readonly property real keyboardHeight: fakeKeyboard >= 0 ? fakeKeyboard * eased
                                           : Qt.inputMethod.visible ? Qt.inputMethod.keyboardRectangle.height : 0
    readonly property real topInset: Math.max(Screen.topCutout.height, Theme.paddingLarge)

    // the pill it grows out of, in the sheet's coordinates
    property rect origin: Qt.rect(width * 0.1, Theme.paddingLarge, width * 0.8, Theme.itemSizeSmall)
    property real progress: 0
    readonly property real eased: Motion.outCubic(progress)
    readonly property bool opened: visible && progress === 1

    readonly property string query: field.text
    readonly property bool searching: query.replace(/\s+/g, "") !== ""
    readonly property var results: searching ? Search.search(entries, query, usage, Date.now()) : []
    readonly property var sectionList: Search.sections(entries)
    readonly property real cellWidth: Math.floor((width - rail.width) / columns)
    property string railLetter

    signal launch(var entry)
    signal reveal(var entry)
    signal closed()

    function open(pill) {
        if (pill)
            origin = Qt.rect(pill.mapToItem(sheet, 0, 0).x, pill.mapToItem(sheet, 0, 0).y, pill.width, pill.height)
        field.text = ""
        list.contentY = 0
        visible = true
        closeAnimation.stop()
        openAnimation.start()
        if (keyboard)
            field.forceActiveFocus()
    }

    // now: at once, without the motion (the app grid hid, the display went off)
    function close(now) {
        if (!visible)
            return
        field.focus = false
        openAnimation.stop()
        if (now) {
            closeAnimation.stop()
            progress = 0
            finishClose()
        } else if (!closeAnimation.running) {
            closeAnimation.from = progress
            closeAnimation.start()
        }
    }

    function finishClose() {
        visible = false
        field.text = ""
        railLetter = ""
        closed()
    }

    function choose(entry, longPress) {
        if (longPress)
            sheet.reveal(entry)
        else
            sheet.launch(entry)
        close()
    }

    // the rail: the section of a letter (the nearest one there is; "#" is after Z)
    function scrubTo(letter) {
        railLetter = letter
        var key = letter === "#" ? "~" : letter
        for (var i = 0; i < sections.count; i++) {
            var section = sections.itemAt(i)
            if (section && (section.letter === "#" ? "~" : section.letter) >= key) {
                list.contentY = Math.min(section.y + all.y, Math.max(0, list.contentHeight - list.height))
                return
            }
        }
    }

    visible: false

    NumberAnimation {
        id: openAnimation

        target: sheet
        property: "progress"
        to: 1
        duration: 320 * sheet.timeScale
        easing.type: Easing.Linear
        // the app grid may have come up only now: ask for the keyboard again
        onStopped: if (sheet.keyboard && sheet.progress === 1 && !field.activeFocus) field.forceActiveFocus()
    }

    NumberAnimation {
        id: closeAnimation

        target: sheet
        property: "progress"
        to: 0
        duration: 220 * sheet.timeScale
        onStopped: if (sheet.progress === 0) sheet.finishClose()
    }

    // Taps outside the sheet while it grows or shrinks go nowhere
    MouseArea {
        anchors.fill: parent
    }

    // The sheet: glass growing out of the pill, rounded like it while small
    Item {
        id: body

        x: sheet.origin.x * (1 - sheet.eased)
        y: sheet.origin.y * (1 - sheet.eased)
        width: sheet.origin.width + (sheet.width - sheet.origin.width) * sheet.eased
        height: sheet.origin.height + (sheet.height - sheet.origin.height) * sheet.eased

        GlassPane {
            id: pane

            anchors.fill: parent
            radius: sheet.origin.height / 2 * (1 - sheet.eased)
            glass: sheet.glass
            frost: 1
            color: sheet.glass ? sheet.glass.tintColor(3) : "transparent"
            edgeLight: radius > 0 && sheet.glass !== null && sheet.glass.edgeLight
        }

        Rectangle {
            anchors.fill: parent
            radius: pane.radius
            visible: !pane.visible
            color: Theme.rgba(Theme.overlayBackgroundColor, 0.92)
        }
    }

    // The field: where the pill was, then a little wider; at the bottom, on the keyboard
    Item {
        id: header

        readonly property real restY: sheet.fieldAtBottom
                                      ? sheet.height - sheet.keyboardHeight - height - Theme.paddingLarge
                                      : sheet.origin.y

        x: sheet.origin.x * (1 - sheet.eased) + Theme.horizontalPageMargin * sheet.eased
        y: sheet.origin.y + (restY - sheet.origin.y) * sheet.eased
        width: sheet.origin.width + (sheet.width - 2 * Theme.horizontalPageMargin - cancel.width
                                     - Theme.paddingLarge - sheet.origin.width) * sheet.eased
        height: sheet.origin.height

        GlassPane {
            id: fieldPane

            anchors.fill: parent
            radius: height / 2
            glass: sheet.glass
            frost: 1
            color: sheet.glass ? sheet.glass.tintColor(4) : "transparent"
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            visible: !fieldPane.visible
            color: Theme.rgba(Theme.highlightDimmerColor, 0.55)
        }

        SearchField {
            id: field

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            background: null
            textLeftMargin: Theme.paddingLarge + Theme.iconSizeMedium + Theme.paddingMedium
            // the primary colour, not the highlight: readable on the glass whatever the wallpaper
            color: Theme.primaryColor
            placeholderColor: Theme.secondaryColor
            //: The search field of the app search
            placeholderText: qsTr("Search apps")
            inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            EnterKey.enabled: sheet.results.length > 0
            EnterKey.iconSource: "image://theme/icon-m-enter-accept"
            EnterKey.onClicked: sheet.choose(sheet.results[0], false)
        }
    }

    // Cancel: closes the search (as does hiding the app grid)
    MouseArea {
        id: cancel

        anchors.verticalCenter: header.verticalCenter
        x: sheet.width - Theme.horizontalPageMargin - width + (1 - sheet.eased) * Theme.itemSizeLarge
        width: cancelLabel.implicitWidth + 2 * Theme.paddingSmall
        height: header.height
        opacity: sheet.eased
        onClicked: sheet.close()

        Label {
            id: cancelLabel

            anchors.centerIn: parent
            color: cancel.pressed && cancel.containsMouse ? Theme.highlightColor : Theme.primaryColor
            //: Closes the app search
            text: qsTr("Cancel")
        }
    }

    // The apps: used most and A–Z, or the matches
    SilicaFlickable {
        id: list

        y: sheet.fieldAtBottom ? sheet.topInset : header.y + header.height + Theme.paddingMedium
        width: sheet.width - (sheet.searching ? 0 : rail.width)
        height: sheet.fieldAtBottom ? header.y - Theme.paddingMedium - y : sheet.height - y - sheet.keyboardHeight
        contentHeight: content.height + Theme.paddingLarge
        clip: true
        opacity: Motion.clamp((sheet.progress - 0.35) / 0.65, 0, 1)
        visible: opacity > 0

        Column {
            id: content

            width: list.width

            // with the field at the bottom, the matches sit just over it
            Item {
                width: 1
                height: sheet.fieldAtBottom && sheet.searching
                        ? Math.max(0, list.height - matches.height - (noMatch.visible ? noMatch.height : 0)
                                   - Theme.paddingLarge) : 0
            }

            // While typing: the matches
            Grid {
                id: matches

                columns: sheet.columns
                visible: sheet.searching

                Repeater {
                    model: sheet.searching ? sheet.results : []

                    SearchTile {
                        width: sheet.cellWidth
                        glass: sheet.glass
                        entry: modelData
                        first: index === 0
                        onChosen: sheet.choose(modelData, longPress)
                    }
                }
            }

            Label {
                id: noMatch

                visible: sheet.searching && sheet.results.length === 0
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                topPadding: Theme.paddingLarge * 2
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeLarge
                //: The app search found nothing; %1 is what was typed
                text: qsTr("No apps for “%1”").arg(sheet.query.trim())
            }

            // Before typing: the apps used most
            SectionHeader {
                visible: !sheet.searching && sheet.suggested.length > 0
                //: The app search: the apps used most
                text: qsTr("Used most")
            }

            Grid {
                columns: sheet.columns
                visible: !sheet.searching

                Repeater {
                    model: sheet.searching ? [] : sheet.suggested

                    SearchTile {
                        width: sheet.cellWidth
                        glass: sheet.glass
                        entry: modelData
                        onChosen: sheet.choose(modelData, longPress)
                    }
                }
            }

            // and all the apps, A–Z
            Column {
                id: all

                width: parent.width
                visible: !sheet.searching

                Repeater {
                    id: sections

                    model: sheet.sectionList

                    Column {
                        readonly property string letter: modelData.letter

                        width: all.width

                        Label {
                            x: Theme.horizontalPageMargin
                            height: implicitHeight + Theme.paddingMedium
                            verticalAlignment: Text.AlignBottom
                            color: sheet.railLetter === modelData.letter ? Theme.highlightColor
                                                                         : Theme.secondaryHighlightColor
                            font.pixelSize: Theme.fontSizeLarge
                            font.family: Theme.fontFamilyHeading
                            text: modelData.letter
                        }

                        Grid {
                            columns: sheet.columns

                            Repeater {
                                model: modelData.entries

                                SearchTile {
                                    width: sheet.cellWidth
                                    glass: sheet.glass
                                    entry: modelData
                                    onChosen: sheet.choose(modelData, longPress)
                                }
                            }
                        }
                    }
                }
            }
        }

        VerticalScrollDecorator {}
    }

    // The letter rail on the right edge: drag along it, a bubble shows the letter and the list goes there
    Item {
        id: rail

        readonly property real step: Math.min(Theme.fontSizeSmall * 1.25, height / Math.max(1, sheet.sectionList.length))

        x: sheet.width - width
        y: list.y
        width: Theme.paddingLarge * 2.5
        height: list.height
        opacity: list.opacity
        visible: !sheet.searching && opacity > 0

        Column {
            anchors.centerIn: parent

            Repeater {
                model: sheet.sectionList

                Label {
                    width: rail.width
                    height: rail.step
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Theme.fontSizeTiny
                    font.bold: sheet.railLetter === modelData.letter
                    color: sheet.railLetter === modelData.letter ? Theme.highlightColor : Theme.secondaryColor
                    text: modelData.letter
                }
            }
        }

        MouseArea {
            id: railArea

            anchors.fill: parent
            preventStealing: true

            function letterAt(y) {
                var count = sheet.sectionList.length
                var top = (rail.height - count * rail.step) / 2
                var i = Math.floor((y - top) / rail.step)
                return count > 0 ? sheet.sectionList[Motion.clamp(i, 0, count - 1)].letter : ""
            }

            onPressed: sheet.scrubTo(letterAt(mouse.y))
            onPositionChanged: sheet.scrubTo(letterAt(mouse.y))
            onReleased: sheet.railLetter = ""
            onCanceled: sheet.railLetter = ""
        }
    }

    // the bubble: the letter, large, beside the finger
    Item {
        id: bubble

        readonly property int count: sheet.sectionList.length
        readonly property int index: {
            for (var i = 0; i < count; i++) {
                if (sheet.sectionList[i].letter === sheet.railLetter)
                    return i
            }
            return -1
        }

        x: rail.x - width - Theme.paddingLarge
        y: rail.y + (rail.height - count * rail.step) / 2 + (index + 0.5) * rail.step - height / 2
        width: Theme.itemSizeExtraLarge
        height: width
        visible: index >= 0 && rail.visible

        GlassPane {
            id: bubblePane

            anchors.fill: parent
            radius: width / 2
            glass: sheet.glass
            frost: 1
            color: sheet.glass ? sheet.glass.tintColor(4) : "transparent"
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            visible: !bubblePane.visible
            color: Theme.rgba(Theme.highlightBackgroundColor, 0.6)
        }

        Label {
            anchors.centerIn: parent
            font.pixelSize: Theme.fontSizeHuge
            font.family: Theme.fontFamilyHeading
            color: Theme.highlightColor
            text: sheet.railLetter
        }
    }
}
