// Shatter's shards (Shards.qml): the shard's triangle cut out of its quad, with the picture of the pane where the
// shard was, a light on its cracked edges and a glint when it faces the light.
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
uniform sampler2D source;
uniform lowp float qt_Opacity;
uniform highp float aspect;
// the triangle, in height units of the pane
uniform vec2 a;
uniform vec2 b;
uniform vec2 c;
uniform vec3 tint;
uniform float useTint;
// closing: the window's top edge as the swipe left it (0 to 1)
uniform float clipTop;
varying highp vec2 rest;
varying highp float glint;
varying highp float fade;
varying highp float crack;
varying highp vec2 nudge;

void main()
{
    vec2 v0 = b - a;
    vec2 v1 = c - a;
    vec2 v2 = rest - a;
    float d00 = dot(v0, v0);
    float d01 = dot(v0, v1);
    float d11 = dot(v1, v1);
    float d20 = dot(v2, v0);
    float d21 = dot(v2, v1);
    float den = max(d00 * d11 - d01 * d01, 0.0000001);
    float v = (d11 * d20 - d01 * d21) / den;
    float w = (d00 * d21 - d01 * d20) / den;
    float e = min(1.0 - v - w, min(v, w));
    vec2 uv = vec2(rest.x / aspect, rest.y) + nudge;
    float onPane = step(0.0, uv.x) * step(uv.x, 1.0) * step(clipTop, uv.y) * step(uv.y, 1.0);
    vec4 col = texture2D(source, clamp(uv, 0.0, 1.0)) * onPane;
    float l = dot(vec3(0.9, 0.97, 1.0), vec3(0.299, 0.587, 0.114));
    vec3 glass = mix(vec3(0.9, 0.97, 1.0), mix(tint * (l / max(dot(tint, vec3(0.299, 0.587, 0.114)), 0.05)), vec3(1.0), 0.3),
                     useTint);
    float edge = 1.0 - smoothstep(0.0, 0.03, e);
    col.rgb += glass * (edge * crack * 0.85 + glint * 0.9) * col.a;
    gl_FragColor = col * smoothstep(-0.004, 0.002, e) * fade * qt_Opacity;
}
