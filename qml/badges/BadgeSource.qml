// The notifications behind the badges (docs/BADGES.md). The home screen's own notification model (as the Events view's,
// without system updates), each notification matched to an app of the launcher, counted. HomeController.qml loads this
// (it uses the home screen's in-process types, so it loads only inside Lipstick) and gives it entries: the apps and
// folders of the search, {key, title, file, folder, iconId, item, isFolder}. It offers:
//   counts        {key: count}: an app's notifications (one that stands for several items counts as many)
//   folderCounts  {folder title: count}: its apps' together
//   notes         {key: [notification]}: newest first, for the peek
//   revision      goes up after every recount (for bindings)
// How a notification finds its app, first match wins: the Android package (the x-nemo-origin-package hint and the
// app's X-apkd-packageName), the owner (x-nemo-owner) and the desktop file's name, the icon, the app's name.
// The probe (only with Debug log on): each notification's identity fields and its match are logged once
// (never its summary or body), and each recount's totals.
import QtQuick 2.6
import QtQml 2.2
import org.nemomobile.lipstick 0.1
import com.jolla.lipstick 0.1
import "../search/search.js" as Search

Item {
    id: source

    property var entries: []
    property bool probe

    property var counts: ({})
    property var folderCounts: ({})
    property var notes: ({})
    property int revision
    property var logged: ({})

    visible: false

    // off: what was logged is forgotten
    onProbeChanged: if (!probe) logged = ({})

    JollaNotificationListModel {
        id: notifications

        filters: [ {
                "property": "category",
                "comparator": "!match",
                "value": "^x-nemo.system-update"
            }
        ]
    }

    Instantiator {
        id: list

        model: notifications.populated ? notifications : null

        QtObject {
            readonly property QtObject notification: modelData
            property Connections watch: Connections {
                target: modelData
                ignoreUnknownSignals: true
                onItemCountChanged: recount.restart()
                onAppNameChanged: recount.restart()
                onAppIconChanged: recount.restart()
                onTimestampChanged: recount.restart()
            }
        }

        onObjectAdded: recount.restart()
        onObjectRemoved: recount.restart()
    }

    onEntriesChanged: recount.restart()

    Timer {
        id: recount

        interval: 200
        onTriggered: source.count()
    }

    // an icon's name without its directory and file type: "/usr/share/icons/.../harbour-x.png" -> "harbour-x"
    function iconName(icon) {
        var name = String(icon || "").split("/").pop()
        return name.replace(/\.(png|svg|svgz|jpg)$/, "")
    }

    function count() {
        // the apps by what a notification may name them by
        var byPackage = {}
        var byFile = {}
        var byIcon = {}
        var byTitle = {}
        var folderOf = {}
        for (var i = 0; i < entries.length; i++) {
            var e = entries[i]
            if (e.isFolder)
                continue
            folderOf[e.key] = e.folder
            var pkg = e.item && e.item.readValue ? String(e.item.readValue("X-apkd-packageName") || "") : ""
            if (pkg !== "")
                byPackage[pkg] = e.key
            if (e.file)
                byFile[e.file] = e.key
            if (e.iconId)
                byIcon[iconName(e.iconId)] = e.key
            byTitle[Search.fold(e.title)] = e.key
        }

        var nextCounts = {}
        var nextNotes = {}
        var unmatched = 0
        var total = 0
        for (var k = 0; k < list.count; k++) {
            var holder = list.objectAt(k)
            var n = holder ? holder.notification : null
            if (!n)
                continue
            total++
            var hints = n.hints || {}
            var origin = String(hints["x-nemo-origin-package"] || "")
            var owner = String(n.owner || hints["x-nemo-owner"] || "").replace(/\.desktop$/, "")
            var key = ""
            var by = ""
            if (origin !== "" && byPackage[origin]) {
                key = byPackage[origin]
                by = "package"
            } else if (owner !== "" && byFile[owner]) {
                key = byFile[owner]
                by = "owner"
            } else if (n.appIcon && byIcon[iconName(n.appIcon)]) {
                key = byIcon[iconName(n.appIcon)]
                by = "icon"
            } else if (n.appName && byTitle[Search.fold(n.appName)]) {
                key = byTitle[Search.fold(n.appName)]
                by = "name"
            } else if (n.disambiguatedAppName && byTitle[Search.fold(n.disambiguatedAppName)]) {
                key = byTitle[Search.fold(n.disambiguatedAppName)]
                by = "name"
            }
            if (probe) {
                var id = n.id !== undefined ? n.id : (n.appName + ":" + n.timestamp)
                if (!logged[id]) {
                    logged[id] = true
                    // the identity fields only: never the summary or the body
                    console.log("seaglass: notification", JSON.stringify({
                        "appName": n.appName, "disambiguated": n.disambiguatedAppName, "appIcon": n.appIcon,
                        "appIconOrigin": n.appIconOrigin, "owner": owner, "package": origin,
                        "category": n.category, "itemCount": n.itemCount, "removable": n.userRemovable,
                        "matched": key ? key.split("/").pop() : "-", "by": by || "-" }))
                }
            }
            if (!key) {
                unmatched++
                continue
            }
            nextCounts[key] = (nextCounts[key] || 0) + Math.max(1, n.itemCount || 0)
            if (!nextNotes[key])
                nextNotes[key] = []
            nextNotes[key].push(n)
        }

        var nextFolders = {}
        for (var key2 in nextCounts) {
            if (nextCounts.hasOwnProperty(key2) && folderOf[key2])
                nextFolders[folderOf[key2]] = (nextFolders[folderOf[key2]] || 0) + nextCounts[key2]
        }
        for (var key3 in nextNotes) {
            if (nextNotes.hasOwnProperty(key3)) {
                nextNotes[key3].sort(function (a, b) {
                    return (b.timestamp ? b.timestamp.getTime() : 0) - (a.timestamp ? a.timestamp.getTime() : 0)
                })
            }
        }
        counts = nextCounts
        folderCounts = nextFolders
        notes = nextNotes
        revision++
        if (probe)
            console.log("seaglass: badges", Object.keys(nextCounts).length, "apps,", total,
                        "notifications,", unmatched, "without an app")
    }
}
