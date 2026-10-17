// Shatter's shards (docs/ANIMATIONS.md): a pane broken at a point into about 130 triangles, which fall (closing) or
// fly in and fit together (opening, assemble). Qt 5.6's ShaderEffect has no custom meshes, so each shard is a small
// ShaderEffect over its triangle's bounding box: shaders/shards.vert turns and moves it, shaders/shards.frag cuts the
// triangle out. The shard items are made once; build() lays them out for a new break, at impact (0 to 1 over the
// pane). Show it only when ready.
import QtQuick 2.6
import "shaders.js" as Shaders

Item {
    id: pane

    // the shard items exist only while active
    property bool active: true
    property variant source
    property real progress
    property bool assemble
    property point impact: Qt.point(0.5, 0.5)
    property vector3d tint: Qt.vector3d(1, 1, 1)
    property real useTint
    property real clipTop
    // how many shard items there are, and the break: rays from the impact, rings further out (in pane heights)
    property int capacity: 140
    property int rays: 11
    property var rings: [0.05, 0.12, 0.22, 0.35, 0.52, 0.75, 1.05, 1.5]
    property string vertexText
    property string fragmentText
    readonly property bool ready: active && vertexText !== "" && fragmentText !== ""
                                  && shardRepeater.count === capacity

    // a radial break: 11 cracks from the impact, rings of them further out, every cell split in two
    function build() {
        var side = Math.max(1, height)
        var aspect = width / side
        var centre = [impact.x * aspect, impact.y]
        var rings = pane.rings
        var rays = pane.rays
        var turnBy = Math.random() * Math.PI * 2
        var angles = []
        var jitter = []
        for (var k = 0; k < rays; k++) {
            angles.push((k + (Math.random() - 0.5) * 0.6) / rays * Math.PI * 2 + turnBy)
            var row = []
            for (var m = 0; m < rings.length; m++)
                row.push(0.85 + 0.3 * Math.random())
            jitter.push(row)
        }
        var corner = function (ray, ring) {
            var r = ray % rays
            var length = rings[ring] * jitter[r][ring]
            return [centre[0] + Math.cos(angles[r]) * length, centre[1] + Math.sin(angles[r]) * length]
        }
        var triangles = []
        for (k = 0; k < rays; k++)
            triangles.push([centre, corner(k, 0), corner(k + 1, 0)])
        for (m = 0; m < rings.length - 1; m++) {
            for (k = 0; k < rays; k++) {
                var p = corner(k, m), q = corner(k + 1, m), r2 = corner(k + 1, m + 1), s = corner(k, m + 1)
                if (Math.random() < 0.5)
                    triangles.push([p, q, r2], [p, r2, s])
                else
                    triangles.push([p, q, s], [q, r2, s])
            }
        }
        var used = 0
        for (var i = 0; i < triangles.length && used < capacity; i++) {
            var t = triangles[i]
            var minX = Math.min(t[0][0], t[1][0], t[2][0]), maxX = Math.max(t[0][0], t[1][0], t[2][0])
            var minY = Math.min(t[0][1], t[1][1], t[2][1]), maxY = Math.max(t[0][1], t[1][1], t[2][1])
            if (maxX < -0.02 || minX > aspect + 0.02 || maxY < -0.02 || minY > 1.02)
                continue
            var shard = shardRepeater.itemAt(used++)
            shard.x = Math.floor(minX * side) - 2
            shard.y = Math.floor(minY * side) - 2
            shard.width = Math.ceil((maxX - minX) * side) + 4
            shard.height = Math.ceil((maxY - minY) * side) + 4
            shard.a = Qt.point(t[0][0], t[0][1])
            shard.b = Qt.point(t[1][0], t[1][1])
            shard.c = Qt.point(t[2][0], t[2][1])
            shard.centroid = Qt.point((t[0][0] + t[1][0] + t[2][0]) / 3, (t[0][1] + t[1][1] + t[2][1]) / 3)
            shard.rnd = Qt.vector4d(Math.random(), Math.random(), Math.random(), Math.random())
            shard.visible = true
        }
        for (i = used; i < capacity; i++)
            shardRepeater.itemAt(i).visible = false
    }

    Repeater {
        id: shardRepeater

        model: pane.active && pane.vertexText !== "" && pane.fragmentText !== "" ? pane.capacity : 0

        ShaderEffect {
            property variant source: pane.source
            property real progress: pane.progress
            property real mode: pane.assemble ? 1 : 0
            property point impact: Qt.point(pane.impact.x * pane.width / Math.max(1, pane.height), pane.impact.y)
            property real side: Math.max(1, pane.height)
            property real aspect: pane.width / Math.max(1, pane.height)
            property point corner: Qt.point(x, y)
            property point a
            property point b
            property point c
            property point centroid
            property vector4d rnd
            property vector3d tint: pane.tint
            property real useTint: pane.useTint
            property real clipTop: pane.clipTop

            visible: false
            blending: true
            vertexShader: pane.vertexText
            fragmentShader: pane.fragmentText
        }
    }

    Component.onCompleted: {
        var base = Qt.resolvedUrl("shaders/")
        Shaders.loadFile(base + "shards.vert", function (text) { pane.vertexText = text })
        Shaders.loadFile(base + "shards.frag", function (text) { pane.fragmentText = text })
    }
}
