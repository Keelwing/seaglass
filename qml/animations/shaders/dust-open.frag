// Dust, opening: sand blows in and settles into the app, from the icon outward.
void main()
{
    vec2 uv = qt_TexCoord0;
    float k = 1.0 - progress;
    float gp = max(2.0, resolution.y / 300.0);
    // start: at most 0.6 at the icon down to 0 at the farthest corner, at an even pace: a grain flies for 0.4
    // before it lands, so none shows at progress 0 and the last one lands at 1
    float M = maxDist(origin);
    vec4 sw = vec4(asp(origin), -0.47 / M, 0.505);
    vec3 tone = tinted(vec3(0.86, 0.72, 0.52));
    vec4 fly = vec4(0.0);
    if (part != 1.0) {
        // grains show for most of their flight, so the sand blows in from the start
        fly = grains(uv, k, gp, sw, 0.05, normalize(vec2(1.0, -0.6)), vec2(0.0, -0.6), 0.4, tone, 0.35, 0.7);
        fly.rgb *= 1.15;
        // until the first grains come, a puff of sand out of the icon's rim: specks on rays from it, each ray at
        // its own speed
        if (progress < 0.25) {
            vec2 v = (asp(uv) - asp(origin)) * resolution.y;
            float r = length(v);
            float turn = (atan(v.y, v.x) / (2.0 * PI) + 0.5) * 72.0;
            float ray = floor(turn);
            float s = r - max(radiusPx * 0.8, gp * 3.0) - progress * resolution.y * (0.2 + 0.4 * hash(vec2(ray, 7.0)));
            float n = floor(s / gp);
            float hs = gp * (0.25 + 0.2 * hash(vec2(n, ray + 3.0)));
            float g = step(0.7, hash(vec2(ray, n))) * step(0.0, s);
            g *= step(abs(fract(s / gp) - 0.5) * gp, hs) * step(abs(fract(turn) - 0.5) * 2.0 * PI * r / 72.0, hs);
            float a = g * exp(-s * s / pow(resolution.y * (0.02 + 0.2 * progress), 2.0))
                    * (1.0 - smoothstep(0.06, 0.25, progress));
            fly = vec4(tone, 1.0) * a + fly * (1.0 - a);
        }
    }
    vec4 base = part != 2.0 && k < grainStart(floor(uv * resolution / gp), gp, sw, 0.05) ? src(uv) : vec4(0.0);
    FRAG_COLOR = (fly + base * (1.0 - fly.a)) * qt_Opacity;
}
