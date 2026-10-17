// The notification badge of a launcher item (docs/BADGES.md): Badge.qml at its parent's top right corner (the parent is
// the item's icon), with the count from HomeController.qml (an app's notifications, a folder's apps' together), in the
// style of the settings. The hook loads it into a Loader inside each app's icon on the app grid and in open folders;
// the Loader provides launcherItem (a Loader has an item of its own). FolderPreview.qml, GroupWidget.qml and the search
// use it directly, with item set.
//   item   the LauncherItem (an app, or a folder)
//   home   HomeController.qml (by default the one motion.js knows)
//   dot    always a dot (the small icons of the search capsule)
//   onCard an app on a folder's card: shown only with the badges on folders and cards
// peek(): a long press on the icon: shows the app's or the folder's notifications when the setting is on and there
// are some (true).
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../core/motion.js" as Motion

Item {
    id: root

    readonly property bool loaded: parent !== null && parent.launcherItem !== undefined
    property QtObject item: loaded ? parent.launcherItem : null
    property Item home: Motion.home
    property bool dot
    property bool onCard
    // the icon: the Loader's parent when loaded by the hook, else the parent
    readonly property Item icon: loaded ? parent.parent : parent
    readonly property int count: home && item && home.badgesShown && (!onCard || home.badgeFolders)
                                 ? (home.badgeRevision, home.badgeCount(item)) : 0

    function peek() {
        return home !== null && item !== null && count > 0 && home.peekAt(item, icon)
    }

    anchors.fill: parent

    Badge {
        x: root.width - width * 0.75
        y: -height * 0.25
        iconSize: Math.max(root.width, Theme.iconSizeSmall)
        count: root.count
        style: root.dot ? "dot" : root.home ? root.home.badgeStyle : "count"
        tone: root.home ? root.home.badgeTone : "accent"
    }

    // Motion.home is not a property that notifies: look again until the controller is there, for a minute
    Timer {
        property int tries

        interval: 1000
        repeat: true
        running: root.home === null && tries < 60
        onTriggered: {
            tries++
            if (Motion.home)
                root.home = Motion.home
        }
    }
}
