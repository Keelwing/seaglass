// Tide, opening: a drop lands on the icon and throws a crown of droplets; the app spreads in its ripple. The rings
// bend the picture a little and catch the light on one side.
void main()
{
    vec2 uv = qt_TexCoord0;
    float t = progress;
    vec2 p = asp(uv);
    vec2 o = asp(origin);
    vec2 v = p - o;
    float r = length(v);
    float M = maxDist(origin) + 0.05;
    float R = mix(t, easeOutCubic(t), 0.35) * M;
    float x = r - R;
    // the crown's glint and droplets stay this near the icon
    bool crown = t < 0.3 && r < 0.11;
    // ahead of the water, and away from the crown: the home screen
    if (x > 0.02 && !crown) {
        FRAG_COLOR = vec4(0.0);
        return;
    }
    // the drop lands over the first frames, so frame 0 is still the home screen
    float land = smoothstep(0.0, 0.03, t);
    float settle = 1.0 - smoothstep(0.8, 1.0, t);
    vec3 water = tinted(vec3(0.75, 0.95, 1.0));
    float alpha = (1.0 - smoothstep(-0.006, 0.006, x)) * land;
    vec3 col = vec3(0.0);
    float ca = 0.0;
    // a little past where alpha ends: a still's app has mipmaps, and a read's level comes from the pixels around it,
    // which must read too
    if (x < 0.02) {
        vec2 dir = v / max(r, 0.0001);
        // the ripple's slope: a swell at the front, under a ten-millionth past 0.3, and a train of rings behind it that
        // dies away
        float env = x < 0.0 ? exp(x * 6.0) * 0.8 : 0.0;
        if (x > -0.3)
            env += exp(-x * x * 180.0);
        float slope = cos(x * 110.0) * env * settle * (1.0 - 0.6 * t);
        vec4 c = src(uv - vec2(dir.x / aspect, dir.y) * slope * 0.0025);
        // lit from the top left: one side of each ring bright, the other in shade
        float shade = slope * dot(dir, vec2(-0.6, -0.8));
        float lit = max(shade, 0.0);
        col = (c.rgb * (1.0 + 0.5 * shade) + water * lit * lit * lit * 0.45 * c.a) * alpha;
        ca = c.a;
    }
    // a thin, faint line where the water meets the home screen, below a millionth of a level past 0.015
    float seam = x * 300.0;
    if (abs(seam) < 4.5)
        col += water * exp(-seam * seam) * settle * 0.3 * land;
    // the impact: a soft glint and a crown of droplets thrown out from the icon
    if (crown) {
        float tc = t / 0.3;
        float pxu = 1.0 / resolution.y;
        float drops = 0.0;
        for (int i = 0; i < 10; i++) {
            float fi = float(i);
            float angle = (fi + hash(vec2(fi, 5.0)) * 0.6) * 0.628;
            vec2 at = vec2(cos(angle), sin(angle)) * (0.012 + (0.05 + 0.04 * hash(vec2(fi, 9.0))) * easeOutCubic(tc));
            float size = pxu * mix(7.0, 2.0, tc);
            drops += 1.0 - smoothstep(size * 0.3, size, length(v - at));
        }
        float glint = exp(-r * r * 6000.0) * (1.0 - smoothstep(0.0, 0.12, t)) * 0.7;
        col += water * (glint + drops * (1.0 - tc) * 0.8) * land;
    }
    FRAG_COLOR = vec4(col, ca * alpha) * qt_Opacity;
}
