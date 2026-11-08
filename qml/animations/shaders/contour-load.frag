// Contour, loading: the icon sends out round lines over a dark cover, as a beacon does, fainter as they go.
void main()
{
    vec2 uv = qt_TexCoord0;
    float d;
    float inside = cardInside(d);
    vec2 v = asp(uv - vec2(0.5, 0.46));
    float r = length(v);
    float x = r * 13.0 - time * 1.1;
    float f = fract(x);
    float line = 1.0 - smoothstep(0.0, resolution.y * 0.001 + 1.0, min(f, 1.0 - f) / 13.0 * resolution.y);
    float fall = 1.0 - smoothstep(0.1, 0.6, r);
    line *= fall * fall * 0.95;
    vec3 ink = mix(vec3(0.42, 0.72, 0.98), tint, useTint);
    vec3 glass = mix(ink * 0.18 + 0.03, ink * 0.06 + 0.01, uv.y) * 0.65;
    vec4 col = vec4(glass * (1.0 - line) + ink * line, 0.65 + 0.35 * line);
    vec4 icon = iconAt(vec2(0.5, 0.46), 0.42 * resolution.x, vec2(0.0));
    FRAG_COLOR = (icon + col * (1.0 - icon.a)) * inside * qt_Opacity;
}
