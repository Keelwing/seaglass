// The peek at notifications (docs/BADGES.md): a long press on a badged app or folder opens a glass card by the icon.
// It lists the notifications newest first (summary, preview, time; in a folder, each with its app's icon), scrolling
// when there are more than fit, and has Open (an app: its newest notification's own action, or the app; a folder: the
// folder), Clear (the removable ones) and Edit grid (the stock edit mode the long press would have started). A tap on
// a notification opens it; a tap anywhere else closes the card. HomeController.qml makes it over the app grid and gives
// it what to show (open()).
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import org.nemomobile.lipstick 0.1
import "../glass"
import "../core/motion.js" as Motion

Item {
    id: peek

    property Item glass
    // the app or the folder held
    property QtObject item
    readonly property bool folder: item !== null && item.type === LauncherModel.Folder
    // [{app, note}], newest first
    property var entries: []
    // the icon's place, in this item's coordinates
    property rect origin
    property real progress: 0

    signal openRequested(QtObject item, QtObject notification)
    signal clearRequested(var notes)
    signal editRequested()

    function open(launcherItem, list, icon) {
        item = launcherItem
        entries = list
        var corner = icon.mapToItem(peek, 0, 0)
        origin = Qt.rect(corner.x, corner.y, icon.width, icon.height)
        notifications.contentY = notifications.originY
        visible = true
        closing.stop()
        opening.start()
    }

    function close(now) {
        if (!visible)
            return
        opening.stop()
        if (now) {
            closing.stop()
            progress = 0
            visible = false
        } else if (!closing.running) {
            closing.start()
        }
    }

    // how many, counted as the badge counts them (a notification for five messages is five)
    readonly property int total: {
        var sum = 0
        for (var i = 0; i < entries.length; i++)
            sum += Math.max(1, entries[i].note && entries[i].note.itemCount ? entries[i].note.itemCount : 0)
        return sum
    }

    function notes() {
        var list = []
        for (var i = 0; i < entries.length; i++)
            list.push(entries[i].note)
        return list
    }

    visible: false

    NumberAnimation {
        id: opening

        target: peek
        property: "progress"
        to: 1
        duration: 240
        easing.type: Easing.OutBack
        easing.overshoot: 1.2
    }

    NumberAnimation {
        id: closing

        target: peek
        property: "progress"
        to: 0
        duration: 160
        onStopped: if (peek.progress === 0) peek.visible = false
    }

    // a tap anywhere else closes it
    MouseArea {
        anchors.fill: parent
        onClicked: peek.close()
    }

    Item {
        id: card

        readonly property real margin: Theme.horizontalPageMargin
        // under the icon when there is room, else over it, and always on the screen
        readonly property bool below: peek.origin.y + peek.origin.height + height + margin < peek.height
        readonly property real wantedY: below ? peek.origin.y + peek.origin.height + Theme.paddingMedium
                                              : peek.origin.y - height - Theme.paddingMedium

        x: margin
        y: Motion.clamp(wantedY, margin, Math.max(margin, peek.height - height - margin))
        width: peek.width - 2 * margin
        height: headerRow.height + notifications.height + actions.height + 2 * Theme.paddingMedium
        opacity: Motion.clamp(peek.progress, 0, 1)
        scale: 0.85 + 0.15 * peek.progress
        transformOrigin: below ? Item.Top : Item.Bottom

        // the card takes its own taps
        MouseArea {
            anchors.fill: parent
        }

        GlassPane {
            id: pane

            anchors.fill: parent
            radius: Theme.paddingLarge
            glass: peek.glass
            frost: 1
            color: peek.glass ? peek.glass.tintColor(3) : "transparent"
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.paddingLarge
            visible: !pane.visible
            color: Theme.rgba(Theme.overlayBackgroundColor, 0.92)
        }

        // the app or the folder, and how many
        Item {
            id: headerRow

            x: Theme.paddingLarge
            y: Theme.paddingMedium
            width: parent.width - 2 * x
            height: Theme.itemSizeSmall

            LauncherIcon {
                id: headerIcon

                anchors.verticalCenter: parent.verticalCenter
                size: Theme.iconSizeMedium
                icon: peek.item ? peek.item.iconId : ""
            }

            Label {
                anchors {
                    left: headerIcon.right
                    leftMargin: Theme.paddingMedium
                    right: countLabel.left
                    rightMargin: Theme.paddingMedium
                    verticalCenter: parent.verticalCenter
                }
                truncationMode: TruncationMode.Fade
                color: Theme.highlightColor
                text: peek.item ? peek.item.title : ""
            }

            Label {
                id: countLabel

                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                //: The peek's header: how many notifications the app or the folder has
                text: peek.total === 1 ? qsTr("1 notification") : qsTr("%1 notifications").arg(peek.total)
            }
        }

        // the notifications: four and a half rows at most, then they scroll
        SilicaListView {
            id: notifications

            readonly property real rowHeight: Theme.itemSizeMedium

            anchors.top: headerRow.bottom
            x: Theme.paddingLarge
            width: parent.width - 2 * x
            height: Math.min(peek.entries.length, 4.5) * rowHeight
            clip: true
            interactive: peek.entries.length > 4
            model: peek.entries

            delegate: BackgroundItem {
                width: notifications.width
                height: notifications.rowHeight
                onClicked: {
                    peek.openRequested(modelData.app, modelData.note)
                    peek.close()
                }

                // in a folder: which app it is from
                LauncherIcon {
                    id: appIcon

                    anchors.verticalCenter: parent.verticalCenter
                    visible: peek.folder
                    width: peek.folder ? Theme.iconSizeSmall : 0
                    size: Theme.iconSizeSmall
                    icon: modelData.app ? modelData.app.iconId : ""
                }

                Label {
                    id: summary

                    anchors {
                        left: appIcon.right
                        leftMargin: peek.folder ? Theme.paddingMedium : 0
                        right: time.left
                        rightMargin: Theme.paddingMedium
                    }
                    y: Theme.paddingSmall
                    truncationMode: TruncationMode.Fade
                    font.pixelSize: Theme.fontSizeSmall
                    text: modelData.note ? modelData.note.previewSummary || modelData.note.summary || "" : ""
                }

                Label {
                    id: time

                    anchors.right: parent.right
                    anchors.baseline: summary.baseline
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    text: modelData.note && modelData.note.timestamp
                          ? Format.formatDate(modelData.note.timestamp, Formatter.TimeElapsedShort) : ""
                }

                Label {
                    anchors {
                        top: summary.bottom
                        left: summary.left
                        right: parent.right
                    }
                    truncationMode: TruncationMode.Fade
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    text: modelData.note ? modelData.note.previewBody || modelData.note.body || "" : ""
                }
            }

            VerticalScrollDecorator {}
        }

        // the actions
        Row {
            id: actions

            anchors.top: notifications.bottom
            x: Theme.paddingLarge
            height: Theme.itemSizeSmall
            spacing: Theme.paddingLarge * 1.5

            Repeater {
                //: The peek's actions: open the app (or its newest notification) or the folder, clear the
                //: notifications, the launcher's edit mode
                model: [qsTr("Open"), qsTr("Clear"), qsTr("Edit grid")]

                MouseArea {
                    width: action.implicitWidth
                    height: parent.height
                    onClicked: {
                        if (index === 0)
                            peek.openRequested(peek.item, !peek.folder && peek.entries.length > 0
                                                          ? peek.entries[0].note : null)
                        else if (index === 1)
                            peek.clearRequested(peek.notes())
                        else
                            peek.editRequested()
                        peek.close()
                    }

                    Label {
                        id: action

                        anchors.verticalCenter: parent.verticalCenter
                        color: parent.pressed && parent.containsMouse ? Theme.primaryColor : Theme.highlightColor
                        text: modelData
                    }
                }
            }
        }
    }
}
