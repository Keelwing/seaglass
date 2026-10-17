// Launching an app and opening a folder from a group widget, the way the app grid's own delegate does it
// (LauncherGrid.qml, onClicked), and opening a settings page from a data widget. It uses the home screen's in-process
// types (com.jolla.lipstick), so it loads only inside Lipstick; HomeController.qml logs the taps when it cannot load
// (the harness).
//
// The imports follow LauncherGrid.qml's, which finds Desktop through them.
import QtQuick 2.6
import org.nemomobile.lipstick 0.1
import com.jolla.lipstick 0.1
import Sailfish.Silica 1.0
import Sailfish.Policy 1.0
import Sailfish.Lipstick 1.0
import Nemo.DBus 2.0
import "file:///usr/share/lipstick-jolla-home-qt5/main"

// an Item, not a QtObject: Qt 5's Loader does not load non-visual root objects
Item {
    id: actions

    // the root LauncherGrid
    property Item grid

    visible: false

    property PolicyValue appSupport: PolicyValue {
        policyType: PolicyValue.AppsupportEnabled
    }

    function launch(item) {
        if (item.readValue("X-apkd-packageName") != "" && !appSupport.value)
            return
        if (item.isUpdating) {
            // the launch goes out as a D-Bus signal to whoever handles updates
            item.launchApplication()
        } else {
            Desktop.instance.switcher.activateWindowFor(item)
        }
        if (Lipstick.compositor.multitaskingHome)
            Lipstick.compositor.launcherLayer.hide()
        grid.itemLaunched()
        Lipstick.compositor.launcherLayer.pinned = false
    }

    // the app grid away, as after a launch (a notification's own action opens its app)
    function hideLauncher() {
        if (Lipstick.compositor.multitaskingHome)
            Lipstick.compositor.launcherLayer.hide()
        Lipstick.compositor.launcherLayer.pinned = false
    }

    // the app grid fully up (it may be peeking from the bottom, or half pulled up), as when a folder opens: for the
    // search, which needs the keyboard
    function showLauncher() {
        if (Lipstick.compositor.multitaskingHome)
            Lipstick.compositor.setCurrentWindow(Lipstick.compositor.launcherLayer.window)
        Lipstick.compositor.launcherLayer.pinned = false
    }

    // A settings page (a data widget's chip or battery), the way the top menu opens its pages
    function openSettings(page) {
        settings.call("showPage", [page])
        hideLauncher()
    }

    property DBusInterface settings: DBusInterface {
        service: "com.jolla.settings"
        path: "/com/jolla/settings/ui"
        iface: "com.jolla.settings.ui"
    }

    function open(folder) {
        grid.setEditMode(false)
        grid.showFolder(folder)
        if (Lipstick.compositor.multitaskingHome) {
            // the launcher may be peeking from the bottom because of the hint
            Lipstick.compositor.setCurrentWindow(Lipstick.compositor.launcherLayer.window)
        }
        Lipstick.compositor.launcherLayer.pinned = false
    }
}
