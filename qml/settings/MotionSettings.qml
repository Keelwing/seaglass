// How a folder opens and closes (FolderMotion.qml reads them when a folder opens)
import QtQuick 2.6
import Nemo.Configuration 1.0

ConfigurationGroup {
    path: "/apps/seaglass/motion"

    readonly property var keys: ["style", "cascade", "depth", "speed"]

    property string style: "zoom"
    property bool cascade: true
    property bool depth: true
    property real speed: 1.0
}
