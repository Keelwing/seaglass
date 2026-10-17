// The probe scene: does the picture seen through the glass follow the glass's motion? Two panes over one GlassSource
// and the stock picture, side by side (the left one frosted with "frost" in the argument). At 1.5 s the motion changes:
//   zoom    from 1 to 1.6 around the centre
//   anchor  the zoom stays at 1.3; its anchor goes from the top to the bottom (as the parallax moves it)
//   shift   the zoom stays at 1.3; the picture moves down 300 px (as the tilt shifts it)
// Grab before and after: scripts/harness.sh --scene "probe anchor" --shot NAME --grab 1 (and --grab 2.5)
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../qml/glass"

Item {
    id: scene

    property Item harness
    readonly property string mode: harness ? harness.sceneArgument : ""
    property real zoom: mode.indexOf("anchor") >= 0 || mode.indexOf("shift") >= 0 ? 1.3 : 1
    property real anchorY: mode.indexOf("anchor") >= 0 ? 0 : height / 2
    property real shiftY: 0

    Image {
        id: picture

        visible: false
        sourceSize.height: Screen.height
        source: scene.harness ? "image://silica-square/" + encodeURIComponent("file://" + scene.harness.picture) : ""
    }

    // the home screen's frame: a centred square
    Item {
        id: stockFrame

        anchors.centerIn: parent
        width: Math.max(scene.width, scene.height)
        height: width
    }

    GlassSource {
        id: glass

        home: picture.status === Image.Ready ? picture : null
        frameParent: stockFrame
        viewport: scene
        zoom: scene.zoom
        anchor: Qt.point(scene.width / 2, scene.anchorY)
        shift: Qt.point(0, scene.shiftY)
        preset: ({ "look": "clear", "picture": "home", "image": "", "frost": 1, "tint": "none", "dim": 0,
                   "edge": false, "folders": true, "openFolder": true, "cards": true, "parallax": 0,
                   "depth": false, "tilt": false, "drift": false })
    }

    GlassPane {
        width: scene.width / 2
        height: scene.height
        glass: glass
        frost: scene.mode.indexOf("frost") >= 0 ? 1 : 0
        edgeLight: false
    }

    GlassPane {
        x: scene.width / 2
        width: scene.width / 2
        height: scene.height
        glass: glass
        frost: 0
        edgeLight: false
    }

    Timer {
        interval: 1500
        running: scene.harness !== null
        onTriggered: {
            if (scene.mode.indexOf("anchor") >= 0)
                scene.anchorY = scene.height
            else if (scene.mode.indexOf("shift") >= 0)
                scene.shiftY = 300
            else
                scene.zoom = 1.6
            console.log("harness: probe", scene.mode, "zoom", scene.zoom, "anchor", scene.anchorY, "shift", scene.shiftY)
        }
    }
}
