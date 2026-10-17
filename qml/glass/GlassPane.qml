// A glass surface (docs/GLASS.md): the wallpaper of GlassSource.qml seen through it, aligned with the home screen
// wherever the surface is and however it moves (Silica's Background, which samples its textures through the source's
// frame). Used for the app grid, the folder icons, the open folder and the cards.
//   glass       the GlassSource
//   frost       0 the sharp wallpaper .. 1 frosted
//   color       the tint over it
//   radius      rounded corners (a tile); a tile has a rim of light, a sheet (radius 0) a light line at its top
//   edgeHeight  the top fades in over so many pixels (the clear app grid: covers dissolve under its edge)
//   lit         pressed, or an app held over it: the glass lights up
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Silica.Background 1.0

Background {
    id: pane

    property Item glass
    property real frost: 1
    property color color: "transparent"
    property real edgeHeight: 0
    property bool edgeLight: glass ? glass.edgeLight : true
    property bool lit

    // the material's other textures and amounts (uniforms of GlassSource's material)
    readonly property Item homeTexture: glass ? glass.picture : null
    readonly property Item baseTexture: glass ? glass.home : null
    readonly property real reveal: glass ? glass.reveal : 1
    // the motion (GlassSource's zoom, anchor and shift, in the frame's coordinates)
    readonly property real motionZoom: glass ? glass.motionZoom : 1
    readonly property real anchorU: glass ? glass.anchorU : 0.5
    readonly property real anchorV: glass ? glass.anchorV : 0.5
    readonly property real shiftU: glass ? glass.shiftU : 0
    readonly property real shiftV: glass ? glass.shiftV : 0

    readonly property real line: Math.max(1, Math.round(Theme.pixelRatio))

    visible: glass !== null && glass.ready
    sourceItem: visible ? glass.frosted : null
    transformItem: visible ? glass.frame : null
    material: visible ? glass.material : null

    // A tile: a rim of light and a soft sheen on its upper half
    Rectangle {
        anchors.fill: parent
        radius: pane.radius
        visible: pane.radius > 0 && pane.edgeLight
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.rgba("white", 0.10) }
            GradientStop { position: 0.45; color: "transparent" }
        }
        border.width: pane.line
        border.color: Theme.rgba("white", 0.26)
    }

    // A sheet: a light line along its top and a soft sheen under it
    Rectangle {
        width: parent.width
        height: Theme.paddingLarge * 3
        visible: pane.radius === 0 && pane.edgeLight
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.rgba("white", 0.10) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Rectangle {
        width: parent.width
        height: pane.line
        visible: pane.radius === 0 && pane.edgeLight
        color: Theme.rgba("white", 0.30)
    }

    // Lit
    Rectangle {
        anchors.fill: parent
        radius: pane.radius
        visible: pane.lit
        color: Theme.rgba(Theme.highlightBackgroundColor, Theme.highlightBackgroundOpacity)
    }
}
