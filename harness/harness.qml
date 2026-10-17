// seaglass development harness: draws qml/ of this tree with the launcher's folders (the stock apps in made-up
// folders, unless scripts/harness.sh --own-apps), without
// touching the home screen. scripts/harness.sh runs it with qmlscene on the phone and picks the scene:
//   folders   the folder preview (FoldersScene.qml)
//   selector  an open folder's shape selector with the home screen types (SelectorScene.qml)
//   controller  HomeController.qml on a stand-in grid: layout, hit testing, renames (ControllerScene.qml)
//   layout    group widgets between the icons, normal or edit mode (LayoutScene.qml)
//   motion    a folder opening and closing with FolderMotion.qml, slowed down for frames (MotionScene.qml)
//   glass     the app grid on glass over the home wallpaper (LauncherWallpaper.qml on GlassSource.qml), with a glass
//             folder and a glass card: pull up, page and back, slowed down (GlassScene.qml)
//   search    the search row and the search sheet (A–Z, rail, typing), "pos=bottom|top" (SearchScene.qml)
//   badges    notification badges (Badge.qml) in each style, a folder's sum, a sketch of the peek (BadgesScene.qml)
//   switcher  the task switcher with made-up covers, grid or cards (SwitcherScene.qml)
//   widgets   data widgets among the icons with sample data: normal, edit or the gallery (WidgetsScene.qml)
//   touch     data widgets driven by mouse events: taps, long press, drags, the gallery (TouchScene.qml)
//   animations  an opening, loading or closing effect on a made-up app, or every shader's compile check
//             (AnimationsScene.qml)
// The scene file next to this one holds "NAME [ARGUMENT]".
//
// XDG_CONFIG_HOME points at a copy of ~/.config/lipstick, so this LauncherFolderModel reads the real folders
// but can never write the real applications.menu.
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Silica.private 1.0
import Sailfish.Lipstick 1.0
import org.nemomobile.lipstick 0.1

Rectangle {
    id: root

    // The picture every scene draws as the wallpaper: a stock ambience, never the phone's own wallpaper (which may
    // be private), unless scripts/harness.sh --picture names one (the picture file next to this one)
    readonly property string picture: readFile("picture") || "/usr/share/ambience/water/images/ambience_water.jpg"
    readonly property var sceneLine: readScene().split(" ")
    readonly property string scene: sceneLine[0] || "folders"
    readonly property string sceneArgument: sceneLine.slice(1).join(" ")
    readonly property alias launcherModel: launcherModel
    // the launcher grid's geometry, from the same base type as the launcher's
    readonly property alias grid: grid
    property bool ready

    width: Screen.width
    height: Screen.height
    color: "#11161c"

    function readFile(name) {
        var xhr = new XMLHttpRequest()
        try {
            xhr.open("GET", Qt.resolvedUrl(name), false)
            xhr.send()
            return xhr.responseText.replace(/\s+$/, "")
        } catch (e) {
            return ""
        }
    }

    function readScene() {
        return readFile("scene")
    }

    function shape(n) {
        return "icon-launcher-folder-" + (n < 10 ? "0" : "") + n
    }

    function folders() {
        var list = []
        for (var i = 0; i < launcherModel.itemCount; i++) {
            var item = launcherModel.get(i)
            if (item.type === LauncherModel.Folder)
                list.push(item)
        }
        return list
    }

    function folderNamed(title) {
        var list = folders()
        for (var i = 0; i < list.length; i++) {
            if (list[i].title === title)
                return list[i]
        }
        return null
    }

    // the apps of the real launcher, for made-up folders
    function apps(folder, list) {
        for (var i = 0; i < folder.itemCount; i++) {
            var item = folder.get(i)
            if (item.type === LauncherModel.Folder)
                apps(item, list)
            else if (item.iconId)
                list.push(item)
        }
        return list
    }

    function madeUpFolder(count, offset) {
        var list = apps(launcherModel, [])
        var model = Qt.createQmlObject("import QtQuick 2.6; ListModel {}", root)
        for (var i = 0; i < count; i++) {
            var app = list[(offset + i) % list.length]
            model.append({ "iconId": app.iconId, "title": app.title })
        }
        return model
    }

    LauncherFolderModel {
        id: launcherModel

        iconDirectories: Theme.launcherIconDirectories
    }

    IconGridViewBase {
        id: grid

        visible: false
        pageHeight: root.height - 2 * Theme.paddingSmall
    }

    // the model reads the menu and the apps when it is completed; give the icons a moment
    Timer {
        interval: 1500
        running: true
        onTriggered: {
            var list = root.folders()
            for (var i = 0; i < list.length; i++)
                console.log("harness: folder", JSON.stringify(list[i].title), list[i].itemCount, list[i].iconId)
            if (list.length) {
                var properties = []
                for (var key in list[0]) {
                    var value = list[0][key]
                    if (typeof value !== "function" && typeof value !== "object")
                        properties.push(key + "=" + value)
                }
                console.log("harness: folder properties", properties.join(" "))
            }
            console.log("harness: scene", root.scene, root.sceneArgument, "iconSizeLauncher", Theme.iconSizeLauncher,
                        "pixelRatio", Theme.pixelRatio, "screen", Screen.width + "x" + Screen.height,
                        "grid", grid.columns + "x" + grid.rows, "cell", grid.cellWidth + "x" + grid.cellHeight)
            root.ready = true
            grabTimer.start()
        }
    }

    Loader {
        anchors.fill: parent
        active: root.ready
        source: Qt.resolvedUrl(root.scene.charAt(0).toUpperCase() + root.scene.slice(1) + "Scene.qml")
        onLoaded: item.harness = root
    }

    // Frames for scripts/harness.sh --frames: a scene calls startFrames() and stopFrames(); every frameTimer tick
    // grabs the window into frames/f_NNN.jpg (JPEG: PNG encoding of a full screen photo takes a second on the
    // phone). Scenes slow their motion down (frameSlow), so that the grabs keep up; the GIF's frame delay is the
    // real time between grabs divided by it (logged for scripts/harness.sh)
    property int frameCount: 0
    property real frameSlow: 10
    // between two grabs, in the scene's time (with qmlscene --slow-animations, Timers run slow too)
    property int frameInterval: 200
    // the size of a grab (0 x 0: the window's): smaller grabs keep up better
    property size frameSize: Qt.size(0, 0)
    property double frameStart: 0

    function startFrames() {
        frameCount = 0
        frameStart = new Date().getTime()
        frameTimer.start()
    }

    function stopFrames() {
        frameTimer.stop()
        var each = frameCount > 0 ? (new Date().getTime() - frameStart) / frameCount : 0
        // the GIF's delay in centiseconds: the animation time between two frames
        console.log("harness: frames", frameCount, "delay", Math.max(2, Math.round(each / frameSlow / 10)))
    }

    Timer {
        id: frameTimer

        interval: root.frameInterval
        repeat: true
        onTriggered: {
            var n = root.frameCount++
            var name = "frames/f_" + (n < 10 ? "00" : n < 100 ? "0" : "") + n + ".jpg"
            var path = Qt.resolvedUrl(name).toString().replace(/^file:\/\//, "")
            var save = function (result) { result.saveToFile(path) }
            if (root.frameSize.width > 0)
                root.grabToImage(save, root.frameSize)
            else
                root.grabToImage(save)
        }
    }

    // scripts/harness.sh --shot copies this picture: the harness grabs its own window, 2.5 s after the scene starts
    // or when the grab file next to this one says (scripts/harness.sh --grab SECS: a moment of a scene's timeline)
    Timer {
        id: grabTimer

        interval: (parseFloat(root.readFile("grab")) || 2.5) * 1000
        onTriggered: {
            var path = Qt.resolvedUrl("harness.png").toString().replace(/^file:\/\//, "")
            root.grabToImage(function (result) {
                console.log("harness: screenshot", result.saveToFile(path) ? path : "failed")
            })
        }
    }
}
