// Frost, loading: frost grows over the cover from its edges, and thaws again.
void main()
{
    vec2 uv = qt_TexCoord0;
    vec2 p = asp(uv);
    float d;
    float inside = cardInside(d);
    float cyc = 3.0;
    float ph = fract(time / cyc);
    float grow = smoothstep(0.0, 0.6, ph) * (1.0 - smoothstep(0.8, 1.0, ph));
    // a new shape every cycle, while nothing is frozen. The cover is about a quarter of the screen high: the frost is
    // drawn at the screen's scale (finer, the noise tile would show its texels)
    vec2 q = p * 0.3 + floor(time / cyc) * vec2(0.37, 0.21);
    float ed = (-d) / resolution.y;
    // the front: ragged at two scales (centred: the fractal channel averages 0.35). It stops short of the icon's
    // middle. With no growth there is no frost at all, so that the cycles meet without a seam
    float n = fbm(q * 4.0);
    float fd = ed - grow * 0.2 + ((n - 0.35) * 0.1 + (fbm(q * 15.0 + 0.5) - 0.35) * 0.03) * smoothstep(0.0, 0.15, grow);
    float frozen = 1.0 - smoothstep(-0.008, 0.0, fd);
    // thick along the edges, thin at the front
    float thick = (1.0 - smoothstep(0.0, 0.16, ed + (n - 0.35) * 0.1)) * smoothstep(0.0, 0.08, -fd);
    float fr = frostPat(q, thick);
    // behind the frost the icon is blurred a little, as through frosted glass
    vec2 bend = (vec2(vnoise(q * 10.0), vnoise(q * 10.0 + 0.5)) - 0.5) * 0.05 * frozen;
    vec4 icon = iconAt(vec2(0.5, 0.46), 0.46 * resolution.x, bend);
    vec4 col = icon + vec4(vec3(0.05, 0.08, 0.12) * 0.6, 0.6) * (1.0 - icon.a);
    float a = max(col.a, frozen * 0.85);
    col.rgb = mix(col.rgb, iced(vec4(col.rgb / max(col.a, 0.001), 1.0), fr) * a, frozen);
    // a bright rime along the front (it comes and goes with the frost: switched on and off, it would flash on the
    // cover's edge where the cycles meet), and glints on the dense frost
    float fdp = fd * resolution.y / 3.0;
    col.rgb += tinted(vec3(0.9, 0.97, 1.0)) * exp(-fdp * fdp) * 0.6 * smoothstep(0.0, 0.08, grow);
    vec2 g = floor(uv * resolution / 2.0);
    float sp = step(0.99, hash(g)) * (0.5 + 0.5 * sin(time * 7.0 + hash(g + 5.0) * 30.0)) * frozen * smoothstep(0.6, 0.8, fr);
    col.rgb += tinted(vec3(0.9, 0.97, 1.0)) * sp * 0.8;
    col.a = a;
    FRAG_COLOR = col * inside * qt_Opacity;
}
