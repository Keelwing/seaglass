// Volt, loading: arcs run around the cover; now and then a strike.
void main()
{
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * resolution;
    vec2 p = asp(uv);
    float d;
    float inside = cardInside(d);
    vec3 elec = tinted(vec3(0.55, 0.75, 1.0));
    float cyc = 1.1;
    float ph = fract(time / cyc);
    float seed = floor(time / cyc) * 0.123 + floor(time * 20.0) * 0.011;
    float strike = 1.0 - smoothstep(0.0, 0.18, ph);
    vec4 icon = iconAt(vec2(0.5, 0.5), 0.44 * resolution.x, vec2(0.0));
    icon.rgb *= 0.75 + strike * 0.9;
    vec4 col = icon + vec4(vec3(0.03, 0.05, 0.10) * 0.75, 0.75) * (1.0 - icon.a);
    vec2 v = px - resolution * 0.5;
    float ang = atan(v.y, v.x);
    float bd = abs(d + 3.0);
    float tick = floor(time * 18.0);
    float n = fbm(vec2(ang * 0.9 + time * 0.9, time * 0.37 + tick * 0.07));
    float crackle = 0.55 + 0.45 * hash(vec2(floor(ang * 24.0), tick));
    float wob = (vnoise(vec2(ang * 3.0, time * 2.0 + tick * 0.1)) - 0.5) * 5.0;
    float bw = abs(d + 3.0 + wob);
    float arc = (exp(-bw / 1.3) * smoothstep(0.42, 0.68, n) * 1.6 + exp(-bd / 10.0) * 0.35 * smoothstep(0.35, 0.75, n)) * crackle;
    float core;
    float g = boltGlow(p, vec2(aspect * (0.35 + hash(vec2(floor(time / cyc), 3.0)) * 0.3), 0.0), vec2(aspect * 0.5, 0.31), seed, core);
    vec3 light = elec * (arc * 1.5 + g * strike * 1.2) + vec3(1.0) * core * strike * 1.4;
    col.rgb += light;
    col.a = max(col.a, clamp(arc, 0.0, 1.0));
    FRAG_COLOR = col * inside * qt_Opacity;
}
