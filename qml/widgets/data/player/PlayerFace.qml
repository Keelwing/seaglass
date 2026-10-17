// The Now playing widget's face (docs/WIDGETS.md), drawn inside DataWidget.qml's glass: the album art, the title and
// the artist, the progress, and previous, play/pause and next.
//   source      PlayerSource.qml, or null
//   size        card | shelf | panel
//   idleMode    last (a play button starts the last player again) | hide (only "Nothing playing")
//   artBehind   the art, blurred and dimmed, fills the glass
//   lastPlayer  the desktop entry of the last player (the controller keeps it), or ""
//   radius      the glass's corners
// A tap on the buttons acts in place; anywhere else it brings the player up (activate()). The buttons take no
// touches themselves: DataWidget.qml's handle lies over the whole widget and calls pressAt, release and tapAt.
import QtQuick 2.6
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0
import "../faces.js" as Faces

Item {
    id: face

    property Item source
    property string size: "card"
    property bool editMode
    property string idleMode: "last"
    property bool artBehind: true
    property string lastPlayer
    property real radius: Theme.paddingLarge

    signal request(string what, string argument)

    // the button under the finger, lit while pressed
    property string pressedKey

    readonly property bool idle: !source || source.idle
    readonly property bool playing: source ? source.playing : false
    readonly property real progress: source && source.length > 0 ? Math.min(1, source.position / source.length) : 0
    readonly property string title: source && source.title !== "" ? source.title : qsTr("Unknown track")
    readonly property string artist: source ? source.artist : ""
    readonly property string artUrl: source && !idle ? source.art : ""
    readonly property string appIcon: source && !idle ? source.appIcon : ""
    readonly property bool canStart: idleMode !== "hide"
    readonly property real pad: Theme.paddingLarge
    readonly property bool several: source !== null && !idle && source.players.length > 1

    function activate() {
        var entry = source && source.present && source.desktopEntry !== "" ? source.desktopEntry
                  : lastPlayer !== "" ? lastPlayer : "jolla-mediaplayer"
        request("player", "/usr/share/applications/" + entry + ".desktop")
    }

    function controlAt(x, y) {
        return Faces.controlAt(face, x, y)
    }

    // DataWidget.qml: a press on a button lights it (true), elsewhere nothing (false)
    function pressAt(x, y) {
        pressedKey = controlAt(x, y)
        return pressedKey !== ""
    }

    function release() {
        pressedKey = ""
    }

    // a tap: on a button, its action (true); elsewhere false, and the widget brings the player up
    function tapAt(x, y) {
        var key = controlAt(x, y)
        if (key === "" || !source)
            return false
        if (key === "playPause")
            source.playPause()
        else if (key === "next")
            source.next()
        else if (key === "previous")
            source.previous()
        else if (key === "switch")
            source.switchPlayer()
        else if (key === "start") {
            // a player paused for long plays on; without one, the last player starts again
            if (source.present)
                source.playPause()
            else
                activate()
        }
        return true
    }

    // ---- the art behind: blurred and dimmed, in the glass's corners ----

    Item {
        anchors.fill: parent
        visible: face.artBehind && backdropPicture.status === Image.Ready && !face.idle

        Image {
            id: backdropPicture

            anchors.fill: parent
            visible: false
            source: face.artBehind ? face.artUrl : ""
            sourceSize.width: 96
            sourceSize.height: 96
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        FastBlur {
            id: backdropBlur

            anchors.fill: parent
            visible: false
            source: backdropPicture
            radius: 40
            cached: true
        }

        Rectangle {
            id: backdropCorners

            anchors.fill: parent
            radius: face.radius
            visible: false
        }

        OpacityMask {
            anchors.fill: parent
            source: backdropBlur
            maskSource: backdropCorners
            opacity: 0.5
        }

        // a veil, so that the text stays readable on any art
        Rectangle {
            anchors.fill: parent
            radius: face.radius
            color: Theme.rgba(Theme.overlayBackgroundColor, 0.35)
        }
    }

    // ---- the card: the art, the title and the artist, the progress, the controls ----

    Item {
        id: card

        visible: face.size === "card" && !face.idle
        anchors.fill: parent

        readonly property real gap: Theme.paddingMedium
        readonly property real button: Math.min(Theme.itemSizeSmall, (width - 2 * face.pad) / 3.8)

        // the art fills what the text leaves (a title of two lines takes a little of it)
        RoundedArt {
            readonly property real room: cardTitle.y - face.pad * 0.6 - card.gap

            x: (card.width - width) / 2
            y: face.pad * 0.6 + (room - height) / 2
            width: Math.max(0, Math.min(card.width - 2 * face.pad, room))
            height: width
            radius: Theme.paddingMedium
            source: face.artUrl
            appIcon: face.appIcon
        }

        Label {
            id: cardTitle

            x: face.pad * 0.75
            width: card.width - 2 * x
            anchors.bottom: cardArtist.top
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.primaryColor
            text: face.title
        }

        Label {
            id: cardArtist

            x: face.pad * 0.75
            width: card.width - 2 * x
            anchors.bottom: cardProgress.top
            anchors.bottomMargin: card.gap
            horizontalAlignment: implicitWidth > width ? Text.AlignLeft : Text.AlignHCenter
            truncationMode: TruncationMode.Fade
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
            text: face.artist
        }

        ProgressLine {
            id: cardProgress

            x: face.pad
            width: card.width - 2 * x
            anchors.bottom: cardControls.top
            anchors.bottomMargin: card.gap * 0.75
            value: face.progress
        }

        Row {
            id: cardControls

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: face.pad * 0.5
            spacing: Math.min(Theme.paddingLarge, (card.width - 2 * face.pad - 3 * card.button) / 2)

            FaceButton {
                key: "previous"
                icon: "icon-m-simple-previous"
                diameter: card.button
                available: face.source !== null && face.source.canGoPrevious
                down: face.pressedKey === key
            }
            FaceButton {
                key: "playPause"
                icon: face.playing ? "icon-m-simple-pause" : "icon-m-simple-play"
                filled: true
                diameter: card.button
                down: face.pressedKey === key
            }
            FaceButton {
                key: "next"
                icon: "icon-m-simple-next"
                diameter: card.button
                available: face.source !== null && face.source.canGoNext
                down: face.pressedKey === key
            }
        }
    }

    // ---- the shelf: the art, the title and the artist over the progress, the controls ----

    Item {
        id: shelf

        visible: face.size === "shelf" && !face.idle
        anchors.fill: parent

        readonly property real button: Math.min(Theme.itemSizeSmall, height * 0.5)

        RoundedArt {
            id: shelfArt

            x: Theme.paddingMedium
            y: Theme.paddingMedium
            width: shelf.height - 2 * Theme.paddingMedium
            height: width
            radius: Theme.paddingMedium
            source: face.artUrl
            appIcon: face.appIcon
        }

        Column {
            x: shelfArt.x + shelfArt.width + Theme.paddingLarge
            width: shelfControls.x - x - Theme.paddingLarge
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.paddingSmall

            Label {
                width: parent.width
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.primaryColor
                text: face.title
            }

            Label {
                width: parent.width
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                text: face.artist
                visible: text !== ""
            }

            Item {
                width: parent.width
                height: Theme.paddingSmall

                ProgressLine {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    value: face.progress
                }
            }
        }

        Row {
            id: shelfControls

            anchors.right: parent.right
            anchors.rightMargin: Theme.paddingMedium
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.paddingSmall

            FaceButton {
                key: "previous"
                icon: "icon-m-simple-previous"
                diameter: shelf.button
                available: face.source !== null && face.source.canGoPrevious
                down: face.pressedKey === key
            }
            FaceButton {
                key: "playPause"
                icon: face.playing ? "icon-m-simple-pause" : "icon-m-simple-play"
                filled: true
                diameter: shelf.button
                down: face.pressedKey === key
            }
            FaceButton {
                key: "next"
                icon: "icon-m-simple-next"
                diameter: shelf.button
                available: face.source !== null && face.source.canGoNext
                down: face.pressedKey === key
            }
        }
    }

    // ---- the panel: a large art; the player, title, artist and album, the progress with its times, the controls ----

    Item {
        id: panel

        visible: face.size === "panel" && !face.idle
        anchors.fill: parent

        readonly property real button: Math.min(Theme.itemSizeSmall, (panelText.width - 2 * Theme.paddingLarge) / 3)

        RoundedArt {
            id: panelArt

            x: face.pad
            y: face.pad
            width: Math.min(panel.height - 2 * face.pad, panel.width * 0.42)
            height: width
            radius: Theme.paddingLarge
            source: face.artUrl
            appIcon: face.appIcon
        }

        Column {
            id: panelText

            x: panelArt.x + panelArt.width + face.pad
            y: face.pad * 0.75
            width: panel.width - x - face.pad
            spacing: Theme.paddingSmall / 2

            // the player: with several, a chip that switches between them
            Item {
                width: parent.width
                height: playerChip.height

                Rectangle {
                    id: playerChip

                    readonly property string key: face.several ? "switch" : ""
                    readonly property bool down: face.pressedKey === "switch"

                    width: Math.min(parent.width, chipRow.width + 2 * Theme.paddingMedium)
                    height: Math.round(Theme.fontSizeExtraSmall * 1.9)
                    radius: height / 2
                    color: !face.several ? "transparent"
                           : down ? Theme.rgba(Theme.highlightBackgroundColor, Theme.highlightBackgroundOpacity)
                                  : Theme.rgba(Theme.highlightBackgroundColor, 0.22)
                    x: face.several ? 0 : -Theme.paddingMedium

                    Row {
                        id: chipRow

                        anchors.centerIn: parent
                        spacing: Theme.paddingSmall

                        Label {
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryHighlightColor
                            truncationMode: TruncationMode.Fade
                            text: face.source ? face.source.identity : ""
                        }

                        Label {
                            visible: face.several
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.highlightColor
                            text: face.source ? (face.source.players.indexOf(face.source.currentService) + 1) + "/"
                                                + face.source.players.length : ""
                        }
                    }
                }
            }

            Label {
                width: parent.width
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSizeMedium
                font.family: Theme.fontFamilyHeading
                color: Theme.primaryColor
                text: face.title
            }

            // the artist and the album in one line
            Label {
                width: parent.width
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                text: {
                    var album = face.source ? face.source.album : ""
                    return face.artist !== "" && album !== "" ? face.artist + " · " + album : face.artist + album
                }
                visible: text !== ""
            }
        }

        Item {
            x: panelText.x
            width: panelText.width
            anchors.bottom: panelControls.top
            anchors.bottomMargin: Theme.paddingMedium
            height: panelElapsed.height + Theme.paddingMedium

            ProgressLine {
                width: parent.width
                value: face.progress
            }

            Label {
                id: panelElapsed

                anchors.bottom: parent.bottom
                font.pixelSize: Theme.fontSizeTiny
                color: Theme.secondaryColor
                text: face.source && face.source.length > 0 ? Faces.duration(face.source.position) : ""
            }

            Label {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                font.pixelSize: Theme.fontSizeTiny
                color: Theme.secondaryColor
                text: face.source && face.source.length > 0 ? Faces.duration(face.source.length) : ""
            }
        }

        Row {
            id: panelControls

            anchors.horizontalCenter: panelText.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: face.pad * 0.75
            spacing: Theme.paddingLarge

            FaceButton {
                key: "previous"
                icon: "icon-m-simple-previous"
                diameter: panel.button
                available: face.source !== null && face.source.canGoPrevious
                down: face.pressedKey === key
            }
            FaceButton {
                key: "playPause"
                icon: face.playing ? "icon-m-simple-pause" : "icon-m-simple-play"
                filled: true
                diameter: panel.button
                down: face.pressedKey === key
            }
            FaceButton {
                key: "next"
                icon: "icon-m-simple-next"
                diameter: panel.button
                available: face.source !== null && face.source.canGoNext
                down: face.pressedKey === key
            }
        }
    }

    // ---- idle: Nothing playing, and a play button that starts the last player again ----

    Item {
        id: idleFace

        visible: face.idle
        anchors.fill: parent

        readonly property bool wide: face.size !== "card"
        readonly property real tile: wide ? Math.min(height - 2 * Theme.paddingMedium, Theme.itemSizeExtraLarge)
                                          : Math.min(width * 0.42, Theme.itemSizeExtraLarge)
        readonly property real button: Math.min(Theme.itemSizeSmall, wide ? height * 0.5 : width * 0.3)

        RoundedArt {
            id: idleTile

            x: idleFace.wide ? Theme.paddingMedium + (face.size === "panel" ? face.pad : 0) : (idleFace.width - width) / 2
            y: idleFace.wide ? (idleFace.height - height) / 2 : face.pad
            width: idleFace.tile
            height: width
            radius: Theme.paddingMedium
        }

        Label {
            id: idleLabel

            x: idleFace.wide ? idleTile.x + idleTile.width + Theme.paddingLarge : face.pad * 0.75
            width: idleFace.wide ? idleStart.x - x - Theme.paddingLarge : idleFace.width - 2 * x
            anchors.verticalCenter: idleFace.wide ? parent.verticalCenter : undefined
            y: idleFace.wide ? 0 : idleTile.y + idleTile.height + Theme.paddingLarge
            horizontalAlignment: idleFace.wide ? Text.AlignLeft : Text.AlignHCenter
            wrapMode: Text.Wrap
            font.pixelSize: face.size === "panel" ? Theme.fontSizeLarge : Theme.fontSizeMedium
            color: Theme.secondaryColor
            text: qsTr("Nothing playing")
        }

        FaceButton {
            id: idleStart

            visible: face.canStart
            key: "start"
            icon: "icon-m-simple-play"
            filled: true
            diameter: idleFace.button
            down: face.pressedKey === key
            x: idleFace.wide ? idleFace.width - width - Theme.paddingLarge - (face.size === "panel" ? face.pad : 0)
                             : (idleFace.width - width) / 2
            y: idleFace.wide ? (idleFace.height - height) / 2 : idleFace.height - height - face.pad * 0.75
        }
    }
}
