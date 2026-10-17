// Seaglass, loading: a glass cover in the ambience's colour; the icon breathes and a glint crosses it.
void main()
{
    vec2 uv = qt_TexCoord0;
    float d;
    float inside = cardInside(d);
    float breath = 0.5 + 0.5 * sin(time * PI);
    vec3 glass = mix(tint * 0.30 + 0.06, tint * 0.12 + 0.02, uv.y);
    float ga = 0.40 + 0.08 * breath;
    vec4 col = vec4(glass * ga, ga);
    vec4 icon = iconAt(vec2(0.5, 0.46), 0.46 * resolution.x * (0.97 + 0.03 * breath), vec2(0.0));
    col = icon + col * (1.0 - icon.a);
    float ph = fract(time / 1.9);
    float band = (uv.x * 0.55 + uv.y * 0.45) - mix(-0.35, 1.35, ph);
    float glint = exp(-band * band * 70.0);
    col.rgb += vec3(1.0) * glint * (0.10 + 0.30 * icon.a);
    float rim = 1.0 - smoothstep(0.0, 1.6, abs(d + 0.8));
    col.rgb += tint * rim * 0.7;
    col.a = max(col.a, rim * 0.7);
    FRAG_COLOR = col * inside * qt_Opacity;
}
