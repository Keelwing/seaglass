// One still of a moment of a style, as a texture (AnimationsPage.qml, through FreezeQueue.qml): develop() makes the
// moment on the kit's textures (PreviewKit.qml) for a few frames, grabs it, and drops it again, so that nothing of it
// is left to draw but the picture. The holder stays, and with it the picture; grabbed from the effect itself, the
// picture would go with it.
//
// An opening or closing is caught at its progress at the normal speed, whatever the speed setting says, so that no
// still depends on it; a loading at its seconds. With a cut, the frame shows that band of the whole screen: the holder
// is the phone's screen at the frame's width, and the picture takes only the band. Stock is drawn with plain items: the
// app fading in over the grid, the app sliding away, and a cover with a busy indicator standing still.
import QtQuick 2.6
import QtQuick.Window 2.2
import Sailfish.Silica 1.0
import "../animations"
import "../animations/styles.js" as Styles
import "stills.js" as Stills

SilicaControl {
    id: frame

    // "stock" or a style, and "open", "close" or "load"
    property string style
    property string moment
    // the progress of an opening or closing, the seconds of a loading
    property real at
    property Item kit
    // the band of the screen the frame shows, in pixels of the holder; empty for the whole frame
    property rect cut
    // a loading at the frame's own shape, with the icon at 60 percent (the sheet), rather than on a cover of its true
    // size on the wallpaper (the viewer)
    property bool wideLoad
    // grabbed at least once
    readonly property bool developed: picture.sourceItem !== null
    readonly property bool developing: scene.active
    // how many passes a develop draws in its frame, for the queue's pace: a field moment bakes its field first, and a
    // closing with a field also its blurred picture
    readonly property int passes: withField ? (moment === "close" ? 3 : 2) : 1
    // a moment with a field (FrostField.qml, one or two Effects more): its effect is made hidden and shown a frame
    // later, which makes the field, and the shot waits for it. Made together, the two hold the GUI thread for longer
    // than two frames
    readonly property bool withField: kind === "effect" && Styles.listed(style, "field", moment)

    readonly property bool hasCut: cut.width > 0 && cut.height > 0
    readonly property string kind: style === "stock" ? "stock-" + moment
                                   : moment !== "load" && Styles.has(style, "shards") ? "shards" : "effect"
    readonly property bool blurs: moment !== "load" && Styles.has(style, "blur")
    readonly property bool sceneReady: scene.item !== null && scene.item.ready
    // A hidden window (the app in the background, the display off) draws no frame, and a grab is drawn in the window's
    // next frame. A shot the window hid before it could draw is taken again once the window shows, and only then does
    // the moment go
    readonly property bool windowShown: Window.visibility !== Window.Hidden && Window.visibility !== Window.Minimized
    property bool missed

    signal done

    function easeIn(x) {
        return x * x * x
    }

    function easeInOut(x) {
        return x * x * (3 - 2 * x)
    }

    function develop() {
        if (scene.active)
            return
        if (blurs)
            kit.blurWanted = true
        scene.active = true
        if (sceneReady)
            shoot()
        else
            patience.start()
    }

    function shoot() {
        patience.stop()
        missed = !windowShown
        if (picture.sourceItem === null)
            picture.sourceItem = holder
        else
            picture.scheduleUpdate()
        settle.count(2)
    }

    // the busy ring takes a SilicaControl's palette (a SilicaItem's it does not)
    palette.colorScheme: Theme.LightOnDark
    onSceneReadyChanged: {
        if (sceneReady && patience.running)
            shoot()
    }
    onWindowShownChanged: {
        if (!scene.active)
            return
        if (!windowShown)
            missed = true
        else if (missed && !patience.running)
            shoot()
    }

    // drawn only through the picture: a grab starts below the holder's own opacity
    Item {
        id: holder

        width: frame.hasCut && frame.kit ? frame.kit.side : frame.width
        height: frame.hasCut && frame.kit ? frame.kit.sideHeight : frame.height
        opacity: 0

        // the home screen behind an opening, the switcher behind a closing; a loading's cover is dark
        ShaderEffect {
            property variant source: !frame.kit ? null : frame.moment === "open" ? frame.kit.home : frame.kit.plain

            anchors.fill: parent
            visible: source !== null && !(frame.moment === "load" && frame.wideLoad)
        }

        Loader {
            id: scene

            anchors.fill: parent
            active: false
            sourceComponent: frame.kind === "effect" ? effectScene
                             : frame.kind === "shards" ? shardsScene
                             : frame.kind === "stock-open" ? stockOpen
                             : frame.kind === "stock-close" ? stockClose
                             : stockLoad
        }
    }

    ShaderEffectSource {
        id: picture

        anchors.fill: parent
        live: false
        hideSource: true
        sourceRect: frame.hasCut ? frame.cut : Qt.rect(0, 0, 0, 0)
    }

    // the grab is drawn in the frame whose sync takes the shot to the render thread, and the next sync waits until that
    // frame is drawn: two frames after the shot (FrameCounter.qml), what made it goes. Not while a hidden window kept
    // the shot from being drawn: the window showing again shoots it again
    FrameCounter {
        id: settle

        onCounted: {
            if (frame.missed)
                return
            scene.active = false
            frame.done()
        }
    }

    // a shader that does not come holds the queue up no longer than this: the still shows what is behind it
    Timer {
        id: patience

        interval: 2000
        onTriggered: frame.shoot()
    }

    // a style's shader over the app, or a loading on its cover: all of the holder on the sheet, the cover's true place
    // in the viewer
    Component {
        id: effectScene

        Item {
            id: effectItem

            readonly property bool ready: effect.ready && shown
            property bool shown: !frame.withField

            // shows the effect a frame after it is ready, so that its field is made in a GUI turn of its own
            FrameCounter {
                running: frame.withField && effect.ready && !effectItem.shown
                onCounted: effectItem.shown = true
            }

            Rectangle {
                id: cover

                x: frame.moment === "load" && !frame.wideLoad ? frame.kit.coverRect.x * parent.width : 0
                y: frame.moment === "load" && !frame.wideLoad ? frame.kit.coverRect.y * parent.height : 0
                width: frame.moment === "load" && !frame.wideLoad ? frame.kit.coverRect.width * parent.width
                                                                  : parent.width
                height: frame.moment === "load" && !frame.wideLoad ? frame.kit.coverRect.height * parent.height
                                                                   : parent.height
                radius: frame.wideLoad ? 0 : frame.kit.coverRadius
                visible: frame.moment === "load"
                color: "#101520"
            }

            Effect {
                id: effect

                x: cover.x
                y: cover.y
                width: cover.width
                height: cover.height
                visible: ready && effectItem.shown
                style: frame.style
                moment: frame.moment
                source: frame.moment === "load" ? (frame.wideLoad ? frame.kit.paddedIcon : frame.kit.icon)
                                                : frame.blurs ? frame.kit.appBlur : frame.kit.app
                noiseTex: frame.kit.noise
                progress: frame.moment === "load" ? 0 : frame.at
                time: frame.moment === "load" ? frame.at
                                              : frame.at * Styles.duration(frame.style, frame.moment, 1) / 1000
                // an opening from the icon, a closing let go at the upper third, a loading on its cover
                origin: frame.moment === "open" ? Qt.point(frame.kit.iconRect.x + frame.kit.iconRect.width / 2,
                                                           frame.kit.iconRect.y + frame.kit.iconRect.height / 2)
                        : frame.moment === "close" ? Qt.point(0.5, 0.3) : Qt.point(0.5, 0.5)
                originRect: frame.moment === "open" ? frame.kit.iconRect
                            : frame.moment === "close" ? Qt.rect(0, 0, 1, 1) : Qt.rect(0.35, 0.4, 0.3, 0.2)
                radiusPx: frame.moment === "open" ? frame.kit.iconRadius
                          : frame.moment === "load" && !frame.wideLoad ? frame.kit.coverRadius : 0
                tint: frame.kit.tint
                useTint: frame.kit.useTint
            }
        }
    }

    Component {
        id: shardsScene

        Shards {
            rays: 9
            rings: [0.08, 0.2, 0.38, 0.6, 1.0]
            seed: Qt.vector4d(Stills.SEED[0], Stills.SEED[1], Stills.SEED[2], Stills.SEED[3])
            visible: ready
            source: frame.kit.app
            assemble: frame.moment === "open"
            impact: frame.moment === "open" ? Qt.point(frame.kit.iconRect.x + frame.kit.iconRect.width / 2,
                                                       frame.kit.iconRect.y + frame.kit.iconRect.height / 2)
                                            : Qt.point(0.5, 0.3)
            progress: frame.at
            tint: frame.kit.tint
            useTint: frame.kit.useTint
        }
    }

    // the stock opening: the app fading in over the grid
    Component {
        id: stockOpen

        ShaderEffect {
            readonly property bool ready: true
            property variant source: frame.kit.app

            opacity: frame.at
        }
    }

    // the stock closing: the app sliding down as it fades
    Component {
        id: stockClose

        Item {
            readonly property bool ready: true

            ShaderEffect {
                property variant source: frame.kit.app

                y: 0.25 * frame.easeIn(frame.at) * height
                width: parent.width
                height: parent.height
                opacity: 1 - frame.easeInOut(frame.at)
            }
        }
    }

    // the stock loading: the icon on a dark cover, with the busy ring standing still
    Component {
        id: stockLoad

        Item {
            readonly property bool ready: true

            Rectangle {
                id: stockCover

                x: frame.wideLoad ? 0 : frame.kit.coverRect.x * parent.width
                y: frame.wideLoad ? 0 : frame.kit.coverRect.y * parent.height
                width: frame.wideLoad ? parent.width : frame.kit.coverRect.width * parent.width
                height: frame.wideLoad ? parent.height : frame.kit.coverRect.height * parent.height
                radius: frame.wideLoad ? 0 : frame.kit.coverRadius
                color: "#101520"

                ShaderEffect {
                    property variant source: frame.kit.icon

                    anchors.centerIn: parent
                    width: Math.round(Math.min(parent.width, parent.height) * 0.5)
                    height: width
                }

                ProgressCircle {
                    anchors.centerIn: parent
                    width: Math.round(Math.min(parent.width, parent.height) * 0.8)
                    height: width
                    value: 0.7
                }
            }
        }
    }
}
