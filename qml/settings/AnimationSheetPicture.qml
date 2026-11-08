// The Animations page's sheet as one picture (AnimationsPage.qml): once every frame is made
// (AnimationSheetBuilder.qml), the page's grid of them is grabbed at rest and shown as one Image, and the frames and
// their kit go. With keep, the picture is also saved as a JPEG with a key file beside it, and a later visit whose key
// the file holds shows the JPEG and makes no frame at all. The page does not need this: without it, the frames are the
// sheet.
//
// Every failure is soft. No file, another key, or a JPEG that does not load: the frames are made. A grab or a picture
// that fails: the frames stay. A save that fails: the picture stays in memory, and the next visit makes the frames.
import QtQuick 2.6
import Sailfish.Silica 1.0
import "stills.js" as Stills

Item {
    id: picture

    // the page's Item that holds the frames: what is grabbed
    property Item frames
    // what the frames are made for: a picture stands for the frames only with the same key
    property string key
    // the kept files without their extension: .jpg for the picture, .key for the key it was made for
    property string path
    // read the kept files, and save the picture
    property bool keep
    // grab the frames once they are made
    property bool flatten: true
    // every frame made for the key
    property bool built
    // the page on top and its view not moving: a grab and a save wait for it
    property bool still

    // a kept file is used only with a KEY: without one, nothing ties the file to the files it was made from
    readonly property bool keeps: keep && Stills.KEY !== ""
    // no frames are wanted: the kept key is being read, the kept picture is loading, or the picture shows
    readonly property bool holds: key !== "" && (checking === key || loading === key && fromFile || shown === key)
    readonly property bool shows: key !== "" && shown === key

    // the key whose kept file is being read
    property string checking
    // the key of the picture loading, and whether it comes from the kept file or from a grab
    property string loading
    property bool fromFile
    // the key of the picture shown
    property string shown
    property string grabbing
    // a key whose grab or grabbed picture failed: its frames stay the sheet
    property string failed
    // a key whose grabbed picture waits to be saved, and the key last saved
    property string unsaved
    property string saved
    // the grab shown: its picture is Qt's to keep only as long as this is
    property var result: null
    // a file written and not yet read back: its name, its text and the step after it
    property var writing: null

    // reads the kept key, and makes no frame meanwhile
    function check() {
        if (!keeps || shown === key) {
            checking = ""
            return
        }
        checking = key
        reader.restart()
    }

    function read() {
        var forKey = key
        var name = path
        checking = forKey
        unanswered.restart()
        var request = new XMLHttpRequest()
        request.onreadystatechange = function () {
            if (request.readyState !== XMLHttpRequest.DONE || picture.checking !== forKey)
                return
            unanswered.stop()
            if (request.responseText === forKey)
                picture.show("file://" + name + ".jpg", true, forKey)
            picture.checking = ""
        }
        request.open("GET", "file://" + name + ".key")
        try {
            request.send()
        } catch (e) {
            unanswered.stop()
            checking = ""
        }
    }

    function grab() {
        var forKey = key
        grabbing = forKey
        var asked = frames.grabToImage(function (result) {
            picture.grabbing = ""
            // the sheet changed while it was grabbed: its new frames are grabbed once they are made
            if (forKey !== picture.key)
                return
            picture.result = result
            if (picture.keeps)
                picture.unsaved = forKey
            picture.show(result.url, false, forKey)
        })
        if (!asked) {
            grabbing = ""
            failed = forKey
        }
    }

    // A source is emptied first, so that the same file loads again, and the cache is set before the new source: the
    // grab's picture is found only in Qt's picture cache, and the file, whose name stays the same, must never come from
    // it. Emptied before the cache changes, the old source is not loaded again with the new setting
    function show(source, file, forKey) {
        fromFile = file
        loading = forKey
        shown = ""
        if (fade.running)
            fade.stop()
        image.opacity = 0
        image.source = ""
        image.cache = !file
        image.source = source
    }

    function loaded() {
        if (loading === "" || image.status === Image.Loading || image.status === Image.Null)
            return
        var forKey = loading
        if (image.status === Image.Ready) {
            // the grab's picture is what the frames show already; the kept one comes in over the dark panel
            if (fromFile)
                fade.start()
            else
                image.opacity = 1
            // shown before loading ends, so that holds never reads false between the two: the page would start a
            // build for that moment
            shown = forKey
            loading = ""
        } else {
            loading = ""
            image.source = ""
            result = null
            if (!fromFile)
                failed = forKey
        }
    }

    // the old key goes before the picture is written and the new one after it, so that a picture is never left beside
    // a key it was not made for
    function save() {
        var forKey = unsaved
        var name = path
        unsaved = ""
        if (result === null || forKey !== shown || forKey !== key || !keeps)
            return
        write(name + ".key", "", function () {
            if (picture.result === null || forKey !== picture.shown || forKey !== picture.key)
                return
            // the encode blocks the GUI thread: a page that moves meanwhile saves at its next rest, from the start
            if (!picture.still) {
                picture.unsaved = forKey
                return
            }
            if (picture.result.saveToFile(name + ".jpg"))
                write(name + ".key", forKey, function () { picture.saved = forKey })
        })
    }

    // a local file written with PUT, as the backup in AboutPage.qml is. In Qt 5.6 the PUT returns before the file is
    // written, and a PUT that fails says nothing: the file is read back on a later turn, and only then does the next
    // step run
    function write(file, text, then) {
        var request = new XMLHttpRequest()
        request.open("PUT", "file://" + file, false)
        try {
            request.send(text)
        } catch (e) {
            return
        }
        writing = { "file": file, "text": text, "then": then, "tries": 0 }
        landing.restart()
    }

    function landed() {
        var step = writing
        var request = new XMLHttpRequest()
        request.open("GET", "file://" + step.file, false)
        try {
            request.send()
        } catch (e) {
            writing = null
            return
        }
        if (request.responseText === step.text) {
            writing = null
            step.then()
        } else if (++step.tries < 10) {
            landing.restart()
        } else {
            writing = null
        }
    }

    onKeyChanged: check()
    onPathChanged: check()
    onKeepsChanged: check()
    Component.onCompleted: check()

    Image {
        id: image

        anchors.fill: parent
        asynchronous: true
        cache: false
        opacity: 0
        onStatusChanged: picture.loaded()
    }

    FadeAnimator {
        id: fade

        target: image
        from: 0
        to: 1
        duration: 150
    }

    // once the key and the path have both changed
    Timer {
        id: reader

        interval: 0
        onTriggered: picture.read()
    }

    // a read that never answers is a miss
    Timer {
        id: unanswered

        interval: 1000
        onTriggered: picture.checking = ""
    }

    // a write is read back until it is there, up to 10 times
    Timer {
        id: landing

        interval: 20
        onTriggered: picture.landed()
    }

    Timer {
        interval: 0
        running: picture.flatten && picture.built && picture.still && picture.grabbing === "" && picture.loading === ""
                 && picture.shown !== picture.key && picture.failed !== picture.key
        onTriggered: picture.grab()
    }

    // the JPEG encode blocks the GUI thread once
    Timer {
        interval: 0
        running: picture.unsaved !== "" && picture.unsaved === picture.shown && picture.unsaved === picture.key
                 && picture.still
        onTriggered: picture.save()
    }
}
