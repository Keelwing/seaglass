// Shatter's shards (Shards.qml): a shard's triangle, with the picture of the pane where the shard was, a light on its
// cracked edges and a glint where it catches the light. shards.vert works out the edge distances, which are linear over
// the triangle, and everything that takes progress: an animator does not drive a uniform declared in both stages.
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
uniform sampler2D source;
uniform lowp float qt_Opacity;
uniform highp float aspect;
uniform highp float side;
uniform highp vec2 impactAt;
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
// the distance to each edge in pixels, negative outside: seams as thin on a big shard as on a small one
varying highp vec3 edges;
varying highp vec3 kinds;
varying highp vec2 middle;
varying highp float flash;

void main()
{
    float inner = min(edges.x, min(edges.y, edges.z));
    vec2 uv = vec2(rest.x / aspect, rest.y) + nudge;
    float onPane = step(0.0, uv.x) * step(uv.x, 1.0) * smoothstep(clipTop - 1.0 / side, clipTop, uv.y)
                 * step(uv.y, 1.0);
    vec4 col = texture2D(source, clamp(uv, 0.0, 1.0)) * onPane;
    float l = dot(vec3(0.9, 0.97, 1.0), vec3(0.299, 0.587, 0.114));
    vec3 glass = mix(vec3(0.9, 0.97, 1.0), mix(tint * (l / max(dot(tint, vec3(0.299, 0.587, 0.114)), 0.05)), vec3(1.0), 0.3),
                     useTint);
    // the cracks, 2 pixels wide
    vec3 lines = (1.0 - smoothstep(0.0, 2.0, edges)) * kinds;
    float edge = max(lines.x, max(lines.y, lines.z));
    // a long light above the top left, seen from in front: as a shard turns towards it, a band of light slides
    // over its face
    vec3 n = facing.z < 0.0 ? -facing : facing;
    vec3 h = normalize(normalize(vec3(aspect * 0.25, -0.15, 0.7) - spot)
                       + normalize(vec3(aspect * 0.5, 0.5, 1.4) - spot));
    vec2 across = vec2(0.6, 0.8);
    float band = (dot(rest - middle, across) - dot(n.xy - h.xy, across) * 0.7) / 0.02;
    float glint = pow(max(dot(n, h), 0.0), 20.0) * exp(-band * band) * apart;
    // the flash, at the impact
    vec2 di = rest - impactAt;
    float burst = exp(-dot(di, di) * 4000.0) * flash;
    col.rgb += glass * (edge * crack * 0.85 + glint * 0.8 + burst) * col.a;
    // the edge: hard while the shard is in its place, soft once it moves. In its place it reaches a tenth of a pixel
    // past its edge: the rasterizer snaps each triangle's corners on its own, which can leave a pixel on a seam that
    // neither neighbour covers, and where they overlap both draw the same picture
    float cover = smoothstep(-max(apart, 0.001), 0.0, inner + (1.0 - min(apart * 8.0, 1.0)) * 0.1);
    gl_FragColor = col * cover * fade * qt_Opacity;
}
