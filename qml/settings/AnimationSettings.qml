// The opening, loading and closing effects of apps (docs/ANIMATIONS.md)
import QtQuick 2.6
import Nemo.Configuration 1.0

ConfigurationGroup {
    path: "/apps/seaglass/animations"

    readonly property var keys: ["enabled", "style", "open", "loading", "close", "surprise", "speed", "ambience",
                                 "covers"]

    property bool enabled: true
    property string style: "ember"
    // a moment's own style: "" the style above, "stock", or a style
    property string open: "ember"
    property string loading: "dust"
    property string close: "aurora"
    property bool surprise: false
    // 0 relaxed, 1 normal, 2 quick
    property int speed: 2
    property bool ambience: true
    property bool covers: true
}
