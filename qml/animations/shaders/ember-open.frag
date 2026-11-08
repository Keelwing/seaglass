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
    // the noise moves the ring by -0.042 to 0.078: far outside it even the sparks are out, and far inside it the
    // warmth has fallen below half a level, whatever the noise
    float y = r - R;
    if (y > 0.262) {
        FRAG_COLOR = vec4(0.0);
        return;
    }
    // one read for all that can be inside the ring and a little further: a read beside pixels that skip it takes no
    // proper level from a mipmapped app (a still's), which would show as a line along the tier's edge
    vec4 c = y < 0.05 ? src(uv) : vec4(0.0);
    if (y < -0.45) {
        FRAG_COLOR = c * qt_Opacity;
        return;
    }
    // the fractal channel averages 0.35: centred there, the ring leaves the farthest corner at about 0.93
    float n = fbm(p * 1.6 + vec2(0.0, time * 0.6)) * 0.7 + fbm(p * 4.0 + vec2(0.0, time * 1.4)) * 0.3;
    float x = y + (n - 0.35) * 0.12;
    float inside = 1.0 - smoothstep(-0.01, 0.0, x);
    // the warmth behind the ring cools off at the end, so that the app is as it is at 1
    float warm = exp(min(x, 0.0) * 14.0) * inside * (1.0 - smoothstep(0.85, 1.0, t));
    vec3 light = vec3(0.0);
    // past 0.1 the band is below a hundredth of a level
    if (abs(x) < 0.1) {
        float band = exp(-x * x * 600.0);
        // 7 / 2 PI: the tile repeats a whole number of times around the ring, so there is no seam on its left
        float flick = fbm(vec2(atan(v.y, r > 0.0 ? v.x : 1.0) * 1.1141, r * 3.0 - time * 1.5));
        float heat = clamp(band * (0.7 + 0.6 * flick), 0.0, 1.0);
        light = fire(heat) * heat * 1.4;
    }
    if (warm > 0.0)
        light += fire(0.5) * warm * 0.35;
    if (x > 0.0 && x < 0.22) {
        vec2 dir = v / max(r, 0.0001);
        vec2 eg = (p - dir * time * 0.25) * 55.0;
        if (hash(eg) >= 0.992)
            light += fire(0.8) * (1.0 - smoothstep(0.1, 0.4, length(fract(eg) - 0.5)))
                     * smoothstep(0.0, 0.03, x) * (1.0 - smoothstep(0.03, 0.22, x)) * 1.6;
    }
    FRAG_COLOR = vec4(c.rgb * inside * (1.0 - warm * 0.25) + light, c.a * inside) * qt_Opacity;
}
