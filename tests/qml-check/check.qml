import QtQuick 2.6

// Compile every QML file named in files.txt (next to this file) without making it: a missing import, type or
// property of this Sailfish OS release shows as an error
Item {
    Component.onCompleted: {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", Qt.resolvedUrl("files.txt"), false)
        xhr.send()
        var files = xhr.responseText.split("\n").filter(function (f) { return f.length > 0 })
        var failed = 0
        for (var i = 0; i < files.length; i++) {
            var c = Qt.createComponent("file://" + files[i], Component.PreferSynchronous)
            if (c.status === Component.Ready) {
                console.log("qml-check: OK  ", files[i])
            } else {
                failed++
                console.log("qml-check: FAIL", files[i], c.errorString().replace(/\n/g, " | "))
            }
        }
        console.log("qml-check:", files.length, "files,", failed, "failed")
        Qt.quit()
    }
}
