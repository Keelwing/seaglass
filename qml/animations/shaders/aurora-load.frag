// Northern lights, loading: an aurora over a night-sky cover.
void main()
{
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * resolution;
    vec2 p = asp(uv);
    float d;
    float inside = cardInside(d);
    vec4 col = vec4(mix(vec3(0.02, 0.05, 0.12), vec3(0.01, 0.02, 0.05), uv.y) * 0.88, 0.88);
    vec2 g = floor(px / 2.0);
    float st = step(0.994, hash(g)) * (0.4 + 0.6 * sin(time * 3.0 + hash(g + 7.0) * 20.0));
    col.rgb += vec3(st) * 0.8 * (1.0 - uv.y);
    float edge = 0.62 + 0.07 * sin(uv.x * 6.0 + time * 1.2) + 0.05 * sin(uv.x * 13.0 - time * 0.8);
    float dy = edge - uv.y;
    float I = (dy > 0.0 ? exp(-dy * 3.5) : exp(dy * 28.0)) * rays(p * vec2(1.6, 1.0), time * 1.5);
    vec3 light = aurora(clamp(dy * 1.4, 0.0, 1.0)) * I * 0.9;
    vec4 icon = iconAt(vec2(0.5, 0.40), 0.40 * resolution.x, vec2(0.0));
    col = vec4(icon.rgb * 0.6, icon.a) + col * (1.0 - icon.a);
    col.rgb += light * (1.0 - icon.a * 0.5);
    FRAG_COLOR = col * inside * qt_Opacity;
}
