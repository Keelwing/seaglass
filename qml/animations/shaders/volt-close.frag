// Volt, closing: charges up and switches off like an old TV.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 p = asp(uv);
    vec3 elec = tinted(vec3(0.55, 0.75, 1.0));
    float ch = smoothstep(0.0, 0.25, t);
    // interference: a band of torn rows rolls down the picture while it charges
    float row = floor(uv.y * resolution.y / 5.0);
    float tick = floor(time * 30.0);
    float by = (uv.y - mix(-0.15, 1.15, fract(time * 2.2))) * 7.0;
    float band = exp(-by * by);
    float jit = (hash(vec2(row, tick)) - 0.5) * 0.012 * band * ch * step(0.6, hash(vec2(row * 1.3, tick + 3.0)))
                * (1.0 - smoothstep(0.24, 0.3, t));
    vec2 cen = originRect.xy + originRect.zw * 0.5;
    float sq = smoothstep(0.24, 0.54, t);
    float sy = mix(1.0, 0.0025, sq * sq * (3.0 - 2.0 * sq));
    float hx = smoothstep(0.54, 0.74, t);
    float sx = 1.0 - hx * hx;
    vec2 q = vec2(cen.x + (uv.x - cen.x) / max(sx, 0.001), cen.y + (uv.y - cen.y) / sy);
    vec4 c = src(q + vec2(jit, 0.0));
    // as it collapses the picture burns to a blue-white line (not brighter colours, which clip)
    float energy = 1.0 / max(sy, 0.08) - 1.0;
    vec3 rgb = mix(c.rgb * (1.0 + 0.12 * ch), mix(elec, vec3(1.0), 0.6) * c.a, clamp(energy * 0.1, 0.0, 0.9));
    vec3 light = vec3(0.0);
    if (t < 0.34) {
        // arcs crawl in from the window's sides, one after the other: each leaps from a point of the edge, both its
        // ends creeping on, and it flickers
        float seed = fract(origin.y * 37.0);
        float x0 = originRect.x * aspect;
        float x1 = (originRect.x + originRect.z) * aspect;
        float arcs = 0.0;
        float cores = 0.0;
        for (int i = 0; i < 4; i++) {
            float fi = float(i);
            float left = mod(fi, 2.0);
            float side = left * 2.0 - 1.0;
            float h1 = hash(vec2(fi, seed * 256.0));
            float h2 = hash(vec2(fi + 7.0, seed * 256.0));
            float y = originRect.y + (0.12 + 0.76 * h1 + (h2 - 0.5) * 0.4 * t) * originRect.w;
            vec2 a = vec2(mix(x1, x0, left), y);
            float reach = 0.1 + 0.08 * h2 + 0.12 * t;
            vec2 b = a + vec2(side * reach, (h1 - 0.5) * 0.16 + sin(time * 7.0 + fi * 2.1) * 0.03);
            float grow = smoothstep(0.02 + fi * 0.04, 0.1 + fi * 0.04, t);
            float cc;
            float g = bolt(p, a, b, fract(seed + fi * 0.21), grow, 0.45, cc);
            float flick = (0.7 + 0.3 * hash(vec2(tick, fi))) * step(0.001, grow);
            arcs += g * flick;
            cores += cc * flick;
        }
        float phaseA = ch * (1.0 - smoothstep(0.26, 0.34, t));
        light = elec * arcs * 1.4 * phaseA + vec3(1.0) * cores * phaseA * 1.2;
    }
    vec2 cp = asp(cen);
    float dy = abs(uv.y - cen.y) * resolution.y;
    float lineGlow = exp(-dy / 6.0) * smoothstep(0.44, 0.54, t) * step(abs(uv.x - cen.x), 0.5 * sx + 0.002) * (1.0 - smoothstep(0.74, 0.8, t));
    float rr = length(p - cp);
    float dotg = exp(-rr * resolution.y / 8.0) * smoothstep(0.68, 0.76, t) * (1.0 - smoothstep(0.8, 0.96, t)) * 2.0;
    float tc = smoothstep(0.76, 1.0, t);
    float rd = (rr - tc * 0.25) * 60.0;
    float ring = exp(-rd * rd) * (1.0 - tc) * step(0.001, tc);
    light += elec * (lineGlow * 0.9 + ring * 0.8) + (elec + 0.5) * dotg;
    // once the line has shrunk to nothing, nothing of the picture is left (a one-pixel column was)
    float inQ = boxMask(q) * (1.0 - step(0.999, hx));
    FRAG_COLOR = vec4(rgb * inQ + light, c.a * inQ) * qt_Opacity;
}
