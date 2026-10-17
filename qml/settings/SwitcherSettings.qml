// The task switcher
import QtQuick 2.6
import Nemo.Configuration 1.0

ConfigurationGroup {
    path: "/apps/seaglass/switcher"

    readonly property var keys: ["background", "chips", "layout", "flickClose", "recent", "recentCount", "pinch"]

    property string background: "wallpaper"
    property bool chips: true
    property string layout: "grid"
    property bool flickClose: true
    property bool recent: true
    property int recentCount: 5
    property string recentApps: "[]"
    property bool pinch: true
}
