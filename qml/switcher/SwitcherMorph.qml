// The switch between the task switcher's grid and card row (docs/SWITCHER.md), a layer over the switcher while a pinch
// runs. Each app's cover flies on a straight path from its place in one layout to its place in the other, with what
// each layout gives it: in the card row a shadow, the dark veil of the cards behind the front one, and the fade past
// the second card; in the grid the name chip under every cover. The card in front leads, and each cover starts a little
// later the further it is from it (lag).
//   covers    [{app, cards: {x, y, w, h, dim, opacity, z, front}, grid: {x, y, w, h}, lag}] in this layer's
//             coordinates; lag 0 .. 1; other fields are the cover component's
//   progress  0 .. 1: from the layout where the pinch started to the other one (SwitcherPinch.qml)
//   toGrid    the pinch goes from the card row to the grid
//   cover     a Component that draws an app's cover; its root has a property spec (an entry of covers), and
//             may have gridness (0 as a card .. 1 as a cover in the grid) and a signal redrawn() (the app drew the
//             cover again, at the size asked: CoverFade.qml) and ready (false: no picture yet, no still)
//   glass     the GlassSource of the chips; chips: the name chips are on
//   pace      the fades' slowness (the harness's slow frames)
// gridness: 0 in the card row .. 1 in the grid, for the rest of the switcher (the dots, Recently closed).
// refresh(): a still of every cover, before the apps are asked to draw them at another size; busy(): a still is up.
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../core/motion.js" as Motion

Item {
    id: morph

    property var covers: []
    property real progress
    property bool toGrid
    property Component cover
    property Item glass
    property bool chips: true
    property real pace: 1

    readonly property real gridness: toGrid ? progress : 1 - progress

    function refresh() {
        for (var i = 0; i < flights.count; i++) {
            if (flights.itemAt(i))
                flights.itemAt(i).freeze()
        }
    }

    function busy() {
        for (var i = 0; i < flights.count; i++) {
            if (flights.itemAt(i) && flights.itemAt(i).busy)
                return true
        }
        return false
    }

    Repeater {
        id: flights

        model: morph.covers.length

        Item {
            id: flying

            readonly property var spec: morph.covers[index]
            readonly property var a: spec ? spec.cards : null
            readonly property var b: spec ? spec.grid : null
            // the lead goes first; the last starts when the lead is a fifth of the way
            readonly property real q: spec ? Motion.clamp((morph.progress - 0.2 * spec.lag) / 0.8, 0, 1) : 0
            // 0 in the card row .. 1 in the grid
            readonly property real t: morph.toGrid ? q : 1 - q

            readonly property bool busy: still.busy

            function mix(from, to) {
                return from + (to - from) * t
            }

            function freeze() {
                // no still of a cover whose picture has not come yet: it would hold an empty cover
                if (!coverLoader.item || coverLoader.item.ready !== false)
                    still.freeze()
            }

            visible: spec !== undefined && spec !== null && opacity > 0
            x: a ? mix(a.x, b.x) : 0
            y: a ? mix(a.y, b.y) : 0
            width: a ? mix(a.w, b.w) : 0
            height: a ? mix(a.h, b.h) : 0
            z: a ? a.z : 0
            opacity: a ? mix(a.opacity, 1) : 0

            // the card's shadow, gone in the grid
            Rectangle {
                anchors.fill: parent
                anchors.margins: -Theme.paddingMedium
                anchors.topMargin: -Theme.paddingSmall
                anchors.bottomMargin: -Theme.paddingLarge
                radius: Theme.paddingMedium * 2
                color: Theme.rgba("black", 0.35)
                opacity: 1 - flying.t
                visible: opacity > 0
            }

            // the live cover, under a still while the app draws it again (CoverFade.qml)
            Loader {
                id: coverLoader

                anchors.fill: parent
                sourceComponent: morph.cover
                onLoaded: {
                    item.spec = Qt.binding(function() { return flying.spec })
                    if (item.gridness !== undefined)
                        item.gridness = Qt.binding(function() { return flying.t })
                    if (typeof item.redrawn === "function")
                        item.redrawn.connect(still.redrawn)
                }
            }

            CoverFade {
                id: still

                anchors.fill: parent
                source: coverLoader
                pace: morph.pace
            }

            // behind the front card: its veil
            Rectangle {
                anchors.fill: parent
                radius: Theme.paddingMedium
                color: "black"
                opacity: flying.a ? flying.mix(flying.a.dim, 0) : 0
                visible: opacity > 0
            }

            // the name chip: under the front card, and under every cover in the grid
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height + Theme.paddingMedium
                width: chip.width
                height: chip.height
                visible: morph.chips && opacity > 0
                opacity: flying.a && flying.a.front ? 1 : flying.t

                SwitcherChip {
                    id: chip

                    glass: morph.glass
                    launcherItem: flying.spec ? flying.spec.app : null
                    hidden: false
                    maxWidth: flying.width
                }
            }
        }
    }
}
