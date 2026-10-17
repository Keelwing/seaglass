// Seaglass's own state, shared by the home screen and the settings: the debug log, the version the home screen
// runs (written by HomeController.qml when it loads, for the settings' status), and the version whose news were seen
import QtQuick 2.6
import Nemo.Configuration 1.0

ConfigurationGroup {
    path: "/apps/seaglass"

    // the keys a backup holds and Reset settings puts back
    readonly property var keys: ["debug"]

    property bool debug
    property string running
    property string seenVersion
    // the hint about the edit mode, after the starter widgets were placed: "" none, "pending", "done"
    property string editHint
}
