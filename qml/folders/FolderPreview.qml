// The apps of a launcher folder as small icons on the folder's shape, instead of the bare item count.
//
// Installed as /usr/share/seaglass/qml/folders/FolderPreview.qml. The Patchmanager hook
// (hook/apply_hook.py) loads it into a Loader inside the folder's LauncherIcon, both on the app grid and in
// the header of an open folder. The Loader is this item's parent and provides:
//   folder      the LauncherFolderItem (itemCount, get(i).iconId; a list model, so the icons follow moves);
//               the harness passes a ListModel (count, get(i).iconId) instead
//   pressed     the folder icon is pressed
//   dropTarget  an app is dragged over the folder (optional)
//   controller  HomeController.qml, on the app grid (optional): with it, in the launcher's edit mode, a badge
//               on the icon's corner opens the folder out into a widget (WidgetBadge.qml)
//   editMode    the launcher's edit mode (optional)
//   iconId      the folder's shape (optional; else the folder's iconId)
//   glass       the GlassSource (optional; else the controller's): the search's folders (SearchTile.qml)
// With the glass (docs/GLASS.md: the controller's GlassSource, folder icons on) the folder is a glass tile:
// the wallpaper frosted through a rounded square, its shape's colour as a soft glow, the small icons on it; the
// hook then empties the stock shape (glass is true).
// When this file is missing or fails to load, the hook keeps the stock item count.
import QtQuick 2.6
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import "../badges"
import "../glass"
import "../widgets/group"

Item {
    id: root

    readonly property QtObject folder: parent ? parent.folder : null
    readonly property bool pressed: parent ? !!parent.pressed : false
    readonly property bool dropTarget: parent ? !!parent.dropTarget : false
    readonly property Item controller: parent && parent.controller !== undefined ? parent.controller : null
    readonly property bool editMode: parent ? !!parent.editMode : false
    readonly property string shapeIcon: parent && parent.iconId !== undefined ? parent.iconId
                                        : folder && folder.iconId !== undefined ? folder.iconId : ""

    // the glass tile instead of the folder's shape
    readonly property Item glassSource: parent && parent.glass !== undefined && parent.glass !== null ? parent.glass
                                        : controller && controller.glass !== undefined ? controller.glass : null
    readonly property bool glass: glassSource !== null && glassSource.ready && glassSource.folders

    readonly property int count: !folder ? 0 : folder.itemCount !== undefined ? folder.itemCount : folder.count
    // 2 × 2 up to four apps, 3 × 3 above; a folder never holds fewer than two apps for long
    readonly property int columns: count <= 4 ? 2 : 3
    readonly property int slots: columns * columns
    // more apps than slots: the last slot shows "+N" for the rest
    readonly property int shown: count > slots ? slots - 1 : count
    readonly property int hidden: count - shown

    // The 16 folder shapes keep a dark inner area of about 70 % of the icon (docs/ARCHITECTURE.md, "Folder shapes");
    // the app icons are round, so the corner icons stay inside the rounded corners of that area.
    readonly property real area: Math.round(width * (glass ? 0.78 : 0.70))
    readonly property real pitch: area / columns
    readonly property real iconSize: Math.floor(pitch * 0.86)

    // The slots in use (the apps shown, "+N", the free slot while an app is held over the folder) are centred:
    // a part-filled grid keeps its rows in the middle and its last row centred
    readonly property bool dropSlotShown: dropTarget && hidden === 0 && count < slots
    readonly property int used: Math.min(slots, shown + (hidden > 0 ? 1 : 0) + (dropSlotShown ? 1 : 0))
    readonly property int rows: Math.max(1, Math.ceil(used / columns))

    function slotX(slot) {
        var row = Math.floor(slot / columns)
        var inRow = row === rows - 1 ? used - row * columns : columns
        return Math.round((width - area) / 2 + (columns - inRow) * pitch / 2 + (slot % columns) * pitch
                          + (pitch - iconSize) / 2)
    }

    function slotY(slot) {
        return Math.round((height - area) / 2 + (columns - rows) * pitch / 2 + Math.floor(slot / columns) * pitch
                          + (pitch - iconSize) / 2)
    }

    function iconOf(i) {
        var item = folder ? folder.get(i) : null
        return item && item.iconId ? item.iconId : ""
    }

    // The glass tile: the wallpaper frosted through a rounded square, lit when pressed or an app is held over it
    GlassPane {
        id: tile

        anchors.fill: parent
        radius: Math.round(width * 0.3)
        glass: root.glass ? root.glassSource : null
        frost: 1
        color: root.glassSource ? root.glassSource.tintColor(1) : "transparent"
        lit: root.pressed || root.dropTarget
    }

    // The folder's colour (its shape, decoded tiny and stretched) as a soft glow in the tile
    Item {
        anchors.fill: parent
        visible: root.glass && root.shapeIcon !== ""
        opacity: 0.4
        layer.enabled: visible
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: tile.width
                height: tile.height
                radius: tile.radius
            }
        }

        Image {
            anchors.fill: parent
            sourceSize.width: 4
            sourceSize.height: 4
            smooth: true
            source: root.glass && root.shapeIcon !== "" ? "image://theme/" + root.shapeIcon : ""
        }
    }

    Repeater {
        // one delegate per app, so that adding, removing and reordering apps in the folder update the preview
        model: root.folder

        LauncherIcon {
            visible: index < root.shown
            x: root.slotX(index)
            y: root.slotY(index)
            size: root.iconSize
            icon: index < root.shown ? root.iconOf(index) : ""
            pressed: root.pressed
        }
    }

    // "+N": the apps that do not fit
    Rectangle {
        visible: root.hidden > 0
        x: root.slotX(root.slots - 1)
        y: root.slotY(root.slots - 1)
        width: root.iconSize
        height: root.iconSize
        radius: width / 2
        color: Theme.rgba(root.pressed ? Theme.highlightBackgroundColor : Theme.lightPrimaryColor,
                          root.dropTarget ? 0.35 : 0.18)

        Text {
            anchors.centerIn: parent
            width: parent.width - 2
            horizontalAlignment: Text.AlignHCenter
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 6
            font.pixelSize: Math.round(parent.height * 0.5)
            font.family: Theme.fontFamilyHeading
            color: root.glass ? Theme.primaryColor : Theme.lightPrimaryColor
            text: "+" + root.hidden
        }
    }

    // Where a dragged app will land: the next free slot pulses while the app is held over the folder
    Rectangle {
        id: dropSlot

        visible: root.dropSlotShown
        x: root.slotX(root.count)
        y: root.slotY(root.count)
        width: root.iconSize
        height: root.iconSize
        radius: width / 2
        color: "transparent"
        border.color: Theme.lightPrimaryColor
        border.width: Math.max(1, Math.round(2 * Theme.pixelRatio))

        SequentialAnimation on opacity {
            running: dropSlot.visible
            loops: Animation.Infinite
            NumberAnimation { from: 0.3; to: 1.0; duration: 450; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 1.0; to: 0.3; duration: 450; easing.type: Easing.InOutQuad }
        }
    }

    // The folder's notification badge: its apps' together
    IconBadge {
        id: folderBadge

        item: root.folder && root.folder.type !== undefined ? root.folder : null
    }

    // a long press on the folder (the hook asks first): its apps' notifications, when it has some and the peek is on
    function peek() {
        return folderBadge.peek()
    }

    // Edit mode on the app grid: open the folder out into a card in place
    WidgetBadge {
        visible: root.editMode && root.controller !== null && root.folder !== null
        x: root.width - width * 0.7
        y: -height * 0.3
        onClicked: root.controller.setType(root.folder, "card")
    }
}
