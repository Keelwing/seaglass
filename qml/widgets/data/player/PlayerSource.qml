// The Now playing widget's source (docs/WIDGETS.md): the current MPRIS player, through Amber.Mpris's MprisController,
// as the lock screen's controls. Never Sailfish.Media's MprisPlayerControls: its MprisManagerControls also takes the
// headset buttons, and a second copy in the home screen would toggle play twice on one press. Loaded by
// DataSources.qml; when Amber.Mpris is missing, Now playing is not offered.
//   live       the app grid is on screen: the progress ticks only then, and only while a track plays
//   demo       sample values (the harness): a made-up track, never the phone's music
//   demoState  with "idle": the sample player has nothing to play
// MPRIS does not signal the position as it moves, and reading it asks the player over D-Bus (the Media player
// answers positionRequested): it is read only when the track, the player or the state changes, on seeked and when
// the grid comes up, and reckoned from there with the rate.
import QtQuick 2.6
import Amber.Mpris 1.0
import org.nemomobile.lipstick 0.1

// an Item, not a QtObject: Qt 5's Loader does not load non-visual root objects
Item {
    id: source

    property bool live: true
    property bool demo
    property string demoState

    // a player is on the bus
    readonly property bool present: demo ? demoState.indexOf("idle") < 0 : mpris.currentService !== ""
    readonly property bool playing: demo ? demoPlaying && present : mpris.playbackStatus === Mpris.Playing
    // nothing to show: no player, a player without a track, or paused for 30 minutes (as on the lock screen)
    readonly property bool idle: !present || expired || (title === "" && artist === "")
    readonly property string title: demo ? (present ? "Northern Lights" : "") : text(meta ? meta.title : "")
    readonly property string artist: demo ? (present ? "The Sample Band" : "") : text(meta ? meta.contributingArtist : "")
    readonly property string album: demo ? (present ? "Field Recordings" : "") : text(meta ? meta.albumTitle : "")
    // the album art as a URL, or ""
    readonly property string art: demo ? (present ? "file:///usr/share/ambience/water/images/ambience_water.jpg" : "")
                                       : artUrl(meta ? meta.artUrl : "")
    // the track's length and the position, in ms (0 when unknown)
    readonly property real length: demo ? 214000 : Math.max(0, Number(meta && meta.duration ? meta.duration : 0) || 0)
    readonly property real position: {
        if (demo)
            return 72000
        var at = positionBase + (playing ? (now - positionAt) * rate : 0)
        return Math.max(0, length > 0 ? Math.min(length, at) : at)
    }
    readonly property string identity: demo ? "Media" : mpris.identity
    readonly property string desktopEntry: demo ? "jolla-mediaplayer" : mpris.desktopEntry
    // the player's app icon (its desktop entry's), for the art's corner
    readonly property string appIcon: app.iconId
    readonly property var players: demo ? (present ? ["org.mpris.MediaPlayer2.jolla-mediaplayer"] : [])
                                        : mpris.availableServices
    readonly property string currentService: demo ? (present ? players[0] : "") : mpris.currentService
    readonly property bool canGoNext: demo ? present : mpris.canGoNext
    readonly property bool canGoPrevious: demo ? present : mpris.canGoPrevious
    readonly property bool canPlay: demo ? present : mpris.canPlay
    readonly property bool canPause: demo ? present : mpris.canPause

    // the last control used (the harness checks it)
    property string lastAction
    property bool demoPlaying: true
    property bool expired
    readonly property QtObject meta: demo ? null : mpris.metaData
    readonly property real rate: demo ? 1 : (mpris.rate > 0 ? mpris.rate : 1)
    property real positionBase
    property double positionAt: new Date().getTime()
    property double now: positionAt

    visible: false

    function text(value) {
        if (value === undefined || value === null)
            return ""
        // the artists are a list
        return value.join ? value.join(", ") : String(value)
    }

    function artUrl(value) {
        var url = text(value)
        return url.charAt(0) === "/" ? "file://" + url : url
    }

    // the position asked of the player once, then reckoned; not while the grid is hidden (read again when it shows)
    function readPosition() {
        if (demo || !live)
            return
        positionAt = new Date().getTime()
        now = positionAt
        positionBase = mpris.currentService !== "" ? Math.max(0, Number(mpris.position) || 0) : 0
    }

    function heard(position) {
        positionAt = new Date().getTime()
        now = positionAt
        positionBase = Math.max(0, Number(position) || 0)
    }

    function playPause() {
        lastAction = "playPause"
        if (demo) {
            demoPlaying = !demoPlaying
            return
        }
        if (playing ? mpris.canPause : mpris.canPlay)
            mpris.playPause()
    }

    function next() {
        lastAction = "next"
        if (!demo && mpris.canGoNext)
            mpris.next()
    }

    function previous() {
        lastAction = "previous"
        if (!demo && mpris.canGoPrevious)
            mpris.previous()
    }

    function raise() {
        lastAction = "raise"
        if (!demo && mpris.canRaise)
            mpris.raise()
    }

    // the next player on the bus, with several
    function switchPlayer() {
        lastAction = "switch"
        if (demo || players.length < 2)
            return
        var index = players.indexOf(mpris.currentService)
        mpris.currentService = players[(index + 1) % players.length]
    }

    onPlayingChanged: {
        readPosition()
        if (playing) {
            expiry.stop()
            expired = false
        } else {
            expiry.restart()
        }
    }
    onLiveChanged: if (live) readPosition()
    onPresentChanged: if (!present) expired = false
    // a turn after loading: DataSources.qml sets demo and live once the source is made
    Timer {
        interval: 0
        running: true
        onTriggered: {
            source.readPosition()
            if (!source.playing)
                expiry.restart()
        }
    }

    MprisController {
        id: mpris

        onCurrentServiceChanged: source.readPosition()
        onSeeked: source.heard(position)
        onPositionChanged: source.heard(position)
    }

    Connections {
        target: source.meta
        onMetaDataChanged: source.readPosition()
    }

    LauncherItem {
        id: app

        filePath: source.desktopEntry !== "" ? "/usr/share/applications/" + source.desktopEntry + ".desktop" : ""
    }

    // paused for 30 minutes: the widget says Nothing playing, as the lock screen hides its controls
    Timer {
        id: expiry

        interval: 30 * 60 * 1000
        onTriggered: source.expired = true
    }

    // the progress, once a second while a track plays and the grid is shown
    Timer {
        interval: 1000
        repeat: true
        running: source.live && source.playing && !source.demo
        onTriggered: source.now = new Date().getTime()
    }
}
