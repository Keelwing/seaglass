// Northern lights, opening: curtains of light sweep down and leave the app behind.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 p = asp(uv);
    float edge = -0.25 + t * 1.55 + 0.05 * sin(p.x * 9.0 + t * 4.0) + (fbm(vec2(p.x * 1.1, t * 0.4)) - 0.5) * 0.12;
    float dy = edge - uv.y;
    float reveal = smoothstep(0.0, 0.22, dy);
    vec4 app = src(uv);
    float ray = rays(p, time + t * 2.0);
    float I = (dy > 0.0 ? exp(-dy * 5.0) : exp(dy * 55.0)) * ray * (1.0 - smoothstep(0.65, 1.0, t)) * 1.3;
    vec3 light = aurora(clamp(dy * 2.0, 0.0, 1.0)) * I;
    float veil = (1.0 - reveal) * 0.28 * (1.0 - smoothstep(0.7, 1.0, t)) * smoothstep(0.0, 0.1, t);
    vec2 g = floor(uv * resolution / 2.0);
    float star = step(0.996, hash(g)) * veil * 3.0 * (0.5 + 0.5 * sin(time * 6.0 + hash(g + 3.0) * 20.0));
    vec3 col = app.rgb * reveal + light + vec3(star);
    float a = app.a * reveal + veil * (1.0 - reveal);
    FRAG_COLOR = vec4(col, a) * qt_Opacity;
}
