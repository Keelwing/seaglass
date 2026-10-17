// Frost, loading: frost grows over the cover and thaws.
void main()
{
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * resolution;
    vec2 p = asp(uv);
    float d;
    float inside = cardInside(d);
    float cyc = 3.0;
    float ph = fract(time / cyc);
    float grow = smoothstep(0.0, 0.6, ph) * (1.0 - smoothstep(0.8, 1.0, ph));
    vec2 q = min(uv, 1.0 - uv);
    float ed = min(q.x * aspect, q.y);
    float n = fbm(p * 2.0 + floor(time / cyc) * 0.37);
    float fr = frostPat(p * 0.9);
    float frozen = 1.0 - smoothstep(-0.01, 0.01, ed + (n - 0.5) * 0.12 - grow * 0.22);
    vec4 icon = iconAt(vec2(0.5, 0.46), 0.46 * resolution.x, vec2(0.0));
    vec4 col = icon + vec4(vec3(0.05, 0.08, 0.12) * 0.6, 0.6) * (1.0 - icon.a);
    vec3 ice = mix(col.rgb, tinted(vec3(0.82, 0.93, 1.0)) * (0.5 + 0.5 * fr), frozen * (0.45 + 0.5 * fr));
    vec2 g = floor(px / 2.0);
    float sp = step(0.992, hash(g)) * (0.5 + 0.5 * sin(time * 7.0 + hash(g + 5.0) * 30.0)) * frozen;
    col.rgb = ice + sp * 0.8;
    col.a = max(col.a, frozen * 0.8);
    FRAG_COLOR = col * inside * qt_Opacity;
}
