// The animations scene (docs/ANIMATIONS.md), "STYLE MOMENT [PROGRESS]": a style's effect for a moment (open,
// close or load) on a made-up app over the stock picture, the same Effect.qml as on the home screen. Without a
// progress it runs from 0 to 1 every 3 s (a cover's loading loop runs on its own); with one it holds there, for a
// shot. "check" draws every style's three effects whose shader is there and logs "harness: animations NAME drawn"
// for each; a shader that does not compile shows up as Qt's "QOpenGLShader::compile" warning in the log.
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../qml/animations"
import "../qml/animations/styles.js" as Styles

Item {
    id: scene

    property Item harness
    readonly property var words: harness ? harness.sceneArgument.split(" ") : []
    readonly property bool check: words[0] === "check"
    readonly property string style: words[0] || "seaglass"
    readonly property string moment: words[1] || "open"
    readonly property real held: words.length > 2 ? parseFloat(words[2]) : -1
    readonly property bool shatter: style === "shatter" && moment !== "load"

    Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: scene.harness ? "file://" + scene.harness.picture : ""
    }

    // the made-up app: a page over the dimmed picture
    Rectangle {
        id: app

        anchors.fill: parent
        color: "#0b1426"

        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            opacity: 0.45
            source: scene.harness ? "file://" + scene.harness.picture : ""
        }

        Column {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * x
            y: Theme.itemSizeLarge
            spacing: Theme.paddingLarge

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignRight
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeLarge
                text: "Notes"
            }

            Rectangle {
                width: parent.width
                height: Theme.itemSizeExtraLarge * 1.4
                radius: Theme.paddingLarge
                color: "#c8a74a"

                Label {
                    x: Theme.paddingLarge
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: Theme.fontSizeHuge
                    text: "12 notes"
                }
            }

            Repeater {
                model: ["Shopping list", "Cabin weekend", "Book tips", "Bike repair", "Gift ideas", "Recipe"]

                Label {
                    font.pixelSize: Theme.fontSizeLarge
                    text: modelData
                }
            }
        }
    }

    ShaderEffectSource {
        id: appTexture

        width: scene.width
        height: scene.height
        visible: false
        mipmap: effect.es3
        hideSource: true
        sourceItem: app
    }

    NoiseTile {
        id: noise
    }

    Effect {
        id: effect

        visible: !scene.check && !scene.shatter && ready
        x: scene.moment === "load" ? (scene.width - width) / 2 : 0
        y: scene.moment === "load" ? scene.height * 0.3 : 0
        width: scene.moment === "load" ? Theme.coverSizeLarge.width : scene.width
        height: scene.moment === "load" ? Theme.coverSizeLarge.height : scene.height
        style: scene.check || scene.shatter ? "" : scene.style
        moment: scene.moment
        source: scene.moment === "load" ? icon : appTexture
        noiseTex: noise
        tint: Qt.vector3d(Theme.highlightColor.r, Theme.highlightColor.g, Theme.highlightColor.b)
        radiusPx: Theme.paddingLarge
        // opening: from a cover at the bottom right; closing: the whole window, let go at its upper third
        originRect: scene.moment === "close" ? Qt.rect(0, 0, 1, 1) : Qt.rect(0.55, 0.62, 0.38, 0.27)
        origin: scene.moment === "close" ? Qt.point(0.5, 0.3) : Qt.point(0.74, 0.75)
        progress: scene.held >= 0 ? scene.held : run.value
        time: clock.seconds
    }

    // Shatter opens and closes with its shards; in the check they break once, for the shaders to compile
    Shards {
        id: pieces

        anchors.fill: parent
        visible: (scene.shatter || scene.check) && ready
        active: scene.shatter || scene.check
        source: appTexture
        assemble: scene.moment === "open"
        impact: Qt.point(0.5, 0.45)
        progress: scene.check ? 0.3 : scene.held >= 0 ? scene.held : run.value
        tint: Qt.vector3d(Theme.highlightColor.r, Theme.highlightColor.g, Theme.highlightColor.b)
        onReadyChanged: {
            if (ready)
                build()
        }
    }

    Image {
        id: icon

        visible: false
        width: 256
        height: 256
        source: "image://theme/icon-launcher-notes"
        sourceSize: Qt.size(256, 256)
    }

    QtObject {
        id: run

        property real value
    }

    NumberAnimation {
        target: run
        property: "value"
        from: 0
        to: 1
        duration: 3000
        loops: Animation.Infinite
        running: scene.held < 0 && scene.moment !== "load"
    }

    QtObject {
        id: clock

        property real seconds
    }

    Timer {
        interval: 16
        repeat: true
        running: !scene.check && scene.held < 0
        onTriggered: clock.seconds += interval / 1000
    }

    // the compile check: every style and moment, one pixel each, for a moment
    Row {
        id: checks

        visible: scene.check
        opacity: 0.02

        Repeater {
            model: {
                var list = []
                if (scene.check) {
                    for (var i = 0; i < Styles.STYLES.length; i++)
                        list.push(Styles.STYLES[i].id + "/open", Styles.STYLES[i].id + "/close",
                                  Styles.STYLES[i].id + "/load")
                }
                return list
            }

            Effect {
                width: 1
                height: 1
                style: modelData.split("/")[0]
                moment: modelData.split("/")[1]
                source: noise
                noiseTex: noise
                progress: 0.5
            }
        }
    }

    Timer {
        interval: 1500
        running: scene.check
        onTriggered: {
            for (var i = 0; i < checks.children.length; i++) {
                var item = checks.children[i]
                if (item.shaderName === undefined || !item.loaded)
                    continue
                console.log("harness: animations", item.shaderName, "drawn")
            }
        }
    }
}
