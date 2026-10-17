// Shatter's shards (Shards.qml): each shard is a quad over its triangle's bounding box. This throws, drops and turns
// it about its own axis, in height units of the pane (1 = its height). mode 0 breaks the pane at impact (closing),
// 1 plays it backwards: the shards fly in and fit together (opening).
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
varying highp float glint;
varying highp float fade;
varying highp float crack;
varying highp vec2 nudge;

vec3 turn(vec3 p, vec3 axis, float angle)
{
    return p * cos(angle) + cross(axis, p) * sin(angle) + axis * dot(axis, p) * (1.0 - cos(angle));
}

void main()
{
    rest = (corner + qt_Vertex.xy) / side;
    float dist = length(centroid - impact);
    float t;
    if (mode < 0.5) {
        t = progress;
        crack = smoothstep(dist * 0.35, dist * 0.35 + 0.04, progress * 1.2);
    } else {
        t = 1.0 - progress;
        crack = smoothstep(0.7, 0.88, progress) * (1.0 - smoothstep(0.9, 1.0, progress)) * 0.6;
    }
    float delay = 0.16 + dist * 0.32 + rnd.x * 0.1;
    float age = max(0.0, t - delay) * 1.25;
    vec2 away = normalize(centroid - impact + vec2(0.0001, 0.0));
    vec2 velocity = away * (0.15 + rnd.y * 0.35) + vec2((rnd.z - 0.5) * 0.25, -0.25 - rnd.w * 0.35);
    vec2 moved = velocity * age + vec2(0.0, 2.4) * age * age;
    float spin = age * (4.0 + rnd.z * 10.0) * (rnd.w > 0.5 ? 1.0 : -1.0);
    vec3 axis = normalize(vec3(rnd.x - 0.5, rnd.y - 0.5, (rnd.z - 0.5) * 0.4) + vec3(0.0001));
    vec3 local = turn(vec3(rest - centroid, 0.0), axis, spin);
    vec3 normal = turn(vec3(0.0, 0.0, 1.0), axis, spin);
    float perspective = 1.0 / (1.0 - local.z * 0.9);
    vec2 position = centroid + moved + local.xy * perspective;
    gl_Position = qt_Matrix * vec4(position * side - corner, 0.0, 1.0);
    glint = pow(max(0.0, dot(normalize(normal), normalize(vec3(-0.35, -0.55, 0.75)))), 30.0) * step(0.001, age);
    fade = (1.0 - smoothstep(0.55, 1.0, age)) * (1.0 - smoothstep(0.86, 1.0, t));
    nudge = (rnd.xy - 0.5) * 0.006 * crack * (1.0 - step(0.5, mode));
}
