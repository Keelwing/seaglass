// Settings: how a folder opens and closes, with a live preview (FolderMotion.qml reads the settings).
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../core/motion.js" as Motion

Page {
    id: page

    allowedOrientations: Orientation.All

    readonly property var styles: [
        { "id": "zoom", "name": qsTr("Zoom"), "about": qsTr("The folder grows out of its icon or widget, and shrinks back into it.") },
        { "id": "spring", "name": qsTr("Spring"), "about": qsTr("The folder pops up from its icon with a springy settle.") },
        { "id": "reveal", "name": qsTr("Reveal"), "about": qsTr("A circle grows from the icon and reveals the folder.") },
        { "id": "slide", "name": qsTr("Slide"), "about": qsTr("The folder rises from the bottom, like a sheet.") },
        { "id": "fade", "name": qsTr("Fade"), "about": qsTr("The stock fade.") }
    ]

    readonly property var speeds: [0.7, 1.0, 1.4]

    function styleIndex(id) {
        for (var i = 0; i < styles.length; i++) {
            if (styles[i].id === id)
                return i
        }
        return 0
    }

    function speedIndex(value) {
        var best = 1
        for (var i = 0; i < speeds.length; i++) {
            if (Math.abs(speeds[i] - value) < Math.abs(speeds[best] - value))
                best = i
        }
        return best
    }

    MotionSettings {
        id: motion
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        VerticalScrollDecorator {}

        Column {
            id: column

            width: parent.width

            PageHeader {
                title: qsTr("Opening a folder")
            }

            // A live preview: a sketch of the app grid, where a folder opens and closes with the chosen motion
            Item {
                width: parent.width
                height: phone.height + 2 * Theme.paddingLarge

                Rectangle {
                    id: phone

                    property real progress: 0

                    anchors.centerIn: parent
                    width: Math.round(Math.min(page.width, page.height) * 0.42)
                    height: Math.round(width * 1.9)
                    radius: Theme.paddingLarge
                    color: Theme.rgba(Theme.highlightDimmerColor, 0.6)
                    border.width: Math.max(1, Math.round(Theme.pixelRatio))
                    border.color: Theme.rgba(Theme.primaryColor, 0.3)
                    clip: true

                    readonly property real cell: width / 4
                    // the folder icon: second row, second column
                    readonly property real originX: cell * 1.5
                    readonly property real originY: Theme.paddingLarge + cell * 1.5
                    readonly property real iconSize: cell * 0.62

                    // the app grid behind
                    Grid {
                        id: apps

                        y: Theme.paddingLarge
                        columns: 4
                        opacity: motion.depth ? 1 - 0.45 * Motion.outCubic(phone.progress) : 1
                        transform: Scale {
                            origin.x: phone.originX
                            origin.y: phone.originY
                            xScale: motion.depth ? 1 - 0.06 * Motion.outCubic(phone.progress) : 1
                            yScale: xScale
                        }

                        Repeater {
                            model: 24

                            Item {
                                width: phone.cell
                                height: phone.cell

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: phone.iconSize
                                    height: width
                                    radius: index === 5 ? width * 0.3 : width / 2
                                    color: index === 5 ? Theme.highlightColor : Theme.rgba(Theme.primaryColor, 0.35)
                                }
                            }
                        }
                    }

                    // the open folder: a panel with its apps
                    Item {
                        id: panel

                        readonly property real p: phone.progress
                        readonly property string style: motion.style
                        readonly property real from: phone.iconSize / phone.width
                        readonly property real e: style === "spring" ? Motion.outBack(p, 2.2)
                                                                     : style === "zoom" ? Motion.outBack(p, 0.9)
                                                                                        : Motion.outCubic(p)

                        width: phone.width
                        height: phone.height
                        opacity: style === "reveal" ? 1 : style === "slide" ? Motion.clamp(p / 0.45, 0, 1)
                                                                            : Motion.clamp(p / 0.3, 0, 1)
                        transform: [
                            Scale {
                                origin.x: phone.originX
                                origin.y: phone.originY
                                xScale: panel.style === "zoom" ? panel.from + (1 - panel.from) * panel.e
                                        : panel.style === "spring" ? 0.82 + 0.18 * panel.e : 1
                                yScale: xScale
                            },
                            Translate {
                                y: panel.style === "slide" ? (1 - panel.e) * phone.height * 0.35 : 0
                            }
                        ]

                        // the panel's background; for "reveal" a circle that grows from the icon (the frame clips it)
                        Rectangle {
                            visible: panel.style !== "reveal"
                            width: phone.width
                            height: phone.height
                            radius: panel.style === "zoom"
                                    ? phone.radius * (1 - panel.e) / Math.max(0.1, panel.from + (1 - panel.from) * panel.e) : 0
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Theme.rgba(Theme.overlayBackgroundColor, 0.95) }
                                GradientStop { position: 1.0; color: Theme.rgba(Theme.overlayBackgroundColor, 0.7) }
                            }
                        }

                        Rectangle {
                            readonly property real r: phone.iconSize / 2 + phone.height * 1.1 * panel.e

                            visible: panel.style === "reveal"
                            x: phone.originX - r
                            y: phone.originY - r
                            width: 2 * r
                            height: 2 * r
                            radius: r
                            color: Theme.rgba(Theme.overlayBackgroundColor, 0.92)
                        }

                        // the folder's apps, rippling in from the icon with "cascade"
                        Grid {
                            x: phone.cell * 0.25
                            y: Theme.paddingLarge + phone.cell
                            columns: 4

                            Repeater {
                                model: 6

                                Item {
                                    readonly property real delay: (index % 4 + Math.floor(index / 4)) / 6 * 0.45
                                    readonly property real t: motion.cascade ? Motion.clamp((panel.p - delay) / 0.55, 0, 1)
                                                                             : Motion.clamp(panel.p / 0.4, 0, 1)

                                    width: phone.cell * 0.875
                                    height: phone.cell

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: phone.iconSize
                                        height: width
                                        radius: width / 2
                                        color: Theme.highlightColor
                                        opacity: parent.t
                                        scale: 0.6 + 0.4 * Motion.outBack(parent.t, 1.4)
                                    }
                                }
                            }
                        }
                    }

                    // open, stay, close, pause: again and again; the closing motion runs the progress back
                    SequentialAnimation {
                        // (outside a page stack, in the harness, always)
                        running: (page.status === PageStatus.Active || !page.pageStack) && Qt.application.active
                        loops: Animation.Infinite

                        PauseAnimation { duration: 500 }
                        NumberAnimation {
                            target: phone
                            property: "progress"
                            from: 0
                            to: 1
                            duration: (motion.style === "fade" ? 400 : 380) * motion.speed
                        }
                        PauseAnimation { duration: 900 }
                        NumberAnimation {
                            target: phone
                            property: "progress"
                            from: 1
                            to: 0
                            duration: 260 * motion.speed
                        }
                    }
                }
            }

            ComboBox {
                label: qsTr("Animation")
                description: page.styles[currentIndex].about
                currentIndex: page.styleIndex(motion.style)
                menu: ContextMenu {
                    Repeater {
                        model: page.styles

                        MenuItem {
                            text: modelData.name
                            onClicked: motion.style = modelData.id
                        }
                    }
                }
            }

            TextSwitch {
                text: qsTr("Cascade")
                description: qsTr("The apps ripple in from the icon.")
                enabled: motion.style !== "fade"
                checked: motion.cascade
                automaticCheck: false
                onClicked: motion.cascade = !motion.cascade
            }

            TextSwitch {
                text: qsTr("Depth")
                description: qsTr("The app grid steps back behind the open folder.")
                enabled: motion.style !== "fade"
                checked: motion.depth
                automaticCheck: false
                onClicked: motion.depth = !motion.depth
            }

            ComboBox {
                label: qsTr("Speed")
                enabled: motion.style !== "fade"
                currentIndex: page.speedIndex(motion.speed)
                menu: ContextMenu {
                    MenuItem { text: qsTr("Fast"); onClicked: motion.speed = page.speeds[0] }
                    MenuItem { text: qsTr("Normal"); onClicked: motion.speed = page.speeds[1] }
                    MenuItem { text: qsTr("Relaxed"); onClicked: motion.speed = page.speeds[2] }
                }
            }
        }
    }
}
