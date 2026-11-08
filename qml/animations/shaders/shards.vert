// Shatter's shards (Shards.qml), all of them over one GridMesh of one row. The grid shares its vertices, so a shard
// takes three of its columns, whose two vertices go to the shard's corners A and A, then B and A, then C and C: along
// the strip the grid draws, the triangle ABC is the only one with an area. Which vertex this is comes from
// qt_MultiTexCoord0, and the whole break from seed, so no shard has data of its own. This throws, drops and turns each
// shard about its own axis, in height units of the pane (1 = its height). mode 0 breaks the pane at impactAt (closing),
// 1 plays it the other way: the shards fly out of the impact and fit together (opening). GLSL ES 1.00. progress is only
// here, not in shards.frag: an animator does not drive a uniform declared in both stages.
uniform highp mat4 qt_Matrix;
attribute highp vec4 qt_Vertex;
attribute highp vec2 qt_MultiTexCoord0;
uniform highp float side;
uniform highp float aspect;
uniform highp float progress;
uniform highp float mode;
uniform highp vec2 impactAt;
uniform highp vec4 seed;
// the break: rays from the impact, and up to 8 rings further out, in height units; columns is the mesh's resolution
uniform highp float rays;
uniform highp float columns;
uniform highp vec4 ringsA;
uniform highp vec4 ringsB;
varying highp vec2 rest;
// where the point is in space (height units, z towards the eye) and which way the shard faces, for its glint
varying highp vec3 spot;
varying highp vec3 facing;
varying highp float fade;
varying highp float crack;
// 0 while the shard is in its place, 1 once it is on its way
varying highp float apart;
varying highp vec2 nudge;
// the distance to each edge (bc, ca, ab) in pixels, negative outside, and how each edge broke: 1 a crack out from the
// impact, less a crack round it, little the cut that splits a cell in two
varying highp vec3 edges;
varying highp vec3 kinds;
varying highp vec2 middle;
varying highp float flash;

highp float hash(highp vec2 c)
{
    highp vec3 p = fract(vec3(c.xyx) * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

highp float ringAt(highp float ring)
{
    highp vec4 v = ring < 3.5 ? ringsA : ringsB;
    highp float i = ring < 3.5 ? ring : ring - 4.0;
    return i < 0.5 ? v.x : i < 1.5 ? v.y : i < 2.5 ? v.z : v.w;
}

// where a ray crosses a ring, from 0 to rays round the impact: each ray is jittered once, each crossing once, and the
// shards on either side of it work out the same point
highp vec2 cornerOf(highp float ray, highp float ring)
{
    highp float r = ray < rays - 0.5 ? ray : ray - rays;
    highp float angle = (r + (hash(vec2(r, seed.x * 91.0)) - 0.5) * 0.6) / rays * 6.28318530 + seed.y * 6.28318530;
    highp float reach = ringAt(ring) * (0.85 + 0.3 * hash(vec2(r + 17.0 * ring, seed.z * 91.0)));
    return impactAt + vec2(cos(angle), sin(angle)) * reach;
}

highp vec3 turn(highp vec3 p, highp vec3 axis, highp float angle)
{
    return p * cos(angle) + cross(axis, p) * sin(angle) + axis * dot(axis, p) * (1.0 - cos(angle));
}

void main()
{
    // whole numbers, and a GPU's division may come out just under one: the added half keeps floor() from a step short
    highp float column = floor(qt_MultiTexCoord0.x * columns + 0.5);
    highp float row = floor(qt_MultiTexCoord0.y + 0.5);
    highp float shard = floor((column + 0.5) / 3.0);
    highp float inShard = column - shard * 3.0;
    highp float which = inShard < 0.5 ? 0.0 : inShard < 1.5 ? (row > 0.5 ? 0.0 : 1.0) : 2.0;

    // a radial break: rays cracks from the impact, rings of them further out, every cell split in two
    highp vec2 a, b, c;
    highp float radial = 1.0, round = 0.6, cut = 0.15;
    if (shard < rays - 0.5) {
        a = impactAt;
        b = cornerOf(shard, 0.0);
        c = cornerOf(shard + 1.0, 0.0);
        kinds = vec3(round, radial, radial);
    } else {
        highp float s = shard - rays;
        highp float cell = floor(s / 2.0);
        highp float secondHalf = s - cell * 2.0;
        highp float ring = floor((cell + 0.5) / rays);
        highp float k = cell - ring * rays;
        highp vec2 p = cornerOf(k, ring), q = cornerOf(k + 1.0, ring);
        highp vec2 r = cornerOf(k + 1.0, ring + 1.0), t = cornerOf(k, ring + 1.0);
        if (hash(vec2(cell, seed.w * 91.0)) < 0.5) {
            if (secondHalf < 0.5) { a = p; b = q; c = r; kinds = vec3(radial, cut, round); }
            else { a = p; b = r; c = t; kinds = vec3(round, radial, cut); }
        } else {
            if (secondHalf < 0.5) { a = p; b = q; c = t; kinds = vec3(cut, radial, round); }
            else { a = q; b = r; c = t; kinds = vec3(round, cut, radial); }
        }
    }
    highp vec2 mid = (a + b + c) / 3.0;
    highp vec2 low = min(a, min(b, c)), high = max(a, max(b, c));
    // off the pane, all its vertices go to one point outside the screen
    if (high.x < -0.02 || low.x > aspect + 0.02 || high.y < -0.02 || low.y > 1.02) {
        gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
        rest = vec2(0.0); spot = vec3(0.0); facing = vec3(0.0, 0.0, 1.0); fade = 0.0; crack = 0.0; apart = 0.0;
        nudge = vec2(0.0); edges = vec3(0.0); kinds = vec3(0.0); middle = vec2(0.0); flash = 0.0;
        return;
    }
    highp vec4 rnd = vec4(hash(vec2(shard, 3.0 + seed.x * 57.0)), hash(vec2(shard, 5.0 + seed.y * 57.0)),
                          hash(vec2(shard, 7.0 + seed.z * 57.0)), hash(vec2(shard, 11.0 + seed.w * 57.0)));

    // this corner, pushed out a little: the soft edge of a shard that moves lies outside its triangle
    highp vec2 here = which < 0.5 ? a : which < 1.5 ? b : c;
    highp vec2 outward = here - mid;
    rest = here + outward / max(length(outward), 0.00001) * 2.5 / side;

    // linear over the triangle, so the rasterizer carries them and no pixel has to solve for them
    highp vec2 v0 = b - a, v1 = c - a, v2 = rest - a;
    highp float d00 = dot(v0, v0), d01 = dot(v0, v1), d11 = dot(v1, v1), d20 = dot(v2, v0), d21 = dot(v2, v1);
    highp float den = max(d00 * d11 - d01 * d01, 0.0000001);
    highp float v = (d11 * d20 - d01 * d21) / den, w = (d00 * d21 - d01 * d20) / den;
    highp float a2 = abs(v0.x * v1.y - v0.y * v1.x);
    edges = vec3((1.0 - v - w) / max(length(c - b), 0.00001), v / max(length(c - a), 0.00001),
                 w / max(length(b - a), 0.00001)) * a2 * side;
    middle = mid;

    highp float dist = length(mid - impactAt);
    highp vec3 axis = normalize(vec3(rnd.x - 0.5, rnd.y - 0.5, (rnd.z - 0.5) * 0.4) + vec3(0.0001));
    highp float spin;
    highp float scale = 1.0;
    highp vec2 at;
    if (mode > 0.5) {
        // each shard leaves the impact (the icon) small and turning, and lands in its place, the near ones first and
        // the ones at the icon at once: none shows at 0, the app grows out of the icon at an even pace, the last
        // shard lands by 0.88 and its seam has faded by 1
        highp vec2 i = impactAt;
        highp float far = max(max(length(i), length(i - vec2(aspect, 0.0))),
                              max(length(i - vec2(0.0, 1.0)), length(i - vec2(aspect, 1.0))));
        highp float land = 0.22 + (0.56 + rnd.x * 0.1) * clamp(dist / far, 0.0, 1.0);
        highp float f = clamp((progress - (land - 0.22)) / 0.22, 0.0, 1.0);
        highp float e = 1.0 - (1.0 - f) * (1.0 - f) * (1.0 - f);
        highp vec2 path = mid - impactAt;
        at = mix(impactAt, mid, e) + vec2(-path.y, path.x) * (rnd.y - 0.5) * 0.5 * sin(3.14159265 * e);
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
        highp float delay = 0.08 + dist * 0.36 + rnd.x * 0.1;
        highp float age = max(0.0, progress - delay) * 1.25;
        highp vec2 away = normalize(mid - impactAt + vec2(0.0001, 0.0));
        highp vec2 velocity = away * (0.15 + rnd.y * 0.35) + vec2((rnd.z - 0.5) * 0.25, -0.25 - rnd.w * 0.35);
        at = mid + velocity * age + vec2(0.0, 3.0) * age * age;
        spin = age * (4.0 + rnd.z * 10.0) * (rnd.w > 0.5 ? 1.0 : -1.0);
        fade = 1.0 - smoothstep(0.9, 1.0, progress);
        apart = min(1.0, age * 8.0);
        nudge = (rnd.xy - 0.5) * 0.006 * crack;
    }
    // a flash at the impact: where the pane breaks, or the shards burst out of the icon
    flash = sin(3.14159265 * clamp(progress / 0.12, 0.0, 1.0));
    highp vec3 local = turn(vec3((rest - mid) * scale, 0.0), axis, spin);
    facing = turn(vec3(0.0, 0.0, 1.0), axis, spin);
    highp float perspective = 1.0 / (1.0 - local.z * 0.9);
    highp vec2 position = at + local.xy * perspective;
    spot = vec3(position, local.z);
    gl_Position = qt_Matrix * vec4(position * side, 0.0, 1.0);
}
