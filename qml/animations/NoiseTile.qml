// The noise tile of the effects (scripts/noise.py makes noise.png when the package is built), as a texture that
// repeats. It draws nothing itself. While it is not wanted, the picture is not read.
import QtQuick 2.6

ShaderEffectSource {
    property bool wanted: true

    width: 0
    height: 0
    textureSize: Qt.size(256, 256)
    wrapMode: ShaderEffectSource.Repeat
    hideSource: true
    sourceItem: tile

    Image {
        id: tile

        width: 256
        height: 256
        source: wanted ? "noise.png" : ""
    }
}
