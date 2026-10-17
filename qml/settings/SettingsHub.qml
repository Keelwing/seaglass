// The settings' first page (main.qml, the page Patchmanager pushes, holds only this): first whether Seaglass runs
// and what to do if not, then one row per feature, each with what it is set to now and a page of its own.
//
// The status checks, in order: that patch.json lists this Sailfish OS, that Patchmanager's preload line is in
// /etc/ld.so.preload (an OS update can drop it), that the patch is applied, and that the home screen runs this
// version (HomeController.qml writes the version it runs to GeneralSettings.running).
import QtQuick 2.6
import Sailfish.Silica 1.0
import Nemo.DBus 2.0

SilicaFlickable {
    id: hub

    // the harness's copy of main.qml sets this: no D-Bus calls from there
    property bool inHarness

    // the installed package and the phone
    property string version
    property var compatible: []
    property string osVersion
    property bool preloadOk: true
    // whether Patchmanager has applied the patch: -1 not known (yet)
    property int applied: -1

    readonly property string repository: "https://github.com/D31m05z/seaglass"
    readonly property string problem: {
        if (version === "")
            return ""
        if (osVersion !== "" && compatible.length > 0 && compatible.indexOf(osVersion) < 0)
            return "os"
        if (!preloadOk)
            return "preload"
        if (applied === 0)
            return "inactive"
        if (general.running === "")
            return "restart"
        if (general.running !== version)
            return "old"
        return ""
    }

    contentHeight: column.height + Theme.paddingLarge

    function read(url, done) {
        var request = new XMLHttpRequest()
        request.onreadystatechange = function () {
            if (request.readyState === XMLHttpRequest.DONE)
                done(request.responseText || "")
        }
        request.open("GET", url)
        request.send()
    }

    function restartHomeScreen() {
        if (!inHarness)
            systemd.call("RestartUnit", ["lipstick.service", "replace"])
    }

    function open(name, properties) {
        pageStack.push(Qt.resolvedUrl(name + ".qml"), properties || {})
    }

    // Reset settings: every key a group lists goes back to its default, read from a copy of the group at a path
    // that is never written. The widgets, the folder types, the launch counts and the closed apps stay.
    function resetSettings() {
        var pairs = [[general, generalDefaults], [motion, motionDefaults], [glass, glassDefaults],
                     [search, searchDefaults], [badges, badgeDefaults], [switcher, switcherDefaults],
                     [animations, animationDefaults], [widgets, widgetDefaults]]
        for (var p = 0; p < pairs.length; p++) {
            var keys = pairs[p][0].keys
            for (var k = 0; k < keys.length; k++)
                pairs[p][0][keys[k]] = pairs[p][1][keys[k]]
        }
    }

    Component.onCompleted: {
        read("file:///usr/share/patchmanager/patches/seaglass/patch.json", function (text) {
            try {
                var meta = JSON.parse(text)
                hub.compatible = meta.compatible || []
                hub.version = meta.version || ""
            } catch (e) {
            }
        })
        read("file:///etc/sailfish-release", function (text) {
            var found = /^VERSION_ID="?([0-9.]+)"?/m.exec(text)
            hub.osVersion = found ? found[1] : ""
        })
        read("file:///etc/ld.so.preload", function (text) {
            hub.preloadOk = text.indexOf("libpreloadpatchmanager") >= 0
        })
        if (!inHarness) {
            patchmanager.typedCall("isPatchApplied", [{ "type": "s", "value": "seaglass" }],
                                   function (result) { hub.applied = result ? 1 : 0 },
                                   function () { hub.applied = -1 })
        }
    }

    GeneralSettings { id: general }
    MotionSettings { id: motion }
    GlassSettings { id: glass }
    SearchSettings { id: search }
    BadgeSettings { id: badges }
    SwitcherSettings { id: switcher }
    AnimationSettings { id: animations }
    WidgetSettings { id: widgets }

    GeneralSettings { id: generalDefaults; path: "/apps/seaglass/defaults" }
    MotionSettings { id: motionDefaults; path: "/apps/seaglass/defaults/motion" }
    GlassSettings { id: glassDefaults; path: "/apps/seaglass/defaults/glass" }
    SearchSettings { id: searchDefaults; path: "/apps/seaglass/defaults/search" }
    BadgeSettings { id: badgeDefaults; path: "/apps/seaglass/defaults/badges" }
    SwitcherSettings { id: switcherDefaults; path: "/apps/seaglass/defaults/switcher" }
    AnimationSettings { id: animationDefaults; path: "/apps/seaglass/defaults/animations" }
    WidgetSettings { id: widgetDefaults; path: "/apps/seaglass/defaults/widgets" }

    DBusInterface {
        id: patchmanager

        bus: DBus.SystemBus
        service: "org.SfietKonstantin.patchmanager"
        path: "/org/SfietKonstantin/patchmanager"
        iface: "org.SfietKonstantin.patchmanager"
    }

    DBusInterface {
        id: systemd

        bus: DBus.SessionBus
        service: "org.freedesktop.systemd1"
        path: "/org/freedesktop/systemd1"
        iface: "org.freedesktop.systemd1.Manager"
    }

    RemorsePopup {
        id: remorse
    }

    PullDownMenu {
        MenuItem {
            text: qsTr("Reset settings")
            onClicked: remorse.execute(qsTr("Resetting the settings"), hub.resetSettings)
        }

        MenuItem {
            text: qsTr("Restart home screen")
            onClicked: hub.restartHomeScreen()
        }

        MenuItem {
            text: qsTr("What's new")
            onClicked: hub.open("WhatsNewPage", { "version": hub.version })
        }
    }

    VerticalScrollDecorator {}

    Column {
        id: column

        width: parent.width

        PageHeader {
            title: "Seaglass"
            description: hub.version
        }

        // Whether Seaglass runs, and what to do if not
        Item {
            width: parent.width
            height: status.height + 2 * Theme.paddingMedium
            visible: hub.version !== ""

            Row {
                id: status

                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.paddingLarge

                Icon {
                    source: hub.problem === "" ? "image://theme/icon-m-acknowledge" : "image://theme/icon-m-warning"
                    color: hub.problem === "" ? Theme.highlightColor : Theme.errorColor || "#ff4956"
                }

                Column {
                    width: parent.width - Theme.iconSizeMedium - parent.spacing
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        wrapMode: Text.Wrap
                        color: Theme.highlightColor
                        text: hub.problem === "" ? qsTr("Running")
                              : hub.problem === "os" ? qsTr("Not made for this Sailfish OS")
                              : hub.problem === "preload" ? qsTr("Patchmanager cannot reach the home screen")
                              : hub.problem === "inactive" ? qsTr("Not active")
                              : hub.problem === "restart" ? qsTr("Waiting for a restart")
                              : qsTr("An older version is running")
                    }

                    Label {
                        width: parent.width
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryHighlightColor
                        text: hub.problem === ""
                              ? qsTr("Seaglass %1 runs on the home screen.").arg(hub.version)
                              : hub.problem === "os"
                                ? qsTr("Seaglass %1 is made for Sailfish OS %2, and this phone has %3. Patchmanager "
                                       + "keeps it off until a version for %3 is out.")
                                  .arg(hub.version).arg(hub.compatible.join(", ")).arg(hub.osVersion)
                              : hub.problem === "preload"
                                ? qsTr("Its line is missing from /etc/ld.so.preload, which a Sailfish OS update can "
                                       + "do. No patch reaches the home screen until it is back.")
                              : hub.problem === "inactive"
                                ? qsTr("Activate Seaglass in Patchmanager's list, then restart the home screen.")
                              : hub.problem === "restart"
                                ? qsTr("Restart the home screen to load Seaglass %1.").arg(hub.version)
                              : qsTr("The home screen runs Seaglass %1. Restart it to load %2.")
                                .arg(general.running).arg(hub.version)
                    }

                    Button {
                        visible: hub.problem === "restart" || hub.problem === "old" || hub.problem === "preload"
                        preferredWidth: Theme.buttonWidthMedium
                        text: hub.problem === "preload" ? qsTr("How to fix it") : qsTr("Restart home screen")
                        onClicked: {
                            if (hub.problem === "preload")
                                Qt.openUrlExternally(hub.repository + "#troubleshooting")
                            else
                                hub.restartHomeScreen()
                        }
                    }
                }
            }
        }

        FeatureRow {
            visible: hub.version !== "" && general.seenVersion !== hub.version
            icon: "icon-m-refresh"
            title: qsTr("What's new in %1").arg(hub.version)
            onClicked: hub.open("WhatsNewPage", { "version": hub.version })
        }

        SectionHeader {
            text: qsTr("Features")
        }

        FeatureRow {
            icon: "icon-m-folder"
            title: qsTr("Folders")
            summary: {
                var names = { "zoom": qsTr("Zoom"), "spring": qsTr("Spring"), "reveal": qsTr("Reveal"),
                              "slide": qsTr("Slide"), "fade": qsTr("Fade") }
                var name = names[motion.style] || names.zoom
                return motion.style !== "fade" && motion.cascade ? qsTr("%1, with cascade").arg(name) : name
            }
            onClicked: hub.open("FoldersPage")
        }

        FeatureRow {
            icon: "icon-m-ambience"
            title: qsTr("Glass")
            summary: glass.look === "stock" ? qsTr("Stock background")
                     : glass.look === "clear" ? qsTr("Clear")
                     : [qsTr("Glass, light frost"), qsTr("Glass, medium frost"), qsTr("Glass, strong frost")][glass.frost]
                       || qsTr("Glass")
            onClicked: hub.open("GlassPage")
        }

        FeatureRow {
            icon: "icon-m-search"
            title: qsTr("Search")
            summary: search.row === "off" ? qsTr("Off")
                     : (search.row === "pill" ? qsTr("Search only") : qsTr("With the apps used most")) + ", "
                       + (search.position === "top" ? qsTr("at the top") : qsTr("at the bottom"))
            onClicked: hub.open("SearchPage")
        }

        FeatureRow {
            icon: "icon-m-notifications"
            title: qsTr("Badges")
            summary: !badges.show ? qsTr("Off")
                     : (badges.style === "dot" ? qsTr("Dots") : qsTr("Counts"))
                       + (badges.peek ? ", " + qsTr("peek on a long press") : "")
            onClicked: hub.open("BadgesPage")
        }

        FeatureRow {
            icon: "icon-m-levels"
            title: qsTr("Task switcher")
            summary: (switcher.layout === "cards" ? qsTr("Card row") : qsTr("Grid"))
                     + (switcher.chips ? ", " + qsTr("name chips") : "")
            onClicked: hub.open("SwitcherPage")
        }

        FeatureRow {
            icon: "icon-m-add-to-grid"
            title: qsTr("Widgets")
            summary: {
                if (!widgets.show)
                    return qsTr("Hidden")
                var count = 0
                try {
                    count = (JSON.parse(widgets.list || "[]") || []).length
                } catch (e) {
                }
                return count === 0 ? qsTr("None on the grid") : qsTr("%n on the grid", "", count)
            }
            onClicked: hub.open("WidgetsPage")
        }

        SectionHeader {
            text: qsTr("Seaglass")
        }

        FeatureRow {
            icon: "icon-m-about"
            title: qsTr("About")
            summary: general.debug ? qsTr("Debug log on") : ""
            onClicked: hub.open("AboutPage")
        }
    }
}
