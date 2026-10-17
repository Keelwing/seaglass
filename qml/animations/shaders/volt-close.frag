// Volt, closing: charges up and switches off like an old TV.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 p = asp(uv);
    vec3 elec = tinted(vec3(0.55, 0.75, 1.0));
    float ch = smoothstep(0.0, 0.4, t);
    float row = floor(uv.y * resolution.y / 5.0);
    float tick = floor(time * 30.0);
    float jit = (hash(vec2(row, tick)) - 0.5) * 0.02 * ch * step(0.8, hash(vec2(row * 1.3, tick + 3.0))) * (1.0 - step(0.42, t));
    vec2 cen = originRect.xy + originRect.zw * 0.5;
    float sq = smoothstep(0.38, 0.66, t);
    float sy = mix(1.0, 0.0025, sq * sq * (3.0 - 2.0 * sq));
    float hx = smoothstep(0.66, 0.86, t);
    float sx = 1.0 - hx * hx;
    vec2 q = vec2(cen.x + (uv.x - cen.x) / max(sx, 0.001), cen.y + (uv.y - cen.y) / sy);
    vec4 c = src(q + vec2(jit, 0.0));
    float energy = 1.0 / max(sy, 0.08) - 1.0;
    vec3 rgb = c.rgb * (1.0 + 0.35 * ch + 0.25 * energy) + elec * c.a * min(energy * 0.12, 1.0);
    float arcs = 0.0;
    float cores = 0.0;
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float tk = floor(time * 14.0 + fi * 0.37);
        vec2 a = vec2(hash(vec2(tk, fi * 7.0 + 1.0)) * aspect, originRect.y + hash(vec2(tk, fi * 7.0 + 2.0)) * originRect.w * 0.8);
        vec2 b = a + vec2((hash(vec2(tk, fi * 7.0 + 3.0)) - 0.5) * 0.3, 0.12 + hash(vec2(tk, fi * 7.0 + 4.0)) * 0.2);
        float on = step(0.35, hash(vec2(tk, fi * 7.0 + 5.0)));
        float cc;
        float g = boltGlow(p, a, b, fi * 0.21 + tk * 0.013, cc);
        arcs += g * on;
        cores += cc * on;
    }
    float phaseA = ch * (1.0 - smoothstep(0.36, 0.44, t));
    vec3 light = elec * arcs * 1.4 * phaseA + vec3(1.0) * cores * phaseA * 1.2;
    vec2 cp = asp(cen);
    float dy = abs(uv.y - cen.y) * resolution.y;
    float lineGlow = exp(-dy / 6.0) * smoothstep(0.55, 0.66, t) * step(abs(uv.x - cen.x), 0.5 * sx + 0.002) * (1.0 - smoothstep(0.86, 0.92, t));
    float rr = length(p - cp);
    float dotg = exp(-rr * resolution.y / 8.0) * smoothstep(0.8, 0.88, t) * (1.0 - smoothstep(0.9, 1.0, t)) * 2.0;
    float tc = smoothstep(0.86, 1.0, t);
    float ring = exp(-pow((rr - tc * 0.25) * 60.0, 2.0)) * (1.0 - tc) * step(0.001, tc);
    light += elec * (lineGlow * 0.9 + ring * 0.8) + (elec + 0.5) * dotg;
    float inQ = boxMask(q);
    FRAG_COLOR = vec4(rgb * inQ + light, c.a * inQ) * qt_Opacity;
}
