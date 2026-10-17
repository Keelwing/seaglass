// Notification badges and the peek
import QtQuick 2.6
import Nemo.Configuration 1.0

ConfigurationGroup {
    path: "/apps/seaglass/badges"

    readonly property var keys: ["show", "style", "tone", "folders", "peek"]

    property bool show: true
    property string style: "count"
    property string tone: "accent"
    property bool folders: true
    // on by default: a long press on a badged app or folder shows its notifications (Edit grid there starts the edit
    // mode); off, the long press starts the edit mode, as stock
    property bool peek: true
}
