// The made-up home screen the Animations page and its viewer draw their stills and runs on (FrozenFrame.qml), as
// frozen textures at a width of side: the app grid of stock icons over a wallpaper, the wallpaper alone, the made-up
// Notes app (NotesPreview.qml) and its icon. Each texture is grabbed once from an item at the phone's size; the items
// are scaled to side as well, though a grab leaves an item's own scale out, as it does its opacity. The kit itself is
// at opacity 0: nothing here is drawn but through its textures. Light on dark in any ambience, so that the textures
// do not depend on the ambience's scheme.
//
// No mipmaps on app: every still and run of a style that does not blur reads it one texel per pixel, as a run on the
// home screen reads the window. A read inside a branch that not every pixel takes has no defined mip level, so the
// shaders' early returns draw hairlines on a mipmapped source. appBlur, with mipmaps where GLSL ES 3.00 blurs with
// them, is for the styles that blur, and is made only once a still asks for it (blurWanted).
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Silica.private 1.0
import "../animations"

SilicaControl {
    id: kit

    // the textures' width: a cell of the sheet, or the viewer's stage or strip
    property real side
    // the wallpaper: a picture file, or "" for a neutral gradient. A change grabs the textures again
    property string picture
    // what the effects take of the ambience: its colour, and whether they use it (1) or their own (0)
    property vector3d tint: Qt.vector3d(1, 1, 1)
    property real useTint
    property bool blurWanted
    // the app as a run draws it (runApp): a fraction of side, 0 for none, and whether it has mipmaps. It is grabbed
    // again whenever they change
    property real runScale
    property bool runMip

    // valid once the window has its OpenGL context, which a page waits for before it makes a kit
    readonly property bool es3: OpenGLInfo.renderableType === OpenGLInfo.OpenGLES && OpenGLInfo.majorVersion >= 3
    readonly property real phoneWidth: Math.min(Screen.width, Screen.height)
    readonly property real phoneHeight: Math.max(Screen.width, Screen.height)
    readonly property real k: side / phoneWidth
    readonly property int sideHeight: Math.round(side * phoneHeight / phoneWidth)

    // every picture loaded, or 1.5 s gone, and the textures grabbed once
    readonly property bool ready: shot
    property bool shot
    // a change of the picture or the colours waits for its pictures before the textures are grabbed again
    property bool stale
    // what the pictures still waited for when giveUp last grabbed the textures, "nothing" if every one had come; "" if
    // the last grab came once they had. The harness logs it
    property string gaveUpOn

    readonly property Item home: homeTexture
    readonly property Item plain: plainTexture
    readonly property Item app: appTexture
    readonly property Item appBlur: blurCopy.item
    readonly property Item runApp: runCopy.item
    readonly property Item paddedIcon: paddedTexture
    readonly property Item icon: iconImage
    readonly property Item noise: noiseTile

    // the icon Notes opens from and the cover it loads on, 0 to 1 over the screen, and their corners in pixels at side
    readonly property rect iconRect: Qt.rect((gridLeft + (notesAt % columns) * grid.cellWidth
                                              + (grid.cellWidth - Theme.iconSizeLauncher) / 2) / phoneWidth,
                                             (Math.floor(notesAt / columns) * cellHeight + iconTop) / phoneHeight,
                                             Theme.iconSizeLauncher / phoneWidth, Theme.iconSizeLauncher / phoneHeight)
    readonly property real iconRadius: Theme.iconSizeLauncher * k / 2
    readonly property rect coverRect: Qt.rect((phoneWidth - Theme.coverSizeLarge.width) / 2 / phoneWidth,
                                              0.4 - Theme.coverSizeLarge.height / 2 / phoneHeight,
                                              Theme.coverSizeLarge.width / phoneWidth,
                                              Theme.coverSizeLarge.height / phoneHeight)
    readonly property real coverRadius: Theme.paddingMedium * k

    // the launcher's grid as the home screen lays it out in portrait: every page a screen high, the icon and its
    // title in the middle of a cell
    readonly property int columns: Math.max(1, grid.columns)
    readonly property int rows: Math.max(1, grid.rows)
    readonly property real gridLeft: Math.round((phoneWidth - columns * grid.cellWidth) / 2)
    readonly property real cellHeight: Math.floor(phoneHeight / rows)
    readonly property real iconTop: Math.round((cellHeight - Theme.iconSizeLauncher - titleMetrics.height) / 2)
    // the stock launcher icons known to be there on every phone
    readonly property var others: [["phone", "Phone"], ["messaging", "Messages"], ["people", "People"],
                                   ["browser", "Browser"], ["email", "Email"], ["camera", "Camera"],
                                   ["gallery", "Gallery"], ["clock", "Clock"], ["calendar", "Calendar"],
                                   ["weather", "Weather"], ["settings", "Settings"], ["store", "Store"],
                                   ["calculator", "Calculator"], ["map", "Maps"], ["mediaplayer", "Media"],
                                   ["file-manager", "Files"], ["todo", "Tasks"], ["office", "Documents"],
                                   ["shell", "Terminal"]]
    // Notes in the middle column of the last row the icons reach, at most the middle row, so that a ring is not cut
    // off in its first frames
    readonly property int notesAt: {
        var count = others.length + 1
        var notesRow = Math.min(Math.floor(rows / 2), Math.floor((count - 1) / columns))
        var notesAt = Math.min(count - 1, columns * notesRow + Math.floor(columns / 2))
        return notesAt
    }
    readonly property var apps: others.slice(0, notesAt).concat([["notes", "Notes"]], others.slice(notesAt))
    readonly property color highlight: kit.palette.highlightColor
    // the size of the icons' pictures: they are drawn into the textures at that size
    readonly property int iconPixels: Math.max(1, Math.ceil(Theme.iconSizeLauncher * k))
    readonly property int coverIcon: Math.round(Theme.iconSizeLauncher * 1.5)

    signal grabbed

    // the first picture the textures still wait for, by what it shows, or "" once every one has come. Each picture
    // calls check() once what this reads of it has changed
    function waitingFor() {
        if (icons.count < apps.length)
            return "the grid"
        for (var i = 0; i < icons.count; i++) {
            var cell = icons.itemAt(i)
            if (cell === null || !cell.made)
                return "the " + apps[i][1] + " cell"
            if (cell.loading)
                return "the " + apps[i][1] + " icon"
        }
        if (homePicture.status === Image.Loading || plainPicture.status === Image.Loading || notesItem.loading)
            return "the wallpaper"
        if (iconImage.status === Image.Loading || paddedImage.status === Image.Loading)
            return "the cover's icon"
        return noiseTile.sourceItem.status === Image.Loading ? "the noise tile" : ""
    }

    function check() {
        if ((!shot || stale) && waitingFor() === "")
            shoot("")
    }

    // the first time, setting the sources grabs them once; after that each is grabbed again. waited: what giveUp
    // still waited for, or ""
    function shoot(waited) {
        giveUp.stop()
        gaveUpOn = waited
        stale = false
        if (!shot) {
            shot = true
        } else {
            var textures = [homeTexture, plainTexture, appTexture, paddedTexture, blurCopy.item, runCopy.item]
            for (var i = 0; i < textures.length; i++) {
                if (textures[i])
                    textures[i].scheduleUpdate()
            }
        }
        grabbed()
    }

    function regrab() {
        if (!shot)
            return
        stale = true
        giveUp.restart()
        recheck.restart()
    }

    opacity: 0
    // the labels take a SilicaControl's palette (a SilicaItem's they do not)
    palette.colorScheme: Theme.LightOnDark
    onPictureChanged: regrab()
    onHighlightChanged: regrab()
    Component.onCompleted: check()

    // a picture that never comes holds nothing up
    Timer {
        id: giveUp

        interval: 1500
        running: true
        onTriggered: kit.shoot(kit.waitingFor() || "nothing")
    }

    // once the pictures have their new sources, and are loading them
    Timer {
        id: recheck

        interval: 0
        onTriggered: kit.check()
    }

    FontMetrics {
        id: titleMetrics

        font.pixelSize: Theme.fontSizeTiny
    }

    // the grid takes its orientation from a page and its columns from its parent's width: a phone held upright
    Item {
        width: kit.phoneWidth
        height: kit.phoneHeight

        IconGridViewBase {
            id: grid

            visible: false
            orientation: Orientation.Portrait
            pageHeight: kit.phoneHeight - 2 * Theme.paddingSmall
        }
    }

    // the home screen behind an opening: the wallpaper under the launcher's veil, and the app grid
    Item {
        id: homeItem

        width: kit.phoneWidth
        height: kit.phoneHeight
        scale: kit.k
        transformOrigin: Item.TopLeft

        Rectangle {
            anchors.fill: parent
            visible: kit.picture === ""
            gradient: Gradient {
                GradientStop { position: 0; color: "#2d3f66" }
                GradientStop { position: 0.55; color: "#7a5a78" }
                GradientStop { position: 1; color: "#d98b5f" }
            }
        }

        Image {
            id: homePicture

            anchors.fill: parent
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.height: kit.sideHeight
            source: kit.picture ? "file://" + kit.picture : ""
            onStatusChanged: kit.check()
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.rgba("black", 0.4)
        }

        Repeater {
            id: icons

            model: kit.apps
            // a cell is added once it is complete, after its own Component.onCompleted
            onItemAdded: kit.check()

            Item {
                // set once the cell is complete. In an asynchronous creation, as the kit's, itemAt() returns a cell
                // before that, while its icon has not asked for its picture yet and loading reads false
                property bool made
                // checked once it has changed: in the icon's own status handler it still holds the old status
                readonly property bool loading: launcherIcon.status === Image.Loading

                x: kit.gridLeft + (index % kit.columns) * grid.cellWidth
                y: Math.floor(index / kit.columns) * kit.cellHeight
                width: grid.cellWidth
                height: kit.cellHeight
                onLoadingChanged: kit.check()
                Component.onCompleted: made = true

                Image {
                    id: launcherIcon

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: kit.iconTop
                    width: Theme.iconSizeLauncher
                    height: width
                    asynchronous: true
                    sourceSize: Qt.size(kit.iconPixels, kit.iconPixels)
                    source: "image://theme/icon-launcher-" + modelData[0]
                }

                Label {
                    anchors {
                        top: launcherIcon.bottom
                        topMargin: Theme.paddingSmall
                        left: parent.left
                        right: parent.right
                    }
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    font.pixelSize: Theme.fontSizeTiny
                    color: kit.palette.primaryColor
                    text: modelData[1]
                }
            }
        }
    }

    // the switcher behind a closing: the wallpaper alone
    Item {
        id: plainItem

        width: kit.phoneWidth
        height: kit.phoneHeight
        scale: kit.k
        transformOrigin: Item.TopLeft

        Rectangle {
            anchors.fill: parent
            visible: kit.picture === ""
            gradient: Gradient {
                GradientStop { position: 0; color: "#2d3f66" }
                GradientStop { position: 0.55; color: "#7a5a78" }
                GradientStop { position: 1; color: "#d98b5f" }
            }
        }

        Image {
            id: plainPicture

            anchors.fill: parent
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.height: kit.sideHeight
            source: kit.picture ? "file://" + kit.picture : ""
            onStatusChanged: kit.check()
        }
    }

    NotesPreview {
        id: notesItem

        width: kit.phoneWidth
        height: kit.phoneHeight
        scale: kit.k
        transformOrigin: Item.TopLeft
        picture: kit.picture
        onLoadingChanged: kit.check()
    }

    // a loading's icon: plain, as a cover shows it, and at 60 percent in a clear box, for the sheet's wide loadings
    Image {
        id: iconImage

        width: kit.coverIcon
        height: width
        asynchronous: true
        sourceSize: Qt.size(width, height)
        source: "image://theme/icon-launcher-notes"
        onStatusChanged: kit.check()
    }

    Item {
        id: paddedBox

        width: kit.coverIcon
        height: width

        Image {
            id: paddedImage

            anchors.centerIn: parent
            width: Math.round(parent.width * 0.6)
            height: width
            asynchronous: true
            sourceSize: Qt.size(width, height)
            source: "image://theme/icon-launcher-notes"
            onStatusChanged: kit.check()
        }
    }

    NoiseTile {
        id: noiseTile
    }

    ShaderEffectSource {
        id: homeTexture

        width: kit.side
        height: kit.sideHeight
        visible: false
        live: false
        hideSource: true
        textureSize: Qt.size(kit.side, kit.sideHeight)
        sourceItem: kit.shot ? homeItem : null
    }

    ShaderEffectSource {
        id: plainTexture

        width: kit.side
        height: kit.sideHeight
        visible: false
        live: false
        hideSource: true
        textureSize: Qt.size(kit.side, kit.sideHeight)
        sourceItem: kit.shot ? plainItem : null
    }

    ShaderEffectSource {
        id: appTexture

        width: kit.side
        height: kit.sideHeight
        visible: false
        live: false
        hideSource: true
        textureSize: Qt.size(kit.side, kit.sideHeight)
        sourceItem: kit.shot ? notesItem : null
    }

    ShaderEffectSource {
        id: paddedTexture

        width: kit.coverIcon
        height: width
        visible: false
        live: false
        hideSource: true
        textureSize: Qt.size(width, height)
        sourceItem: kit.shot ? paddedBox : null
    }

    Loader {
        id: blurCopy

        active: kit.blurWanted
        sourceComponent: Component {
            ShaderEffectSource {
                width: kit.side
                height: kit.sideHeight
                visible: false
                live: false
                hideSource: true
                mipmap: kit.es3
                textureSize: Qt.size(kit.side, kit.sideHeight)
                sourceItem: kit.shot ? notesItem : null
            }
        }
    }

    Loader {
        id: runCopy

        active: kit.runScale > 0
        sourceComponent: Component {
            ShaderEffectSource {
                width: textureSize.width
                height: textureSize.height
                visible: false
                live: false
                hideSource: true
                mipmap: kit.runMip
                textureSize: Qt.size(Math.round(kit.side * kit.runScale), Math.round(kit.sideHeight * kit.runScale))
                sourceItem: kit.shot ? notesItem : null
                onTextureSizeChanged: scheduleUpdate()
                onMipmapChanged: scheduleUpdate()
            }
        }
    }
}
