// Feel, under the sheet of the Animations page (AnimationsPage.qml): the speed of the effects, Surprise me, Ambience
// colours and Covers too. A file of its own, made once the page has started, so that the page's push compiles no
// ComboBox or menu.
import QtQuick 2.6
import Sailfish.Silica 1.0

Column {
    id: feel

    // the page's settings (AnimationSettings.qml), and whether the page is on top. The page passes the settings with
    // the source; made on its own, as a check that creates every file does, it has none, and the switches read off
    property QtObject settings
    property bool live

    // a tap on the menu sets currentIndex by hand, which ends the binding: bind again when back
    onLiveChanged: {
        if (live)
            speedBox.currentIndex = Qt.binding(function () { return feel.settings.speed })
    }

    SectionHeader {
        text: qsTr("Feel")
    }

    ComboBox {
        id: speedBox

        label: qsTr("Speed")
        currentIndex: feel.settings.speed
        menu: ContextMenu {
            MenuItem { text: qsTr("Relaxed"); onClicked: feel.settings.speed = 0 }
            MenuItem { text: qsTr("Normal"); onClicked: feel.settings.speed = 1 }
            MenuItem { text: qsTr("Quick"); onClicked: feel.settings.speed = 2 }
        }
    }

    TextSwitch {
        text: qsTr("Surprise me")
        description: qsTr("A different style each time an app opens, loads or closes, for every moment not set to "
                          + "Stock.")
        checked: feel.settings !== null && feel.settings.surprise
        automaticCheck: false
        onClicked: feel.settings.surprise = !feel.settings.surprise
    }

    TextSwitch {
        text: qsTr("Ambience colours")
        description: qsTr("Fire, water and light take the ambience's highlight colour.")
        checked: feel.settings !== null && feel.settings.ambience
        automaticCheck: false
        onClicked: feel.settings.ambience = !feel.settings.ambience
    }

    TextSwitch {
        text: qsTr("Covers too")
        description: qsTr("Closing a cover in the switcher, or all of them, plays the closing effect on the covers.")
        checked: feel.settings !== null && feel.settings.covers
        automaticCheck: false
        onClicked: feel.settings.covers = !feel.settings.covers
    }
}
