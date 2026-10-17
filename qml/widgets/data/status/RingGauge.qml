// A ring that fills clockwise from the top: the battery of the status widget. Drawn by a small shader, crisp at any
// size and cheap to redraw.
//   value      0 .. 1
//   color      the filled part
//   track      the rest of the ring
//   thickness  the ring's width as a part of its radius
// (Qt hands colours to a shader premultiplied by their alpha.)
import QtQuick 2.6
import Sailfish.Silica 1.0

ShaderEffect {
    id: ring

    property real value: 0
    property color color: Theme.highlightColor
    property color track: Theme.rgba(Theme.primaryColor, 0.15)
    property real thickness: 0.16
    // the antialiased edge, in texture units
    readonly property real feather: width > 0 ? 2.0 / width : 0.01

    blending: true
    fragmentShader: "
        varying highp vec2 qt_TexCoord0;
        uniform lowp float qt_Opacity;
        uniform highp float value;
        uniform highp float thickness;
        uniform highp float feather;
        uniform lowp vec4 color;
        uniform lowp vec4 track;
        void main() {
            highp vec2 p = qt_TexCoord0 * 2.0 - 1.0;
            highp float r = length(p);
            highp float inner = 1.0 - thickness;
            highp float body = smoothstep(inner - feather, inner + feather, r)
                             * (1.0 - smoothstep(1.0 - 2.0 * feather, 1.0, r));
            highp float angle = atan(p.x, -p.y);
            highp float t = (angle < 0.0 ? angle + 6.2831853 : angle) / 6.2831853;
            highp float on = 1.0 - smoothstep(value - 0.003, value + 0.003, t);
            lowp vec4 c = mix(track, color, value <= 0.0 ? 0.0 : on);
            gl_FragColor = c * body * qt_Opacity;
        }"
}
