// The glass (docs/GLASS.md): one wallpaper, seen through every glass surface (GlassPane.qml): the app grid, the folder
// icons, the open folder, the widget cards. Made once: HomeController.qml makes it on the home screen, the harness and
// the settings page make their own. It is given:
//   home         the home screen's wallpaper texture (Lipstick.compositor.wallpaper.homeWallpaperItem, a square
//                picture); the harness and the settings page give a square Image of their own
//   frameParent  the frame the home screen draws its wallpaper in (Lipstick.compositor.wallpaper.transformItem,
//                a centred square that turns with the screen); the glass is drawn through a frame on it, so it is
//                aligned with the home screen
// The app grid's background (LauncherWallpaper.qml) moves the frame and says how far the grid is pulled up:
//   viewport     the screen as the app grid sees it (its pages run down it)
//   exposure     0 (grid hidden) .. 1 (open)
//   zoom         the wallpaper seen larger (1: as on the home screen), around anchor (in viewport coordinates)
//   shift        the wallpaper moved by so many pixels (in viewport coordinates)
// Settings: dconf /apps/seaglass/glass (Settings > Patchmanager > Seaglass); preset, when set (the harness),
// replaces them.
// No Lipstick import: the settings page (another application) uses this file too.
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Silica.Background 1.0
import "../settings"

Item {
    id: glass

    property Item home
    property Item frameParent
    property Item viewport
    property var preset: null

    property real exposure: 1
    property real zoom: 1
    property point anchor
    property point shift

    // The settings, in dconf (the settings page writes them here)
    readonly property alias settings: store
    readonly property string look: value("look")            // glass | clear | stock
    readonly property string pictureKind: value("picture")  // home | photo
    readonly property string image: value("image")
    readonly property int frost: value("frost")             // 0 light | 1 medium | 2 strong
    readonly property string tintSetting: value("tint")     // auto | dark | light | none
    readonly property real dim: value("dim")                 // the clear look's veil
    readonly property bool edgeLight: value("edge")
    readonly property bool folders: value("folders")
    readonly property bool openFolder: value("openFolder")
    readonly property bool cards: value("cards")
    readonly property int parallax: value("parallax")       // 0 off | 1 subtle | 2 deep
    readonly property bool depth: value("depth")
    readonly property bool tilt: value("tilt")
    readonly property bool drift: value("drift")

    readonly property bool lightAmbience: Theme.colorScheme === Theme.DarkOnLight
    readonly property string tint: tintSetting === "auto" ? (lightAmbience ? "light" : "dark") : tintSetting

    // What the surfaces draw
    readonly property url photoUrl: pictureKind === "photo" && image !== "" ? "file://" + image : ""
    readonly property Item picture: photoUrl != "" ? (photo.status === Image.Ready ? photo : null) : home
    readonly property Item frosted: filter
    readonly property Item frame: frameItem
    readonly property QtObject material: frostMaterial
    readonly property bool ready: home !== null && picture !== null && frameParent !== null
    // a photo is not on the home screen: it fades in over the home wallpaper as the grid rises
    readonly property real reveal: photoUrl != "" ? exposure : 1

    // The tint of a surface: 0 the app grid, 1 a tile on it (lighter, so that it stands out), 2 the open folder,
    // 3 a sheet to read (the search), 4 a control with text on it (the search field, the letter bubble): dark
    // enough for the text on a bright wallpaper
    function tintColor(level) {
        if (tint === "light")
            return Theme.rgba("white", [0.20, 0.30, 0.26, 0.55, 0.75][level])
        if (tint === "none")
            return level === 1 ? Theme.rgba("white", 0.10) : Theme.rgba("black", [0.0, 0, 0.0, 0.30, 0.45][level])
        return level === 1 ? Theme.rgba("white", 0.12) : Theme.rgba("black", [0.26, 0, 0.36, 0.50, 0.55][level])
    }

    function value(key) {
        return preset && preset[key] !== undefined ? preset[key] : store[key]
    }

    visible: false

    GlassSettings {
        id: store
    }

    readonly property int blurSize: frost === 0 ? 256 : frost === 2 ? 128 : 192

    // the photo's size: the screen's height (the settings page's preview: its own)
    property int pictureSize: Screen.height

    // The photo, square as the home screen's wallpaper (Silica's ImageWallpaper)
    Image {
        id: photo

        visible: false
        asynchronous: true
        cache: false
        sourceSize.height: glass.pictureSize
        source: glass.photoUrl != "" ? "image://silica-square/" + encodeURIComponent(glass.photoUrl) : ""
    }

    // The frost: the picture blurred once (Sailfish's glass blur: smaller, smoother, a little more saturated)
    FilteredImage {
        id: filter

        visible: false
        sourceItem: glass.picture
        filtering: glass.picture !== null
        filters: GlassBlur {
            size.width: glass.blurSize
            size.height: glass.blurSize
            deviation: glass.frost === 0 ? 3.5 : glass.frost === 2 ? 4.5 : 4.25
            repetitions: glass.frost === 0 ? 2 : glass.frost === 2 ? 4 : 3
            saturationMultiplier: 1.4
        }
    }

    // The frame the glass sees the wallpaper in: the home screen's own frame, at rest. The Background maps its textures
    // through it, and it follows neither a frame moved by its geometry nor a Scale's origin or a Translate (the parallax
    // and the tilt stayed still on the phone). So the motion is the material's: these, in the frame's coordinates (0 .. 1
    // across it), move the textures' coordinates in its vertex shader.
    Item {
        id: frameItem

        parent: glass.frameParent
        anchors.fill: parent
    }

    readonly property real motionZoom: Math.max(0.5, zoom)
    property real anchorU: 0.5
    property real anchorV: 0.5
    property real shiftU: 0
    property real shiftV: 0

    function updateFrame() {
        if (!frameParent || !viewport || frameParent.width <= 0 || frameParent.height <= 0) {
            anchorU = 0.5
            anchorV = 0.5
            shiftU = 0
            shiftV = 0
            return
        }
        var a = frameParent.mapFromItem(viewport, anchor.x, anchor.y)
        var o = frameParent.mapFromItem(viewport, 0, 0)
        var d = frameParent.mapFromItem(viewport, shift.x, shift.y)
        anchorU = a.x / frameParent.width
        anchorV = a.y / frameParent.height
        shiftU = (d.x - o.x) / frameParent.width
        shiftV = (d.y - o.y) / frameParent.height
    }

    // the home screen's frame changes size (an ambience, a turn of the screen)
    Connections {
        target: glass.frameParent
        ignoreUnknownSignals: true
        onWidthChanged: glass.updateFrame()
        onHeightChanged: glass.updateFrame()
    }

    onZoomChanged: updateFrame()
    onAnchorChanged: updateFrame()
    onShiftChanged: updateFrame()
    onViewportChanged: updateFrame()
    onFrameParentChanged: updateFrame()

    // The sharp picture and the frost mixed by frost; a photo fades in over the home wallpaper by reveal; a tint
    // over it; the top fades in over edgeHeight pixels. The stock HomeMaterials.dimming does the same with the
    // ambience's picture when the Events view slides over the home screen.
    Material {
        id: frostMaterial

        // the clear look's edge fades in: alpha
        blending: true
        vertexShader: "
attribute highp vec4 position;
uniform highp mat4 positionMatrix;
uniform highp mat4 transformMatrix;
uniform highp mat4 sourceMatrix;
uniform highp float motionZoom;
uniform highp float anchorU;
uniform highp float anchorV;
uniform highp float shiftU;
uniform highp float shiftV;
varying highp vec2 homeCoord;
varying highp vec2 sourceCoord;
varying highp float paneY;
void backgroundMain() {
    gl_Position = positionMatrix * position;
    // the motion: larger around the anchor, moved by the shift (the wallpaper moves with it, so it samples back)
    highp vec2 anchor = vec2(anchorU, anchorV);
    highp vec2 shift = vec2(shiftU, shiftV);
    homeCoord = anchor + ((transformMatrix * gl_Position).xy - anchor - shift) / motionZoom;
    sourceCoord = anchor + ((sourceMatrix * gl_Position).xy - anchor - shift) / motionZoom;
    paneY = position.y;
}
"
        fragmentShader: "
uniform lowp sampler2D sourceTexture;
uniform lowp sampler2D homeTexture;
uniform lowp sampler2D baseTexture;
uniform lowp vec4 color;
uniform lowp float frost;
uniform lowp float reveal;
uniform highp float edgeHeight;
varying highp vec2 homeCoord;
varying highp vec2 sourceCoord;
varying highp float paneY;
void backgroundMain() {
    lowp vec4 picture = mix(texture2D(homeTexture, homeCoord), background2D(sourceTexture, sourceCoord), frost);
    picture = mix(texture2D(baseTexture, homeCoord), picture, reveal);
    picture = picture * (1.0 - color.a) + color;
    lowp float edge = edgeHeight > 0.0 ? clamp(paneY / edgeHeight, 0.0, 1.0) : 1.0;
    gl_FragColor = picture * edge;
}
"
    }
}
