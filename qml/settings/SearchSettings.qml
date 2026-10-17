// The search row and the launch counts it ranks by
import QtQuick 2.6
import Nemo.Configuration 1.0

ConfigurationGroup {
    path: "/apps/seaglass/search"

    readonly property var keys: ["row", "position", "remember"]

    property string row: "suggestions"
    property string position: "bottom"
    property bool remember: true
    property string usage: "{}"
}
