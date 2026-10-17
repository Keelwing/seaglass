// Tide, loading: water rises in the cover, bubbles and all.
void main()
{
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * resolution;
    float d;
    float inside = cardInside(d);
    float level = 0.16 + 0.64 * (1.0 - exp(-time / 2.2));
    float surf = 1.0 - level + 0.018 * sin(uv.x * 11.0 + time * 3.1) + 0.010 * sin(uv.x * 23.0 - time * 4.7);
    float under = smoothstep(surf - 0.004, surf + 0.004, uv.y);
    vec2 off = under * vec2(sin(uv.y * 40.0 + time * 3.0), cos(uv.x * 35.0 + time * 2.0)) * 0.012;
    vec4 icon = iconAt(vec2(0.5, 0.46), 0.46 * resolution.x, off);
    vec4 col = vec4(mix(vec3(0.06, 0.09, 0.12), vec3(0.03, 0.05, 0.07), uv.y) * 0.55, 0.55);
    col = icon + col * (1.0 - icon.a);
    vec3 tone = tinted(vec3(0.10, 0.50, 0.70));
    vec2 cq = asp(uv) * 1.6 + vec2(time * 0.05, -time * 0.12) + (vec2(fbm(uv + time * 0.05), fbm(uv + 0.5 - time * 0.05)) - 0.5) * 0.2;
    float caust = (1.0 - smoothstep(0.0, 0.07, cells(cq))) * (0.3 + 0.7 * fbm(asp(uv) * 1.5 + time * 0.1));
    vec3 w = tone * 0.9 + caust * 0.25;
    float wa = under * 0.55;
    col.rgb = col.rgb * (1.0 - wa) + w * wa;
    col.a = col.a + wa * (1.0 - col.a);
    float line = exp(-pow((uv.y - surf) * resolution.y, 2.0) * 0.25);
    col.rgb += vec3(0.8, 0.95, 1.0) * line * 0.7;
    vec2 bg = vec2(uv.x * 14.0, uv.y * 14.0 * resolution.y / resolution.x + time * 1.6);
    vec2 f = fract(bg) - 0.5;
    float bub = step(0.9, hash(floor(bg))) * (1.0 - smoothstep(0.12, 0.2, length(f))) * under;
    col.rgb += vec3(0.85, 0.95, 1.0) * bub * 0.6;
    FRAG_COLOR = col * inside * qt_Opacity;
}
