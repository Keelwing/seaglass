// Volt, closing: charges up and switches off like an old TV.
// arc fi (0 to 3) of the charging: its glow and its core, by its flicker. One call per arc, not a loop, so that all of
// an arc that does not depend on the pixel is the same for the whole draw and can be worked out once
vec2 arc(vec2 p, float fi)
{
    float t = progress;
    float grow = smoothstep(0.02 + fi * 0.04, 0.1 + fi * 0.04, t);
    if (grow < 0.001)
        return vec2(0.0);
    float seed = fract(origin.y * 37.0);
    float x0 = originRect.x * aspect;
    float x1 = (originRect.x + originRect.z) * aspect;
    float left = mod(fi, 2.0);
    float side = left * 2.0 - 1.0;
    float h1 = hash(vec2(fi, seed * 256.0));
    float h2 = hash(vec2(fi + 7.0, seed * 256.0));
    float y = originRect.y + (0.12 + 0.76 * h1 + (h2 - 0.5) * 0.4 * t) * originRect.w;
    vec2 a = vec2(mix(x1, x0, left), y);
    float reach = 0.1 + 0.08 * h2 + 0.12 * t;
    vec2 b = a + vec2(side * reach, (h1 - 0.5) * 0.16 + sin(time * 7.0 + fi * 2.1) * 0.03);
    float cc;
    float g = bolt(p, a, b, fract(seed + fi * 0.21), grow, 0.45, cc);
    float flick = 0.7 + 0.3 * hash(vec2(floor(time * 30.0), fi));
    return vec2(g, cc) * flick;
}

void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 p = asp(uv);
    vec2 cen = originRect.xy + originRect.zw * 0.5;
    vec2 cp = asp(cen);
    float dy = abs(uv.y - cen.y) * resolution.y;
    float rr = length(p - cp);
    float tc = smoothstep(0.76, 1.0, t);
    // from 0.54 the picture is a line a few pixels high. What is left is that line, its glow, the dot and the ring,
    // and past these limits each of them is below half a level
    if (t > 0.54 && dy > 48.0 && rr * resolution.y > 72.0 && abs(rr - tc * 0.25) > 0.048) {
        FRAG_COLOR = vec4(0.0);
        return;
    }
    vec3 elec = tinted(vec3(0.55, 0.75, 1.0));
    float ch = smoothstep(0.0, 0.25, t);
    float tick = floor(time * 30.0);
    float jit = 0.0;
    if (t < 0.3) {
        // interference: a band of torn rows rolls down the picture while it charges
        float by = (uv.y - mix(-0.15, 1.15, fract(time * 2.2))) * 7.0;
        if (abs(by) < 3.0) {
            float row = floor(uv.y * resolution.y / 5.0);
            jit = (hash(vec2(row, tick)) - 0.5) * 0.012 * exp(-by * by) * ch * step(0.6, hash(vec2(row * 1.3, tick + 3.0)))
                  * (1.0 - smoothstep(0.24, 0.3, t));
        }
    }
    float sq = smoothstep(0.24, 0.54, t);
    float sy = mix(1.0, 0.0025, sq * sq * (3.0 - 2.0 * sq));
    float hx = smoothstep(0.54, 0.74, t);
    float sx = 1.0 - hx * hx;
    vec2 sc = vec2(max(sx, 0.001), sy);
    vec2 q = cen + (uv - cen) / sc;
    // once the line has shrunk to nothing, nothing of the picture is left (a one-pixel column was)
    float inQ = boxMask(q) * (1.0 - step(0.999, hx));
    vec4 c = vec4(0.0);
    vec3 rgb = vec3(0.0);
    // read two pixels past its edge: a read beside pixels that skip it takes no proper level from a mipmapped window
    // (a still's), which would show as a line along that edge
    vec2 past = (abs(q - 0.5) - 0.5) * resolution * sc;
    if (hx < 0.999 && past.x < 2.0 && past.y < 2.0) {
        c = src(q + vec2(jit, 0.0));
        // as it collapses the picture burns to a blue-white line (not brighter colours, which clip)
        float energy = 1.0 / max(sy, 0.08) - 1.0;
        rgb = mix(c.rgb * (1.0 + 0.12 * ch), mix(elec, vec3(1.0), 0.6) * c.a, clamp(energy * 0.1, 0.0, 0.9));
    }
    vec3 light = vec3(0.0);
    if (t < 0.34) {
        // arcs crawl in from the window's sides, one after the other: each leaps from a point of the edge, both its
        // ends creeping on, and it flickers
        vec2 ac = arc(p, 0.0) + arc(p, 1.0) + arc(p, 2.0) + arc(p, 3.0);
        float arcs = ac.x;
        float cores = ac.y;
        float phaseA = ch * (1.0 - smoothstep(0.26, 0.34, t));
        light = elec * arcs * 1.4 * phaseA + vec3(1.0) * cores * phaseA * 1.2;
    }
    if (t > 0.44) {
        float lineGlow = exp(-dy / 6.0) * smoothstep(0.44, 0.54, t) * step(abs(uv.x - cen.x), 0.5 * sx + 0.002) * (1.0 - smoothstep(0.74, 0.8, t));
        float dotg = exp(-rr * resolution.y / 8.0) * smoothstep(0.68, 0.76, t) * (1.0 - smoothstep(0.8, 0.96, t)) * 2.0;
        float rd = (rr - tc * 0.25) * 60.0;
        float ring = exp(-rd * rd) * (1.0 - tc) * step(0.001, tc);
        light += elec * (lineGlow * 0.9 + ring * 0.8) + (elec + 0.5) * dotg;
    }
    FRAG_COLOR = vec4(rgb * inQ + light, c.a * inQ) * qt_Opacity;
}
