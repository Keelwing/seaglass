// What this version changed: its section of the CHANGELOG.md installed with Seaglass. Opening it marks the version
// as seen, so the first page stops offering it.
import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: page

    property string version
    property string heading
    property var items: []

    allowedOrientations: Orientation.All

    GeneralSettings {
        id: general
    }

    // Markdown, as far as the changelog uses it, as plain text
    function plain(text) {
        return text.replace(/\*\*([^*]+)\*\*/g, "$1").replace(/\*([^*]+)\*/g, "$1").replace(/\x60([^\x60]+)\x60/g, "$1")
                   .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
    }

    // the first section: its heading, and its items (a "- " line and the lines indented under it)
    function parse(text) {
        var lines = text.split("\n")
        var list = []
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (line.indexOf("## ") === 0) {
                if (heading !== "")
                    break
                heading = line.slice(3)
            } else if (heading !== "" && line.indexOf("- ") === 0) {
                list.push(line.slice(2))
            } else if (heading !== "" && list.length > 0 && /^  \S/.test(line)) {
                list[list.length - 1] += " " + line.replace(/^\s+/, "")
            }
        }
        items = list.map(plain)
    }

    Component.onCompleted: {
        var request = new XMLHttpRequest()
        request.onreadystatechange = function () {
            if (request.readyState === XMLHttpRequest.DONE)
                page.parse(request.responseText || "")
        }
        // installed next to the QML: /usr/share/seaglass/CHANGELOG.md
        request.open("GET", Qt.resolvedUrl("../../CHANGELOG.md"))
        request.send()
        if (version !== "")
            general.seenVersion = version
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        VerticalScrollDecorator {}

        Column {
            id: column

            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("What's new")
                description: page.heading
            }

            Repeater {
                model: page.items

                Row {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    spacing: Theme.paddingMedium

                    Label {
                        text: "•"
                        color: Theme.highlightColor
                    }

                    Label {
                        width: parent.width - parent.spacing - Theme.paddingLarge
                        wrapMode: Text.Wrap
                        color: Theme.highlightColor
                        text: modelData
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.items.length === 0
                wrapMode: Text.Wrap
                color: Theme.secondaryHighlightColor
                text: qsTr("No notes for this version")
            }
        }
    }
}
