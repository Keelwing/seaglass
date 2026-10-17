// Shatter, loading: cracks run through the cover and fill with gold.
void main()
{
    vec2 uv = qt_TexCoord0;
    vec2 p = asp(uv);
    float d;
    float inside = cardInside(d);
    float cyc = 2.6;
    float ph = fract(time / cyc);
    float sd = floor(time / cyc);
    vec2 o = vec2(aspect * (0.25 + 0.5 * hash(vec2(sd, 1.0))), 0.25 + 0.5 * hash(vec2(sd, 2.0)));
    float e = cells(p * 0.9 + vec2(sd * 0.37, sd * 0.71));
    float line = 1.0 - smoothstep(0.0, 0.035, e);
    float reach = smoothstep(0.0, 0.45, ph) * 0.9;
    float on = 1.0 - smoothstep(reach - 0.05, reach, length(p - o));
    float heal = 1.0 - smoothstep(0.7, 1.0, ph);
    vec3 gold = mix(vec3(1.0, 0.78, 0.36), tint, 0.25 + 0.5 * useTint);
    vec4 icon = iconAt(vec2(0.5, 0.46), 0.46 * resolution.x, vec2(0.0));
    vec4 col = icon + vec4(vec3(0.04, 0.05, 0.07) * 0.7, 0.7) * (1.0 - icon.a);
    float seam = line * on * heal;
    float shimmer = 0.6 + 0.4 * sin(time * 5.0 + (p.x + p.y) * 20.0);
    col.rgb = mix(col.rgb, gold * col.a, seam * 0.85) + gold * seam * shimmer * 0.5;
    col.a = max(col.a, seam);
    FRAG_COLOR = col * inside * qt_Opacity;
}
