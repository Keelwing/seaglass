// A launcher folder shown open on the home screen, as a glass tile on the app grid.
//
// The apps are launched with one tap; the title, and the "+N" slot when the apps do not fit, open the folder.
// Types (FolderTypeSelector.qml, grid.js): "card" two by two cells, "shelf" the full width and one row, "panel"
// the full width and two rows. The caller places and sizes the tile; the tile only draws itself and reports taps
// through launch(item) and open(), and in the launcher's edit mode the size control through resize(type).
import QtQuick 2.6
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import ".."
import "../../badges"
import "../../glass"

Item {
    id: tile

    // LauncherFolderItem (itemCount, get(i), title, iconId), or a ListModel in the harness
    property QtObject folder
    property string type: "panel"
    property bool editMode
    // an app is held over the tile: dropping it adds it to the folder
    property bool dropTarget
    // the tile is being dragged in edit mode
    property bool lifted
    // set when the tile cannot use Lipstick's glass (the harness): the plain tint only
    property bool plainGlass
    // the glass (docs/GLASS.md): with glass cards on, the wallpaper frosted through the card instead of
    // Lipstick's cover glass
    property Item glassSource
    readonly property bool glassCard: glassSource !== null && glassSource.ready && glassSource.cards

    signal launch(QtObject item)
    signal open()
    // a long press: the launcher's edit mode
    signal hold()
    // the size control in edit mode: "card", "shelf", "panel", or "icon" (back to a folder icon)
    signal resize(string type)

    // (a model move can hand a tile an app for a moment, before the layout follows: then it has no count)
    readonly property int count: !folder ? 0 : folder.itemCount !== undefined ? folder.itemCount
                                                : folder.count !== undefined ? folder.count : 0
    readonly property string title: folder && folder.title !== undefined ? folder.title : ""

    // Geometry: the tile's outer box is whole grid rows high; the glass sits a gutter inside it
    readonly property real gutter: Theme.paddingSmall
    readonly property real radius: Theme.paddingLarge
    readonly property real headerHeight: Math.round(Theme.fontSizeSmall * 1.9)
    readonly property real labelHeight: Math.ceil(labelMetrics.height)
    // a slot is its icon plus the space for the name
    readonly property real slotExtra: 2 * Theme.paddingSmall + labelHeight + Theme.paddingSmall
    readonly property real contentWidth: glass.width - 2 * Theme.paddingMedium
    // in edit mode the apps make room for the size control at the bottom
    readonly property real controlsHeight: editMode ? sizeBar.height + Theme.paddingMedium : 0
    readonly property real contentHeight: glass.height - headerHeight - Theme.paddingSmall - controlsHeight
    // while an app is held over the tile, it is laid out as if the app were in it already: the apps make room
    readonly property int laidOut: count + (dropTarget ? 1 : 0)
    readonly property var fit: layoutFor(laidOut, contentWidth, contentHeight)
    readonly property int columns: fit.columns
    readonly property int rows: fit.rows
    readonly property real iconSize: fit.icon
    readonly property int capacity: columns * rows
    // more apps than slots: the last slot opens the folder and shows the rest as "+N"
    readonly property int shown: count > capacity ? capacity - 1 : count
    readonly property int hidden: count - shown
    readonly property int used: Math.min(capacity, laidOut)
    readonly property int usedRows: Math.max(1, Math.ceil(used / columns))
    readonly property real pitchX: contentWidth / columns
    readonly property real pitchY: Math.min(contentHeight / usedRows, iconSize + slotExtra + Theme.paddingLarge)

    // The biggest icons (at most the launcher's, at least two thirds of it) with which all the apps fit; when
    // they do not fit even at the smallest size, as many as fit, and "+N" for the rest
    function layoutFor(n, w, h) {
        var largest = Theme.iconSizeLauncher
        // in edit mode the apps are a dimmed preview beside the size control: smaller, so that they still fit
        var smallest = Math.round(Theme.iconSizeLauncher * (editMode ? 0.5 : 0.66))
        var maxColumns = Math.max(1, Math.floor(w / (smallest + Theme.paddingLarge)))
        var best = null
        for (var c = 1; c <= maxColumns; c++) {
            var r = Math.ceil(Math.max(1, n) / c)
            var icon = Math.floor(Math.min(largest, w / c - Theme.paddingLarge, h / r - slotExtra))
            if (icon >= smallest && (!best || icon > best.icon))
                best = { "columns": c, "rows": r, "icon": icon }
        }
        if (!best) {
            // not "rows": a var would hide the property of that name in the whole function
            var fitRows = Math.max(1, Math.floor(h / (smallest + slotExtra)))
            best = { "columns": maxColumns, "rows": fitRows,
                     "icon": Math.floor(Math.min(largest, w / maxColumns - Theme.paddingLarge, h / fitRows - slotExtra)) }
        }
        return best
    }

    // Slots are centred: the used rows in the middle of the tile, a part-filled last row in the middle of it
    function slotX(slot) {
        var row = Math.floor(slot / columns)
        var inRow = row === usedRows - 1 ? used - row * columns : columns
        return (columns - inRow) * pitchX / 2 + (slot % columns) * pitchX
    }

    function slotY(slot) {
        return (contentHeight - usedRows * pitchY) / 2 + Math.floor(slot / columns) * pitchY
    }

    function itemAt(i) {
        return folder ? folder.get(i) : null
    }

    FontMetrics {
        id: labelMetrics
        font.pixelSize: Theme.fontSizeTiny
    }

    // Lifted while dragged: a soft shadow under the glass
    RectangularGlow {
        anchors.fill: glass
        visible: tile.lifted
        glowRadius: Theme.paddingLarge * 1.5
        spread: 0.2
        cornerRadius: tile.radius + glowRadius
        color: Theme.rgba("black", 0.6)
    }

    Item {
        id: glass

        x: tile.gutter
        y: tile.gutter
        width: tile.width - 2 * tile.gutter
        height: tile.height - 2 * tile.gutter

        // Lipstick's glass: the same material as the app covers on the home screen
        Loader {
            id: lipstickGlass

            anchors.fill: parent
            active: !tile.plainGlass && !tile.glassCard
            source: "file:///usr/share/lipstick-jolla-home-qt5/backgrounds/CoverBackground.qml"
            onLoaded: item.radius = tile.radius
        }

        // Our glass: the wallpaper frosted through the card, a touch lighter than the grid, with a rim of light
        GlassPane {
            anchors.fill: parent
            radius: tile.radius
            glass: tile.glassCard ? tile.glassSource : null
            frost: 1
            color: tile.glassSource ? tile.glassSource.tintColor(1) : "transparent"
        }

        // The tint: on top of Lipstick's glass a light veil, or the whole glass when that is not available
        Rectangle {
            anchors.fill: parent
            radius: tile.radius
            visible: !tile.glassCard
            color: lipstickGlass.status === Loader.Ready ? Theme.rgba(Theme.primaryColor, 0.04)
                                                         : Theme.rgba(Theme.highlightDimmerColor, 0.55)
            border.width: Math.max(1, Math.round(Theme.pixelRatio))
            border.color: Theme.rgba(Theme.primaryColor, 0.14)
        }

        // A soft sheen along the top edge
        Rectangle {
            visible: !tile.glassCard
            x: tile.radius
            width: parent.width - 2 * tile.radius
            height: Math.max(1, Math.round(Theme.pixelRatio))
            color: Theme.rgba(Theme.primaryColor, 0.22)
        }

        // Header: the title and the number of apps; opens the folder
        MouseArea {
            id: header

            width: parent.width
            height: tile.headerHeight
            enabled: !tile.editMode
            onClicked: tile.open()
            onPressAndHold: tile.hold()

            Rectangle {
                anchors.fill: parent
                anchors.margins: Theme.paddingSmall / 2
                radius: tile.radius - Theme.paddingSmall / 2
                color: Theme.rgba(Theme.highlightBackgroundColor, Theme.highlightBackgroundOpacity)
                visible: header.pressed && header.containsMouse
            }

            Label {
                anchors {
                    left: parent.left
                    leftMargin: Theme.paddingLarge
                    right: countLabel.left
                    rightMargin: Theme.paddingMedium
                    verticalCenter: parent.verticalCenter
                }
                text: tile.title
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamilyHeading
                color: header.pressed && header.containsMouse ? Theme.highlightColor : Theme.primaryColor
            }

            Label {
                id: countLabel

                anchors {
                    right: chevron.left
                    verticalCenter: parent.verticalCenter
                }
                text: tile.count
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
            }

            Icon {
                id: chevron

                anchors {
                    right: parent.right
                    rightMargin: Theme.paddingMedium
                    verticalCenter: parent.verticalCenter
                }
                width: Math.round(tile.headerHeight * 0.5)
                height: width
                source: "image://theme/icon-m-right"
                highlighted: header.pressed && header.containsMouse
            }
        }

        // The apps, one slot each: icon and name, as on the grid but a size smaller
        Item {
            id: apps

            // in edit mode the apps step back: the tile is moved and sized, not launched
            opacity: tile.editMode ? 0.45 : 1.0
            Behavior on opacity { FadeAnimation {} }

            x: Theme.paddingMedium
            y: tile.headerHeight
            width: tile.contentWidth
            height: tile.contentHeight

            Repeater {
                model: tile.folder

                MouseArea {
                    id: slot

                    readonly property QtObject entry: index < tile.shown ? tile.itemAt(index) : null

                    visible: index < tile.shown
                    enabled: visible && !tile.editMode
                    x: tile.slotX(index)
                    y: tile.slotY(index)
                    width: tile.pitchX
                    height: tile.pitchY
                    onClicked: if (entry) tile.launch(entry)
                    onPressAndHold: tile.hold()

                    LauncherIcon {
                        id: appIcon

                        anchors.horizontalCenter: parent.horizontalCenter
                        y: (parent.height - tile.iconSize - tile.slotExtra) / 2 + Theme.paddingSmall
                        size: tile.iconSize
                        icon: slot.entry && slot.entry.iconId ? slot.entry.iconId : ""
                        pressed: slot.pressed && slot.containsMouse

                        // the app's notification badge
                        IconBadge {
                            item: slot.entry
                            onCard: true
                        }
                    }

                    Label {
                        anchors {
                            top: appIcon.bottom
                            topMargin: Theme.paddingSmall
                            left: parent.left
                            right: parent.right
                            leftMargin: Theme.paddingSmall / 2
                            rightMargin: Theme.paddingSmall / 2
                        }
                        horizontalAlignment: implicitWidth > width ? Text.AlignLeft : Text.AlignHCenter
                        truncationMode: TruncationMode.Fade
                        font.pixelSize: Theme.fontSizeTiny
                        textFormat: Text.PlainText
                        text: slot.entry && slot.entry.title ? slot.entry.title.replace(/\n|\r/g, " ") : ""
                        color: slot.pressed && slot.containsMouse ? Theme.highlightColor : Theme.primaryColor
                    }
                }
            }

            // "+N": the next apps in a small stack, the rest as a number; opens the folder
            MouseArea {
                id: more

                visible: tile.hidden > 0
                enabled: visible && !tile.editMode
                x: tile.slotX(tile.capacity - 1)
                y: tile.slotY(tile.capacity - 1)
                width: tile.pitchX
                height: tile.pitchY
                onClicked: tile.open()
                onPressAndHold: tile.hold()

                Rectangle {
                    id: stack

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: (parent.height - tile.iconSize - tile.slotExtra) / 2 + Theme.paddingSmall
                    width: tile.iconSize
                    height: tile.iconSize
                    radius: width * 0.28
                    color: Theme.rgba(more.pressed && more.containsMouse ? Theme.highlightBackgroundColor
                                                                         : Theme.primaryColor, 0.12)
                    border.width: Math.max(1, Math.round(Theme.pixelRatio))
                    border.color: Theme.rgba(Theme.primaryColor, 0.18)

                    Repeater {
                        model: Math.min(4, tile.hidden)

                        LauncherIcon {
                            readonly property QtObject entry: tile.itemAt(tile.shown + index)

                            x: Math.round(stack.width * (index % 2 === 0 ? 0.12 : 0.52))
                            y: Math.round(stack.height * (index < 2 ? 0.12 : 0.52))
                            size: Math.round(stack.width * 0.36)
                            icon: entry && entry.iconId ? entry.iconId : ""
                        }
                    }
                }

                Label {
                    anchors {
                        top: stack.bottom
                        topMargin: Theme.paddingSmall
                        horizontalCenter: parent.horizontalCenter
                    }
                    font.pixelSize: Theme.fontSizeTiny
                    color: more.pressed && more.containsMouse ? Theme.highlightColor : Theme.secondaryColor
                    text: "+" + tile.hidden
                }
            }
        }

        // An app held over the tile: the glass lights up and the slot it will take pulses
        Rectangle {
            anchors.fill: parent
            radius: tile.radius
            color: Theme.rgba(Theme.highlightBackgroundColor, 0.22)
            opacity: tile.dropTarget ? 1.0 : 0.0
            Behavior on opacity { FadeAnimation {} }
        }

        Rectangle {
            id: dropSlot

            visible: tile.dropTarget && tile.count < tile.capacity
            x: apps.x + tile.slotX(tile.count) + (tile.pitchX - tile.iconSize) / 2
            y: apps.y + tile.slotY(tile.count) + (tile.pitchY - tile.iconSize - tile.slotExtra) / 2 + Theme.paddingSmall
            width: tile.iconSize
            height: tile.iconSize
            radius: width / 2
            color: "transparent"
            border.width: Math.max(1, Math.round(2 * Theme.pixelRatio))
            border.color: Theme.highlightColor

            SequentialAnimation on opacity {
                running: dropSlot.visible
                loops: Animation.Infinite
                NumberAnimation { from: 0.3; to: 1.0; duration: 450; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 1.0; to: 0.3; duration: 450; easing.type: Easing.InOutQuad }
            }
        }

        // Edit mode: the tile is outlined in the highlight colour and carries its size control
        Rectangle {
            anchors.fill: parent
            radius: tile.radius
            color: "transparent"
            border.width: Math.max(1, Math.round(2 * Theme.pixelRatio))
            border.color: Theme.rgba(Theme.highlightColor, 0.8)
            opacity: tile.editMode ? 1.0 : 0.0
            Behavior on opacity { FadeAnimation {} }
        }

        SizeBar {
            id: sizeBar

            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: Theme.paddingMedium
            }
            current: tile.type
            maxWidth: parent.width - 2 * Theme.paddingMedium
            enabled: tile.editMode && !tile.lifted
            opacity: enabled ? 1.0 : 0.0
            visible: opacity > 0
            Behavior on opacity { FadeAnimation {} }
            onChosen: tile.resize(type)
        }
    }
}
