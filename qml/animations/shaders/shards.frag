// Shatter's shards (Shards.qml): the shard's triangle cut out of its quad, with the picture of the pane where the
// shard was, a light on its cracked edges and a glint where it catches the light.
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
uniform sampler2D source;
uniform lowp float qt_Opacity;
uniform highp float aspect;
uniform highp float side;
uniform highp float progress;
uniform highp vec2 impact;
uniform highp vec2 centroid;
// the triangle, in height units of the pane, and how its edges broke (bc, ca, ab): 1 a crack out from the impact,
// less a crack round it, little the cut that splits a cell in two
uniform vec2 a;
uniform vec2 b;
uniform vec2 c;
uniform vec3 kinds;
uniform vec3 tint;
uniform float useTint;
// closing: the window's top edge as the swipe left it (0 to 1)
uniform float clipTop;
varying highp vec2 rest;
varying highp vec3 spot;
varying highp vec3 facing;
varying highp float fade;
varying highp float crack;
varying highp float apart;
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
    // the distance to each edge in pixels (negative outside): seams as thin on a big shard as on a small one
    float a2 = abs(v0.x * v1.y - v0.y * v1.x);
    vec3 dpx = vec3((1.0 - v - w) / max(length(c - b), 0.00001), v / max(length(c - a), 0.00001),
                    w / max(length(b - a), 0.00001)) * a2 * side;
    float inner = min(dpx.x, min(dpx.y, dpx.z));
    vec2 uv = vec2(rest.x / aspect, rest.y) + nudge;
    float onPane = step(0.0, uv.x) * step(uv.x, 1.0) * smoothstep(clipTop - 1.0 / side, clipTop, uv.y)
                 * step(uv.y, 1.0);
    vec4 col = texture2D(source, clamp(uv, 0.0, 1.0)) * onPane;
    float l = dot(vec3(0.9, 0.97, 1.0), vec3(0.299, 0.587, 0.114));
    vec3 glass = mix(vec3(0.9, 0.97, 1.0), mix(tint * (l / max(dot(tint, vec3(0.299, 0.587, 0.114)), 0.05)), vec3(1.0), 0.3),
                     useTint);
    // the cracks, 2 pixels wide
    vec3 lines = (1.0 - smoothstep(0.0, 2.0, dpx)) * kinds;
    float edge = max(lines.x, max(lines.y, lines.z));
    // a long light above the top left, seen from in front: as a shard turns towards it, a band of light slides
    // over its face
    vec3 n = facing.z < 0.0 ? -facing : facing;
    vec3 h = normalize(normalize(vec3(aspect * 0.25, -0.15, 0.7) - spot)
                       + normalize(vec3(aspect * 0.5, 0.5, 1.4) - spot));
    vec2 across = vec2(0.6, 0.8);
    float band = (dot(rest - centroid, across) - dot(n.xy - h.xy, across) * 0.7) / 0.02;
    float glint = pow(max(dot(n, h), 0.0), 20.0) * exp(-band * band) * apart;
    // a flash at the impact: where the pane breaks, or the shards burst out of the icon
    vec2 di = rest - impact;
    float flash = exp(-dot(di, di) * 4000.0) * sin(3.14159265 * clamp(progress / 0.12, 0.0, 1.0));
    col.rgb += glass * (edge * crack * 0.85 + glint * 0.8 + flash) * col.a;
    // the edge: hard while the shard is in its place, so that the shards meet without a seam, soft once it moves
    float cover = smoothstep(-max(apart, 0.001), 0.0, inner);
    gl_FragColor = col * cover * fade * qt_Opacity;
}
