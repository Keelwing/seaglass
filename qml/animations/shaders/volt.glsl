// Volt's lightning: jagged bolts from white noise, as a glow and a white core
// a line of straight pieces, k * 256 of them over y = 0 to 1, and its slope: exact (slope), and blended into the
// next piece's around each corner (soft). A glow measured with the exact one steps at every corner, in bands across
// the whole bolt
float jag(float y, float k, float row, out float slope, out float soft)
{
    float x = y * k * 256.0;
    float i = floor(x);
    float f = x - i;
    float r = floor(row * 256.0);
    float h0 = hash(vec2(i, r));
    float h1 = hash(vec2(i + 1.0, r));
    // the piece before this one in its first half, the one after it in its second
    float hn = hash(vec2(f < 0.5 ? i - 1.0 : i + 2.0, r));
    slope = h1 - h0;
    soft = f < 0.5 ? mix(h0 - hn, slope, f + 0.5) : mix(slope, hn - h1, f - 0.5);
    slope *= k * 256.0;
    soft *= k * 256.0;
    return mix(h0, h1, f) - 0.5;
}
// the same around a closed line: n straight pieces over a (0 to 1), so that 1 meets 0 without a seam
float ringJag(float a, float n, float row)
{
    float x = a * n;
    float i = floor(x);
    float r = floor(row * 256.0);
    return mix(hash(vec2(mod(i, n), r)), hash(vec2(mod(i + 1.0, n), r)), x - i) - 0.5;
}
// a bolt's offset sideways at y in three octaves, coarse to fine, and their slopes, for a bolt drawn at size (1:
// one as long as a screen is high; a smaller one is as jagged, at a smaller scale). An octave whose pieces would be
// only a few pixels long is left out
vec3 boltX(float y, float seed, float size, out vec3 slopes, out vec3 soft)
{
    vec3 f = vec3(0.10, 0.45, 1.9);
    vec3 k = vec3(0.10, 0.028, 0.008) * smoothstep(2.0, 5.0, resolution.y * size / (f * 256.0));
    float s0, s1, s2, b0, b1, b2;
    vec3 x = vec3(jag(y / size, f.x, seed, s0, b0), jag(y / size, f.y, seed + 0.137, s1, b1),
                  jag(y / size, f.z, seed + 0.311, s2, b2)) * k;
    slopes = vec3(s0, s1, s2) * k;
    soft = vec3(b0, b1, b2) * k;
    return x * size;
}
// a bolt from a to b in any direction, drawn from a as far as upto (0 to 1): jagged across the line between them,
// still at both ends, and round where it ends. Each distance to it is divided by its slope, so that its steep
// pieces are as thick as the others. The glows follow only the octaves with pieces long enough not to streak them,
// and only near the bolt: further out the slope would carry a steep piece's glow on along its line, as a band. How
// far a pixel is from the straight line drawn so far says how much of this can show there. Glows are measured in
// pixels and jags in the bolt's size, so the limits below have both: on a smaller item a glow reaches further across
float bolt(vec2 p, vec2 a, vec2 b, float seed, float upto, float size, out float core)
{
    core = 0.0;
    float len = max(length(b - a), 0.0001);
    vec2 dir = (b - a) / len;
    vec2 q = p - a;
    float s = dot(q, dir);
    float sc = clamp(s, 0.0, len * upto);
    float px1 = 1.0 / resolution.y;
    float away = length(q - dir * sc);
    // past the wide glow, which is below one level here
    if (away > 280.0 * px1 + 0.12 * size)
        return 0.0;
    float env = pow(max(sin(PI * sc / len), 0.0), 0.6);
    float w = dot(q, vec2(-dir.y, dir.x));
    float ds = s - sc;
    // half the length of a coarse piece
    float lx = 0.5 * size / (0.10 * 256.0);
    // only the wide glow reaches here, and it needs only the coarse octave
    if (away > 114.0 * px1 + 0.1 * size) {
        float kx = 0.10 * smoothstep(2.0, 5.0, resolution.y * size / (0.10 * 256.0));
        float s0, b0;
        float off0 = jag(sc / size, 0.10, seed, s0, b0) * kx * size * env;
        float sb0 = b0 * kx * env;
        float wf0 = abs(w - off0);
        float far0 = length(vec2(max(wf0 / sqrt(1.0 + sb0 * sb0), wf0 - abs(sb0) * lx), ds));
        return exp(-far0 / (px1 * 45.0)) * 0.22;
    }
    // boltX's octaves, the fine one only where the core needs it
    vec3 k = vec3(0.10, 0.028, 0.008) * smoothstep(2.0, 5.0, resolution.y * size / (vec3(0.10, 0.45, 1.9) * 256.0));
    float s0, s1, b0, b1;
    float off0 = jag(sc / size, 0.10, seed, s0, b0) * k.x * size * env;
    float off1 = jag(sc / size, 0.45, seed + 0.137, s1, b1) * k.y * size * env;
    float sb0 = b0 * k.x * env;
    float sb1 = b1 * k.y * env;
    float m = smoothstep(8.0, 16.0, resolution.y * size / (0.45 * 256.0));
    float sMid = sb0 + sb1 * m;
    float wm = abs(w - off0 - off1 * m);
    float mid = length(vec2(max(wm / sqrt(1.0 + sMid * sMid), wm - abs(sMid) * lx), ds));
    float wf = abs(w - off0);
    float far = length(vec2(max(wf / sqrt(1.0 + sb0 * sb0), wf - abs(sb0) * lx), ds));
    // the fine octave moves the core by half of k.z and steepens it by 486.4 * k.z at most: past 4.5 pixels the core
    // is below a tenth of a level
    float sl01 = s0 * k.x * env + s1 * k.y * env;
    float sMax = abs(sl01) + 486.4 * k.z;
    float near = max(abs(w - off0 - off1) - 0.5 * k.z * size, 0.0);
    if (length(vec2(near / sqrt(1.0 + sMax * sMax), ds)) < 4.5 * px1) {
        float s2, b2;
        float off2 = jag(sc / size, 1.9, seed + 0.311, s2, b2) * k.z * size * env;
        float sAll = sl01 + s2 * k.z * env;
        float dist = length(vec2((w - off0 - off1 - off2) / sqrt(1.0 + sAll * sAll), ds));
        core = exp(-dist * dist / (px1 * px1 * 2.2));
    }
    return exp(-mid / (px1 * 10.0)) * 0.55 + exp(-far / (px1 * 45.0)) * 0.22;
}
// the point of that bolt at u (0 at a, 1 at b), where a branch can leave it
vec2 boltAt(vec2 a, vec2 b, float seed, float size, float u)
{
    float len = max(length(b - a), 0.0001);
    vec2 dir = (b - a) / len;
    vec3 sl, sb;
    vec3 off = boltX(len * u, seed, size, sl, sb);
    return a + dir * len * u + vec2(-dir.y, dir.x) * (off.x + off.y + off.z) * pow(max(sin(PI * u), 0.0), 0.6);
}
