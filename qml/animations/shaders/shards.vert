// Shatter's shards (Shards.qml): each shard is a quad over its triangle's bounding box. This throws, drops and turns
// it about its own axis, in height units of the pane (1 = its height). mode 0 breaks the pane at impact (closing),
// 1 plays it the other way: the shards fly out of the impact and fit together (opening).
uniform highp mat4 qt_Matrix;
attribute highp vec4 qt_Vertex;
// the quad's corner in the pane, in pixels, and the pane's height in pixels
uniform highp vec2 corner;
uniform highp float side;
uniform highp float aspect;
uniform highp float progress;
uniform highp float mode;
uniform highp vec2 impact;
uniform highp vec2 centroid;
uniform highp vec4 rnd;
varying highp vec2 rest;
// where the point is in space (height units, z towards the eye) and which way the shard faces, for its glint
varying highp vec3 spot;
varying highp vec3 facing;
varying highp float fade;
varying highp float crack;
// 0 while the shard is in its place, 1 once it is on its way
varying highp float apart;
varying highp vec2 nudge;

vec3 turn(vec3 p, vec3 axis, float angle)
{
    return p * cos(angle) + cross(axis, p) * sin(angle) + axis * dot(axis, p) * (1.0 - cos(angle));
}

void main()
{
    rest = (corner + qt_Vertex.xy) / side;
    float dist = length(centroid - impact);
    vec3 axis = normalize(vec3(rnd.x - 0.5, rnd.y - 0.5, (rnd.z - 0.5) * 0.4) + vec3(0.0001));
    float spin;
    float scale = 1.0;
    vec2 at;
    if (mode > 0.5) {
        // each shard leaves the impact (the icon) small and turning, and lands in its place, the near ones first and
        // the ones at the icon at once: none shows at 0, the app grows out of the icon at an even pace, the last
        // shard lands by 0.88 and its seam has faded by 1
        vec2 i = impact;
        float far = max(max(length(i), length(i - vec2(aspect, 0.0))),
                        max(length(i - vec2(0.0, 1.0)), length(i - vec2(aspect, 1.0))));
        float land = 0.22 + (0.56 + rnd.x * 0.1) * clamp(dist / far, 0.0, 1.0);
        float f = clamp((progress - (land - 0.22)) / 0.22, 0.0, 1.0);
        float e = 1.0 - (1.0 - f) * (1.0 - f) * (1.0 - f);
        vec2 path = centroid - impact;
        at = mix(impact, centroid, e) + vec2(-path.y, path.x) * (rnd.y - 0.5) * 0.5 * sin(3.14159265 * e);
        spin = (1.0 - e) * (3.0 + rnd.z * 5.0) * (rnd.w > 0.5 ? 1.0 : -1.0);
        scale = mix(0.3, 1.0, e);
        fade = smoothstep(0.0, 0.2, f);
        crack = step(land, progress) * (1.0 - smoothstep(0.0, 0.1, progress - land));
        apart = min(1.0, (1.0 - e) * 8.0);
        nudge = vec2(0.0);
    } else {
        // the crack runs out from the impact; each shard drops a little after it, the near ones first, and falls
        // off the pane by the end
        crack = smoothstep(dist * 0.35, dist * 0.35 + 0.04, progress * 1.2);
        float delay = 0.08 + dist * 0.36 + rnd.x * 0.1;
        float age = max(0.0, progress - delay) * 1.25;
        vec2 away = normalize(centroid - impact + vec2(0.0001, 0.0));
        vec2 velocity = away * (0.15 + rnd.y * 0.35) + vec2((rnd.z - 0.5) * 0.25, -0.25 - rnd.w * 0.35);
        at = centroid + velocity * age + vec2(0.0, 3.0) * age * age;
        spin = age * (4.0 + rnd.z * 10.0) * (rnd.w > 0.5 ? 1.0 : -1.0);
        fade = 1.0 - smoothstep(0.9, 1.0, progress);
        apart = min(1.0, age * 8.0);
        nudge = (rnd.xy - 0.5) * 0.006 * crack;
    }
    vec3 local = turn(vec3((rest - centroid) * scale, 0.0), axis, spin);
    facing = turn(vec3(0.0, 0.0, 1.0), axis, spin);
    float perspective = 1.0 / (1.0 - local.z * 0.9);
    vec2 position = at + local.xy * perspective;
    spot = vec3(position, local.z);
    gl_Position = qt_Matrix * vec4(position * side - corner, 0.0, 1.0);
}
