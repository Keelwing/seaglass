// Ember, opening: a ring of fire spreads from the icon.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 p = asp(uv);
    vec2 o = asp(origin);
    vec2 v = p - o;
    float r = length(v);
    float M = maxDist(origin);
    float R = mix(t, easeOutCubic(t), 0.3) * (M + 0.11);
    // the fractal channel averages 0.35: centred there, the ring leaves the farthest corner at about 0.93
    float n = fbm(p * 1.6 + vec2(0.0, time * 0.6)) * 0.7 + fbm(p * 4.0 + vec2(0.0, time * 1.4)) * 0.3;
    float x = r - R + (n - 0.35) * 0.12;
    float inside = 1.0 - smoothstep(-0.01, 0.0, x);
    vec4 c = src(uv);
    // the warmth behind the ring cools off at the end, so that the app is as it is at 1
    float warm = exp(min(x, 0.0) * 14.0) * inside * (1.0 - smoothstep(0.85, 1.0, t));
    float band = exp(-x * x * 600.0);
    // 7 / 2 PI: the tile repeats a whole number of times around the ring, so there is no seam on its left
    float flick = fbm(vec2(atan(v.y, v.x) * 1.1141, r * 3.0 - time * 1.5));
    float heat = clamp(band * (0.7 + 0.6 * flick), 0.0, 1.0);
    vec3 light = fire(heat) * heat * 1.4 + fire(0.5) * warm * 0.35;
    vec2 dir = v / max(r, 0.0001);
    vec2 eg = (p - dir * time * 0.25) * 55.0;
    float es = step(0.992, hash(eg)) * (1.0 - smoothstep(0.1, 0.4, length(fract(eg) - 0.5)));
    light += fire(0.8) * es * smoothstep(0.0, 0.03, x) * (1.0 - smoothstep(0.03, 0.22, x)) * 1.6;
    FRAG_COLOR = vec4(c.rgb * inside * (1.0 - warm * 0.25) + light, c.a * inside) * qt_Opacity;
}
