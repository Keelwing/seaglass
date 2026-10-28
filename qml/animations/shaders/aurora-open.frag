// Northern lights, opening: a thin ray rises from the icon into the sky, and curtains of light sweep down, first
// above it and then all along, and leave the app behind them.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 p = asp(uv);
    vec2 o = asp(origin);
    // the front leads above the icon, and the sides catch up by 0.85
    float lag = 0.3 * smoothstep(0.0, 0.7, abs(p.x - o.x)) * (1.0 - smoothstep(0.35, 0.85, t));
    float edge = -0.25 + t * 1.55 - lag + 0.05 * sin(p.x * 9.0 + t * 4.0)
               + (fbm(vec2(p.x * 1.1, t * 0.4)) - 0.5) * 0.12;
    float dy = edge - uv.y;
    float reveal = smoothstep(0.0, 0.22, dy);
    vec4 app = src(uv);
    float ray = rays(p, time + t * 2.0);
    float fadeOut = 1.0 - smoothstep(0.65, 1.0, t);
    float I = (dy > 0.0 ? rayFade(p, dy) * 1.3 : exp(dy * 55.0)) * ray * fadeOut;
    vec3 light = aurora(clamp(dy * 2.0, 0.0, 1.0)) * I + fringe() * exp(-abs(dy + 0.012) * 90.0) * ray * fadeOut * 0.35;
    // the ray from the icon: up to the top by 0.12, gone by 0.35, and a glow where it starts
    float top = mix(origin.y, 0.0, smoothstep(0.0, 0.12, t));
    float span = smoothstep(top - 0.01, top + 0.03, uv.y) * (1.0 - smoothstep(origin.y - 0.02, origin.y + 0.01, uv.y));
    float dx = p.x - o.x;
    float beam = (exp(-dx * dx * 9000.0) + exp(-dx * dx * 500.0) * 0.25) * span * (1.0 - smoothstep(0.12, 0.35, t));
    float glow = exp(-dot(p - o, p - o) * 900.0) * smoothstep(0.0, 0.04, t) * (1.0 - smoothstep(0.04, 0.2, t));
    light += aurora(0.1) * (beam * 0.9 + glow * 0.6);
    float veil = (1.0 - reveal) * 0.28 * (1.0 - smoothstep(0.7, 1.0, t)) * smoothstep(0.0, 0.1, t);
    vec2 g = floor(uv * resolution / 2.0);
    float star = step(0.996, hash(g)) * veil * 3.0 * (0.5 + 0.5 * sin(time * 6.0 + hash(g + 3.0) * 20.0));
    vec3 col = app.rgb * reveal + light + vec3(star);
    float a = app.a * reveal + veil * (1.0 - reveal);
    FRAG_COLOR = vec4(col, a) * qt_Opacity;
}
