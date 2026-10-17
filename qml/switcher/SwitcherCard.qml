// A card of the task switcher's card row (docs/SWITCHER.md): an app's cover as a card (opaque, as the stock cover:
// never see-through), its name chip under it when it is in front, and flick up to close made plain. A card behind the
// front one is dimmed (dim), not faded. Pushed up, the card shrinks as it goes, and a ring with a × shows where it was,
// filling as the card nears the point of closing ("Pull up to close"). Past that point the ring and the card turn the
// error colour, a tick is felt, and the label says "Release to close"; let go there and the card flies off
// (closeRequested: the stock close); let go before and it springs back. The controller uses it with the live cover (a
// WindowPixmapItem), the harness with a made-up one.
//   cover          what the card shows (a Component: a live cover, or the harness's)
//   launcherItem   the app (the chip)
//   glass          the GlassSource
//   housekeeping   the stock housekeeping mode: the stock × on the card, no flicking
//   flickClose     flick up to close is on
//   chips          the name chip is on
//   front          the card is the one in front (its chip shows)
//   dim            0 .. 1: how far the card is in the background (a dark veil over it)
// progress: 0 at rest .. 1 at the point of closing; dragging, armed: for the row's scrim.
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import "../glass"
import "../core/motion.js" as Motion

Item {
    id: card

    property real cardWidth: Theme.coverSizeLarge.width
    property real cardHeight: Theme.coverSizeLarge.height
    property Component cover
    property var launcherItem
    property Item glass
    property bool housekeeping
    property bool flickClose: true
    property bool chips: true
    property bool front: true
    property real dim: 0

    readonly property real threshold: cardHeight * 0.32
    readonly property real progress: Math.max(0, -face.y) / threshold
    readonly property bool armed: progress >= 1
    readonly property bool dragging: touch.drag.active || flyOff.running || springBack.running
    readonly property color danger: Theme.errorColor !== undefined ? Theme.errorColor : "#ff4956"

    signal tapped()
    signal held()
    signal closeRequested()

    // for the harness: as if the finger pushed the card up to amount (of the point of closing) and let go
    function pushUp(amount) {
        face.y = -threshold * amount
    }

    function release() {
        if (armed)
            flyOff.start()
        else
            springBack.start()
    }

    width: cardWidth
    height: cardHeight + chip.height + Theme.paddingMedium * 2

    // a tick when the card reaches the point of closing (no hard dependency on the module, as the stock)
    property QtObject tick
    onArmedChanged: {
        if (!armed || !touch.drag.active)
            return
        if (!tick) {
            try {
                tick = Qt.createQmlObject("import Nemo.Ngf 1.0; NonGraphicalFeedback { event: 'push_gesture' }",
                                          card, "NonGraphicalFeedback")
            } catch (e) {
                tick = null
            }
        }
        if (tick)
            tick.play()
    }

    // The ring under the card: where it was; it fills as the card goes up
    Item {
        id: target

        readonly property real size: Theme.iconSizeLarge * 1.15

        // just under where the card's bottom is at the point of closing: it comes out from under the card
        anchors.horizontalCenter: parent.horizontalCenter
        y: card.cardHeight - card.threshold + Theme.paddingMedium
        width: size
        height: size
        opacity: Motion.clamp(card.progress * 2.5, 0, 1)
        visible: opacity > 0 && !card.housekeeping
        scale: card.armed ? 1.12 : 0.85 + 0.15 * Math.min(1, card.progress)
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

        GlassPane {
            id: ringPane

            anchors.fill: parent
            radius: width / 2
            glass: card.glass
            frost: 1
            color: card.glass ? card.glass.tintColor(4) : "transparent"
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            visible: !ringPane.visible
            color: Theme.rgba("black", 0.6)
        }

        // the fill: grows from the middle with the push, the error colour once armed
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * Math.min(1, card.progress)
            height: width
            radius: width / 2
            color: card.armed ? card.danger : Theme.rgba(Theme.highlightBackgroundColor, 0.45)
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        // the rim
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: Math.max(2, Math.round(2 * Theme.pixelRatio))
            border.color: card.armed ? card.danger : Theme.rgba(Theme.primaryColor, 0.6)
        }

        Image {
            anchors.centerIn: parent
            source: "image://theme/icon-close-app?" + (card.armed ? "#ffffff" : Theme.primaryColor)
        }
    }

    // the label, on a pill of its own: glass, the error colour once armed
    Item {
        anchors.horizontalCenter: target.horizontalCenter
        anchors.top: target.bottom
        anchors.topMargin: Theme.paddingSmall
        width: label.implicitWidth + 2 * Theme.paddingLarge
        height: label.implicitHeight + Theme.paddingSmall * 2
        opacity: target.opacity
        visible: target.visible

        GlassPane {
            id: labelPane

            anchors.fill: parent
            radius: height / 2
            glass: card.glass
            frost: 1
            color: card.glass ? card.glass.tintColor(4) : "transparent"
            visible: !card.armed && card.glass !== null && card.glass.ready
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            visible: card.armed || !labelPane.visible
            color: card.armed ? card.danger : Theme.rgba("black", 0.6)
        }

        Label {
            id: label

            anchors.centerIn: parent
            font.pixelSize: Theme.fontSizeSmall
            font.bold: card.armed
            color: card.armed ? "white" : Theme.primaryColor
            //: The task switcher's card row: a card pushed up, short of closing / past it
            text: card.armed ? qsTr("Release to close") : qsTr("Pull up to close")
        }
    }

    // The card itself
    Item {
        id: face

        width: card.cardWidth
        height: card.cardHeight
        scale: 1 - 0.12 * Math.min(1, card.progress)
        transformOrigin: Item.Bottom

        // a soft shadow lifts the card off the wallpaper (and off the cards behind it)
        Rectangle {
            anchors.fill: parent
            anchors.margins: -Theme.paddingMedium
            anchors.topMargin: -Theme.paddingSmall
            anchors.bottomMargin: -Theme.paddingLarge
            radius: Theme.paddingMedium * 2
            color: Theme.rgba("black", 0.35)
            z: -1
        }

        Loader {
            anchors.fill: parent
            sourceComponent: card.cover
        }

        // behind the front card: a dark veil, so that the card stays opaque and steps back
        Rectangle {
            anchors.fill: parent
            radius: Theme.paddingMedium
            color: "black"
            opacity: card.dim
            visible: opacity > 0
        }

        // armed: the card takes the error colour
        Rectangle {
            anchors.fill: parent
            radius: Theme.paddingMedium
            color: card.danger
            opacity: card.armed ? 0.35 : 0
            Behavior on opacity { FadeAnimation { duration: 120 } }
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.paddingMedium
            color: "transparent"
            border.width: Math.max(2, Math.round(2 * Theme.pixelRatio))
            border.color: card.danger
            visible: card.armed
        }

        MouseArea {
            id: touch

            property real lastY
            property double lastTime
            property real speed

            anchors.fill: parent
            z: -1
            drag.target: card.flickClose && !card.housekeeping ? face : null
            drag.axis: Drag.YAxis
            drag.maximumY: 0
            drag.minimumY: -card.cardHeight * 1.5
            preventStealing: drag.active

            onPressed: {
                lastY = mouse.y
                lastTime = Date.now()
                speed = 0
            }
            onPositionChanged: {
                var now = Date.now()
                if (now > lastTime)
                    speed = (mouse.y - lastY) / (now - lastTime)
                lastY = mouse.y
                lastTime = now
            }
            onReleased: {
                if (face.y < 0) {
                    // a fast flick up closes as well
                    if (card.armed || speed < -1.4)
                        flyOff.start()
                    else
                        springBack.start()
                }
            }
            // a pinch took the touch over: back down
            onCanceled: if (face.y < 0 && !flyOff.running) springBack.start()
            onClicked: if (face.y === 0) card.tapped()
            onPressAndHold: if (face.y === 0) card.held()
        }

        // the stock × in housekeeping
        Rectangle {
            anchors.verticalCenter: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.iconSizeMedium
            height: width
            radius: width / 2
            color: closeArea.pressed ? Theme.highlightColor : Theme.primaryColor
            opacity: card.housekeeping ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { FadeAnimation {} }

            Image {
                anchors.centerIn: parent
                source: "image://theme/icon-close-app?" + Theme.highlightBackgroundColor
            }

            MouseArea {
                id: closeArea

                anchors.fill: parent
                anchors.margins: -Theme.paddingSmall
                onClicked: card.closeRequested()
            }
        }
    }

    SwitcherChip {
        id: chip

        anchors.horizontalCenter: parent.horizontalCenter
        y: card.cardHeight + Theme.paddingMedium
        glass: card.glass
        launcherItem: card.launcherItem
        hidden: card.housekeeping || card.progress > 0.05 || !card.front
        maxWidth: card.cardWidth
        visible: card.chips
    }

    // off the top, shrinking; then closed (the stock close)
    ParallelAnimation {
        id: flyOff

        NumberAnimation { target: face; property: "y"; to: -card.cardHeight * 1.3; duration: 200; easing.type: Easing.InQuad }
        NumberAnimation { target: face; property: "opacity"; to: 0; duration: 200 }
        onStopped: card.closeRequested()
    }

    NumberAnimation {
        id: springBack

        target: face
        property: "y"
        to: 0
        duration: 320
        easing.type: Easing.OutBack
        easing.overshoot: 1.6
    }
}
