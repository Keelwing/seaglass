// The settings scene: the patch's settings in Patchmanager (patchmanager/main.qml, copied by scripts/harness.sh as
// SettingsPage.qml with the pages of this tree), or one of its pages, with the live previews running. The pages read
// the real dconf settings; outside a page stack they are made visible by hand.
// Argument: "[PAGE] [SCROLL]": a page of qml/settings (Folders, Glass, Search, Badges, Switcher, Animations, Widgets,
// About, WhatsNew; by default the first page), and how far to scroll it down in pixels (e.g. "settings Glass 900").
import QtQuick 2.6
import Sailfish.Silica 1.0

Rectangle {
    id: scene

    property Item harness
    readonly property var words: harness ? harness.sceneArgument.split(" ") : []
    readonly property string pageName: words.length > 0 && /^[A-Z]/.test(words[0]) ? words[0] : ""
    readonly property int scroll: parseInt(words[words.length - 1], 10) || 0

    color: Theme.overlayBackgroundColor

    function findFlickable(item) {
        if (!item || !item.children)
            return null
        for (var i = 0; i < item.children.length; i++) {
            var child = item.children[i]
            if (child.contentY !== undefined && child.contentHeight > child.height)
                return child
            var found = findFlickable(child)
            if (found)
                return found
        }
        return null
    }

    Loader {
        id: page

        anchors.fill: parent
        // once the harness is there: the glass page gets its picture from it
        active: scene.harness !== null
        source: scene.pageName !== "" ? Qt.resolvedUrl("../qml/settings/" + scene.pageName + "Page.qml")
                                      : Qt.resolvedUrl("SettingsPage.qml")
        onStatusChanged: if (status === Loader.Error) console.log("harness: the settings page did not load")
        onLoaded: {
            item.visible = true
            item.opacity = 1
            // the glass preview's picture: the harness's stock one (scripts/harness.sh empties the phone's
            // wallpaper in the page's copy)
            if (scene.harness && item.ambienceFile !== undefined) {
                item.ambienceFile = scene.harness.picture
                console.log("harness: settings preview picture", item.ambienceFile)
            }
            scroller.start()
        }
    }

    // scroll the page down, once it is laid out
    Timer {
        id: scroller

        interval: 1500
        onTriggered: {
            var flickable = scene.findFlickable(page.item)
            if (scene.scroll > 0 && flickable)
                flickable.contentY = scene.scroll
        }
    }
}
