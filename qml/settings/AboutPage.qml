// Settings: the debug log, a backup of Seaglass's settings and widgets, the version and where the source is.
//
// The backup is a JSON file in Documents: every group's settings (their keys), the data widgets, the folder types
// (by folder title), and with "Include usage" the launch counts and the recently closed apps. Qt 5.6's XMLHttpRequest
// writes a local file with PUT. A restore sets what the file holds; the home screen follows at once.
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import Nemo.Configuration 1.0

Page {
    id: page

    allowedOrientations: Orientation.All

    GeneralSettings {
        id: seaglassSettings
    }

    MotionSettings { id: motion }
    GlassSettings { id: glass }
    SearchSettings { id: search }
    BadgeSettings { id: badges }
    SwitcherSettings { id: switcher }
    AnimationSettings { id: animations }
    WidgetSettings { id: widgets }

    ConfigurationValue {
        id: folderTypes

        key: "/apps/seaglass/folder_types"
        defaultValue: "{}"
    }

    // the groups a backup holds, by name
    readonly property var groups: ({ "general": seaglassSettings, "motion": motion, "glass": glass, "search": search,
                                     "badges": badges, "switcher": switcher, "animations": animations,
                                     "widgets": widgets })
    property bool includeUsage
    property string backupResult

    function parsed(text, fallback) {
        try {
            return JSON.parse(text) || fallback
        } catch (e) {
            return fallback
        }
    }

    function backup() {
        var data = { "app": "seaglass", "version": page.version, "saved": new Date().toISOString(),
                     "settings": {}, "widgets": parsed(widgets.list, []), "folderTypes": parsed(folderTypes.value, {}) }
        for (var name in groups) {
            var group = groups[name]
            data.settings[name] = {}
            for (var k = 0; k < group.keys.length; k++)
                data.settings[name][group.keys[k]] = group[group.keys[k]]
        }
        if (includeUsage) {
            data.usage = { "launches": parsed(search.usage, {}), "recentlyClosed": parsed(switcher.recentApps, []) }
        }
        var file = StandardPaths.documents + "/seaglass-" + Qt.formatDate(new Date(), "yyyy-MM-dd") + ".json"
        var request = new XMLHttpRequest()
        request.open("PUT", "file://" + file, false)
        try {
            request.send(JSON.stringify(data, null, 2))
            page.backupResult = qsTr("Saved to %1").arg(file.replace(StandardPaths.home + "/", ""))
        } catch (e) {
            page.backupResult = qsTr("Could not write %1").arg(file)
        }
    }

    function restore(path) {
        var request = new XMLHttpRequest()
        request.open("GET", "file://" + path, false)
        request.send()
        var data = parsed(request.responseText, null)
        if (!data || data.app !== "seaglass" || typeof data.settings !== "object") {
            page.backupResult = qsTr("%1 is not a Seaglass backup").arg(path.split("/").pop())
            return
        }
        for (var name in groups) {
            var saved = data.settings[name] || {}
            var group = groups[name]
            for (var k = 0; k < group.keys.length; k++) {
                var key = group.keys[k]
                if (saved[key] !== undefined && typeof saved[key] === typeof group[key])
                    group[key] = saved[key]
            }
        }
        if (data.widgets && data.widgets.length !== undefined)
            widgets.list = JSON.stringify(data.widgets)
        if (data.folderTypes && typeof data.folderTypes === "object")
            folderTypes.value = JSON.stringify(data.folderTypes)
        if (data.usage) {
            if (data.usage.launches)
                search.usage = JSON.stringify(data.usage.launches)
            if (data.usage.recentlyClosed)
                switcher.recentApps = JSON.stringify(data.usage.recentlyClosed)
        }
        page.backupResult = qsTr("Restored from %1").arg(path.split("/").pop())
    }

    RemorsePopup {
        id: remorse
    }

    Component {
        id: backupPicker

        FilePickerPage {
            title: qsTr("Restore a backup")
            nameFilters: ["seaglass-*.json", "*.json"]
            onSelectedContentPropertiesChanged: {
                var path = selectedContentProperties.filePath
                remorse.execute(qsTr("Restoring the settings"), function () { page.restore(path) })
            }
        }
    }

    readonly property string repository: "https://github.com/D31m05z/seaglass"
    // the installed version, from the installed patch.json
    property string version

    Component.onCompleted: {
        var request = new XMLHttpRequest()
        request.onreadystatechange = function () {
            if (request.readyState !== XMLHttpRequest.DONE)
                return
            try {
                page.version = JSON.parse(request.responseText).version || ""
            } catch (e) {
                page.version = ""
            }
        }
        request.open("GET", "file:///usr/share/patchmanager/patches/seaglass/patch.json")
        request.send()
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        VerticalScrollDecorator {}

        Column {
            id: column

            width: parent.width

            PageHeader {
                title: qsTr("About")
            }

            SectionHeader {
                text: qsTr("Debug")
            }

            TextSwitch {
                text: qsTr("Debug log")
                description: qsTr("Writes Seaglass's diagnostics to the system journal: how notifications match their "
                                  + "apps, the pinch's checks, the grid's corrections. Off (the default), nothing is "
                                  + "written and those checks do not run.")
                checked: seaglassSettings.debug
                automaticCheck: false
                onClicked: seaglassSettings.debug = !seaglassSettings.debug
            }

            SectionHeader {
                text: qsTr("Backup")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                text: qsTr("Keep your settings, widgets and folder types in a file in Documents, for a new phone or "
                           + "after a reflash. The order of the apps belongs to the home screen and is not in it.")
            }

            TextSwitch {
                text: qsTr("Include usage")
                description: qsTr("The apps you launch most and the apps you closed last.")
                checked: page.includeUsage
                automaticCheck: false
                onClicked: page.includeUsage = !page.includeUsage
            }

            ButtonLayout {
                Button {
                    text: qsTr("Back up")
                    onClicked: page.backup()
                }

                Button {
                    text: qsTr("Restore")
                    onClicked: pageStack.push(backupPicker)
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.backupResult !== ""
                topPadding: Theme.paddingMedium
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.highlightColor
                text: page.backupResult
            }

            SectionHeader {
                text: qsTr("About")
            }

            DetailItem {
                label: qsTr("Version")
                value: page.version !== "" ? page.version : "–"
            }

            DetailItem {
                label: qsTr("Package")
                value: "seaglass"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                bottomPadding: Theme.paddingMedium
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                text: qsTr("Home screen extensions for Sailfish OS: folder previews and widgets, folder motion, glass, "
                           + "app search, notification badges, the task switcher and data widgets. A small Patchmanager "
                           + "hook; switch the patch off to get the stock home screen back.")
            }

            // the repository, opened in the browser
            BackgroundItem {
                id: repositoryItem

                width: parent.width
                height: repositoryColumn.height + 2 * Theme.paddingMedium
                onClicked: Qt.openUrlExternally(page.repository)

                Column {
                    id: repositoryColumn

                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    anchors.verticalCenter: parent.verticalCenter

                    Label {
                        width: parent.width
                        color: repositoryItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                        text: qsTr("Source code and documentation")
                    }

                    Label {
                        width: parent.width
                        truncationMode: TruncationMode.Fade
                        font.pixelSize: Theme.fontSizeSmall
                        color: repositoryItem.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                        text: page.repository.replace(/^https:\/\//, "")
                    }
                }
            }
        }
    }
}
