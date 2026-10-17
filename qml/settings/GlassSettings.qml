// The app grid's background and the glass (GlassSource.qml)
import QtQuick 2.6
import Nemo.Configuration 1.0

ConfigurationGroup {
    path: "/apps/seaglass/glass"

    readonly property var keys: ["look", "picture", "image", "frost", "tint", "dim", "edge", "folders", "openFolder",
                                 "cards", "parallax", "depth", "tilt", "drift"]

    property string look: "clear"
    property string picture: "home"
    property string image: ""
    property int frost: 1
    property string tint: "auto"
    property real dim: 0.25
    property bool edge: true
    property bool folders: true
    property bool openFolder: true
    property bool cards: true
    property int parallax: 1
    property bool depth: true
    property bool tilt: false
    property bool drift: false
}
