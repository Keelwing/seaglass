// The search scene: the app grid's first page on glass with the search row (a pill and the apps used most) at its
// bottom (the default) or its top, then the search sheet growing out of the pill: the apps A–Z with the letter rail
// being dragged, then typing ("ca", "set", "med": a folder and its apps), then closing. Slowed down for frames
// (scripts/harness.sh --frames makes a GIF). No keyboard: a grey stand-in shows where it would be, and the script fills
// the field in. Argument: "[pos=bottom|top] [type=WORD,WORD,WORD] [slow=4]" type: the three words typed (default
// ca,set,med: the first one letter by letter)
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import org.nemomobile.lipstick 0.1
import "../qml/glass"
import "../qml/search"
import "../qml/search/search.js" as Search

Item {
    id: scene

    property Item harness
    property real slow: 4
    property var typed: ["ca", "set", "med"]
    property bool atBottom: true
    // as the app grid: the camera's island at the top
    readonly property real topMargin: Math.max(Screen.topCutout.height, Theme.paddingSmall)
    property var apps: []
    property var entries: []
    property var usage: ({})

    readonly property real cellWidth: harness ? harness.grid.cellWidth : 200
    readonly property real cellHeight: harness ? harness.grid.cellHeight : 250
    readonly property int columns: harness ? harness.grid.columns : 5
    readonly property int rows: harness ? harness.grid.rows : 9
    readonly property real inset: (width - columns * cellWidth) / 2

    // the apps and folders of the phone's launcher, as the controller would hand them to the search
    function collect(folder, folderTitle, list) {
        for (var i = 0; i < folder.itemCount; i++) {
            var item = folder.get(i)
            if (item.type === LauncherModel.Folder) {
                list.push({ "key": "folder:" + item.title, "title": item.title, "file": "", "folder": "",
                            "iconId": item.iconId, "item": item, "isFolder": true })
                collect(item, item.title, list)
            } else if (item.iconId) {
                var file = String(item.filePath || "").split("/").pop().replace(/\.desktop$/, "")
                list.push({ "key": item.filePath, "title": item.title, "file": file, "folder": folderTitle,
                            "iconId": item.iconId, "item": item, "isFolder": false })
            }
        }
        return list
    }

    onHarnessChanged: {
        var words = (harness.sceneArgument || "").split(" ")
        for (var i = 0; i < words.length; i++) {
            if (words[i].indexOf("slow=") === 0)
                slow = parseFloat(words[i].slice(5))
            else if (words[i] === "pos=top")
                atBottom = false
            else if (words[i].indexOf("type=") === 0) {
                var list = words[i].slice(5).split(",")
                while (list.length < 3)
                    list.push(list[list.length - 1])
                typed = list
            }
        }
        apps = harness.apps(harness.launcherModel, [])
        entries = collect(harness.launcherModel, "", [])
        // made-up use: a few apps launched now and then
        var now = Date.now()
        var made = {}
        var picks = ["Phone", "Messages", "Web Browser", "Settings", "Camera"]
        for (var p = 0; p < picks.length; p++) {
            for (var e = 0; e < entries.length; e++) {
                if (entries[e].title === picks[p] && !entries[e].isFolder)
                    made[entries[e].key] = { "n": 30 - 4 * p, "t": now - p * 3600 * 1000 }
            }
        }
        usage = made
        // every folder's apps are in the search
        for (var f = 0; f < entries.length; f++) {
            if (!entries[f].isFolder)
                continue
            var inside = 0
            for (var g = 0; g < entries.length; g++) {
                if (entries[g].folder === entries[f].title)
                    inside++
            }
            console.log("harness: search folder", entries[f].title, "apps", entries[f].item.itemCount, "found", inside)
        }
        console.log("harness: search", entries.length, "entries; suggested",
                    JSON.stringify(Search.suggestions(entries, usage, 5, now).map(function (x) { return x.title })))
        script.start()
    }

    // The home screen's wallpaper and frame, and the app grid on glass (open)
    Image {
        id: homePicture

        visible: false
        sourceSize.height: Screen.height
        source: scene.harness ? "image://silica-square/" + encodeURIComponent("file://" + scene.harness.picture) : ""
    }

    Item {
        id: stockFrame

        anchors.centerIn: parent
        width: Math.max(scene.width, scene.height)
        height: width
    }

    GlassSource {
        id: glass

        home: homePicture.status === Image.Ready ? homePicture : null
        frameParent: stockFrame
        preset: ({ "look": "glass", "picture": "home", "image": "", "frost": 1, "tint": "auto", "dim": 0.25,
                   "edge": true, "folders": true, "openFolder": true, "cards": true, "parallax": 0,
                   "depth": false, "tilt": false, "drift": false })
    }

    GlassPane {
        anchors.fill: parent
        glass: glass
        frost: 1
        color: glass.tintColor(0)
        edgeLight: false
    }

    // The first page: the search row, then the apps
    SearchRow {
        id: searchRow

        y: scene.topMargin + (scene.atBottom ? (scene.rows - 1) * scene.cellHeight : 0)
        width: scene.width
        height: scene.cellHeight
        pillBelow: scene.atBottom
        glass: glass
        cellWidth: scene.cellWidth
        inset: scene.inset
        suggested: Search.suggestions(scene.entries, scene.usage, scene.columns, Date.now())
        onSearch: sheet.open(pill)
    }

    Repeater {
        model: scene.apps.slice(0, scene.columns * (scene.rows - 1))

        Item {
            x: scene.inset + (index % scene.columns) * scene.cellWidth
            y: scene.topMargin + scene.cellHeight * ((scene.atBottom ? 0 : 1) + Math.floor(index / scene.columns))
            width: scene.cellWidth
            height: scene.cellHeight

            LauncherIcon {
                id: icon

                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.paddingLarge
                icon: modelData.iconId
            }

            Label {
                anchors.top: icon.bottom
                anchors.topMargin: Theme.paddingSmall
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeTiny
                text: modelData.title
            }
        }
    }

    SearchSheet {
        id: sheet

        anchors.fill: parent
        glass: glass
        entries: scene.entries
        usage: scene.usage
        suggested: Search.suggestions(scene.entries, scene.usage, scene.columns, Date.now())
        keyboard: false
        fieldAtBottom: scene.atBottom
        fakeKeyboard: Math.round(scene.height * 0.36)
        timeScale: scene.slow
        onLaunch: console.log("harness: launch", entry.title)
        onReveal: console.log("harness: show in the grid", entry.title)
    }

    // where the keyboard would be
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: sheet.keyboardHeight
        visible: sheet.visible && height > 0
        color: Theme.rgba("#202428", 0.92)

        Label {
            anchors.centerIn: parent
            color: Theme.secondaryColor
            text: "keyboard"
        }
    }

    // The run
    SequentialAnimation {
        id: script

        PauseAnimation { duration: 1500 }
        ScriptAction { script: { scene.harness.frameSlow = scene.slow; scene.harness.startFrames() } }
        PauseAnimation { duration: 400 * scene.slow }
        ScriptAction { script: sheet.open(searchRow.pill) }
        PauseAnimation { duration: 700 * scene.slow }
        ScriptAction { script: sheet.scrubTo("G") }
        PauseAnimation { duration: 250 * scene.slow }
        ScriptAction { script: sheet.scrubTo("P") }
        PauseAnimation { duration: 250 * scene.slow }
        ScriptAction { script: sheet.scrubTo("S") }
        PauseAnimation { duration: 400 * scene.slow }
        ScriptAction { script: sheet.railLetter = "" }
        PauseAnimation { duration: 200 * scene.slow }
        ScriptAction { script: { field().text = scene.typed[0].charAt(0) } }
        PauseAnimation { duration: 200 * scene.slow }
        ScriptAction { script: { field().text = scene.typed[0] } }
        PauseAnimation { duration: 600 * scene.slow }
        ScriptAction { script: { field().text = scene.typed[1] } }
        PauseAnimation { duration: 600 * scene.slow }
        ScriptAction { script: { field().text = scene.typed[2] } }
        PauseAnimation { duration: 600 * scene.slow }
        ScriptAction { script: sheet.close() }
        PauseAnimation { duration: 400 * scene.slow }
        ScriptAction { script: scene.harness.stopFrames() }
    }

    // the sheet's field (a SearchField somewhere inside it)
    function field() {
        return findField(sheet)
    }

    function findField(item) {
        for (var i = 0; i < item.children.length; i++) {
            var child = item.children[i]
            if (child.placeholderText !== undefined && child.text !== undefined)
                return child
            var found = findField(child)
            if (found)
                return found
        }
        return null
    }
}
