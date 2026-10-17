// A data widget's block in the app grid (docs/WIDGETS.md): the glass, its kind's face, and in the launcher's edit mode
// the size pill with × and the drag. HomeController.qml makes one per widget in the grid's content and places it at its
// block (targetX, targetY, targetWidth, targetHeight); the harness places it in a scene, and the gallery shows previews
// (preview) and the widget dragged out of it (floating). It calls the controller's dataLift, dataMoved, dataDrop,
// dataResize, dataRemove, dataRequest, dataDragContainer and enterEditMode.
//
// Touches: one handle lies over the whole widget, so that a long press anywhere starts the edit mode and lifts the
// widget, as on an icon. A tap goes to the face (pressAt, release, tapAt: a chip of the status widget, a player's
// button or an event acts), or else opens the widget's app. The drag mirrors the stock delegate's (main/EditableGridDelegate.qml): the block stays in
// the grid as a placeholder (its place outlined) while its body, reparented to the pager (the stock drag
// container), follows the finger; in edit mode a press lifts it after 150 ms (the stock startReorderTimer), outside
// edit mode a long press lifts it at once. The body is moved by hand rather than with MouseArea.drag: with
// preventStealing (so that the pager cannot take the touch) a MouseArea's own drag never starts.
import QtQuick 2.6
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0
import ".."
import "../../glass"

Item {
    id: widget

    // {id, kind, size, at}
    property var entry: ({})
    property Item controller
    property Item sources
    // the widgets' settings (ConfigurationGroup /apps/seaglass/widgets), or null
    property QtObject settings
    property bool editMode
    // the glass (docs/GLASS.md): with glass cards on, the wallpaper frosted through the widget
    property Item glassSource
    // the harness: the plain tint only
    property bool plainGlass
    // shown in the gallery: a preview that takes no touches
    property bool preview
    // dragged out of the gallery: lifted, without a place in the grid yet
    property bool floating

    property real targetX
    property real targetY
    property real targetWidth
    property real targetHeight

    readonly property string kind: entry && entry.kind ? entry.kind : ""
    readonly property string size: entry && entry.size ? entry.size : "card"
    readonly property bool lifted: handle.dragging || floating
    readonly property Item dragBody: bodyItem
    // the kind's face (ClockFace.qml, StatusFace.qml, PlayerFace.qml, EventFace.qml, WeatherFace.qml), once loaded
    readonly property Item faceItem: face.item
    readonly property bool glassCard: glassSource !== null && glassSource.ready && glassSource.cards
    readonly property Item source: sources ? sources.sourceOf(kind) : null
    readonly property bool unavailable: sources ? sources.failed(kind) : false
    readonly property var sizes: {
        var list = controller && controller.dataSizesOf ? controller.dataSizesOf(kind).slice() : []
        list.push("remove")
        return list
    }

    readonly property real gutter: Theme.paddingSmall
    readonly property real radius: Theme.paddingLarge

    // geometry follows the layout with the stock slide (150 ms), once placed
    property bool placed
    x: targetX
    y: targetY
    width: targetWidth
    height: targetHeight
    Behavior on x { enabled: widget.placed && !widget.preview && !widget.floating; NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
    Behavior on y { enabled: widget.placed && !widget.preview && !widget.floating; NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
    Component.onCompleted: placeTimer.start()

    Timer {
        id: placeTimer

        interval: 400
        onTriggered: widget.placed = true
    }

    // a setting of the widgets (settings may lack it, as the harness's): read in bindings, so it follows a change
    function setting(name, fallback) {
        return settings && settings[name] !== undefined ? settings[name] : fallback
    }

    function activate() {
        if (face.item && face.item.activate)
            face.item.activate()
    }

    function releaseControl() {
        if (face.item && face.item.release)
            face.item.release()
        handle.onControl = false
    }

    // The body leaves the grid for the drag container, keeping its place on the screen (as the stock reparent())
    function reparentBody(newParent) {
        var position = bodyItem.mapToItem(newParent, 0, 0)
        bodyItem.parent = newParent
        bodyItem.x = position.x - bodyItem.width / 2 * (1 - bodyItem.scale)
        bodyItem.y = position.y - bodyItem.height / 2 * (1 - bodyItem.scale)
    }

    function lift() {
        if (handle.dragging || preview || !controller)
            return
        settle.stop()
        releaseControl()
        var container = controller.dataDragContainer ? controller.dataDragContainer() : null
        handle.dragging = true
        if (container)
            reparentBody(container)
        bodyItem.z = 1000
        // the finger moves the body from here
        handle.dragOrigin = handle.lastScene
        handle.bodyStart = Qt.point(bodyItem.x, bodyItem.y)
        controller.dataLift(widget)
    }

    // the finger at a point of the scene: the body follows it
    function follow(scene) {
        bodyItem.x = handle.bodyStart.x + scene.x - handle.dragOrigin.x
        bodyItem.y = handle.bodyStart.y + scene.y - handle.dragOrigin.y
    }

    function drop() {
        if (!handle.dragging)
            return
        handle.dragging = false
        if (controller)
            controller.dataDrop(widget)
        if (bodyItem.parent !== widget)
            reparentBody(widget)
        bodyItem.z = 0
        settle.start()
    }

    // a ring of light, twice: a widget just added
    function pulse() {
        pulseAnimation.restart()
    }

    function remove() {
        removeAnimation.start()
    }

    SequentialAnimation {
        id: removeAnimation

        FadeAnimation { target: widget; property: "opacity"; to: 0 }
        ScriptAction { script: if (widget.controller) widget.controller.dataRemove(widget.entry.id) }
    }

    // the place of the lifted widget: an outlined glass slot
    Rectangle {
        visible: handle.dragging
        x: widget.gutter
        y: widget.gutter
        width: widget.width - 2 * widget.gutter
        height: widget.height - 2 * widget.gutter
        radius: widget.radius
        color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
        border.width: Math.max(1, Math.round(2 * Theme.pixelRatio))
        border.color: Theme.rgba(Theme.highlightColor, 0.45)
    }

    Item {
        id: bodyItem

        width: widget.width
        height: widget.height
        scale: widget.lifted ? 1.04 : 1.0
        transformOrigin: Item.Center
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }

        onXChanged: if (handle.dragging && widget.controller) widget.controller.dataMoved(widget)
        onYChanged: if (handle.dragging && widget.controller) widget.controller.dataMoved(widget)

        ParallelAnimation {
            id: settle

            NumberAnimation { target: bodyItem; property: "x"; to: 0; duration: 200; easing.type: Easing.OutQuad }
            NumberAnimation { target: bodyItem; property: "y"; to: 0; duration: 200; easing.type: Easing.OutQuad }
        }

        // Lifted while dragged: a soft shadow under the glass
        RectangularGlow {
            anchors.fill: glass
            visible: widget.lifted
            glowRadius: Theme.paddingLarge * 1.5
            spread: 0.2
            cornerRadius: widget.radius + glowRadius
            color: Theme.rgba("black", 0.6)
        }

        Item {
            id: glass

            x: widget.gutter
            y: widget.gutter
            width: bodyItem.width - 2 * widget.gutter
            height: bodyItem.height - 2 * widget.gutter

            // Lifted, the widget passes over icons, which the glass (it shows the wallpaper) would let through: a
            // backing under it
            Rectangle {
                anchors.fill: parent
                radius: widget.radius
                visible: widget.lifted
                color: Theme.rgba(Theme.overlayBackgroundColor, 0.92)
            }

            // Lipstick's glass: the same material as the app covers on the home screen (as the group widgets)
            Loader {
                id: lipstickGlass

                anchors.fill: parent
                active: !widget.plainGlass && !widget.glassCard
                source: "file:///usr/share/lipstick-jolla-home-qt5/backgrounds/CoverBackground.qml"
                onLoaded: item.radius = widget.radius
            }

            // Our glass: the wallpaper frosted through the widget, with a rim of light. A data widget carries text, so
            // it takes the tint of the glass's text controls (the search field's: dark enough on a bright wallpaper),
            // not the lighter tint of a group widget's tile, which carries only icons
            GlassPane {
                anchors.fill: parent
                radius: widget.radius
                glass: widget.glassCard ? widget.glassSource : null
                frost: 1
                color: widget.glassSource ? widget.glassSource.tintColor(4) : "transparent"
            }

            Rectangle {
                anchors.fill: parent
                radius: widget.radius
                visible: !widget.glassCard
                color: lipstickGlass.status === Loader.Ready ? Theme.rgba(Theme.primaryColor, 0.04)
                                                             : Theme.rgba(Theme.highlightDimmerColor, 0.55)
                border.width: Math.max(1, Math.round(Theme.pixelRatio))
                border.color: Theme.rgba(Theme.primaryColor, 0.14)
            }

            // and a veil for Lipstick's glass, for the same reason (dark on a dark ambience, light on a light one)
            Rectangle {
                anchors.fill: parent
                radius: widget.radius
                visible: !widget.glassCard
                color: Theme.rgba(Theme.overlayBackgroundColor, 0.3)
            }

            Rectangle {
                visible: !widget.glassCard
                x: widget.radius
                width: parent.width - 2 * widget.radius
                height: Math.max(1, Math.round(Theme.pixelRatio))
                color: Theme.rgba(Theme.primaryColor, 0.22)
            }

            // pressed (not on a chip, which lights up itself)
            Rectangle {
                anchors.fill: parent
                radius: widget.radius
                visible: handle.pressed && handle.containsMouse && !handle.onControl && !handle.moved
                         && !widget.editMode && !widget.lifted
                color: Theme.rgba(Theme.highlightBackgroundColor, Theme.highlightBackgroundOpacity)
            }

            Loader {
                id: face

                anchors.fill: parent
                // in edit mode the face steps back behind the size pill: the widget is moved and sized, not used
                opacity: widget.editMode && !widget.preview && !widget.floating ? 0.3 : 1.0
                Behavior on opacity { FadeAnimation {} }
                source: widget.kind === "clock" ? "clock/ClockFace.qml"
                        : widget.kind === "status" ? "status/StatusFace.qml"
                        : widget.kind === "player" ? "player/PlayerFace.qml"
                        : widget.kind === "event" ? "event/EventFace.qml"
                        : widget.kind === "weather" ? "weather/WeatherFace.qml" : ""
                onLoaded: {
                    item.source = Qt.binding(function () { return widget.source })
                    item.size = Qt.binding(function () { return widget.size })
                    item.editMode = Qt.binding(function () { return widget.editMode })
                    if (widget.kind === "clock") {
                        item.style = Qt.binding(function () { return widget.setting("clockFace", "digital") })
                        item.showAlarm = Qt.binding(function () { return widget.setting("clockAlarm", true) })
                    } else if (widget.kind === "status") {
                        item.switches = Qt.binding(function () { return widget.setting("statusSwitches", true) })
                    } else if (widget.kind === "player") {
                        item.radius = widget.radius
                        item.idleMode = Qt.binding(function () { return widget.setting("playerIdle", "last") })
                        item.artBehind = Qt.binding(function () { return widget.setting("playerArt", true) })
                        item.lastPlayer = Qt.binding(function () { return widget.setting("lastPlayer", "") })
                    } else if (widget.kind === "event") {
                        item.hideDetails = Qt.binding(function () { return widget.setting("eventPrivate", false) })
                        item.days = Qt.binding(function () { return widget.setting("eventDays", 6) })
                    } else if (widget.kind === "weather") {
                        item.showFeels = Qt.binding(function () { return widget.setting("weatherFeels", true) })
                        item.forecast = Qt.binding(function () { return widget.setting("weatherForecast", "auto") })
                    }
                    item.request.connect(function (what, argument) {
                        if (widget.controller && !widget.preview)
                            widget.controller.dataRequest(what, argument)
                    })
                }
            }

            // the kind's source could not be loaded on this phone
            Label {
                visible: widget.unavailable
                anchors.centerIn: parent
                width: parent.width - 2 * Theme.paddingLarge
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("Not available on this phone")
            }

            // The handle: over the face, so that a long press anywhere lifts the widget
            MouseArea {
                id: handle

                property bool dragging
                property bool moved
                property bool onControl
                property point pressScene
                property point lastScene
                property point dragOrigin
                property point bodyStart

                anchors.fill: parent
                enabled: !widget.preview && !widget.floating
                preventStealing: dragging

                onPressed: {
                    moved = false
                    pressScene = handle.mapToItem(null, mouse.x, mouse.y)
                    lastScene = pressScene
                    var p = face.mapFromItem(handle, mouse.x, mouse.y)
                    onControl = !widget.editMode && face.item && face.item.pressAt ? face.item.pressAt(p.x, p.y) : false
                    if (widget.editMode)
                        liftTimer.restart()
                }
                onPositionChanged: {
                    var scene = handle.mapToItem(null, mouse.x, mouse.y)
                    lastScene = scene
                    if (!moved && (Math.abs(scene.x - pressScene.x) > Theme.paddingLarge
                                   || Math.abs(scene.y - pressScene.y) > Theme.paddingLarge)) {
                        moved = true
                        if (!dragging)
                            widget.releaseControl()
                    }
                    if (dragging)
                        widget.follow(scene)
                }
                onPressAndHold: {
                    if (!widget.editMode && widget.controller) {
                        widget.controller.enterEditMode()
                        widget.lift()
                    }
                }
                onReleased: {
                    liftTimer.stop()
                    var tapped = onControl
                    widget.releaseControl()
                    if (dragging) {
                        widget.drop()
                    } else if (!widget.editMode && !moved) {
                        var p = face.mapFromItem(handle, mouse.x, mouse.y)
                        if (!(tapped && face.item && face.item.tapAt(p.x, p.y)))
                            widget.activate()
                    }
                }
                onCanceled: {
                    liftTimer.stop()
                    widget.releaseControl()
                    widget.drop()
                }
                // should the touch be lost some other way, the widget never stays lifted
                onPressedChanged: if (!pressed && dragging) widget.drop()

                Timer {
                    id: liftTimer

                    interval: 150
                    onTriggered: widget.lift()
                }
            }

            // a widget just added: a ring of light, twice
            Rectangle {
                id: ring

                anchors.fill: parent
                radius: widget.radius
                color: "transparent"
                border.width: Math.max(2, Math.round(3 * Theme.pixelRatio))
                border.color: Theme.highlightColor
                opacity: 0

                SequentialAnimation {
                    id: pulseAnimation

                    PauseAnimation { duration: 300 }
                    NumberAnimation { target: ring; property: "opacity"; to: 1; duration: 200 }
                    NumberAnimation { target: ring; property: "opacity"; to: 0.3; duration: 300 }
                    NumberAnimation { target: ring; property: "opacity"; to: 1; duration: 300 }
                    PauseAnimation { duration: 400 }
                    NumberAnimation { target: ring; property: "opacity"; to: 0; duration: 400 }
                }
            }

            // Edit mode: the widget is outlined in the highlight colour and carries its size pill
            Rectangle {
                anchors.fill: parent
                radius: widget.radius
                color: "transparent"
                border.width: Math.max(1, Math.round(2 * Theme.pixelRatio))
                border.color: Theme.rgba(Theme.highlightColor, 0.8)
                opacity: widget.editMode && !widget.preview && !widget.floating ? 1.0 : 0.0
                Behavior on opacity { FadeAnimation {} }
            }

            SizeBar {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: Theme.paddingMedium
                }
                types: widget.sizes
                current: widget.size
                maxWidth: parent.width - 2 * Theme.paddingMedium
                enabled: widget.editMode && !widget.lifted && !widget.preview && !widget.floating
                opacity: enabled ? 1.0 : 0.0
                visible: opacity > 0
                Behavior on opacity { FadeAnimation {} }
                onChosen: {
                    if (type === "remove")
                        widget.remove()
                    else if (widget.controller)
                        widget.controller.dataResize(widget.entry.id, type)
                }
            }
        }
    }
}
