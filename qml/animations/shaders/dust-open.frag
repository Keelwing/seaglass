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
    vec2 v = (asp(uv) - sw.xy) * resolution.y;
    float r = length(v);
    // how long ago the ring passed this pixel, before the noise, which moves a start by -0.045 to 0.093 (the tile's
    // fractal channel ends at 248 of 255). A grain's cell is at most slack from where it covers
    float past = k - r / resolution.y * sw.z - sw.w;
    float slack = -sw.z * gp / resolution.y;
    vec4 fly = vec4(0.0);
    if (part != 1.0) {
        vec3 tone = tinted(vec3(0.86, 0.72, 0.52));
        // no grain has come here yet, or the last has gone: it flies for 0.4 and up to 0.286 of the height, over
        // which the ring's start changes by its slope
        if (past > -0.046 - slack && past < 0.494 - sw.z * 0.286 + slack) {
            // grains show for most of their flight, so the sand blows in from the start
            fly = grains(uv, k, gp, sw, 0.05, normalize(vec2(1.0, -0.6)), vec2(0.0, -0.6), 0.4, tone, 0.35, 0.7);
            fly.rgb *= 1.15;
        }
        // until the first grains come, a puff of sand out of the icon's rim: specks on rays from it, each ray at
        // its own speed, 0.2 to 0.6 of the height per progress. Past three widths of the Gaussian it adds nothing a
        // screen shows
        if (progress < 0.25) {
            float rim = max(radiusPx * 0.8, gp * 3.0);
            float w = resolution.y * (0.02 + 0.2 * progress);
            if (r >= rim + progress * resolution.y * 0.2 && r < rim + progress * resolution.y * 0.6 + 3.0 * w) {
                float turn = (atan(v.y, r > 0.0 ? v.x : 1.0) / (2.0 * PI) + 0.5) * 72.0;
                float ray = floor(turn);
                float s = r - rim - progress * resolution.y * (0.2 + 0.4 * hash(vec2(ray, 7.0)));
                float n = floor(s / gp);
                float hs = gp * (0.25 + 0.2 * hash(vec2(n, ray + 3.0)));
                float g = step(0.7, hash(vec2(ray, n))) * step(0.0, s);
                g *= step(abs(fract(s / gp) - 0.5) * gp, hs) * step(abs(fract(turn) - 0.5) * 2.0 * PI * r / 72.0, hs);
                float a = g * exp(-s * s / (w * w)) * (1.0 - smoothstep(0.06, 0.25, progress));
                fly = vec4(tone, 1.0) * a + fly * (1.0 - a);
            }
        }
    }
    // the noise decides only within its own reach of the ring
    vec4 base = vec4(0.0);
    if (part != 2.0 && past < 0.093 + slack) {
        if (past < -0.046 - slack || k < grainStart(floor(uv * resolution / gp), gp, sw, 0.05))
            base = src(uv);
    }
    FRAG_COLOR = (fly + base * (1.0 - fly.a)) * qt_Opacity;
}
