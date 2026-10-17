// Helpers of the data widgets' faces (docs/WIDGETS.md).
.pragma library

// The control under a point of a face: the key of the visible item with a key property (FaceButton.qml, an event's
// row) that holds the point, or "". DataWidget.qml's handle lies over the whole widget, so the faces hit-test their
// controls themselves (pressAt, tapAt).
function controlAt(root, x, y) {
    var children = root.children || []
    for (var i = children.length - 1; i >= 0; i--) {
        var child = children[i]
        if (!child.visible || child.opacity === 0)
            continue
        if (child.key !== undefined) {
            if (child.key !== "" && child.available !== false) {
                var p = child.mapFromItem(root, x, y)
                if (p.x >= 0 && p.y >= 0 && p.x < child.width && p.y < child.height)
                    return child.key
            }
            continue
        }
        var p2 = child.mapFromItem(root, x, y)
        var key = controlAt(child, p2.x, p2.y)
        if (key !== "")
            return key
    }
    return ""
}

// A length of time in ms as m:ss (h:mm:ss from an hour)
function duration(ms) {
    var s = Math.max(0, Math.floor(ms / 1000))
    var h = Math.floor(s / 3600)
    var m = Math.floor(s / 60) % 60
    var rest = s % 60
    var tail = (rest < 10 ? "0" : "") + rest
    return h > 0 ? h + ":" + (m < 10 ? "0" : "") + m + ":" + tail : m + ":" + tail
}
